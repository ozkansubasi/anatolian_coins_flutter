"""AI12 / ADR-009 — modern Türk parası kapısı (servis içi).

Eşleşme bulunamadığında (`no_match`) fotoğraftaki yazı okunur; Latin harfli Cumhuriyet parası (lira / kuruş / Yeni Türk
Lirası) ise yanıt "eşleşme yok" yerine `no_match_reason=modern_coin` olur. Kural seti ölçüm betiğindeki `kapi.py`
kural **v2** ile birebir aynıdır (scripts/ai_eval/modern_kapi/; ölçüm: antik yanlış alarm 0/2.359, modern yakalama %76 —
claudedocs/ai-modern-para-kapisi-olcum-2026-10-14.md). Kuralı burada değiştirme: önce kapi.py'de ölç.

Korumalar (ADR-009 K1):
  * açma / kapama: bayrak dosyası FLAG (konteynere bağlı index dizininde; her istekte bakılır → restart gerekmez,
    geri alma = dosyayı silmek) ya da ortam değişkeni MODERN_GATE=1 (atılabilir sınama konteyneri). Canlı konteyner
    yeniden YARATILMAZ (pip kurulumları + şema yazılabilir katmanda) → ortam değişkeni canlıda eklenemez.
  * kapalıyken hiçbir şey yüklenmez, `kontrol` hep None döner (bugünkü davranış)
  * OCR motoru ilk ihtiyaçta yüklenir; yükleme başarısızsa kapı süreç boyunca kapanır (her istekte yeniden denenmez)
  * aynı anda tek OCR: kilit LOCK_WAIT_S içinde alınamazsa kapı atlanır
  * süre bütçesi BUDGET_S: her geçişten önce bakılır; aşılınca o ana kadar okunanla karar verilir (karar tekdüze: metin
    eklemek kanıtı yalnız artırır → kısmi okuma ölçülen kuraldan daha fazla yanlış alarm üretemez)
  * hiçbir hata tanımayı düşürmez: `kontrol` istisna fırlatmaz (fail-open → çağıran bugünkü yanıtı döner)
Gizlilik: görsel ve OCR metni saklanmaz / loglanmaz; log yalnız kanıt anahtar sözcükleri, geçiş sayısı ve süre.
"""
import logging
import os
import re
import sys
import threading
import time
import unicodedata
from typing import Any, Dict, List, Optional

import cv2
import numpy as np

logger = logging.getLogger(__name__)

FLAG = "/app/index/modern_gate.on"            # host: /opt/ai_service/index/modern_gate.on
PYLIB = os.environ.get("MODERN_GATE_PYLIB", "/opt/pylib_ocr")   # rapidocr_onnxruntime==1.4.4 (sürüm sabit)
BUDGET_S = 4.0                  # kapının toplam süresi (motor yüklemesi hariç)
LOCK_WAIT_S = 2.0               # tek uçuş kilidi için bekleme
FLAT_MAX = 960                  # düz kare geçişinin en uzun kenarı
OCR_THREADS = 2                 # det / cls / rec her biri (ölçülen yapılandırma)

try:
    from rapidfuzz import fuzz
except ImportError:             # canlı imajda var; yoksa aynı ölçüyü veren yedek
    fuzz = None


# ---------------------------------------------------------------------------------------------
# 1) Geometri: sikke dairesi + kutupsal şerit (kapi.py ile aynı)
# ---------------------------------------------------------------------------------------------
def daire_bul(bgr):
    """(cx, cy, R, yontem). Hough (ALT) -> Otsu kontur -> merkez varsayımı."""
    h, w = bgr.shape[:2]
    s = 512.0 / max(h, w)
    small = cv2.resize(bgr, (max(1, int(w * s)), max(1, int(h * s))), interpolation=cv2.INTER_AREA)
    g = cv2.medianBlur(cv2.cvtColor(small, cv2.COLOR_BGR2GRAY), 5)
    sh, sw = g.shape
    m = min(sh, sw)
    best = None
    try:
        c = cv2.HoughCircles(g, cv2.HOUGH_GRADIENT_ALT, dp=1.5, minDist=m * 0.5, param1=300, param2=0.75,
                             minRadius=int(0.18 * m), maxRadius=int(0.55 * m))
        if c is not None:
            for x, y, r in c[0]:
                off = np.hypot(x - sw / 2, y - sh / 2) / m
                score = r / m - 0.8 * off            # büyük ve merkeze yakın daire
                if best is None or score > best[0]:
                    best = (score, x, y, r)
    except cv2.error:
        best = None
    if best is not None:
        _, x, y, r = best
        return float(x / s), float(y / s), float(r / s), "hough"
    _, th = cv2.threshold(g, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    for t in (th, 255 - th):
        cs, _ = cv2.findContours(t, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not cs:
            continue
        k = max(cs, key=cv2.contourArea)
        (x, y), r = cv2.minEnclosingCircle(k)
        a = cv2.contourArea(k)
        if r > 0.18 * m and a > 0.6 * np.pi * r * r and np.hypot(x - sw / 2, y - sh / 2) < 0.25 * m:
            return float(x / s), float(y / s), float(r / s), "kontur"
    return w / 2.0, h / 2.0, 0.45 * min(h, w), "merkez"


def kirp(bgr, cx, cy, R, pad=0.06):
    """Dairenin etrafını (canlıdaki SAM kırpımı gibi %6 pay) kare kırp."""
    h, w = bgr.shape[:2]
    r = R * (1 + pad)
    x0, y0 = int(max(0, cx - r)), int(max(0, cy - r))
    x1, y1 = int(min(w, cx + r)), int(min(h, cy + r))
    return bgr[y0:y1, x0:x1]


def kutupsal_serit(bgr, cx, cy, R, r_in=0.35, r_out=1.04, hedef_R=380, ek=0.22):
    """Kenar yazısını düz satıra açar: dış kenar üstte, saat yönü soldan sağa; dikiş için %ek sarma."""
    k = hedef_R / max(R, 1.0)
    img = cv2.resize(bgr, None, fx=k, fy=k, interpolation=cv2.INTER_CUBIC if k > 1 else cv2.INTER_AREA)
    cx, cy, R = cx * k, cy * k, R * k
    maxr = R * r_out
    n_ang = int(2 * np.pi * 0.8 * R)
    n_rad = int(maxr)
    pol = cv2.warpPolar(img, (n_rad, n_ang), (cx, cy), maxr, cv2.WARP_POLAR_LINEAR + cv2.INTER_LINEAR)
    band = pol[:, int(n_rad * r_in / r_out):]                               # (açı, yarıçap)
    strip = np.ascontiguousarray(np.flipud(band.transpose(1, 0, 2)))        # (yarıçap: dış üstte, açı)
    return np.concatenate([strip, strip[:, :int(ek * strip.shape[1])]], axis=1)


# ---------------------------------------------------------------------------------------------
# 2) Karar: metin -> modern Türk parası mı (kapi.py kural v2 ile aynı)
# ---------------------------------------------------------------------------------------------
TR_MAP = str.maketrans({"İ": "I", "ı": "I", "Ş": "S", "ş": "S", "Ğ": "G", "ğ": "G", "Ü": "U", "ü": "U",
                        "Ç": "C", "ç": "C", "Ö": "O", "ö": "O", "Â": "A", "â": "A", "Î": "I", "î": "I",
                        "Û": "U", "û": "U"})
TR_HARF = set("İŞĞÜÇÖışğüçö")
# uzun, Türkçeye özgü sözcükler: bulanık (alt dizi) eşleşme serbest. Hepsi >= 7 harf, antik lejantlarda geçmez.
GUCLU = {"CUMHURIYETI": 86, "TURKIYE": 85, "ATATURK": 88, "CUMHURIYET": 88, "TURKEY": 88, "YENITURK": 88,
         "HURIYET": 86, "HAKIMIYET": 88, "MILLETINDIR": 88, "HATIRASI": 88, "ANISINA": 88, "BIRLIGI": 88,
         "BESINGUNU": 88}
AYLAR = {"OCAK", "SUBAT", "MART", "NISAN", "MAYIS", "HAZIRAN", "TEMMUZ", "AGUSTOS", "EYLUL", "EKIM", "KASIM", "ARALIK"}
# kısa sözcükler: yalnız tam sözcük (OCR tek harf hatası için KURUS/LIRASI'da 1 düzeltme)
ORTA = {"LIRA", "LIRASI", "KURUS", "KURUSH"}
BIRIM = {"LIRA": "lira", "LIRASI": "lira", "KURUS": "kurus", "KURUSH": "kurus"}
GECERLI_DEGER = {1, 2, 5, 10, 20, 25, 50, 100, 250, 500, 1000, 1500, 2500, 5000, 10000, 25000, 50000,
                 100000, 250000, 500000, 750000}


def normal(s):
    s = unicodedata.normalize("NFC", s or "")
    s = s.translate(TR_MAP).upper()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    return re.sub(r"[^A-Z0-9 ]+", " ", s)


def _lev1(a, b):
    """a ile b arasında en çok 1 düzenleme var mı."""
    if abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) <= 1
    if len(a) > len(b):
        a, b = b, a
    return any(b[:i] + b[i + 1:] == a for i in range(len(b)))


def _partial(kw, text):
    if fuzz is not None:
        return fuzz.partial_ratio(kw, text)
    best, n = 0, len(kw)
    for i in range(0, max(1, len(text) - n + 1)):
        seg = text[i:i + n]
        best = max(best, int(100 * sum(x == y for x, y in zip(kw, seg)) / n))
    return best


def karar(metinler) -> Dict[str, Any]:
    """metinler: [(metin, guven, kutu_yuksekligi)] -> {'modern', 'kanit', 'birim', 'deger', 'yil'}."""
    ham = " ".join(m[0] for m in metinler)
    tr_harf = sorted({ch for ch in ham if ch in TR_HARF})
    norm_parcalar = [normal(m[0]) for m in metinler]
    tokens = [tok for p in norm_parcalar for tok in p.split()]
    bitisik = "".join(p.replace(" ", "") for p in norm_parcalar)
    kanit = []
    for kw, esik in GUCLU.items():
        if len(bitisik) >= len(kw) - 1:
            sc = _partial(kw, bitisik)
            if sc >= esik:
                kanit.append(("guclu", kw, int(sc)))
    birim = None
    for tok in tokens:
        for kw in ORTA:
            if tok == kw or (kw in ("KURUS", "LIRASI") and len(tok) >= 5 and _lev1(tok, kw)):
                kanit.append(("orta", kw, tok))
                birim = birim or BIRIM[kw]
    for p in norm_parcalar:
        ts = p.split()
        for i, tok in enumerate(ts):
            m = re.fullmatch(r"(\d+|BIN|YENI)(LIRA|LIRASI|KURUS)", tok)       # bitişik okunmuş "BINLIRA", "5KURUS"
            if m:
                kanit.append(("orta", m.group(2), tok))
                birim = birim or BIRIM[m.group(2)]
            elif tok == "IRA" and i > 0 and ts[i - 1].isdigit() and int(ts[i - 1]) in GECERLI_DEGER:
                kanit.append(("orta", "LIRA", ts[i - 1] + " IRA"))           # ilk harfi düşmüş "10 IRA"
                birim = birim or "lira"
            g = re.fullmatch(r"(\d{1,2})?([A-Z]+)", tok)                       # "16 EKIM" / "16EKIM" / "27MAYIS"
            if g and g.group(2) in AYLAR:
                gun = g.group(1) or (ts[i - 1] if i > 0 and ts[i - 1].isdigit() else None)
                if gun and 1 <= int(gun) <= 31:
                    kanit.append(("orta", "TARIH", (gun + " " + g.group(2))))
    yillar = [int(y) for y in re.findall(r"(?<!\d)(19[2-9]\d|20[0-2]\d)(?!\d)", " ".join(norm_parcalar))]
    yillar = [y for y in yillar if 1923 <= y <= 2026]
    if yillar:
        kanit.append(("zayif", "YIL", yillar[0]))
    if tr_harf:
        kanit.append(("zayif", "TR_HARF", "".join(tr_harf)))
    modern = any(k[0] in ("guclu", "orta") for k in kanit)
    deger = None
    if modern and birim:
        # yalnız bitişik kalıp ("1 LIRA"; ölçüm %91 kesin) — "en büyük yazıdaki rakam" yolu %51'di, kapalı
        m = re.search(r"(?<!\d)(\d+)\s*(BIN\s*)?(LIRA|KURUS)", " ".join(norm_parcalar))
        if m:
            v = int(m.group(1)) * (1000 if m.group(2) else 1)
            if v in GECERLI_DEGER:
                deger = v
    # en sık okunan yıl, en az 2 okumada (düz kare / şerit / 180° şerit) görülmüş olmalı (ölçüm: %87 -> %92 kesin)
    sayac = {}
    for y in yillar:
        sayac[y] = sayac.get(y, 0) + 1
    enc = max(sayac.items(), key=lambda kv: (kv[1], -yillar.index(kv[0]))) if sayac else None
    yil = enc[0] if (modern and enc and enc[1] >= 2) else None
    return {"modern": bool(modern), "kanit": kanit, "birim": birim if modern else None, "deger": deger, "yil": yil}


# ---------------------------------------------------------------------------------------------
# 3) Okuma: RapidOCR (tembel yükleme, tek uçuş)
# ---------------------------------------------------------------------------------------------
_motor = None
_motor_hata = False
_yukle_kilit = threading.Lock()
_calis_kilit = threading.Lock()


def etkin() -> bool:
    return os.environ.get("MODERN_GATE", "0") == "1" or os.path.exists(FLAG)


def _motor_al():
    global _motor, _motor_hata
    if _motor is not None or _motor_hata:
        return _motor
    with _yukle_kilit:
        if _motor is None and not _motor_hata:
            try:
                t = time.time()
                if PYLIB and os.path.isdir(PYLIB) and PYLIB not in sys.path:
                    sys.path.append(PYLIB)
                from rapidocr_onnxruntime import RapidOCR
                kw = {}
                for p in ("det", "cls", "rec"):          # global anahtar alt modellere geçmiyor: tek tek ver
                    kw[p + "_intra_op_num_threads"] = OCR_THREADS
                    kw[p + "_inter_op_num_threads"] = 1
                _motor = RapidOCR(**kw)
                logger.info("AI12 modern kapı: OCR motoru yüklendi (%.1f sn)" % (time.time() - t))
            except Exception as e:
                _motor_hata = True                       # süreç boyunca kapalı: her istekte yeniden deneme yok
                logger.error("AI12 modern kapı: OCR motoru yüklenemedi, kapı kapalı: %s" % e, exc_info=True)
    return _motor


def _oku(motor, img) -> List[list]:
    r, _ = motor(img, use_cls=True)
    out = []
    for box, t, c in (r or []):
        ys = [p[1] for p in box]
        out.append([t, float(c), float(max(ys) - min(ys))])
    return out


def _gecisler(bgr):
    """Okuma sırası: kenar şeridi -> 180° şerit -> düz kare (karar en sık şeritte çıkıyor: 416 / 61 / 207)."""
    cx, cy, R, _ = daire_bul(bgr)
    serit = kutupsal_serit(bgr, cx, cy, R)
    yield serit
    yield np.ascontiguousarray(serit[::-1, ::-1])   # alt yaydaki yazı (harf tepeleri merkeze bakar) şeritte ters
    crop = kirp(bgr, cx, cy, R)
    if crop.size == 0:
        crop = bgr
    s = FLAT_MAX / max(crop.shape[:2])
    yield cv2.resize(crop, None, fx=s, fy=s, interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)


def kontrol(yuzler) -> Optional[Dict[str, Any]]:
    """yuzler: [ön yüz BGR, arka yüz BGR] (None'lar atlanır). Modern Türk parasıysa
    {'country': 'TR', 'unit', 'denomination', 'year'} (okunamayan alan None), değilse / atlanırsa None. İstisna fırlatmaz.

    Bir yüzde karar "modern" çıkınca o yüzün kalan geçişleri bütçe içinde tamamlanır (değer / yıl için: hemen durmak
    yılı verilebilen açılışları 118'den 55'e düşürüyordu), öteki yüze geçilmez.
    """
    try:
        if not etkin():
            return None
        motor = _motor_al()
        if motor is None:
            return None
        if not _calis_kilit.acquire(timeout=LOCK_WAIT_S):
            logger.warning("AI12 modern kapı: meşgul, atlandı")
            return None
        try:
            t0 = time.time()
            hepsi, gecis, modern, bitti = [], 0, False, "tamam"
            for bgr in yuzler:
                if bgr is None:
                    continue
                yuz = []
                for img in _gecisler(bgr):
                    if time.time() - t0 > BUDGET_S:
                        bitti = "butce"
                        break
                    yuz += _oku(motor, img)
                    gecis += 1
                hepsi += yuz
                # karar yüz başına (ölçülen birim: tek görsel); değer / yıl iki yüzün metninden birlikte
                modern = karar(yuz)["modern"]
                if modern or bitti == "butce":
                    break
            d = karar(hepsi) if modern else {"kanit": []}
            logger.info("AI12 modern kapı: modern=%s kanit=%s gecis=%d %s %d ms" % (
                modern, ",".join(sorted({str(k[1]) for k in d["kanit"] if k[0] != "zayif"})) or "-",
                gecis, bitti, int(1000 * (time.time() - t0))))
            if not modern:
                return None
            return {"country": "TR", "unit": d["birim"], "denomination": d["deger"], "year": d["yil"]}
        finally:
            _calis_kilit.release()
    except Exception as e:                                  # kapı isteğe bağlı: tanımayı asla düşürmez
        logger.error("AI12 modern kapı başarısız: %s" % e, exc_info=True)
        return None
