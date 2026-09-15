"""Pydantic models for recognition API"""

from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class CoinMatch(BaseModel):
    """Single coin match result"""
    rank: int = Field(..., description="Match ranking (1-based)")
    article_id: int = Field(..., description="NumisTR article ID")
    title: str = Field(..., description="Coin title")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Overall confidence score")
    visual_score: float = Field(..., ge=0.0, le=1.0, description="Visual similarity score")
    ocr_score: Optional[float] = Field(None, ge=0.0, le=1.0, description="OCR match score")
    obverse_score: Optional[float] = Field(None, ge=0.0, le=1.0, description="Obverse-side visual score")
    reverse_score: Optional[float] = Field(None, ge=0.0, le=1.0, description="Reverse-side visual score")
    image_type: Optional[str] = Field(None, description="Matched image side/type")
    tied_with: Optional[List[int]] = Field(None, description="Article IDs this match is indistinguishable from (identical photograph)")
    distance: Optional[float] = Field(None, description="FAISS L2 distance")

    # Coin metadata
    region: Optional[str] = Field(None, description="Geographic region")
    mint_name: Optional[str] = Field(None, description="Mint name")
    authority_name: Optional[str] = Field(None, description="Authority name")
    material: Optional[str] = Field(None, description="Material (metal)")
    date_from: Optional[int] = Field(None, description="Dating start year")
    date_to: Optional[int] = Field(None, description="Dating end year")

    class Config:
        json_schema_extra = {
            "example": {
                "rank": 1,
                "article_id": 12345,
                "title": "Antoninus Pius AE26",
                "confidence": 0.89,
                "visual_score": 0.92,
                "ocr_score": 0.75,
                "distance": 45.2,
                "region": "Lydia",
                "mint_name": "Sardis",
                "authority_name": "Antoninus Pius",
                "material": "AE",
                "date_from": 138,
                "date_to": 161
            }
        }


class RecognitionResponse(BaseModel):
    """Recognition API response"""
    matches: List[CoinMatch] = Field(..., description="Top matching coins")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Top match confidence")
    method: str = Field(..., description="Recognition method used (primary/automl/hybrid)")
    processing_time_ms: int = Field(..., description="Processing time in milliseconds")
    ocr_extracted: Optional[Dict[str, Any]] = Field(None, description="Extracted OCR text")
    ambiguous: bool = Field(False, description="Top candidates are indistinguishable (same photograph on several catalog records)")
    tie_size: int = Field(0, description="Number of tied top candidates (0 when not ambiguous)")
    tied_articles: List[int] = Field(default_factory=list, description="Article IDs in the tied top group")
    no_match: bool = Field(False, description="True when no confident match was found")
    no_match_reason: Optional[str] = Field(None, description="no_coin_detected | low_detail_surface | below_confidence | ambiguous_match | service_unavailable")
    quality: Optional[Dict[str, Any]] = Field(None, description="Per-side input quality metrics")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Response timestamp")

    class Config:
        json_schema_extra = {
            "example": {
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
                "processing_time_ms": 342,
                "ocr_extracted": {"obverse": ["ANTONINVS", "AVG"], "reverse": ["CONCORDIA"]},
                "timestamp": "2025-10-19T12:34:56.789Z"
            }
        }


class HealthResponse(BaseModel):
    """Health check response"""
    status: str = Field(..., description="Service status (healthy/degraded/unhealthy)")
    model_loaded: bool = Field(..., description="Whether ML model is loaded")
    index_loaded: bool = Field(..., description="Whether FAISS index is loaded")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Check timestamp")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "healthy",
                "model_loaded": True,
                "index_loaded": True,
                "timestamp": "2025-10-19T12:34:56.789Z"
            }
        }
