"""FastAPI Application - NumisTR AI Coin Recognition Service"""

import time
import logging
from datetime import datetime
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse

from app.config import settings
from app.api.schemas.recognition import RecognitionResponse, HealthResponse

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# FastAPI app
app = FastAPI(
    title="NumisTR AI Service",
    description="Ancient Anatolian Coin Recognition API",
    version="0.1.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global service instances (lazy loaded)
recognition_service = None


def get_recognition_service():
    """Lazy load recognition service"""
    global recognition_service
    if recognition_service is None:
        try:
            # Import here to avoid circular imports
            from app.services.recognition import RecognitionService
            recognition_service = RecognitionService(
                efficientnet_path=settings.efficientnet_path,
                faiss_index_path=settings.faiss_index_path,
                faiss_metadata_path=settings.faiss_metadata_path,
                db_host=settings.db_host,
                db_port=settings.db_port,
                db_name=settings.db_name,
                db_user=settings.db_user,
                db_password=settings.db_password,
            )
            logger.info("Recognition service initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize recognition service: {e}")
            recognition_service = None
    return recognition_service


@app.on_event("startup")
async def startup_event():
    """Application startup event"""
    logger.info("NumisTR AI Service starting...")
    logger.info(f"CORS origins: {settings.cors_origins_list}")

    # Try to initialize services
    try:
        service = get_recognition_service()
        if service:
            logger.info("✓ Recognition service ready")
        else:
            logger.warning("⚠ Recognition service not available (models not loaded)")
    except Exception as e:
        logger.error(f"Startup error: {e}")


@app.get("/", response_class=HTMLResponse)
async def root():
    """Root endpoint - HTML landing page"""
    html_content = """
    <!DOCTYPE html>
    <html lang="tr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>NumisTR AI - Coin Recognition Service</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            .container {
                background: white;
                border-radius: 16px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                padding: 40px;
                max-width: 600px;
                width: 100%;
            }
            h1 {
                color: #667eea;
                font-size: 2rem;
                margin-bottom: 10px;
                text-align: center;
            }
            .subtitle {
                color: #666;
                text-align: center;
                margin-bottom: 30px;
                font-size: 1.1rem;
            }
            .status {
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 10px;
                padding: 15px;
                background: #f0fdf4;
                border: 2px solid #86efac;
                border-radius: 8px;
                margin-bottom: 30px;
            }
            .status-dot {
                width: 12px;
                height: 12px;
                background: #22c55e;
                border-radius: 50%;
                animation: pulse 2s infinite;
            }
            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.5; }
            }
            .endpoints {
                background: #f8fafc;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
            }
            .endpoints h2 {
                color: #334155;
                font-size: 1.2rem;
                margin-bottom: 15px;
            }
            .endpoint {
                display: flex;
                justify-content: space-between;
                padding: 12px;
                margin-bottom: 8px;
                background: white;
                border-radius: 6px;
                border-left: 4px solid #667eea;
            }
            .endpoint:last-child { margin-bottom: 0; }
            .endpoint-path {
                font-family: 'Courier New', monospace;
                color: #667eea;
                font-weight: 600;
            }
            .endpoint-method {
                background: #ddd6fe;
                color: #5b21b6;
                padding: 4px 12px;
                border-radius: 4px;
                font-size: 0.85rem;
                font-weight: 600;
            }
            .stats {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 15px;
                margin-top: 20px;
            }
            .stat {
                text-align: center;
                padding: 20px;
                background: #f1f5f9;
                border-radius: 8px;
            }
            .stat-value {
                font-size: 1.5rem;
                font-weight: bold;
                color: #667eea;
            }
            .stat-label {
                color: #64748b;
                font-size: 0.9rem;
                margin-top: 5px;
            }
            .footer {
                text-align: center;
                color: #94a3b8;
                font-size: 0.9rem;
                margin-top: 20px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🪙 NumisTR AI</h1>
            <p class="subtitle">Ancient Anatolian Coin Recognition Service</p>
            
            <div class="status">
                <div class="status-dot"></div>
                <strong>Service Running</strong>
            </div>

            <div class="endpoints">
                <h2>📡 API Endpoints</h2>
                <div class="endpoint">
                    <span class="endpoint-path">/health</span>
                    <span class="endpoint-method">GET</span>
                </div>
                <div class="endpoint">
                    <span class="endpoint-path">/recognize</span>
                    <span class="endpoint-method">POST</span>
                </div>
                <div class="endpoint">
                    <span class="endpoint-path">/docs</span>
                    <span class="endpoint-method">GET</span>
                </div>
            </div>

            <div class="stats">
                <div class="stat">
                    <div class="stat-value">37K+</div>
                    <div class="stat-label">Training Images</div>
                </div>
                <div class="stat">
                    <div class="stat-value">EfficientNet</div>
                    <div class="stat-label">Deep Learning Model</div>
                </div>
            </div>

            <div class="footer">
                v0.1.0 &middot; Powered by FastAPI &middot; NumisTR &copy; 2025
            </div>
        </div>
    </body>
    </html>
    """
    return html_content

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    model_loaded = False
    index_loaded = False

    try:
        service = get_recognition_service()
        if service:
            model_loaded = service.encoder is not None
            index_loaded = service.faiss_index is not None
    except Exception as e:
        logger.error(f"Health check error: {e}")

    return HealthResponse(
        status="healthy" if (model_loaded or index_loaded) else "degraded",
        model_loaded=model_loaded,
        index_loaded=index_loaded,
        timestamp=datetime.utcnow()
    )


@app.post("/recognize", response_model=RecognitionResponse)
async def recognize_coin(
    image: UploadFile = File(..., description="Obverse coin image"),
    reverse: Optional[UploadFile] = File(None, description="Reverse coin image (optional)"),
    metal: Optional[str] = Form(None, description="Optional metal hint (silver/bronze/gold/electrum/copper/lead/...)"),
    weight_g: Optional[str] = Form(None, description="Optional weight in grams"),
    diameter_mm: Optional[str] = Form(None, description="Optional diameter in mm")
):
    """
    Recognize a coin from uploaded image(s)

    Args:
        image: Obverse (front) image of the coin
        reverse: Optional reverse (back) image of the coin

    Returns:
        RecognitionResponse with top matches and confidence scores
    """
    start_time = time.time()

    try:
        # Get recognition service
        service = get_recognition_service()
        if service is None:
            raise HTTPException(
                status_code=503,
                detail="Recognition service not available. Models not loaded."
            )

        # Read image bytes
        obverse_bytes = await image.read()
        reverse_bytes = await reverse.read() if reverse else None

        # Validate file sizes
        if len(obverse_bytes) > 10 * 1024 * 1024:  # 10MB
            raise HTTPException(status_code=413, detail="Obverse image too large (max 10MB)")
        if reverse_bytes and len(reverse_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Reverse image too large (max 10MB)")

        # Perform recognition
        result = await service.recognize(
            obverse_bytes=obverse_bytes,
            reverse_bytes=reverse_bytes,
            metal=metal,
            weight_g=weight_g,
            diameter_mm=diameter_mm
        )

        # Add processing time
        processing_time = int((time.time() - start_time) * 1000)
        result['processing_time_ms'] = processing_time

        return RecognitionResponse(**result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Recognition error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Recognition failed: {str(e)}")


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
