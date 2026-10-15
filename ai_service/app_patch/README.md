# app_patch — CANLI /opt/ai_service/app_patch kopyası (2026-08-24, Faz A)

- `recognition.py` → VPS'te container'a mount: `/opt/ai_service/app_patch/recognition.py -> /app/app/services/recognition.py`. Değişiklik sonrası sadece `docker restart numistr_ai` (recreate YAPMA — pip kurulumları gider).
- `api_schemas_recognition.py` → container İÇİNDE `/app/app/api/schemas/recognition.py` (mount değil): `docker cp` ile güncellenir.
- Rollback yedekleri VPS'te: `app_patch/recognition.py.backup_fazA_*`, `app_patch/schema_recognition.py.backup_fazA_*`.
- Faz A içeriği: yüz-başına arama + makale füzyonu (0.45 ön/0.55 arka), ham+segment çift embedding (index HAM görsellerle build edilmiş — build≡serve düzeltmesi), eşik MIN_CONF=0.30 / TOP_N=5, nedenli no_match (no_coin_detected|low_detail_surface|below_confidence|ambiguous_match) + quality metrikleri.
- **AI12 modern para kapısı (2026-10-15, ADR-009):** `modern_kapi.py` → container İÇİNDE `/app/app/services/modern_kapi.py`
  (mount değil, `docker cp`); OCR paketi `rapidocr_onnxruntime` 1.4.4 → container İÇİNDE `/opt/pylib_ocr` (`docker cp`,
  VPS kaynağı `/root/ocr_gate/pylib`). Kapı **bayrak dosyasıyla** açılır: `/opt/ai_service/index/modern_gate.on` (container'da
  `/app/index/…`, her istekte bakılır — restart gerekmez; silmek = kapatmak). Ortam değişkeni `MODERN_GATE=1` yalnız atılabilir
  sınama konteynerinde. Kurallar `scripts/ai_eval/modern_kapi/kapi.py` v2 ile birebir (`esdeger_denetim.py`); kuralı önce orada ölç.
