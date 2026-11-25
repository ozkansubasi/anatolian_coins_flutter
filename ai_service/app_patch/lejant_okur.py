"""Kimlik katmanı aşaması: LEJANT + PORTRE ile hükümdar (25 Kas 2026).

Sunucuda `app/services/lejant_okur.py` (docker cp); ana depoda `scripts/ai1/lejant_okur.py` aynı dosyadır.
Aynı modül Mac'teki ölçüm düzeneğinde de kullanılır (`scripts/ai1/lejant_olc.py`): offline sayı = canlı davranış.

Akış (yalnız doğrulanmamış sonuçta, portre yüzünün sikke kırpımında):
  1) sikke çemberi (Hough; bulunamazsa kırpım merkezi) → kenar halkası `warpPolar` ile düz şerit (saat yönü)
  2) PP-OCRv5 tanıma modeli (metin bulma yok) şeridi kayan pencerelerle okur
  3) hükümdar sözcüğü oylaması: 5 harfe kadar birebir, 6-8 harf 1, 9+ 2 hata; C ile G aynı; güven >= OKUMA_MIN
  4) sözcüğün aday kişileri (ANTONINVS → Caracalla / Antoninus Pius / ...) arasından portre başının en olası bulduğu
Ölçüm (25 Kas, offline): Facebook gerçek seti 15/17 doğru kişi (canlı kural 0), VCoins 11/12.
"""
import logging
import os
import re
import threading

import numpy as np

logger = logging.getLogger(__name__)

OKUMA_MIN = 0.6           # pencere okuması bu güvenin altındaysa sayılmaz
PORTRE_MIN = 0.01         # birden çok aday varsa seçilenin portre olasılığı en az bu
PORTRE_SIRA_MAX = 5       # seçilen kişi portre başının GENEL sıralamasında ilk 5'te değilse ad verilmez
                          # (OCR yanlış okuması: Maximinus Daia için "VALENS" -> portre sırası 12; FB 9/10, VCoins 8/10)
PENCERE_EN = 14           # pencere genişliği = şerit yüksekliği x 14 (uzun adlar sığsın; VCoins sınama yarısı 8/33)
PENCERE_ADIM = 0.1        # adım = pencere genişliğinin %10'u
SERIT_Y = 72
BANT_IC, BANT_DIS = 0.64, 1.02
TOPLU = 16

SOZCUK = {
    "ANTONINVS": ["Caracalla", "Antoninus Pius", "Elagabalus", "Marcus Aurelius"], "ANTON": ["Caracalla"],
    "CONSTANTINVS": ["Constantine I", "Constantine II"],
    "CONSTANTIVS": ["Constantius I", "Constantius II", "Constantius Gallus"],
    "MAXIMIANVS": ["Maximian", "Galerius"], "GALERIVS": ["Galerius"], "LICIN": ["Licinius", "Licinius II"],
    "GORDIANVS": ["Gordian III"], "PHILIPPVS": ["Philip I", "Philip II"],
    "SEVERVS": ["Septimius Severus", "Severus Alexander"], "SEPT": ["Septimius Severus"],
    "ALEXAND": ["Severus Alexander"], "GETA": ["Geta"], "PLAVTILLA": ["Plautilla"], "VESPASIAN": ["Vespasian", "Titus"],
    "TRAIAN": ["Trajan", "Trajan Decius"], "DECIVS": ["Trajan Decius"], "HADRIANVS": ["Hadrian"],
    "VERVS": ["Lucius Verus"], "AVRELIVS": ["Marcus Aurelius", "Commodus"], "FAVSTINA": ["Faustina I", "Faustina II"],
    "NERO": ["Nero"], "GALBA": ["Galba"], "MAESA": ["Julia Maesa"], "SOAEMIAS": ["Julia Soaemias"],
    "OTACIL": ["Otacilia Severa"], "TACITVS": ["Tacitus"], "PROBVS": ["Probus"], "CARVS": ["Carus"],
    "NVMERIANVS": ["Numerian"], "DIOCLETIANVS": ["Diocletian"], "GALLIENVS": ["Gallienus"], "VALENS": ["Valens"],
    "IVLIANVS": ["Julian the Apostate"], "THEODOSIVS": ["Theodosius I", "Theodosius II"], "ARCADIVS": ["Arcadius"],
    "AVRELIANVS": ["Aurelian"], "MAXIMINVS": ["Maximinus Daia", "Maximinus Thrax"], "CRISPVS": ["Crispus"],
    "MAMAEA": ["Julia Mamaea"], "DOMNA": ["Julia Domna"], "COMMODVS": ["Commodus"], "DOMITIAN": ["Domitian"],
    "TITVS": ["Titus"], "VALENTINIANVS": ["Valentinian I", "Valentinian II"], "MACRINVS": ["Macrinus"],
    "VALERIANVS": ["Valerian I"], "SALONINA": ["Salonina"], "TREBONIANVS": ["Trebonianus Gallus"],
    "VOLVSIANVS": ["Volusian"], "AEMILIANVS": ["Aemilian"], "POSTVMVS": ["Postumus"], "TETRICVS": ["Tetricus I"],
    "VICTORINVS": ["Victorinus"], "PERTINAX": ["Pertinax"], "OTHO": ["Otho"], "VITELLIVS": ["Vitellius"],
    "NERVA": ["Nerva"], "TIBERIVS": ["Tiberius"], "CLAVDIVS": ["Claudius", "Claudius II"], "LVCILLA": ["Lucilla"],
    "CRISPINA": ["Crispina"], "CARINVS": ["Carinus"], "FLORIANVS": ["Florian"], "SEVERINA": ["Severina"],
    "GRATIANVS": ["Gratian"], "HONORIVS": ["Honorius"], "IOVIANVS": ["Jovianus"], "MAGNENTIVS": ["Magnentius"],
}


# Eş sözcük kuralı: (sözcük, eşlik eden sözcük) okunduysa bu kişiler aday dışı (unvan bilgisi).
# Marcus Aurelius "PIVS" unvanını kullanmadı; Caracalla, Antoninus Pius ve Elagabalus "ANTONINVS PIVS" yazdırdı.
DISLA = {("ANTONINVS", "PIVS"): ["Marcus Aurelius"]}
ES = {"PIVS"}                 # yalnız eş kural için aranan, kendi başına kişi vermeyen sözcükler


def _norm(s):
    s = s.upper().replace("U", "V").replace("J", "I")
    return re.sub(r"[^A-Z]", "", s).replace("G", "C")          # Roma büyük harfinde G ile C karışıyor


def _mesafe(a, b):
    p = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        c = [i]
        for j, cb in enumerate(b, 1):
            c.append(min(p[j] + 1, c[j - 1] + 1, p[j - 1] + (ca != cb)))
        p = c
    return p[-1]


def _uzaklik(metin, ad):
    """-> sözcüğün metindeki en iyi eşleşmesinin hata sayısı, eşik aşılırsa None.
    5 harfe kadar birebir, 6-8 harf 1, 9+ harf 2 hata."""
    if ad in metin:
        return 0
    L = len(ad)
    tol = 0 if L <= 5 else 1 if L <= 8 else 2
    if tol == 0:
        return None
    d = min((_mesafe(metin[i:i + L], ad) for i in range(0, max(1, len(metin) - L + 1))), default=99)
    return d if d <= tol else None


def _gecer(metin, ad):
    return _uzaklik(metin, ad) is not None


class LejantOkur:
    def __init__(self, model_dir, bas_path, threads=2):
        self.model_dir, self.bas_path, self.threads = model_dir, bas_path, threads
        self._rec = None
        self._hata = False
        self._kilit = threading.Lock()
        z = np.load(bas_path, allow_pickle=False)
        self.W = z["W"].astype(np.float32)          # (C, d)
        self.b = z["b"].astype(np.float32)          # (C,)
        self.siniflar = [str(x) for x in z["siniflar"]]
        self.olcek = float(z["olcek"]) if "olcek" in z else 20.0
        self.idx = {k: i for i, k in enumerate(self.siniflar)}
        self.sozcuk = {_norm(t): [a for a in kisiler if a in self.idx] for t, kisiler in SOZCUK.items()}
        self.sozcuk = {t: k for t, k in self.sozcuk.items() if k}

    def _model(self):
        if self._rec is not None or self._hata:
            return self._rec
        with self._kilit:
            if self._rec is None and not self._hata:
                try:
                    os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
                    from paddleocr import TextRecognition
                    self._rec = TextRecognition(model_name="en_PP-OCRv5_mobile_rec", model_dir=self.model_dir,
                                                cpu_threads=self.threads)
                except Exception as e:                # isteğe bağlı katman: tanımayı asla bozmaz
                    logger.error("lejant: OCR modeli yüklenemedi: %s" % e)
                    self._hata = True
        return self._rec

    @staticmethod
    def serit(crop):
        """Sikke kırpımı -> kenar halkasının düz şeridi (saat yönü, harf tepesi dışta)."""
        import cv2
        h, w = crop.shape[:2]
        k = 800.0 / max(h, w)
        g = cv2.medianBlur(cv2.cvtColor(cv2.resize(crop, None, fx=k, fy=k), cv2.COLOR_BGR2GRAY), 5)
        m = min(g.shape[:2])
        c = cv2.HoughCircles(g, cv2.HOUGH_GRADIENT, dp=1.2, minDist=m, param1=120, param2=40,
                             minRadius=int(m * 0.18), maxRadius=int(m * 0.55))   # ölçülen ayar; SAM yoksa tam kare gelir
        if c is not None:
            cx, cy, r = [v / k for v in c[0][0]]
        else:                                         # SAM kırpımı sikkeyi ortalar (%6 pay)
            cx, cy, r = w / 2.0, h / 2.0, min(h, w) / 2.0 / 1.06
        R = int(r * BANT_DIS)
        cevre = max(64, int(2 * np.pi * r))
        pol = cv2.warpPolar(crop, (R, cevre), (cx, cy), R, cv2.WARP_POLAR_LINEAR)
        bant = pol[:, int(R * BANT_IC / BANT_DIS):]
        s = np.flipud(np.transpose(bant, (1, 0, 2)).copy())
        s = np.concatenate([s, s[:, : s.shape[1] // 2]], axis=1)
        return cv2.resize(s, (max(SERIT_Y, int(s.shape[1] * SERIT_Y / s.shape[0])), SERIT_Y))

    def oku(self, crop):
        """-> [(metin, güven)] kayan pencere okumaları."""
        rec = self._model()
        if rec is None or crop is None or crop.size == 0:
            return []
        s = self.serit(crop)
        h, w = s.shape[:2]
        gen = h * PENCERE_EN
        adim = max(8, int(gen * PENCERE_ADIM))
        pencereler = [s[:, x0: x0 + gen] for x0 in range(0, max(1, w - gen // 2), adim)]
        out = []
        for r in rec.predict(input=pencereler, batch_size=TOPLU):
            out.append((str(r["rec_text"]), float(r["rec_score"])))
        return out

    def portre(self, vec):
        z = (self.W @ np.asarray(vec, np.float32) + self.b) * self.olcek
        z = np.exp(z - z.max())
        return z / z.sum()

    def karar(self, okumalar, vec):
        """-> {'ruler', 'alternatives', 'tokens', 'p'} ya da None."""
        bulunan, es = set(), set()
        for m, g in okumalar:
            if g < OKUMA_MIN:
                continue
            t = _norm(m)
            d = {s: _uzaklik(t, s) for s in self.sozcuk}
            d = {s: v for s, v in d.items() if v is not None}
            # yakın sözcük budaması: aynı okuma birbirine çok benzeyen iki sözcükle eşleşirse (CONSTANTINVS /
            # CONSTANTIVS) yalnız daha az hatalı olan kalır
            for s, v in d.items():
                if not any(o != s and d[o] < v and _mesafe(o, s) <= 2 for o in d):
                    bulunan.add(s)
            es |= {e for e in ES if _uzaklik(t, _norm(e)) is not None}
        if not bulunan:
            return None
        disla = {k for (s, e), kisiler in DISLA.items() if _norm(s) in bulunan and _norm(e) in es for k in kisiler}
        aday = sorted({a for s in bulunan for a in self.sozcuk[s]} - disla)
        if not aday:
            return None
        p = self.portre(vec)
        sirali = sorted(aday, key=lambda a: -p[self.idx[a]])
        best = sirali[0]
        if len(sirali) > 1 and p[self.idx[best]] < PORTRE_MIN:
            return None
        if int((p > p[self.idx[best]]).sum()) + 1 > PORTRE_SIRA_MAX:
            return None
        alt = [a for a in sirali[1:] if p[self.idx[a]] >= 0.25 * p[self.idx[best]]][:2]
        return {"ruler": best, "alternatives": alt, "tokens": sorted(bulunan), "p": round(float(p[self.idx[best]]), 3)}
