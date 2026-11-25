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
KISA = 5                  # bu uzunluğa kadar sözcük en az iki okumada çıkmalı
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
    "SEVERVS": ["Septimius Severus", "Severus Alexander"], "SEPT": ["Septimius Severus", "Geta"],
    "ALEXAND": ["Severus Alexander"], "GETA": ["Geta"], "PLAVTILLA": ["Plautilla"], "VESPASIAN": ["Vespasian", "Titus"],
    "TRAIAN": ["Trajan", "Trajan Decius", "Hadrian"], "DECIVS": ["Trajan Decius"], "HADRIANVS": ["Hadrian"],
    "VERVS": ["Lucius Verus"], "AVRELIVS": ["Marcus Aurelius", "Commodus"], "FAVSTINA": ["Faustina I", "Faustina II"],
    "NERO": ["Nero"], "GALBA": ["Galba"], "MAESA": ["Julia Maesa"], "SOAEMIAS": ["Julia Soaemias"],
    "OTACIL": ["Otacilia Severa"], "TACITVS": ["Tacitus"], "PROBVS": ["Probus"], "CARVS": ["Carus"],
    "NVMERIANVS": ["Numerian"], "DIOCLETIANVS": ["Diocletian"], "GALLIENVS": ["Gallienus"], "VALENS": ["Valens"],
    "IVLIANVS": ["Julian the Apostate"], "THEODOSIVS": ["Theodosius I", "Theodosius II"], "ARCADIVS": ["Arcadius"],
    "AVRELIANVS": ["Aurelian"], "MAXIMINVS": ["Maximinus Daia", "Maximinus Thrax"], "CRISPVS": ["Crispus"],
    "MAMAEA": ["Julia Mamaea"], "DOMNA": ["Julia Domna"], "COMMOD": ["Commodus"], "DOMITIAN": ["Domitian"],
    "TITVS": ["Titus"], "VALENTINIANVS": ["Valentinian I", "Valentinian II"], "MACRINVS": ["Macrinus"],
    "VALERIANVS": ["Valerian I"], "SALONINA": ["Salonina"], "TREBONIANVS": ["Trebonianus Gallus"],
    "VOLVSIANVS": ["Volusian"], "AEMILIANVS": ["Aemilian"], "POSTVMVS": ["Postumus"], "TETRICVS": ["Tetricus I"],
    "VICTORINVS": ["Victorinus"], "PERTINAX": ["Pertinax"], "OTHO": ["Otho"], "VITELLIVS": ["Vitellius"],
    "NERVA": ["Nerva"], "TIBERIVS": ["Tiberius"], "CLAVDIVS": ["Claudius", "Claudius II"], "LVCILLA": ["Lucilla"],
    "CRISPINA": ["Crispina"], "CARINVS": ["Carinus"], "FLORIANVS": ["Florian"], "SEVERINA": ["Severina"],
    "GRATIANVS": ["Gratian"], "HONORIVS": ["Honorius"], "IOVIANVS": ["Jovianus"], "MAGNENTIVS": ["Magnentius"],
}


# Unvan kuralları: (ad sözcüğü, eşlik eden unvan) birlikte okunduysa aday listesi daraltılır (sikke bilgisi).
#   DISLA: bu kişiler aday dışı.  ZORLA: aday listesi yalnız bu kişiler olur.
# - Marcus Aurelius PIVS unvanını kullanmadı (Caracalla, Antoninus Pius, Elagabalus "ANTONINVS PIVS").
# - BRIT(annicus) unvanı ANTONINVS adlılardan yalnız Caracalla'da (210 sonrası).
# - "IVN NOB C" (iunior): CONSTANTINVS IVN = II. Constantinus, LICINIVS IVN = II. Licinius.
# - NERO + DRVSVS imparator Nero değil: "NERO ET DRVSVS CAESARES" (Caligula'nın kardeşleri, FB 0359),
#   "NERO CLAVDIVS DRVSVS GERMANICVS" (Claudius'un babası).
DISLA = {("ANTONINVS", "PIVS"): ["Marcus Aurelius"],
         ("ANTONINVS", "BRIT"): ["Antoninus Pius", "Elagabalus", "Marcus Aurelius"],
         ("NERO", "DRVSVS"): ["Nero"]}
ZORLA = {("CONSTANTINVS", "IVN"): ["Constantine II"], ("CONSTANTIVS", "IVN"): ["Constantine II"],
         ("LICIN", "IVN"): ["Licinius II"], ("VALENTINIANVS", "IVN"): ["Valentinian II"],
         ("TRAIAN", "HAD"): ["Hadrian"]}      # IMP CAESAR TRAIANVS HADRIANVS AVG (Hadrian'ın ilk yılları)
# unvanlar kısa: harf karışmaları düzenli ifadeyle (OCR'da V/N/Y, I/L karışıyor); C ile G _norm'da zaten bir
ES = {"PIVS": r"PI[VNY]S", "BRIT": r"BR[IVL]T", "IVN": r"[IL1S][VN]N(?:N|P)",   # IVN NOB C / IVN P F AVG
      "IMPC": r"I[MAEL]PC", "HAD": r"[AI]AN[VN]?S.{0,3}HAD", "DRVSVS": r"DR[VNY]S[VNY]S"}
# "IMP C" ile başlayan lejant 4. yüzyıl sonu "D N" imparatorlarında yok (Maximinus Daia "IMP C GAL VAL MAXIMINVS"
# okuması "GVALEES" -> VALENS sanılıyordu, VCoins vc101)
DN_IMPARATOR = {"Valens", "Valentinian I", "Valentinian II", "Gratian", "Theodosius I", "Theodosius II", "Arcadius",
                "Honorius", "Jovianus", "Magnentius"}


def _yakin_sozcukler():
    """-> {sözcük: ikizleri}: birbirine en çok 2 harf uzak adlar (CONSTANTINVS / CONSTANTIVS, MAXIMIANVS / MAXIMINVS)."""
    ks = [k for k in SOZCUK if len(k) > 5]
    out = {}
    for i, a in enumerate(ks):
        for b in ks[i + 1:]:
            if _mesafe(a, b) <= 2:
                out.setdefault(a, set()).add(b)
                out.setdefault(b, set()).add(a)
    return out


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


YAKIN = _yakin_sozcukler()


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
                # paddlex yüklenirken kök günlükçünün düzeyini WARNING'e çekiyor: servisin INFO satırları
                # (recognize(...), lejant: ... ms) bayrak açılınca kayboldu (25 Kas canlı). Düzey geri konur.
                kok = logging.getLogger()
                kok_duzey = kok.level
                try:
                    os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
                    from paddleocr import TextRecognition
                    kw = dict(model_name="en_PP-OCRv5_mobile_rec", model_dir=self.model_dir, cpu_threads=self.threads)
                    try:                              # x86: oneDNN açık değilse 13 pencere 4 sn, açıkken 0,75 sn (VPS)
                        self._rec = TextRecognition(enable_mkldnn=True, **kw)
                    except Exception:
                        self._rec = TextRecognition(**kw)
                except Exception as e:                # isteğe bağlı katman: tanımayı asla bozmaz
                    logger.error("lejant: OCR modeli yüklenemedi: %s" % e)
                    self._hata = True
                finally:
                    kok.setLevel(kok_duzey)
        return self._rec

    @staticmethod
    def cemberler(crop):
        """-> sikke çemberi adayları [(cx, cy, r)]: Hough ve (SAM kırpımıysa) maske.
        İkisinin okumaları birlikte oylanır: Hough sikkeden büyük çember bulunca harfler şeridin iç kenarında
        kesiliyor (FB: GETA CAES, GORDIANVS), maske ise kenarı aşınmış sikkede küçük kalıyor. Ölçüm (25 Kas):
        tek Hough FB 13/13 · VCoins 8/9; ikisi birlikte FB 17/17 · VCoins 8/9, yeni FB kümesinde yeni yanlış yok."""
        import cv2
        h, w = crop.shape[:2]
        # Hough 400 px karede: 800 px'te VPS'te servis kırpımı başına ortalama 3,9 sn (en çok 8,3), 400 px'te
        # yaklaşık 25 kat hızlı (25 Kas canlı ölçüm: bayrak açıkken istek süresi 12 -> 23 sn idi)
        kh = 400.0 / max(h, w)
        gh = cv2.medianBlur(cv2.cvtColor(cv2.resize(crop, None, fx=kh, fy=kh), cv2.COLOR_BGR2GRAY), 5)
        m = min(gh.shape[:2])
        c = cv2.HoughCircles(gh, cv2.HOUGH_GRADIENT, dp=1.2, minDist=m, param1=120, param2=40,
                             minRadius=int(m * 0.18), maxRadius=int(m * 0.55))
        out = [tuple(v / kh for v in c[0][0])] if c is not None else [(w / 2.0, h / 2.0, min(h, w) / 2.0 / 1.06)]
        k = 800.0 / max(h, w)
        g = (int(round(h * k)), int(round(w * k)))
        # SAM kırpımı: maske dışı 235 gri; maske yuvarlaksa (alan / çevreleyen çember > 0,6) maske çemberi de.
        # Maske 800 px karede (en yakın komşu: 235 değeri korunur), çevreleyen çember dış
        # konturdan: tam çözünürlükte milyonlarca piksel üzerinde minEnclosingCircle 3351 px katalog görselinde
        # 10 dakikayı aştı (canlıda büyük telefon fotoğrafı isteği kilitlerdi).
        kucuk = cv2.resize(crop, (max(1, g[1]), max(1, g[0])), interpolation=cv2.INTER_NEAREST)
        gri = np.all(np.abs(kucuk.astype(np.int16) - 235) <= 2, axis=2)
        dolu = 1.0 - float(gri.mean())
        if 0.25 < dolu < 0.97:
            n, lab, st, _ = cv2.connectedComponentsWithStats((~gri).astype(np.uint8), 8)
            if n > 1:
                parca = (lab == 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))).astype(np.uint8)
                kontur = max(cv2.findContours(parca, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[0], key=len)
                _, rc = cv2.minEnclosingCircle(kontur)
                ys, xs = np.nonzero(parca)
                if len(xs) / (np.pi * rc * rc + 1e-9) > 0.6:
                    mc = (float(xs.mean()) / k, float(ys.mean()) / k, float(np.sqrt(len(xs) / np.pi)) / k)
                    hx, hy, hr = out[0]
                    if abs(mc[2] - hr) > 0.04 * hr or np.hypot(mc[0] - hx, mc[1] - hy) > 0.04 * hr:
                        out.append(mc)
        return out

    @staticmethod
    def serit(crop, cember=None):
        """Sikke kırpımı -> kenar halkasının düz şeridi (saat yönü, harf tepesi dışta)."""
        import cv2
        cx, cy, r = cember or LejantOkur.cemberler(crop)[0]
        R = int(r * BANT_DIS)
        cevre = max(64, int(2 * np.pi * r))
        pol = cv2.warpPolar(crop, (R, cevre), (cx, cy), R, cv2.WARP_POLAR_LINEAR)
        bant = pol[:, int(R * BANT_IC / BANT_DIS):]
        s = np.flipud(np.transpose(bant, (1, 0, 2)).copy())
        s = np.concatenate([s, s[:, : s.shape[1] // 2]], axis=1)
        return cv2.resize(s, (max(SERIT_Y, int(s.shape[1] * SERIT_Y / s.shape[0])), SERIT_Y))

    def oku(self, crop):
        """-> [(metin, güven)] kayan pencere okumaları (her çember adayının şeridinden)."""
        rec = self._model()
        if rec is None or crop is None or crop.size == 0:
            return []
        pencereler = []
        for cember in self.cemberler(crop):
            s = self.serit(crop, cember)
            h, w = s.shape[:2]
            gen = h * PENCERE_EN
            adim = max(8, int(gen * PENCERE_ADIM))
            pencereler += [s[:, x0: x0 + gen] for x0 in range(0, max(1, w - gen // 2), adim)]
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
        oy, tam = {}, {}                              # sözcük başına eşleşen okuma ve birebir okuma sayısı
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
                    oy[s] = oy.get(s, 0) + 1
                    tam[s] = tam.get(s, 0) + (v == 0)
            es |= {e for e, desen in ES.items() if re.search(desen, t)}
        # pencereler üst üste biniyor: gerçek lejant sözcüğü çoğunlukla birden çok okumada çıkar. Kısa sözcükte tek
        # okumalık eşleşme gürültü sayılır (FB: SAM yalnız arka yüz figürünü kırptı, OCR "cYanmaGetaYeeen" -> Geta)
        bulunan = {s for s in bulunan if oy.get(s, 0) >= 2 or len(s) > KISA}
        # önek kuralı: uzun ad bulunduysa aynı 5 harfle başlayan en az 3 harf kısa ad düşer (VALENTINIANVS -> VALENS değil)
        bulunan = {s for s in bulunan
                   if not any(len(o) - len(s) >= 3 and o[:5] == s[:5] for o in bulunan)}
        if not bulunan:
            return None
        disla = {k for (s, e), kisiler in DISLA.items() if _norm(s) in bulunan and e in es for k in kisiler}
        if "IMPC" in es:
            disla |= DN_IMPARATOR
        zorla = [set(kisiler) & set(self.idx) for (s, e), kisiler in ZORLA.items() if _norm(s) in bulunan and e in es]
        # lejantın ad sözcükleri aynı kişiyi anlatır: adayların kesişimi (P SEPT GETA -> Geta; L SEPT SEV -> Severus);
        # kesişim boşsa (gürültü sözcüğü) birleşim. Yakın çift: tek harfle ayrılan ad hiç birebir okunmadıysa ikizinin
        # kişileri de aday, seçimi portre yapar (VCoins vc022 "CONSTANTINVS IVN NOB C": IVN okunmayınca "CONSTANTIVS"
        # sanıldı; portre Constantine II 0,79 derken aday listesi yalnız Constantius'larken Constantius II seçiliyordu)
        kume = []
        for s in bulunan:
            k = set(self.sozcuk[s])
            if not zorla and tam.get(s, 0) == 0:
                for o in YAKIN.get(s, ()):
                    k |= set(self.sozcuk.get(o, ()))
            kume.append(k)
        aday = set.intersection(*kume) or set.union(*kume)
        if zorla:
            aday = set.union(*zorla)
        aday = sorted(aday - disla)
        if not aday:
            return None
        p = self.portre(vec)
        sirali = sorted(aday, key=lambda a: -p[self.idx[a]])
        best = sirali[0]
        sira = int((p > p[self.idx[best]]).sum()) + 1
        # güçlü lejant: kişiyi taşıyan bir sözcük en az 2 okumada birebir ya da 3 okumada payla. Tek adayda güçlü
        # lejant portreye sorulmadan kabul (geç Roma portreleri birbirine benziyor: ARCADIVS birebir, portre sırası 15)
        guclu = any(tam.get(s, 0) >= 2 or oy.get(s, 0) >= 3 for s in bulunan if best in self.sozcuk[s])
        if len(sirali) == 1:
            if not guclu and sira > PORTRE_SIRA_MAX:
                return None
        elif p[self.idx[best]] < PORTRE_MIN or sira > PORTRE_SIRA_MAX:
            return None
        alt = [a for a in sirali[1:] if p[self.idx[a]] >= 0.25 * p[self.idx[best]]][:2]
        oran = float(p[self.idx[best]] / max(p[self.idx[sirali[1]]], 1e-9)) if len(sirali) > 1 else None
        return {"ruler": best, "alternatives": alt, "tokens": sorted(bulunan), "p": round(float(p[self.idx[best]]), 3),
                "margin": round(oran, 2) if oran else None, "strong": bool(guclu)}
