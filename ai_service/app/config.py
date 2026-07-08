"""Configuration management using Pydantic Settings"""

from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    # Model paths
    efficientnet_path: str = Field(
        default="models/efficientnet_b3_coins_quantized.onnx",
        alias="EFFICIENTNET_PATH"
    )
    faiss_index_path: str = Field(
        default="index/coins.index",
        alias="FAISS_INDEX_PATH"
    )
    faiss_metadata_path: str = Field(
        default="index/metadata.json",
        alias="FAISS_METADATA_PATH"
    )

    # Database configuration
    db_host: str = Field(default="localhost", alias="DB_HOST")
    db_port: int = Field(default=3306, alias="DB_PORT")
    db_name: str = Field(default="numistr", alias="DB_NAME")
    db_user: str = Field(default="root", alias="DB_USER")
    db_password: str = Field(default="", alias="DB_PASSWORD")

    # Recognition settings
    top_k: int = Field(default=50, alias="TOP_K")
    confidence_threshold: float = Field(default=0.6, alias="CONFIDENCE_THRESHOLD")
    ocr_min_confidence: float = Field(default=0.5, alias="OCR_MIN_CONFIDENCE")

    # Google AutoML (optional)
    google_project_id: Optional[str] = Field(default=None, alias="GOOGLE_PROJECT_ID")
    google_model_id: Optional[str] = Field(default=None, alias="GOOGLE_MODEL_ID")
    google_credentials: Optional[str] = Field(default=None, alias="GOOGLE_APPLICATION_CREDENTIALS")

    # FastAPI settings
    log_level: str = Field(default="info", alias="LOG_LEVEL")
    cors_origins: str = Field(
        default="https://www.numistr.org,https://numistr.org",
        alias="CORS_ORIGINS"
    )

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def cors_origins_list(self) -> list[str]:
        """Parse CORS origins string to list"""
        return [origin.strip() for origin in self.cors_origins.split(",")]


# Global settings instance
settings = Settings()
