"""AI15: doğrulanmayan taramada sikke lejantını Claude görme ile okur.

VARSAYILAN KAPALI. İkisi birden yoksa hiçbir görsel dışarı gitmez, SDK içe aktarılmaz:
  bayrak  /app/index/lejant.on                     (host: /opt/ai_service/index/lejant.on; her istekte bakılır, silmek = kapatmak)
  anahtar /app/credentials/anthropic_lejant.key    (host: /opt/ai_service/credentials/)
Açmadan önce gizlilik metni ve mağaza veri beyanları güncellenmeli: görsel Anthropic'e gider.

Hiçbir hata tanımayı bozmaz: kapalı, sınır dolu, zaman aşımı ya da okuma hatasında None döner.
/recognize herkese açık olduğundan günlük görsel sınırı var (GUNLUK_GORSEL), süreç içinde sayılır (tek uvicorn işçisi).
Ölçüm: claudedocs/ai_lejant_2026-11-01/README.md. Komut istemi `scripts/ai_eval/lejant_claude.py` ile ortak: burayı değiştiren yeniden ölçer.
"""
import base64
import json
import logging
import os
import re
import sys
import threading
import unicodedata
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

FLAG = "/app/index/lejant.on"
KEY_FILE = "/app/credentials/anthropic_lejant.key"
PYLIB = os.environ.get("LEJANT_PYLIB", "/opt/pylib_lejant")   # anthropic SDK; ana ortamın paketleriyle karışmaz
MODEL = "claude-opus-5-5"
EFFORT = "low"
MAX_KENAR = 1024
TIMEOUT_S = 12.0
GUNLUK_GORSEL = int(os.environ.get("LEJANT_GUNLUK", "1000"))   # ~8,6 $/gün tavan (ölçülen ~0,0086 $/görsel)
GUVEN = ("medium", "high")

SISTEM = """You read the inscriptions (legends) on photographs of ancient coins.

Report only what is physically legible on the coin in this photo. Transcribe the letters you can actually see, in their original script, and use a dot for each letter you cannot read. Do not complete a legend from your memory of similar coins.

legend_read holds only the transcribed letters, exactly as they stand on the coin, with no explanation, no field names and no words of your own; leave it empty when nothing is legible. Any comment goes in note.

Then decide whether the letters you read name a ruler or another person who issued or is portrayed on the coin. Base that decision on the letters alone, never on the portrait, the style, the design or what the coin looks like. If the legend names a city or people rather than a person, or too little is legible to name anyone, set ruler_from_legend to null: an honest null is the correct answer and a guess is the worst one.

Give the person's usual English name, with a regnal number only if the letters establish it. Confidence: high when the name is spelled out clearly enough that no other person fits, medium when a few letters are missing but one person clearly fits, low otherwise."""

SEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["legend_read", "legibility", "ruler_from_legend", "confidence", "note"],
    "properties": {
        "legend_read": {"type": "string"},
        "legibility": {"type": "string", "enum": ["none", "partial", "clear"]},
        "ruler_from_legend": {"type": ["string", "null"]},
        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
        "note": {"type": "string"},
    },
}

_kilit = threading.Lock()
_gun, _sayac = None, 0
_istemci = None
_istemci_hata = False
_havuz = ThreadPoolExecutor(2, thread_name_prefix="lejant")


# ---- saf karar (Claude'suz sınanır) ----
def _norm(s: str) -> str:
    s = unicodedata.normalize("NFD", s or "").lower()
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z]", "", s.replace("v", "u").replace("j", "i"))


def kok(ad: Optional[str]) -> str:
    """Kişi karşılaştırma kökü: Constantine / Constantius ayrılır, Maximian / Maximinus ayrılır."""
    t = (ad or "").split()
    if not t:
        return ""
    n = _norm(t[0])
    return n[:10] if n.startswith("constan") else n[:7]


def temiz_metin(y: Optional[Dict[str, Any]]) -> Optional[str]:
    """Karta yalnız lejant harfleri çıkar: model alanı açıklamayla doldurduysa gösterilmez."""
    s = ((y or {}).get("legend_read") or "").strip()
    if not s or len(s) > 120 or re.search(r"[a-z]{3}", s):
        return None
    return s


def birlestir(on: Optional[Dict[str, Any]], ark: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """İki yüzün okumasından kart içeriği. Orta/yüksek güvenle kişi yoksa ya da yüzler çelişiyorsa None (kart çıkmaz)."""
    aday = [(y["ruler_from_legend"], y.get("confidence")) for y in (on, ark)
            if y and y.get("ruler_from_legend") and y.get("confidence") in GUVEN]
    if len({kok(a) for a, _ in aday}) > 1:              # çelişki: yalnız tek yüz yüksek güvenliyse o kazanır
        aday = [(a, g) for a, g in aday if g == "high"]
    if not aday or len({kok(a) for a, _ in aday}) != 1:
        return None
    kisi = max(aday, key=lambda x: (x[1] == "high", len(x[0])))
    return {"obverse": temiz_metin(on), "reverse": temiz_metin(ark), "person": kisi[0], "confidence": kisi[1]}


# ---- dış çağrı ----
def etkin() -> bool:
    return os.path.exists(FLAG) and os.path.exists(KEY_FILE)


def _bugun_izin(n: int) -> bool:
    global _gun, _sayac
    bugun = datetime.now(timezone.utc).date()
    with _kilit:
        if bugun != _gun:
            _gun, _sayac = bugun, 0
        if _sayac + n > GUNLUK_GORSEL:
            return False
        _sayac += n
    return True


def _istemci_al():
    global _istemci, _istemci_hata
    if _istemci is not None or _istemci_hata:
        return _istemci
    with _kilit:
        if _istemci is None and not _istemci_hata:
            try:
                if PYLIB and os.path.isdir(PYLIB) and PYLIB not in sys.path:
                    sys.path.append(PYLIB)
                import anthropic
                with open(KEY_FILE, encoding="utf-8") as f:
                    anahtar = f.read().strip()
                _istemci = anthropic.Anthropic(api_key=anahtar, timeout=TIMEOUT_S, max_retries=0)
            except Exception as e:                       # süreç boyunca kapalı: her istekte yeniden deneme yok
                _istemci_hata = True
                logger.error("AI15 lejant: istemci kurulamadı, kapalı: %s" % e, exc_info=True)
    return _istemci


def _jpeg_b64(bgr) -> str:
    import cv2
    h, w = bgr.shape[:2]
    s = MAX_KENAR / max(h, w)
    if s < 1:
        bgr = cv2.resize(bgr, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
    ok, b = cv2.imencode(".jpg", bgr, [cv2.IMWRITE_JPEG_QUALITY, 88])
    if not ok:
        raise ValueError("jpeg")
    return base64.standard_b64encode(b.tobytes()).decode()


def _oku(client, bgr) -> Optional[Dict[str, Any]]:
    r = client.beta.messages.create(
        model=MODEL,
        max_tokens=4000,
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
        system=SISTEM,
        output_config={"effort": EFFORT, "format": {"type": "json_schema", "schema": SEMA}},
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": _jpeg_b64(bgr)}},
            {"type": "text", "text": "Read the legend on this coin."},
        ]}],
    )
    if r.stop_reason in ("refusal", "max_tokens"):
        logger.warning("AI15 lejant: stop_reason=%s" % r.stop_reason)
        return None
    metin = next((b.text for b in r.content if b.type == "text"), "")
    return json.loads(metin)


def oku_yuzler(yuzler: List[Any]) -> Optional[Dict[str, Any]]:
    """yuzler: [ön yüz BGR, arka yüz BGR] (None olabilir). Kart içeriği ya da None. İstisna fırlatmaz."""
    try:
        if not etkin():
            return None
        var = [y for y in yuzler if y is not None]
        if not var or not _bugun_izin(len(var)):
            return None
        client = _istemci_al()
        if client is None:
            return None

        def tek(bgr):
            if bgr is None:
                return None
            try:
                return _oku(client, bgr)
            except Exception as e:                       # bir yüz düşse de öteki kullanılır
                logger.warning("AI15 lejant: okuma hatası: %s" % str(e)[:200])
                return None

        sonuc = list(_havuz.map(tek, (list(yuzler) + [None, None])[:2]))
        return birlestir(sonuc[0], sonuc[1])
    except Exception as e:
        logger.error("AI15 lejant: %s" % e, exc_info=True)
        return None
