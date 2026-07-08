#!/usr/bin/env python3
"""
NumisTR FAISS Index Builder

Builds FAISS vector index from trained model by:
1. Loading all coin images from database
2. Generating embeddings using trained ONNX model
3. Building optimized FAISS index
4. Exporting metadata JSON

Usage:
    python scripts/build_faiss_index.py --model models/efficientnet_b3_coins.onnx --db-config config.yaml
    python scripts/build_faiss_index.py --model models/best.pth --output index/ --gpu
"""

import argparse
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import cv2
import faiss
import numpy as np
import onnxruntime as ort
import torch
import yaml
from PIL import Image
from tqdm import tqdm
import mysql.connector

from app.services.preprocessing import CoinPreprocessor

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ImageLoader:
    """Load coin images from NumisTR database and file system."""

    def __init__(self, db_config: Dict, image_base_path: Path):
        self.db_config = db_config
        self.image_base_path = image_base_path
        self.conn = None
        self.preprocessor = CoinPreprocessor()

    def connect(self):
        """Connect to Joomla database."""
        logger.info("Connecting to database...")
        self.conn = mysql.connector.connect(
            host=self.db_config['host'],
            port=self.db_config.get('port', 3306),
            user=self.db_config['user'],
            password=self.db_config['password'],
            database=self.db_config['database']
        )
        logger.info("✅ Database connected")

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()

    def get_all_variants(self) -> List[Dict]:
        """
        Query all coin variants from database.

        Returns list of dicts with:
            - article_id
            - title_tr
            - title_en
            - region_code
            - mint_name
            - authority_name
            - material
            - date_from
            - date_to
            - obverse_image_id
            - reverse_image_id
        """
        cursor = self.conn.cursor(dictionary=True)

        query = """
        SELECT
            v.article_id,
            v.title_tr,
            v.title_en,
            v.region_code,
            v.mint_name,
            v.authority_name,
            v.metal as material,
            v.date_from,
            v.date_to,
            (SELECT image_id FROM coins_images
             WHERE coin_id = v.article_id AND image_type = 'obverse'
             ORDER BY weight ASC LIMIT 1) as obverse_image_id,
            (SELECT image_id FROM coins_images
             WHERE coin_id = v.article_id AND image_type = 'reverse'
             ORDER BY weight ASC LIMIT 1) as reverse_image_id
        FROM o_numistr_variants_public v
        WHERE v.published = 1
        ORDER BY v.article_id
        """

        cursor.execute(query)
        variants = cursor.fetchall()
        cursor.close()

        logger.info(f"Found {len(variants)} published variants")
        return variants

    def get_image_path(self, image_id: int) -> Optional[Path]:
        """
        Get file path for image_id from database.

        Returns:
            Path object if image exists, None otherwise
        """
        cursor = self.conn.cursor(dictionary=True)

        query = """
        SELECT filename, remote_url
        FROM coins_images
        WHERE image_id = %s
        """

        cursor.execute(query, (image_id,))
        result = cursor.fetchone()
        cursor.close()

        if not result:
            return None

        # Check local file first
        if result['filename']:
            # Extract region from filename path (e.g., 'anatolia/coin123.jpg')
            filename = result['filename']
            local_path = self.image_base_path / filename

            if local_path.exists():
                return local_path

        # TODO: Handle remote_url fetching if needed
        return None

    def load_and_preprocess(self, image_path: Path) -> Optional[np.ndarray]:
        """Load image and apply preprocessing."""
        try:
            # Load image
            img = cv2.imread(str(image_path))
            if img is None:
                logger.warning(f"Failed to load image: {image_path}")
                return None

            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

            # Preprocess
            processed = self.preprocessor.process(img)

            return processed

        except Exception as e:
            logger.error(f"Error processing {image_path}: {e}")
            return None


class EmbeddingGenerator:
    """Generate embeddings using trained model (ONNX or PyTorch)."""

    def __init__(self, model_path: Path, use_gpu: bool = False):
        self.model_path = model_path
        self.use_gpu = use_gpu
        self.session = None
        self.model = None

        self._load_model()

    def _load_model(self):
        """Load model (ONNX or PyTorch based on extension)."""
        if self.model_path.suffix == '.onnx':
            self._load_onnx_model()
        elif self.model_path.suffix == '.pth':
            self._load_pytorch_model()
        else:
            raise ValueError(f"Unsupported model format: {self.model_path.suffix}")

    def _load_onnx_model(self):
        """Load ONNX model."""
        logger.info(f"Loading ONNX model: {self.model_path}")

        providers = ['CUDAExecutionProvider', 'CPUExecutionProvider'] if self.use_gpu else ['CPUExecutionProvider']

        self.session = ort.InferenceSession(
            str(self.model_path),
            providers=providers
        )

        logger.info(f"✅ ONNX model loaded (provider: {self.session.get_providers()[0]})")

    def _load_pytorch_model(self):
        """Load PyTorch checkpoint and convert to eval mode."""
        logger.info(f"Loading PyTorch checkpoint: {self.model_path}")

        device = torch.device('cuda' if self.use_gpu and torch.cuda.is_available() else 'cpu')

        checkpoint = torch.load(self.model_path, map_location=device)

        # Import model class (assumes it's in the same project)
        from scripts.train_model import CoinRecognitionModel

        # Get num_classes from checkpoint
        num_classes = len(checkpoint['id_to_label'])
        embedding_dim = 1536  # Default, could be saved in checkpoint

        self.model = CoinRecognitionModel(
            num_classes=num_classes,
            embedding_dim=embedding_dim,
            pretrained=False
        ).to(device)

        self.model.load_state_dict(checkpoint['model_state_dict'])
        self.model.eval()

        logger.info(f"✅ PyTorch model loaded ({device})")

    def encode(self, obverse: np.ndarray, reverse: Optional[np.ndarray] = None) -> np.ndarray:
        """
        Generate embedding from coin image(s).

        Args:
            obverse: Preprocessed obverse image [H, W, C]
            reverse: Optional preprocessed reverse image [H, W, C]

        Returns:
            L2-normalized embedding vector [D]
        """
        if self.session:
            # ONNX inference
            return self._encode_onnx(obverse, reverse)
        else:
            # PyTorch inference
            return self._encode_pytorch(obverse, reverse)

    def _encode_onnx(self, obverse: np.ndarray, reverse: Optional[np.ndarray]) -> np.ndarray:
        """ONNX inference."""
        # Prepare input: [1, num_sides, C, H, W]
        if reverse is not None:
            # Stack both sides
            images = np.stack([obverse, reverse])  # [2, C, H, W]
        else:
            images = obverse[np.newaxis]  # [1, C, H, W]

        images = images[np.newaxis]  # [1, num_sides, C, H, W]
        images = images.astype(np.float32)

        # Run inference
        input_name = self.session.get_inputs()[0].name
        output_name = self.session.get_outputs()[0].name

        embedding = self.session.run([output_name], {input_name: images})[0][0]

        # L2 normalize
        embedding = embedding / np.linalg.norm(embedding)

        return embedding

    def _encode_pytorch(self, obverse: np.ndarray, reverse: Optional[np.ndarray]) -> np.ndarray:
        """PyTorch inference."""
        device = next(self.model.parameters()).device

        # Convert to tensor
        obverse_tensor = torch.from_numpy(obverse).unsqueeze(0)  # [1, C, H, W]

        if reverse is not None:
            reverse_tensor = torch.from_numpy(reverse).unsqueeze(0)
            images = torch.stack([obverse_tensor, reverse_tensor], dim=1)  # [1, 2, C, H, W]
        else:
            images = obverse_tensor.unsqueeze(1)  # [1, 1, C, H, W]

        images = images.to(device)

        # Inference
        with torch.no_grad():
            embedding = self.model(images, return_embedding=True)[0].cpu().numpy()

        return embedding


def build_faiss_index(
    embeddings: np.ndarray,
    use_gpu: bool = False,
    optimize: bool = True
) -> faiss.Index:
    """
    Build FAISS index from embeddings.

    Args:
        embeddings: Array of embeddings [N, D]
        use_gpu: Use GPU for index
        optimize: Apply index optimization (IVF clustering)

    Returns:
        FAISS index
    """
    n_vectors, dim = embeddings.shape
    logger.info(f"Building FAISS index: {n_vectors} vectors, dimension {dim}")

    if optimize and n_vectors > 10000:
        # Use IVF (Inverted File Index) for large datasets
        nlist = min(int(np.sqrt(n_vectors)), 4096)  # Number of clusters
        quantizer = faiss.IndexFlatL2(dim)
        index = faiss.IndexIVFFlat(quantizer, dim, nlist, faiss.METRIC_L2)

        logger.info(f"Training IVF index with {nlist} clusters...")
        index.train(embeddings.astype(np.float32))
        logger.info("✅ Training complete")

    else:
        # Use flat index for small datasets
        index = faiss.IndexFlatL2(dim)

    # Add vectors
    logger.info("Adding vectors to index...")
    index.add(embeddings.astype(np.float32))
    logger.info(f"✅ Index built: {index.ntotal} vectors")

    # Move to GPU if requested
    if use_gpu and faiss.get_num_gpus() > 0:
        logger.info("Moving index to GPU...")
        res = faiss.StandardGpuResources()
        index = faiss.index_cpu_to_gpu(res, 0, index)
        logger.info("✅ Index on GPU")

    return index


def main():
    parser = argparse.ArgumentParser(description="Build FAISS index for NumisTR")

    # Model
    parser.add_argument('--model', type=Path, required=True, help="Path to trained model (.onnx or .pth)")
    parser.add_argument('--gpu', action='store_true', help="Use GPU for encoding and index")

    # Database
    parser.add_argument('--db-config', type=Path, required=True, help="Database config YAML file")
    parser.add_argument('--image-base', type=Path, help="Base path for coin images (default from config)")

    # Output
    parser.add_argument('--output', type=Path, default=Path('index'), help="Output directory")

    # Options
    parser.add_argument('--optimize', action='store_true', default=True, help="Optimize index with IVF")
    parser.add_argument('--batch-size', type=int, default=32, help="Batch size for encoding")

    args = parser.parse_args()

    # Load database config
    with open(args.db_config) as f:
        db_config = yaml.safe_load(f)

    image_base_path = args.image_base or Path(db_config.get('image_base_path', '../sikke'))

    # Create output directory
    args.output.mkdir(parents=True, exist_ok=True)

    # Initialize components
    loader = ImageLoader(db_config['database'], image_base_path)
    loader.connect()

    encoder = EmbeddingGenerator(args.model, use_gpu=args.gpu)

    # Get all variants from database
    variants = loader.get_all_variants()

    # Generate embeddings
    embeddings = []
    metadata = []
    failed = []

    logger.info("Generating embeddings...")

    for variant in tqdm(variants, desc="Processing variants"):
        article_id = variant['article_id']

        try:
            # Load images
            obverse_path = loader.get_image_path(variant['obverse_image_id']) if variant['obverse_image_id'] else None
            reverse_path = loader.get_image_path(variant['reverse_image_id']) if variant['reverse_image_id'] else None

            if not obverse_path:
                logger.warning(f"No obverse image for article {article_id}, skipping")
                failed.append(article_id)
                continue

            # Preprocess
            obverse = loader.load_and_preprocess(obverse_path)
            reverse = loader.load_and_preprocess(reverse_path) if reverse_path else None

            if obverse is None:
                failed.append(article_id)
                continue

            # Generate embedding
            embedding = encoder.encode(obverse, reverse)

            # Store
            embeddings.append(embedding)
            metadata.append({
                'faiss_id': len(embeddings) - 1,
                'article_id': article_id,
                'title_tr': variant['title_tr'],
                'title_en': variant['title_en'],
                'region_code': variant['region_code'],
                'mint_name': variant['mint_name'],
                'authority_name': variant['authority_name'],
                'material': variant['material'],
                'date_from': variant['date_from'],
                'date_to': variant['date_to']
            })

        except Exception as e:
            logger.error(f"Failed to process article {article_id}: {e}")
            failed.append(article_id)

    # Convert to numpy array
    embeddings = np.array(embeddings, dtype=np.float32)

    logger.info(f"Successfully processed {len(embeddings)} variants")
    logger.info(f"Failed: {len(failed)} variants")

    # Build FAISS index
    index = build_faiss_index(embeddings, use_gpu=args.gpu, optimize=args.optimize)

    # Save index
    index_path = args.output / 'coins.index'
    logger.info(f"Saving FAISS index: {index_path}")

    # If GPU index, move back to CPU for saving
    if args.gpu and faiss.get_num_gpus() > 0:
        index = faiss.index_gpu_to_cpu(index)

    faiss.write_index(index, str(index_path))
    logger.info(f"✅ Index saved: {index_path}")

    # Save metadata
    metadata_path = args.output / 'metadata.json'
    logger.info(f"Saving metadata: {metadata_path}")

    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    logger.info(f"✅ Metadata saved: {metadata_path}")

    # Save failed list
    if failed:
        failed_path = args.output / 'failed.txt'
        with open(failed_path, 'w') as f:
            f.write('\n'.join(map(str, failed)))
        logger.info(f"⚠️ Failed variants saved: {failed_path}")

    # Generate statistics
    stats = {
        'total_variants': len(variants),
        'indexed_variants': len(embeddings),
        'failed_variants': len(failed),
        'embedding_dimension': embeddings.shape[1],
        'index_type': 'IVFFlat' if args.optimize and len(embeddings) > 10000 else 'Flat',
        'model_path': str(args.model),
        'timestamp': np.datetime64('now').astype(str)
    }

    stats_path = args.output / 'stats.json'
    with open(stats_path, 'w') as f:
        json.dump(stats, f, indent=2)

    logger.info(f"✅ Statistics saved: {stats_path}")

    # Close database
    loader.close()

    logger.info("=" * 60)
    logger.info("FAISS Index Build Complete!")
    logger.info(f"  Indexed: {len(embeddings)} / {len(variants)} variants")
    logger.info(f"  Output: {args.output}")
    logger.info("=" * 60)


if __name__ == '__main__':
    main()
