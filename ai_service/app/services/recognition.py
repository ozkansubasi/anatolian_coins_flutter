"""Main Recognition Service - Orchestrates AI pipeline"""

import logging
from typing import Optional, Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)


class RecognitionService:
    """
    Main recognition service orchestrating the entire AI pipeline

    Currently in STUB mode - returns mock data until models are trained
    """

    def __init__(
        self,
        efficientnet_path: str,
        faiss_index_path: str,
        faiss_metadata_path: str,
        db_host: str,
        db_port: int,
        db_name: str,
        db_user: str,
        db_password: str,
    ):
        self.efficientnet_path = efficientnet_path
        self.faiss_index_path = faiss_index_path
        self.faiss_metadata_path = faiss_metadata_path

        self.db_config = {
            'host': db_host,
            'port': db_port,
            'database': db_name,
            'user': db_user,
            'password': db_password,
        }

        # Services (will be initialized when models are ready)
        self.encoder = None
        self.faiss_index = None
        self.preprocessor = None
        self.ocr = None
        self.ranker = None
        self.automl = None

        logger.info("Recognition service created (STUB mode - no models loaded)")

    async def recognize(
        self,
        obverse_bytes: bytes,
        reverse_bytes: Optional[bytes] = None
    ) -> Dict[str, Any]:
        """
        Recognize coin from image bytes

        Args:
            obverse_bytes: Obverse (front) image bytes
            reverse_bytes: Optional reverse (back) image bytes

        Returns:
            Dictionary with recognition results
        """
        logger.info("Recognition requested (STUB mode - returning mock data)")

        # STUB: Return mock data until models are trained
        return {
            'matches': [
                {
                    'rank': 1,
                    'article_id': 12345,
                    'title': 'Antoninus Pius AE26 (MOCK DATA)',
                    'confidence': 0.89,
                    'visual_score': 0.92,
                    'ocr_score': 0.75,
                    'distance': 45.2,
                    'region': 'Lydia',
                    'mint_name': 'Sardis',
                    'authority_name': 'Antoninus Pius',
                    'material': 'AE',
                    'date_from': 138,
                    'date_to': 161
                },
                {
                    'rank': 2,
                    'article_id': 12346,
                    'title': 'Marcus Aurelius AE24 (MOCK DATA)',
                    'confidence': 0.78,
                    'visual_score': 0.81,
                    'ocr_score': 0.68,
                    'distance': 67.8,
                    'region': 'Lydia',
                    'mint_name': 'Sardis',
                    'authority_name': 'Marcus Aurelius',
                    'material': 'AE',
                    'date_from': 161,
                    'date_to': 180
                },
                {
                    'rank': 3,
                    'article_id': 12347,
                    'title': 'Hadrian AE25 (MOCK DATA)',
                    'confidence': 0.65,
                    'visual_score': 0.70,
                    'ocr_score': 0.52,
                    'distance': 89.3,
                    'region': 'Lydia',
                    'mint_name': 'Sardis',
                    'authority_name': 'Hadrian',
                    'material': 'AE',
                    'date_from': 117,
                    'date_to': 138
                }
            ],
            'confidence': 0.89,
            'method': 'stub',
            'processing_time_ms': 0,
            'ocr_extracted': {
                'obverse': ['STUB', 'DATA'],
                'reverse': ['MOCK']
            },
            'timestamp': datetime.utcnow()
        }
