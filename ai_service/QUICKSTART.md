# NumisTR AI Service - Quick Start Guide

Bu rehber, AI service'i kendi bilgisayarında çalıştırmak ve test etmek için gereken tüm adımları içerir.

## ✅ Şu Ana Kadar Tamamlananlar

- [x] FastAPI application (main.py)
- [x] Config management (config.py)
- [x] Recognition service (orchestration)
- [x] Preprocessing pipeline (OpenCV)
- [x] FAISS index manager
- [x] EfficientNet ONNX encoder
- [x] PaddleOCR integration
- [x] Google AutoML fallback
- [x] Ensemble ranker
- [x] API schemas (Pydantic models)
- [x] Training pipeline script
- [x] FAISS index builder script
- [x] Docker deployment files
- [x] Joomla API proxy (PHP)
- [x] Database migration SQL
- [x] Training data preparation script

## 📋 Sıradaki Adımlar

### 1. Dependencies Kurulumu

```bash
cd C:\Users\Hp\Desktop\NumisTR\anatolian_coins_flutter\ai_service

# Python packages
pip install -r requirements.txt
```

**Durum**: 🟡 Şu an kurulum devam ediyor...

### 2. Database Configuration

```bash
# Config template'ini kopyala
copy config\database.yaml.example config\database.yaml

# database.yaml dosyasını düzenle:
# - MySQL host, user, password
# - Joomla database adı
# - sikke images klasör yolu
```

**Örnek database.yaml:**
```yaml
database:
  host: localhost  # veya VPS IP
  port: 3306
  user: your_db_user
  password: your_db_password
  database: your_joomla_database

image_base_path: C:/path/to/sikke  # Windows için
# image_base_path: /var/www/html/sikke  # Linux için
```

### 3. Environment Configuration

```bash
# .env template'ini kopyala
copy .env.example .env

# .env dosyasını düzenle (model paths vs.)
```

**Minimum .env:**
```bash
# Model paths (şimdilik boş bırakabilirsin, training'den sonra doldurulacak)
EFFICIENTNET_PATH=models/efficientnet_b3_coins.onnx
FAISS_INDEX_PATH=index/coins.index
FAISS_METADATA_PATH=index/metadata.json

# Database
DB_HOST=localhost
DB_PORT=3306
DB_NAME=your_joomla_db
DB_USER=your_db_user
DB_PASSWORD=your_db_password

# Settings
TOP_K=50
CONFIDENCE_THRESHOLD=0.6
LOG_LEVEL=info
```

### 4. Joomla Database Migration

Joomla veritabanında yeni tabloları oluştur:

```sql
-- plugins/webservices/numistr/sql/updates/mysql/1.2.0.sql dosyasını çalıştır

-- phpMyAdmin veya MySQL CLI ile:
mysql -u your_user -p your_database < C:\Users\Hp\Desktop\NumisTR\plugins\webservices\numistr\sql\updates\mysql\1.2.0.sql
```

**Oluşturulan tablolar:**
- `#__numistr_recognition_log` - Recognition istekleri log
- `#__numistr_scan_history` - Kullanıcı scan geçmişi
- `#__numistr_recognition_prefs` - Kullanıcı tercihleri

### 5. Training Data Hazırlığı

```bash
# Önce küçük bir test dataset'i (100 coin)
python scripts/prepare_training_data.py \
  --db-config config/database.yaml \
  --output data/training/ \
  --limit 100 \
  --test-split 0.2
```

**Çıktı:**
```
data/training/
├── train/
│   ├── images/
│   │   ├── 12345_obv.jpg
│   │   ├── 12345_rev.jpg
│   │   └── ...
│   └── metadata.json
├── test/
│   ├── images/
│   │   └── ...
│   └── metadata.json
└── stats.json
```

### 6. Model Training (İlk Test)

```bash
# Test dataset ile quick training (10 epoch)
python scripts/train_model.py \
  --data-dir data/training/train \
  --metadata data/training/train/metadata.json \
  --output-dir models/ \
  --epochs 10 \
  --batch-size 16 \
  --lr 0.001 \
  --export-onnx \
  --quantize
```

**Beklenen süre**: ~15-30 dakika (100 coin, CPU)

**Çıktı:**
```
models/
├── best.pth
├── last.pth
├── efficientnet_b3_coins.onnx
├── efficientnet_b3_coins_quantized.onnx
└── label_mapping.json
```

### 7. FAISS Index Build

```bash
# Test model ile index oluştur
python scripts/build_faiss_index.py \
  --model models/efficientnet_b3_coins_quantized.onnx \
  --db-config config/database.yaml \
  --output index/
```

**Çıktı:**
```
index/
├── coins.index
├── metadata.json
├── stats.json
└── failed.txt (varsa)
```

### 8. Local Test

```bash
# AI service'i başlat
uvicorn app.main:app --reload --port 8000
```

**Test endpoint:**
```bash
# Health check
curl http://localhost:8000/health

# Recognition test
curl -X POST http://localhost:8000/recognize \
  -F "image=@test_coin.jpg" \
  | json_pp
```

**Beklenen response:**
```json
{
  "matches": [
    {
      "rank": 1,
      "article_id": 12345,
      "title": "Antoninus Pius AE26",
      "confidence": 0.89,
      "visual_score": 0.92,
      "ocr_score": 0.75,
      "region": "Lydia",
      "mint_name": "Sardis"
    }
  ],
  "confidence": 0.89,
  "method": "primary",
  "processing_time_ms": 342
}
```

### 9. Joomla Integration

```bash
# 1. RecognitionController.php'yi plugin'e ekle
cp C:\Users\Hp\Desktop\NumisTR\plugins\webservices\numistr\src\Controller\RecognitionController.php \
   /var/www/html/plugins/webservices/numistr/src/Controller/

# 2. RecognitionHelper.php'yi ekle
cp C:\Users\Hp\Desktop\NumisTR\plugins\webservices\numistr\src\Helper\RecognitionHelper.php \
   /var/www/html/plugins/webservices/numistr/src/Helper/

# 3. Plugin manifest güncellemesi (version 1.2.0)
# numistr.xml dosyasını düzenle, version'ı 1.2.0 yap

# 4. Joomla admin panelden Extensions > Manage > Discover
# 5. Plugin'i Update et
```

**Test Joomla endpoint:**
```bash
curl -X POST https://www.numistr.org/api/index.php/v1/recognize \
  -H "Authorization: Bearer YOUR_JOOMLA_TOKEN" \
  -F "image=@test_coin.jpg"
```

### 10. Flutter Integration

Flutter app'e recognition API ekle:

```dart
// lib/src/features/recognition/recognition_api.dart
class RecognitionApi {
  final Dio _dio;

  Future<RecognitionResult> recognize(
    File image,
    [File? reverse]
  ) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path),
      if (reverse != null)
        'reverse': await MultipartFile.fromFile(reverse.path),
    });

    final response = await _dio.post(
      '/recognize',
      data: formData
    );

    return RecognitionResult.fromJson(response.data['data']);
  }

  Future<QuotaInfo> getScanQuota() async {
    final response = await _dio.get('/scan-quota');
    return QuotaInfo.fromJson(response.data['data']);
  }
}
```

## 🚀 Full Production Workflow

Yukarıdaki test adımları başarılı olduktan sonra:

### 1. Full Dataset Training

```bash
# Tüm coin'ler ile train et (limit olmadan)
python scripts/prepare_training_data.py \
  --db-config config/database.yaml \
  --output data/full/ \
  --test-split 0.2

# Full training (100 epoch)
python scripts/train_model.py \
  --data-dir data/full/train \
  --metadata data/full/train/metadata.json \
  --output-dir models/production/ \
  --epochs 100 \
  --batch-size 32 \
  --use-arcface \
  --export-onnx \
  --quantize
```

**Beklenen süre**: ~8-12 saat (5000 coin, CPU)

### 2. Full FAISS Index

```bash
python scripts/build_faiss_index.py \
  --model models/production/efficientnet_b3_coins_quantized.onnx \
  --db-config config/database.yaml \
  --output index/production/ \
  --optimize
```

### 3. Docker Deployment

```bash
# Build
docker-compose build

# Start
docker-compose up -d

# Logs
docker-compose logs -f ai-service

# Health
curl http://localhost:8000/health
```

### 4. Production Checklist

- [ ] Model accuracy >90% (test set)
- [ ] FAISS index tüm coin'leri kapsıyor
- [ ] Docker container çalışıyor
- [ ] Health check başarılı
- [ ] Joomla plugin güncel (v1.2.0)
- [ ] Database migration tamamlandı
- [ ] SSL certificates hazır (Nginx)
- [ ] Rate limiting aktif
- [ ] Log rotation konfigüre edildi
- [ ] Backup stratejisi hazır

## 🆘 Troubleshooting

### Dependencies kurulamıyor
```bash
# Python version kontrolü
python --version  # 3.11 veya 3.13 olmalı

# Pip güncelle
pip install --upgrade pip

# Tek tek kur
pip install torch torchvision
pip install onnxruntime faiss-cpu
pip install paddlepaddle paddleocr
```

### Model training hatası
```bash
# CUDA out of memory -> batch size düşür
--batch-size 8

# Memory leak -> restart Python
# Images not found -> image_base_path kontrolü
```

### FAISS index build hatası
```bash
# Database connection error -> database.yaml kontrolü
# Images not found -> image_base_path düzelt
# Out of memory -> optimize=False kullan
```

### Service başlamıyor
```bash
# Model files check
ls models/*.onnx
ls index/*.index

# .env check
cat .env

# Port conflict
lsof -i :8000  # Linux
netstat -ano | findstr :8000  # Windows
```

## 📊 Performans Beklentileri

**Test Setup (100 coin):**
- Training: ~20 dakika
- Index build: ~5 dakika
- Inference: ~300ms/request

**Production Setup (5000 coin):**
- Training: ~10 saat
- Index build: ~30 dakika
- Inference: ~500ms/request

**Accuracy Targets:**
- Top-1: >70%
- Top-5: >85%
- Top-10: >90%

## 📝 Notlar

- İlk test için 100-500 coin ile başla
- Training'de ArcFace loss kullan (daha iyi embeddings)
- ONNX quantization kullan (4x küçük, minimal accuracy loss)
- IVF index kullan (>1000 coin için gerekli)
- AutoML fallback'i sadece production'da aktif et

## 🔗 Kaynaklar

- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [FAISS Wiki](https://github.com/facebookresearch/faiss/wiki)
- [PaddleOCR Docs](https://github.com/PaddlePaddle/PaddleOCR)
- [EfficientNet Paper](https://arxiv.org/abs/1905.11946)
- [ArcFace Paper](https://arxiv.org/abs/1801.07698)
