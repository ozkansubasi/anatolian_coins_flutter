#!/usr/bin/env python3
"""
NumisTR Coin Recognition Model Training Script

Trains EfficientNet-B3 model on ancient coin dataset and exports to ONNX format.

Usage:
    python scripts/train_model.py --data-dir /path/to/coins --output-dir models/
    python scripts/train_model.py --resume models/checkpoint.pth --epochs 50
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import albumentations as A
from albumentations.pytorch import ToTensorV2
import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, random_split
from torch.cuda.amp import autocast, GradScaler
from torchvision.models import efficientnet_b3, EfficientNet_B3_Weights
from tqdm import tqdm

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CoinDataset(Dataset):
    """Dataset loader for ancient coin images from NumisTR database."""

    def __init__(
        self,
        image_dir: Path,
        metadata_file: Path,
        transform: Optional[A.Compose] = None,
        dual_sided: bool = True
    ):
        """
        Args:
            image_dir: Root directory containing coin images
            metadata_file: JSON file with image metadata from database
            transform: Albumentations transform pipeline
            dual_sided: If True, load both obverse and reverse images
        """
        self.image_dir = image_dir
        self.transform = transform
        self.dual_sided = dual_sided

        # Load metadata
        with open(metadata_file) as f:
            self.metadata = json.load(f)

        # Build samples list
        self.samples = self._build_samples()

        # Build label mapping
        self.article_ids = sorted(set(s['article_id'] for s in self.samples))
        self.id_to_label = {aid: idx for idx, aid in enumerate(self.article_ids)}
        self.label_to_id = {idx: aid for aid, idx in self.id_to_label.items()}

        logger.info(f"Loaded {len(self.samples)} samples with {len(self.article_ids)} classes")

    def _build_samples(self) -> List[Dict]:
        """Build list of training samples from metadata."""
        samples = []

        for article_id, variants in self.metadata.items():
            for variant in variants:
                # Get obverse and reverse images
                obverse = variant.get('obverse_image')
                reverse = variant.get('reverse_image')

                if obverse:
                    sample = {
                        'article_id': int(article_id),
                        'obverse': self.image_dir / obverse,
                        'reverse': self.image_dir / reverse if reverse else None,
                        'region': variant.get('region_code'),
                        'material': variant.get('metal'),
                        'date_from': variant.get('date_from'),
                        'date_to': variant.get('date_to')
                    }

                    # Validate files exist
                    if sample['obverse'].exists():
                        if not self.dual_sided or (sample['reverse'] and sample['reverse'].exists()):
                            samples.append(sample)

        return samples

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, int]:
        sample = self.samples[idx]

        # Load obverse
        obverse_img = cv2.imread(str(sample['obverse']))
        obverse_img = cv2.cvtColor(obverse_img, cv2.COLOR_BGR2RGB)

        # Apply transform
        if self.transform:
            obverse_transformed = self.transform(image=obverse_img)['image']
        else:
            obverse_transformed = torch.from_numpy(obverse_img).permute(2, 0, 1)

        # Load reverse if dual-sided
        if self.dual_sided and sample['reverse']:
            reverse_img = cv2.imread(str(sample['reverse']))
            reverse_img = cv2.cvtColor(reverse_img, cv2.COLOR_BGR2RGB)

            if self.transform:
                reverse_transformed = self.transform(image=reverse_img)['image']
            else:
                reverse_transformed = torch.from_numpy(reverse_img).permute(2, 0, 1)

            # Stack obverse and reverse (will be averaged in model)
            image = torch.stack([obverse_transformed, reverse_transformed])
        else:
            image = obverse_transformed.unsqueeze(0)

        label = self.id_to_label[sample['article_id']]

        return image, label


class CoinRecognitionModel(nn.Module):
    """EfficientNet-B3 based model for coin recognition."""

    def __init__(self, num_classes: int, embedding_dim: int = 1536, pretrained: bool = True):
        super().__init__()

        # Load pretrained EfficientNet-B3
        if pretrained:
            weights = EfficientNet_B3_Weights.IMAGENET1K_V1
            self.backbone = efficientnet_b3(weights=weights)
        else:
            self.backbone = efficientnet_b3()

        # Get feature dimension
        in_features = self.backbone.classifier[1].in_features

        # Replace classifier with embedding + classification head
        self.backbone.classifier = nn.Identity()

        # Embedding layer (for FAISS indexing)
        self.embedding = nn.Sequential(
            nn.Linear(in_features, embedding_dim),
            nn.BatchNorm1d(embedding_dim),
            nn.ReLU(),
            nn.Dropout(0.3)
        )

        # Classification head
        self.classifier = nn.Sequential(
            nn.Linear(embedding_dim, num_classes)
        )

    def forward(self, x: torch.Tensor, return_embedding: bool = False):
        """
        Args:
            x: Input tensor [B, N, C, H, W] where N is num sides (1 or 2)
            return_embedding: If True, return embedding instead of logits

        Returns:
            Classification logits or normalized embeddings
        """
        batch_size, num_sides = x.shape[:2]

        # Reshape to [B*N, C, H, W]
        x = x.view(-1, *x.shape[2:])

        # Extract features
        features = self.backbone(x)  # [B*N, D]

        # Average features across sides
        features = features.view(batch_size, num_sides, -1).mean(dim=1)  # [B, D]

        # Get embeddings
        embeddings = self.embedding(features)  # [B, embedding_dim]

        if return_embedding:
            # L2 normalize for FAISS
            return nn.functional.normalize(embeddings, p=2, dim=1)

        # Classification
        logits = self.classifier(embeddings)
        return logits


def get_transforms(train: bool = True) -> A.Compose:
    """Get albumentations transform pipeline for ancient coins."""

    if train:
        # Training augmentation - aggressive for ancient coins
        return A.Compose([
            # Geometric
            A.Rotate(limit=180, border_mode=cv2.BORDER_CONSTANT, p=0.7),
            A.HorizontalFlip(p=0.5),
            A.ShiftScaleRotate(
                shift_limit=0.1,
                scale_limit=0.2,
                rotate_limit=180,
                border_mode=cv2.BORDER_CONSTANT,
                p=0.7
            ),

            # Color/brightness (simulate different lighting and wear)
            A.RandomBrightnessContrast(
                brightness_limit=0.3,
                contrast_limit=0.3,
                p=0.7
            ),
            A.HueSaturationValue(
                hue_shift_limit=20,
                sat_shift_limit=30,
                val_shift_limit=20,
                p=0.5
            ),

            # Simulate wear and damage
            A.OneOf([
                A.GaussNoise(var_limit=(10.0, 50.0), p=1.0),
                A.ISONoise(color_shift=(0.01, 0.05), intensity=(0.1, 0.5), p=1.0),
            ], p=0.5),

            A.OneOf([
                A.MotionBlur(blur_limit=7, p=1.0),
                A.GaussianBlur(blur_limit=7, p=1.0),
            ], p=0.3),

            # CLAHE for contrast enhancement
            A.CLAHE(clip_limit=4.0, tile_grid_size=(8, 8), p=0.5),

            # Normalize and convert to tensor
            A.Resize(300, 300),
            A.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            ),
            ToTensorV2()
        ])
    else:
        # Validation/test - minimal augmentation
        return A.Compose([
            A.Resize(300, 300),
            A.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            ),
            ToTensorV2()
        ])


class ArcFaceLoss(nn.Module):
    """
    ArcFace loss for improved embedding learning.
    Better than standard CrossEntropy for fine-grained classification.

    Reference: https://arxiv.org/abs/1801.07698
    """

    def __init__(self, num_classes: int, embedding_dim: int, scale: float = 30.0, margin: float = 0.5):
        super().__init__()
        self.num_classes = num_classes
        self.scale = scale
        self.margin = margin

        # Weight matrix
        self.weight = nn.Parameter(torch.FloatTensor(num_classes, embedding_dim))
        nn.init.xavier_uniform_(self.weight)

    def forward(self, embeddings: torch.Tensor, labels: torch.Tensor) -> torch.Tensor:
        # Normalize embeddings and weights
        embeddings = nn.functional.normalize(embeddings, p=2, dim=1)
        weight = nn.functional.normalize(self.weight, p=2, dim=1)

        # Compute cosine similarity
        cosine = nn.functional.linear(embeddings, weight)

        # Compute angle
        theta = torch.acos(torch.clamp(cosine, -1.0 + 1e-7, 1.0 - 1e-7))

        # Add margin to target class
        one_hot = torch.zeros_like(cosine)
        one_hot.scatter_(1, labels.view(-1, 1), 1)

        theta_m = torch.where(one_hot.bool(), theta + self.margin, theta)

        # Convert back to cosine
        cosine_m = torch.cos(theta_m)

        # Scale
        logits = cosine_m * self.scale

        return nn.functional.cross_entropy(logits, labels)


def train_epoch(
    model: nn.Module,
    dataloader: DataLoader,
    criterion: nn.Module,
    optimizer: optim.Optimizer,
    scaler: GradScaler,
    device: torch.device,
    epoch: int
) -> Dict[str, float]:
    """Train for one epoch."""
    model.train()

    running_loss = 0.0
    correct = 0
    total = 0

    pbar = tqdm(dataloader, desc=f"Epoch {epoch} [Train]")

    for images, labels in pbar:
        images = images.to(device)
        labels = labels.to(device)

        optimizer.zero_grad()

        # Mixed precision training
        with autocast():
            # Get embeddings
            embeddings = model(images, return_embedding=True)

            # Compute loss
            if isinstance(criterion, ArcFaceLoss):
                loss = criterion(embeddings, labels)
            else:
                logits = model.classifier(embeddings)
                loss = criterion(logits, labels)

        # Backward pass
        scaler.scale(loss).backward()
        scaler.step(optimizer)
        scaler.update()

        # Statistics
        running_loss += loss.item()

        # For accuracy, use classifier output
        with torch.no_grad():
            logits = model.classifier(embeddings)
            _, predicted = torch.max(logits, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

        # Update progress bar
        pbar.set_postfix({
            'loss': f"{running_loss / (pbar.n + 1):.4f}",
            'acc': f"{100 * correct / total:.2f}%"
        })

    return {
        'loss': running_loss / len(dataloader),
        'accuracy': 100 * correct / total
    }


@torch.no_grad()
def validate(
    model: nn.Module,
    dataloader: DataLoader,
    criterion: nn.Module,
    device: torch.device
) -> Dict[str, float]:
    """Validate model."""
    model.eval()

    running_loss = 0.0
    correct = 0
    total = 0

    pbar = tqdm(dataloader, desc="Validation")

    for images, labels in pbar:
        images = images.to(device)
        labels = labels.to(device)

        # Get embeddings
        embeddings = model(images, return_embedding=True)

        # Compute loss
        if isinstance(criterion, ArcFaceLoss):
            loss = criterion(embeddings, labels)
        else:
            logits = model.classifier(embeddings)
            loss = criterion(logits, labels)

        # Statistics
        running_loss += loss.item()

        # Accuracy
        logits = model.classifier(embeddings)
        _, predicted = torch.max(logits, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

        pbar.set_postfix({
            'loss': f"{running_loss / (pbar.n + 1):.4f}",
            'acc': f"{100 * correct / total:.2f}%"
        })

    return {
        'loss': running_loss / len(dataloader),
        'accuracy': 100 * correct / total
    }


def export_to_onnx(
    model: nn.Module,
    output_path: Path,
    input_shape: Tuple[int, int, int, int, int] = (1, 1, 3, 300, 300),
    quantize: bool = True
):
    """Export trained model to ONNX format."""
    logger.info(f"Exporting model to ONNX: {output_path}")

    model.eval()
    device = next(model.parameters()).device

    # Create dummy input
    dummy_input = torch.randn(*input_shape).to(device)

    # Export to ONNX
    torch.onnx.export(
        model,
        (dummy_input, True),  # (input, return_embedding=True)
        str(output_path),
        input_names=['image'],
        output_names=['embedding'],
        dynamic_axes={
            'image': {0: 'batch_size', 1: 'num_sides'},
            'embedding': {0: 'batch_size'}
        },
        opset_version=14,
        do_constant_folding=True
    )

    logger.info(f"✅ ONNX export complete: {output_path}")

    # Quantize for CPU optimization
    if quantize:
        quantized_path = output_path.parent / f"{output_path.stem}_quantized.onnx"
        logger.info(f"Quantizing model: {quantized_path}")

        try:
            import onnx
            from onnxruntime.quantization import quantize_dynamic, QuantType

            quantize_dynamic(
                str(output_path),
                str(quantized_path),
                weight_type=QuantType.QUInt8
            )

            # Size comparison
            original_size = output_path.stat().st_size / (1024 * 1024)
            quantized_size = quantized_path.stat().st_size / (1024 * 1024)

            logger.info(f"✅ Quantization complete!")
            logger.info(f"   Original: {original_size:.2f} MB")
            logger.info(f"   Quantized: {quantized_size:.2f} MB ({quantized_size/original_size*100:.1f}%)")
        except Exception as e:
            logger.error(f"Quantization failed: {e}")


def main():
    parser = argparse.ArgumentParser(description="Train NumisTR coin recognition model")

    # Data
    parser.add_argument('--data-dir', type=Path, required=True, help="Root directory with coin images")
    parser.add_argument('--metadata', type=Path, required=True, help="JSON file with metadata")
    parser.add_argument('--output-dir', type=Path, default=Path('models'), help="Output directory")

    # Training
    parser.add_argument('--epochs', type=int, default=100, help="Number of epochs")
    parser.add_argument('--batch-size', type=int, default=32, help="Batch size")
    parser.add_argument('--lr', type=float, default=1e-4, help="Learning rate")
    parser.add_argument('--weight-decay', type=float, default=1e-4, help="Weight decay")
    parser.add_argument('--val-split', type=float, default=0.2, help="Validation split ratio")

    # Model
    parser.add_argument('--embedding-dim', type=int, default=1536, help="Embedding dimension")
    parser.add_argument('--pretrained', action='store_true', default=True, help="Use pretrained backbone")
    parser.add_argument('--use-arcface', action='store_true', help="Use ArcFace loss instead of CrossEntropy")

    # Resume
    parser.add_argument('--resume', type=Path, help="Resume from checkpoint")

    # Export
    parser.add_argument('--export-onnx', action='store_true', default=True, help="Export to ONNX after training")
    parser.add_argument('--quantize', action='store_true', default=True, help="Quantize ONNX model")

    args = parser.parse_args()

    # Setup device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    logger.info(f"Using device: {device}")

    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # Load dataset
    logger.info("Loading dataset...")
    train_transform = get_transforms(train=True)
    val_transform = get_transforms(train=False)

    full_dataset = CoinDataset(args.data_dir, args.metadata, transform=train_transform)

    # Split train/val
    val_size = int(len(full_dataset) * args.val_split)
    train_size = len(full_dataset) - val_size
    train_dataset, val_dataset = random_split(full_dataset, [train_size, val_size])

    # Update validation transform
    val_dataset.dataset.transform = val_transform

    # Create dataloaders
    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=4,
        pin_memory=True
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )

    logger.info(f"Train samples: {len(train_dataset)}")
    logger.info(f"Val samples: {len(val_dataset)}")
    logger.info(f"Classes: {len(full_dataset.article_ids)}")

    # Create model
    logger.info("Creating model...")
    model = CoinRecognitionModel(
        num_classes=len(full_dataset.article_ids),
        embedding_dim=args.embedding_dim,
        pretrained=args.pretrained
    ).to(device)

    # Loss function
    if args.use_arcface:
        criterion = ArcFaceLoss(
            num_classes=len(full_dataset.article_ids),
            embedding_dim=args.embedding_dim
        ).to(device)
        logger.info("Using ArcFace loss")
    else:
        criterion = nn.CrossEntropyLoss()
        logger.info("Using CrossEntropy loss")

    # Optimizer
    optimizer = optim.AdamW(model.parameters(), lr=args.lr, weight_decay=args.weight_decay)

    # Scheduler
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)

    # Mixed precision scaler
    scaler = GradScaler()

    # Resume from checkpoint
    start_epoch = 0
    best_val_acc = 0.0

    if args.resume and args.resume.exists():
        logger.info(f"Resuming from checkpoint: {args.resume}")
        checkpoint = torch.load(args.resume, map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
        scheduler.load_state_dict(checkpoint['scheduler_state_dict'])
        start_epoch = checkpoint['epoch'] + 1
        best_val_acc = checkpoint.get('best_val_acc', 0.0)

    # Training loop
    logger.info("Starting training...")

    for epoch in range(start_epoch, args.epochs):
        # Train
        train_metrics = train_epoch(model, train_loader, criterion, optimizer, scaler, device, epoch)

        # Validate
        val_metrics = validate(model, val_loader, criterion, device)

        # Update scheduler
        scheduler.step()

        # Log metrics
        logger.info(f"Epoch {epoch}/{args.epochs}")
        logger.info(f"  Train - Loss: {train_metrics['loss']:.4f}, Acc: {train_metrics['accuracy']:.2f}%")
        logger.info(f"  Val   - Loss: {val_metrics['loss']:.4f}, Acc: {val_metrics['accuracy']:.2f}%")

        # Save checkpoint
        checkpoint = {
            'epoch': epoch,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'scheduler_state_dict': scheduler.state_dict(),
            'train_metrics': train_metrics,
            'val_metrics': val_metrics,
            'best_val_acc': best_val_acc,
            'id_to_label': full_dataset.id_to_label,
            'label_to_id': full_dataset.label_to_id
        }

        # Save last checkpoint
        torch.save(checkpoint, args.output_dir / 'last.pth')

        # Save best checkpoint
        if val_metrics['accuracy'] > best_val_acc:
            best_val_acc = val_metrics['accuracy']
            torch.save(checkpoint, args.output_dir / 'best.pth')
            logger.info(f"  ✅ New best model! Acc: {best_val_acc:.2f}%")

    logger.info(f"Training complete! Best val accuracy: {best_val_acc:.2f}%")

    # Export to ONNX
    if args.export_onnx:
        # Load best model
        checkpoint = torch.load(args.output_dir / 'best.pth', map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])

        # Export
        onnx_path = args.output_dir / 'efficientnet_b3_coins.onnx'
        export_to_onnx(model, onnx_path, quantize=args.quantize)

        # Save label mapping
        mapping_path = args.output_dir / 'label_mapping.json'
        with open(mapping_path, 'w') as f:
            json.dump({
                'id_to_label': checkpoint['id_to_label'],
                'label_to_id': checkpoint['label_to_id']
            }, f, indent=2)

        logger.info(f"✅ Label mapping saved: {mapping_path}")


if __name__ == '__main__':
    main()
