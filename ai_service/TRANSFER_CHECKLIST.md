# AI Service File Transfer Checklist

VPS'e kopyalanması gereken dosyalar:

## Zorunlu Klasörler ve Dosyalar

```
ai_service/
├── app/                           # ⚠️ ZORUNLU - Python application code
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── api/
│   │   ├── __init__.py
│   │   └── schemas/
│   │       ├── __init__.py
│   │       └── recognition.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── automl.py
│   │   ├── efficientnet.py
│   │   └── ocr.py
│   └── services/
│       ├── __init__.py
│       ├── ensemble.py
│       ├── faiss_index.py
│       ├── preprocessing.py
│       └── recognition.py
├── scripts/                       # Training scripts
│   ├── train_model.py
│   ├── build_faiss_index.py
│   └── prepare_training_data.py
├── Dockerfile                     # ⚠️ ZORUNLU
├── docker-compose.yml             # ⚠️ ZORUNLU
├── requirements.txt               # ⚠️ ZORUNLU
├── .env                          # VPS'de oluşturulacak
├── config/
│   └── database.yaml             # VPS'de oluşturulacak
├── models/                       # VPS'de oluşturulacak (placeholder)
└── index/                        # VPS'de oluşturulacak (placeholder)
```

## Transfer Komutu

**Windows'tan VPS'e:**
```powershell
# Tüm ai_service klasörünü kopyala
scp -r C:\Users\Hp\Desktop\NumisTR\anatolian_coins_flutter\ai_service root@31.7.37.201:/opt/
```

**VEYA sadece eksik klasörü kopyala:**
```powershell
# Sadece app/ klasörünü kopyala
scp -r C:\Users\Hp\Desktop\NumisTR\anatolian_coins_flutter\ai_service\app root@31.7.37.201:/opt/ai_service/
```

## VPS'de Kontrol

```bash
cd /opt/ai_service

# Klasör yapısını kontrol et
ls -la

# app/ klasörünün içini kontrol et
ls -la app/

# Beklenen çıktı:
# app/
# ├── __init__.py
# ├── main.py
# ├── config.py
# ├── api/
# ├── models/
# └── services/
```

## Dockerfile Path Düzeltmesi

Eğer klasör yapısı farklıysa, Dockerfile'da path'leri düzelt:

```dockerfile
# Şu satır:
COPY app/ /app/app/

# Eğer app/ /opt/ai_service/app/ yerine başka yerdeyse
# path'i buna göre düzelt
```
