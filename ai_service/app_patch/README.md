# app_patch — CANLI /opt/ai_service/app_patch kopyası (2026-08-24, Faz A)

- `recognition.py` → VPS'te container'a mount: `/opt/ai_service/app_patch/recognition.py -> /app/app/services/recognition.py`. Değişiklik sonrası sadece `docker restart numistr_ai` (recreate YAPMA — pip kurulumları gider).
- `api_schemas_recognition.py` → container İÇİNDE `/app/app/api/schemas/recognition.py` (mount değil): `docker cp` ile güncellenir.
- Rollback yedekleri VPS'te: `app_patch/recognition.py.backup_fazA_*`, `app_patch/schema_recognition.py.backup_fazA_*`.
- Faz A içeriği: yüz-başına arama + makale füzyonu (0.45 ön/0.55 arka), ham+segment çift embedding (index HAM görsellerle build edilmiş — build≡serve düzeltmesi), eşik MIN_CONF=0.30 / TOP_N=5, nedenli no_match (no_coin_detected|low_detail_surface|below_confidence|ambiguous_match) + quality metrikleri.
