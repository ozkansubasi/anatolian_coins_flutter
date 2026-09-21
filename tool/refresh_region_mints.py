"""RegionData.mints listesini canlı katalogdan yeniden üretir.

NEDEN (2026-09-21): gömülü darphane listesi katalogda sikkesi OLMAYAN
darphaneleri de içeriyordu (Lidya: 42 darphanenin 34'ü 0 sonuç). Kaynak
artık /v1/variants/facets?filter[region]=… — yalnız sikkesi olan darphaneler.

Kullanım (proje kökünden):  python tool/refresh_region_mints.py
Hız sınırı nedeniyle istekler aralıklı gider (~1 dk sürer).
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://www.numistr.org/api/index.php/v1/variants/facets?"
PATH = "lib/src/core/region_data.dart"

src = open(PATH, encoding="utf-8").read()
regions = re.findall(r"^    '([a-z-]+-coins)': '", src.split("regionNames = {", 1)[1].split("};", 1)[0], re.M)


def facet(region: str):
    # facet_limit: varsayılan 15 (listeyi sessizce kesiyordu), üst sınır 100
    q = urllib.parse.urlencode({"filter[region]": region, "facet_limit": 100})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(API + q, timeout=30) as r:
                body = r.read().decode("utf-8")
            d = json.loads(body)
            f = d.get("facets") or d.get("data", {}).get("facets") or {}
            return [(m["name"], int(m["count"])) for m in f.get("mint", []) if m.get("name")]
        except Exception as e:  # boş yanıt = hız sınırı
            print(f"  {region}: deneme {attempt + 1} başarısız ({e}); bekleniyor", file=sys.stderr)
            time.sleep(15)
    raise SystemExit(f"{region}: facet alınamadı")


result = {}
for i, region in enumerate(regions):
    mints = facet(region)
    result[region] = sorted(name for name, count in mints if count > 0)
    print(f"{region}: {len(result[region])} darphane, {sum(c for _, c in mints)} sikke")
    time.sleep(4)

lines = ["  static const Map<String, List<String>> mints = {"]
for region in regions:
    lines.append(f"    '{region}': [")
    lines += [f"      '{m}'," for m in result[region]]
    lines.append("    ],")
lines.append("  };")
new_block = "\n".join(lines)

start = src.index("  static const Map<String, List<String>> mints = {")
end = src.index("\n  };", start) + len("\n  };")
open(PATH, "w", encoding="utf-8", newline="\n").write(src[:start] + new_block + src[end:])
print(f"\n{PATH} güncellendi: {sum(len(v) for v in result.values())} darphane")
