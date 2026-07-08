#!/usr/bin/env python3
"""
NumisTR Training Data Preparation Script

Exports coin images and metadata from Joomla database for model training.

Usage:
    python scripts/prepare_training_data.py \
        --db-config config/database.yaml \
        --output data/training/ \
        --test-split 0.2
"""

import argparse
import json
import shutil
from pathlib import Path
from typing import Dict, List
import yaml
import mysql.connector
from tqdm import tqdm
import random

import logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def connect_to_database(config_path: Path):
    """Load config and connect to database."""
    with open(config_path) as f:
        config = yaml.safe_load(f)

    db_config = config['database']

    conn = mysql.connector.connect(
        host=db_config['host'],
        port=db_config.get('port', 3306),
        user=db_config['user'],
        password=db_config['password'],
        database=db_config['database']
    )

    return conn, Path(config.get('image_base_path', '../sikke'))


def fetch_training_data(conn) -> List[Dict]:
    """Fetch all variants with images (matching API logic)."""
    cursor = conn.cursor(dictionary=True)

    # Query matches Joomla API logic from numistr.php:1342-1377 and :1488
    query = """
    SELECT DISTINCT
        v.article_id,
        v.title_tr,
        v.title_en,
        v.region_code,
        v.mint_name,
        v.metal as material,
        v.date_from,
        v.date_to
    FROM o_numistr_variants_public v
    WHERE EXISTS (
        SELECT 1 FROM coins_images ci
        WHERE ci.coin_id = v.article_id
    )
    ORDER BY v.article_id
    """

    cursor.execute(query)
    variants = cursor.fetchall()

    logger.info(f"Fetched {len(variants)} variants")

    # For each variant, get ALL images (on, arka, detay)
    for variant in variants:
        article_id = variant['article_id']

        # Get all images for this variant
        cursor.execute("""
            SELECT image_id, filename, image_type
            FROM coins_images
            WHERE coin_id = %s
            ORDER BY
                CASE image_type
                    WHEN 'on' THEN 1
                    WHEN 'arka' THEN 2
                    WHEN 'detay' THEN 3
                    ELSE 4
                END,
                ordering ASC,
                image_id ASC
        """, (article_id,))

        images = cursor.fetchall()

        # Store all images
        variant['images'] = []
        for img in images:
            if img['filename']:
                variant['images'].append({
                    'image_id': img['image_id'],
                    'filename': img['filename'],
                    'type': img['image_type']
                })

    cursor.close()

    logger.info(f"Found {len([v for v in variants if v.get('images')])} variants with images")
    logger.info(f"Total images: {sum(len(v.get('images', [])) for v in variants)}")
    return variants


def copy_images(
    variants: List[Dict],
    image_base: Path,
    output_dir: Path,
    split: str = 'train'
) -> List[Dict]:
    """Copy ALL images (on, arka, detay) to training directory and build metadata."""

    output_images = output_dir / split / 'images'
    output_images.mkdir(parents=True, exist_ok=True)

    metadata = []
    skipped = 0
    total_images_copied = 0

    for variant in tqdm(variants, desc=f"Copying {split} images"):
        article_id = variant['article_id']

        # Skip if no images
        if not variant.get('images'):
            skipped += 1
            continue

        # Copy all images for this variant
        copied_images = []
        has_any_image = False

        for img in variant['images']:
            filename = img['filename']
            image_type = img['type']
            image_id = img['image_id']

            image_src = image_base / filename
            if not image_src.exists():
                logger.warning(f"Image not found: {image_src}")
                continue

            # Filename: {article_id}_{image_type}_{image_id}.jpg
            image_dst = output_images / f"{article_id}_{image_type}_{image_id}.jpg"
            shutil.copy2(image_src, image_dst)

            copied_images.append({
                'image_id': image_id,
                'type': image_type,
                'path': str(image_dst.relative_to(output_dir / split))
            })
            total_images_copied += 1
            has_any_image = True

        # Only add to metadata if at least one image was copied
        if has_any_image:
            metadata.append({
                'article_id': article_id,
                'images': copied_images,
                'title_tr': variant['title_tr'],
                'title_en': variant['title_en'],
                'region_code': variant['region_code'],
                'mint_name': variant['mint_name'],
                'material': variant['material'],
                'date_from': variant['date_from'],
                'date_to': variant['date_to']
            })
        else:
            skipped += 1

    logger.info(f"{split.capitalize()}: Copied {len(metadata)} variants ({total_images_copied} images), skipped {skipped}")
    return metadata


def split_train_test(variants: List[Dict], test_ratio: float = 0.2) -> tuple:
    """Split data into train and test sets."""

    # Shuffle
    random.shuffle(variants)

    # Split
    test_size = int(len(variants) * test_ratio)
    test_set = variants[:test_size]
    train_set = variants[test_size:]

    logger.info(f"Split: {len(train_set)} train, {len(test_set)} test")

    return train_set, test_set


def main():
    parser = argparse.ArgumentParser(description="Prepare NumisTR training data")

    parser.add_argument('--db-config', type=Path, required=True, help="Database config YAML")
    parser.add_argument('--output', type=Path, required=True, help="Output directory")
    parser.add_argument('--test-split', type=float, default=0.2, help="Test set ratio")
    parser.add_argument('--seed', type=int, default=42, help="Random seed")
    parser.add_argument('--limit', type=int, help="Limit number of variants (for testing)")

    args = parser.parse_args()

    # Set random seed
    random.seed(args.seed)

    # Create output directory
    args.output.mkdir(parents=True, exist_ok=True)

    # Connect to database
    logger.info("Connecting to database...")
    conn, image_base = connect_to_database(args.db_config)

    # Fetch data
    logger.info("Fetching training data...")
    variants = fetch_training_data(conn)
    conn.close()

    # Apply limit if specified
    if args.limit:
        variants = variants[:args.limit]
        logger.info(f"Limited to {len(variants)} variants")

    # Split train/test
    train_variants, test_variants = split_train_test(variants, args.test_split)

    # Copy images and build metadata
    logger.info("Copying training images...")
    train_metadata = copy_images(train_variants, image_base, args.output, 'train')

    logger.info("Copying test images...")
    test_metadata = copy_images(test_variants, image_base, args.output, 'test')

    # Save metadata
    train_meta_path = args.output / 'train' / 'metadata.json'
    with open(train_meta_path, 'w', encoding='utf-8') as f:
        json.dump(train_metadata, f, ensure_ascii=False, indent=2)
    logger.info(f"Saved train metadata: {train_meta_path}")

    test_meta_path = args.output / 'test' / 'metadata.json'
    with open(test_meta_path, 'w', encoding='utf-8') as f:
        json.dump(test_metadata, f, ensure_ascii=False, indent=2)
    logger.info(f"Saved test metadata: {test_meta_path}")

    # Save statistics
    stats = {
        'total_variants': len(variants),
        'train_variants': len(train_metadata),
        'test_variants': len(test_metadata),
        'test_split_ratio': args.test_split,
        'random_seed': args.seed,
        'unique_regions': len(set(v['region_code'] for v in train_metadata if v['region_code'])),
        'unique_mints': len(set(v['mint_name'] for v in train_metadata if v['mint_name']))
    }

    stats_path = args.output / 'stats.json'
    with open(stats_path, 'w') as f:
        json.dump(stats, f, indent=2)
    logger.info(f"Saved statistics: {stats_path}")

    # Print summary
    logger.info("=" * 60)
    logger.info("Data Preparation Complete!")
    logger.info(f"  Total variants: {stats['total_variants']}")
    logger.info(f"  Train set: {stats['train_variants']}")
    logger.info(f"  Test set: {stats['test_variants']}")
    logger.info(f"  Unique regions: {stats['unique_regions']}")
    logger.info(f"  Unique mints: {stats['unique_mints']}")
    logger.info(f"  Output: {args.output}")
    logger.info("=" * 60)


if __name__ == '__main__':
    main()
