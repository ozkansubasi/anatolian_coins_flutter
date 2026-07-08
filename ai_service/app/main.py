"""FastAPI Application - NumisTR AI Coin Recognition Service"""

import time
import logging
from datetime import datetime
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

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


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "NumisTR AI Coin Recognition",
        "version": "0.1.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "recognize": "/recognize (POST)",
            "docs": "/docs"
        }
    }


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
    reverse: Optional[UploadFile] = File(None, description="Reverse coin image (optional)")
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
            reverse_bytes=reverse_bytes
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
