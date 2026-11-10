"""Mimari A (ADR-012) — kısa listedeki adayları birbirinden ayıran ayrıntı.

/recognize yanıtında gösterilen her adaya `distinguish` alanı eklenir. Bağımlılık yok (yalnız stdlib); çalışma anında
model ya da ağ çağrısı yok. Veri: ayirt_veri.json (scripts/ai1/ayirt_veri.py üretir; tip başına karşılaştırma alanları).

Kurallar (ölçüm ve gerekçe: ADR-012):
- Bir alan yalnız iki adayda da biliniyorsa karşılaştırılır; eksik veri fark sayılmaz. İstisna: açık verisi olan
  (rec["o"]) iki tipte bir konumda işaret yoksa bu da bilgidir ("none" ↔ "owl").
- Lejant: normalize seçenek kümeleri kesişmiyorsa farklı. Diğer alanlar: eşitlik.
- Gruplama: görünür alanların hiçbiri ayrışmıyor, darphane aynı ve asıl kaynak ikisinde de var (ikisinde de açık veri
  ya da ikisinde de ön + arka tanım) → tek grup ("verimizde aynı"). Veri yokluğu birleştirmez.
- Satırlar: yalnız gruplar arasında değişen alanlar; sınıf önceliği mark > legend > description > authority >
  material > denomination; mint ve date bilgi satırı (info), ayrım kanıtı sayılmaz.
- Tanım vurgusu: metni farklı adaylar içinde en benzeyeniyle eşleşmeyen sözcükler (karakter aralıkları, TR ve EN ayrı).
- Açık veriden (mark / legend / denomination) satır varsa çıktıda "attribution" bulunur; ekranda gösterilmelidir (ODbL).

Kullanım (servis):
    D = Distinguisher("/app/index/ayirt_veri.json")
    D.annotate(matches)        # her girdiye entry["distinguish"] = {...} ya da None (tek aday / veri yok)
"""
import difflib
import json
import re

# sınıf → (gösterim önceliği, ayrım kanıtı mı)
CLASSES = {"mark": (1, True), "legend": (2, True), "description": (3, True), "authority": (4, True),
           "material": (5, True), "denomination": (6, True), "mint": (7, False), "date": (8, False)}
# işaret konumlarının gösterim sırası (NUDS konum adları; darphane işareti parçaları leftField / rightField / exergue)
POSITIONS = ("exergue", "leftField", "rightField", "beneathThrone", "underThrone", "outerLeftField", "outerRightField",
             "innerLeftField", "innerRightField", "leftWing", "rightWing", "above", "below", "officina", "controlMark")
FACE_ORDER = {"reverse": 0, "obverse": 1}
OPEN_DATA_CLASSES = ("mark", "legend", "denomination")   # yalnız açık veriden gelen alanlar → kaynak atfı (ODbL)
ATTRIBUTION = "ANS PELLA / OCRE / SCO (ODbL)"
_NO_NONE = ("legend", "description", "officina")   # bu alanların yokluğu "işaret yok" demek değildir


def tokens(text):
    return tuple(re.findall(r"\w+", (text or "").lower()))


def highlight(texts):
    """Her metinde, metni FARKLI olan metinler içinde en benzeyeniyle eşleşmeyen sözcüklerin karakter aralıkları.
    Birebir aynı metinli ikiz atlanır (yoksa ikizi olan adayda hiçbir şey vurgulanmazdı)."""
    tok = [[(m.group(0).lower(), m.start(), m.end()) for m in re.finditer(r"\w+", t or "")] for t in texts]
    out = []
    for i, ti in enumerate(tok):
        wi = [w for w, _, _ in ti]
        best = None
        for j, tj in enumerate(tok):
            wj = [w for w, _, _ in tj]
            if j == i or not wi or not wj or wi == wj:
                continue
            sm = difflib.SequenceMatcher(a=wi, b=wj, autojunk=False)
            if best is None or sm.ratio() > best.ratio():
                best = sm
        spans = []
        if best is not None:
            matched = {x for b in best.get_matching_blocks() for x in range(b.a, b.a + b.size)}
            prev = None
            for n, (_, s, e) in enumerate(ti):
                if n in matched:
                    continue
                if spans and prev == n - 1:
                    spans[-1][1] = e
                else:
                    spans.append([s, e])
                prev = n
        out.append(spans)
    return out


class Distinguisher:
    def __init__(self, path=None, data=None):
        d = data if data is not None else json.load(open(path, encoding="utf-8"))
        self.version = d.get("surum")
        self.created = d.get("olusturma")
        self.types = d["tipler"]
        for rec in self.types.values():
            for f in rec["f"].values():
                if f["c"] == "description":
                    f["_k"] = tokens(f.get("en") or f.get("tr"))
                elif f["c"] == "legend":
                    f["_k"] = frozenset(f["k"])
                else:
                    k = f.get("k")
                    f["_k"] = tuple(k) if isinstance(k, list) else k

    # ---- karşılaştırma ----
    def record(self, article_id):
        return self.types.get(str(article_id)) or {"f": {}}

    @staticmethod
    def _value(rec, key, cls):
        f = rec["f"].get(key)
        if f is not None:
            return f["_k"]
        pos = key.partition(".")[2]
        if cls == "mark" and pos not in _NO_NONE and rec.get("o"):
            return ()                                   # açık verisi olan tipte işaretsiz konum = "yok"
        return None

    @staticmethod
    def _differs(cls, x, y):
        if x is None or y is None:
            return False
        if cls == "legend":
            return not (x & y)
        return x != y

    @staticmethod
    def _cls(r1, r2, key):
        return (r1["f"].get(key) or r2["f"].get(key))["c"]

    def diff_keys(self, r1, r2):
        """İki tipin ayrıştığı alanlar (her ikisinde de bilinen ve farklı)."""
        out = []
        for key in set(r1["f"]) | set(r2["f"]):
            cls = self._cls(r1, r2, key)
            if self._differs(cls, self._value(r1, key, cls), self._value(r2, key, cls)):
                out.append(key)
        return sorted(out)

    def same(self, r1, r2):
        """Tek gruba girer mi: görünür alan farkı yok, darphane aynı, asıl kaynak ikisinde de var."""
        for key in self.diff_keys(r1, r2):
            cls = self._cls(r1, r2, key)
            if CLASSES[cls][1] or cls == "mint":
                return False
        open_data = r1.get("o") and r2.get("o")
        described = all(f"{face}.description" in r["f"] for r in (r1, r2) for face in ("obverse", "reverse"))
        return bool(open_data or described)

    def compare(self, article_ids):
        """Dönüş: {"groups": [[id…]], "rows": [{"key", "class", "info", "values": [grup başına alan ya da None]}]}"""
        recs = {a: self.record(a) for a in article_ids}
        groups = []
        for a in article_ids:
            for g in groups:
                if all(self.same(recs[a], recs[b]) for b in g):
                    g.append(a)
                    break
            else:
                groups.append([a])
        reps = [recs[g[0]] for g in groups]
        keys = {}
        for r in reps:
            for key, f in r["f"].items():
                keys.setdefault(key, f["c"])
        rows = []
        for key, cls in keys.items():
            vals = [self._value(r, key, cls) for r in reps]
            if not any(self._differs(cls, vals[i], vals[j]) for i in range(len(vals)) for j in range(i + 1, len(vals))):
                continue
            rows.append({"key": key, "class": cls, "info": not CLASSES[cls][1],
                         "values": [{"_none": True} if key not in r["f"] and v == () else r["f"].get(key)
                                    for r, v in zip(reps, vals)]})   # "yok" yalnız alan kayıtta hiç yokken

        def order(row):
            face, _, pos = row["key"].partition(".")
            return (CLASSES[row["class"]][0], FACE_ORDER.get(face, 2),
                    POSITIONS.index(pos) if pos in POSITIONS else len(POSITIONS), row["key"])
        rows.sort(key=order)
        for row in rows:
            if row["class"] == "description":
                for lang in ("tr", "en"):
                    texts = [(v or {}).get(lang) or "" for v in row["values"]]
                    row["hl_" + lang] = highlight(texts)
        return {"groups": groups, "rows": rows}

    # ---- servis çıktısı ----
    @staticmethod
    def _field(row, gi):
        v = row["values"][gi]
        out = {"key": row["key"], "class": row["class"]}
        if row["info"]:
            out["info"] = True
        if v is None:
            out["state"] = "unknown"
        elif v.get("_none"):
            out["state"] = "none"
        elif row["class"] == "description":
            out.update({"text_tr": v.get("tr") or None, "text_en": v.get("en") or None,
                        "highlight_tr": row["hl_tr"][gi], "highlight_en": row["hl_en"][gi]})
        else:
            out["value"] = v.get("v")
            if v.get("tr"):
                out["value_tr"] = v["tr"]
            if v.get("uri"):
                out["uri"] = v["uri"]
        return out

    def annotate(self, entries, key="article_id"):
        """Listedeki her girdiye `distinguish` ekler (yerinde). Tek aday ya da hiçbir satır çıkmazsa ayrıntı yine
        grup bilgisini taşır; liste < 2 ise None."""
        ids = [int(e[key]) for e in entries]
        if len(ids) < 2:
            for e in entries:
                e["distinguish"] = None
            return entries
        res = self.compare(ids)
        gi_of = {a: gi for gi, g in enumerate(res["groups"]) for a in g}
        acik = any(row["class"] in OPEN_DATA_CLASSES for row in res["rows"])
        for e in entries:
            a = int(e[key])
            gi = gi_of[a]
            g = res["groups"][gi]
            e["distinguish"] = {"group": gi + 1, "same_as": [x for x in g if x != a],
                                "fields": [self._field(row, gi) for row in res["rows"]]}
            if acik:
                e["distinguish"]["attribution"] = ATTRIBUTION   # açık veriden satır gösteriliyorsa atıf zorunlu
        return entries
