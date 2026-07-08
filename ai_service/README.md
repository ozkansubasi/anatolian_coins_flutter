# NumisTR AI Recognition Service

FastAPI-based coin recognition microservice for NumisTR mobile app.

## Architecture

**Hybrid Approach**: Self-hosted primary + Google AutoML fallback

### Components

1. **Preprocessing Pipeline** - OpenCV image enhancement
2. **EfficientNet-B3 ONNX** - Visual embedding generation (1536-dim)
3. **FAISS Index** - Fast similarity search
4. **PaddleOCR** - Legend text extraction
5. **Ensemble Ranker** - Weighted visual + text scoring
6. **AutoML Fallback** - Low-confidence backup (Google Cloud)

### Flow

```
Image Upload → Preprocessing → EfficientNet → FAISS Search
                                                    ↓
                                              Top 50 results
                                                    ↓
                                    OCR Extraction (if available)
                                                    ↓
                                           Ensemble Ranking
                                                    ↓
                              Confidence < 0.6? → AutoML Fallback
                                                    ↓
                                            Final Top 10
```

## Quick Start

### 1. Training (Local Development)

```bash
# Install dependencies
pip install -r requirements.txt

# Prepare training data (see data/README.md)
python scripts/prepare_training_data.py \
  --db-config config/database.yaml \
  --output data/training/

# Train model
python scripts/train_model.py \
  --data-dir data/training/ \
  --metadata data/metadata.json \
  --output-dir models/ \
  --epochs 100 \
  --batch-size 32 \
  --use-arcface

# Export to ONNX with quantization
# (automatically done by train_model.py with --export-onnx flag)
```

### 2. Build FAISS Index

```bash
# Build index from trained model
python scripts/build_faiss_index.py \
  --model models/efficientnet_b3_coins_quantized.onnx \
  --db-config config/database.yaml \
  --image-base /path/to/sikke/ \
  --output index/ \
  --optimize
```

### 3. Local Testing

```bash
# Copy environment file
cp .env.example .env

# Edit .env with your config
nano .env

# Run service locally
uvicorn app.main:app --reload --port 8000

# Test endpoint
curl -X POST http://localhost:8000/recognize \
  -F "image=@test_coin.jpg" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. Docker Deployment

```bash
# Build image
docker-compose build

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f ai-service

# Health check
curl http://localhost:8000/health
```

## Configuration

### Environment Variables

See `.env.example` for all available options.

**Required:**
- `EFFICIENTNET_PATH` - Path to ONNX model
- `FAISS_INDEX_PATH` - Path to FAISS index
- `FAISS_METADATA_PATH` - Path to metadata JSON

**Optional:**
- `GOOGLE_PROJECT_ID` - For AutoML fallback
- `GOOGLE_MODEL_ID` - AutoML model ID
- `DB_HOST`, `DB_USER`, `DB_PASSWORD` - For direct DB queries

### Model Files

Place these in `models/` directory:

```
models/
├── efficientnet_b3_coins.onnx (original)
├── efficientnet_b3_coins_quantized.onnx (4x smaller)
└── label_mapping.json
```

### FAISS Index

Place these in `index/` directory:

```
index/
├── coins.index (FAISS binary)
├── metadata.json (article metadata)
└── stats.json (index statistics)
```

## API Endpoints

### POST /recognize

Recognize coin from image.

**Request:**
```bash
curl -X POST http://localhost:8000/recognize \
  -F "image=@obverse.jpg" \
  -F "reverse=@reverse.jpg"  # Optional
```

**Response:**
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
      "mint_name": "Sardis",
      "date_range": "138-161 AD",
      "material": "Bronze",
      "thumbnail_url": "https://..."
    },
    ...
  ],
  "confidence": 0.89,
  "method": "primary",  // or "automl" or "hybrid"
  "processing_time_ms": 342,
  "ocr_extracted": {
    "text": "ANTONINVS AVG",
    "confidence": 0.78
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "index_loaded": true,
  "index_size": 5000,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Performance

### Expected Metrics

- **Latency**: 200-500ms (single image, CPU)
- **Accuracy**: >90% top-10 hit rate
- **Throughput**: 50-100 requests/minute (4-core CPU)

### Optimization Tips

1. **Use Quantized Model** - 4x smaller, minimal accuracy loss
2. **Enable IVF Index** - 10x faster search for >10K coins
3. **GPU Acceleration** - 5-10x faster with CUDA
4. **Batch Processing** - Process multiple images concurrently

### Resource Requirements

**Minimum (CPU-only):**
- 2 CPU cores
- 2 GB RAM
- 500 MB disk (model + index)

**Recommended (Production):**
- 4 CPU cores
- 4 GB RAM
- 1 GB disk
- Optional: NVIDIA GPU with CUDA

## Joomla Integration

### Install Plugin Update

1. Update plugin XML manifest version to 1.2.0
2. Run database migration: `sql/updates/mysql/1.2.0.sql`
3. Configure AI service URL in plugin settings

### API Proxy Endpoints

**POST /api/index.php/v1/recognize**
- Authenticates user
- Checks scan quota
- Proxies to AI service
- Logs recognition request
- Returns formatted results

**GET /api/index.php/v1/scan-quota**
- Returns user's remaining scans
- Shows tier (free/pro)
- Provides reset date

### Quota Management

**Free Tier:**
- 10 scans per month
- Resets on 1st of each month
- Tracked in `#__numistr_recognition_log`

**Pro Tier:**
- Unlimited scans
- Determined by Joomla user group (ID: 9)

## Testing

### Unit Tests

```bash
# Run all tests
pytest tests/

# Run specific test
pytest tests/test_preprocessing.py -v

# With coverage
pytest --cov=app tests/
```

### Integration Tests

```bash
# Test full pipeline
python tests/test_integration.py --model models/efficientnet_b3_coins_quantized.onnx

# Test with sample images
python tests/test_samples.py --images test_data/
```

### Load Testing

```bash
# Install locust
pip install locust

# Run load test
locust -f tests/locustfile.py --host http://localhost:8000
```

## Monitoring

### Logs

```bash
# Docker logs
docker-compose logs -f ai-service

# Local logs
tail -f logs/app.log
```

### Metrics

Check `/health` endpoint for:
- Model load status
- Index size
- Request counts
- Error rates

## Troubleshooting

### Common Issues

**1. Model not loading**
```
Error: Model file not found
Solution: Check EFFICIENTNET_PATH in .env
```

**2. FAISS index error**
```
Error: Cannot load index
Solution: Rebuild index with build_faiss_index.py
```

**3. OCR not working**
```
Warning: PaddleOCR initialization failed
Solution: Install paddlepaddle and paddleocr
```

**4. Low accuracy**
```
Issue: Confidence scores < 0.5
Solution: Retrain with more data or enable AutoML fallback
```

**5. Slow inference**
```
Issue: >1s per request
Solution: Use quantized model, enable IVF index, or add GPU
```

### Debug Mode

Enable debug logging in `.env`:
```
LOG_LEVEL=debug
```

View detailed logs:
```bash
docker-compose logs -f ai-service | grep DEBUG
```

## Production Deployment

### Checklist

- [ ] Train model with full dataset (>5000 samples)
- [ ] Build optimized FAISS index
- [ ] Configure Google AutoML credentials
- [ ] Set up SSL certificates for Nginx
- [ ] Configure firewall rules
- [ ] Set resource limits in docker-compose.yml
- [ ] Enable health check monitoring
- [ ] Configure log rotation
- [ ] Set up backup for models and index
- [ ] Test failover scenarios

### Security

1. **HTTPS only** - Use Nginx with SSL
2. **Rate limiting** - Configure in Nginx (10 req/s)
3. **Authentication** - Verify JWT tokens from Joomla
4. **Input validation** - Check image size and format
5. **No data retention** - Delete uploaded images after processing

### Backup

```bash
# Backup models and index
tar -czf backup_$(date +%Y%m%d).tar.gz models/ index/

# Backup database tables
mysqldump -u user -p database \
  numistr_recognition_log \
  numistr_scan_history \
  > recognition_backup.sql
```

## License

Copyright (C) 2024 NumisTR. All rights reserved.

## Support

For issues or questions:
- GitHub Issues: [numistr/anatolian-coins](https://github.com/numistr/anatolian-coins)
- Email: support@numistr.org
