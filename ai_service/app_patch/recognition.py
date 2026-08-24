"""Main Recognition Service — DINOv3 + SAM2 (Faz A, 2026-08-24).

Pipeline per side: image -> SAM2 segment (isolate coin, neutralize bg) -> quality
metrics (detection + sharpness) -> DINOv3-base embedding -> FAISS search.
Fusion is PER-SIDE + article-level (Faz A fix): each side is searched separately
and article scores are combined 0.45*obverse + 0.55*reverse (reverse is more
discriminative on ancient coins). The old (obv+rev)/2 embedding average capped
exact-match scores at ~0.8 and washed out the reverse signal.

Also new in Faz A:
- confidence threshold: results below MIN_CONF are dropped, at most TOP_N returned,
  an empty list is allowed;
- reasoned fallback: no_match / no_match_reason (no_coin_detected |
  low_detail_surface | below_confidence) + ambiguous_match flag, with per-side
  quality metrics in the response (heavy patina / worn surface UX in the app).

Interface (constructor, recognize(), response dict) stays backward compatible;
new response keys are additive. Index paths hardcoded so a simple `docker
restart` (no recreate) preserves pip installs + model caches.
Rollback: /opt/ai_service/app_patch/recognition.py.backup_fazA_*
"""
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

import numpy as np
import cv2
import faiss
import torch

logger = logging.getLogger(__name__)

IMN = np.array([0.485, 0.456, 0.406], np.float32)
IST = np.array([0.229, 0.224, 0.225], np.float32)
INDEX_PATH = "/app/index/coins_dinov3_base.index"
META_PATH = "/app/index/metadata_dinov3.json"

DIST_LO, DIST_HI = 0.85, 0.98   # cosine -> confidence rescale (unchanged from Faz 2)
SEARCH_K = 60                   # raw FAISS hits per side before article dedup
TOP_N = 5                       # max results returned (fewer is fine)
MIN_CONF = 0.30                 # below this a match is dropped
W_OBV, W_REV = 0.45, 0.55       # side weights when both sides matched an article
AMBIG_MARGIN = 0.05             # top1-top2 confidence margin for ambiguity flag
AMBIG_TOP = 0.50                # ambiguity only flagged when top1 below this
SHARP_MIN = 25.0                # Laplacian variance on 224px crop; below = low detail
QUALITY_CONF = 0.50             # quality reasons only claimed when top conf below this


def _conf(d: float) -> float:
    return float(np.clip((float(d) - DIST_LO) / (DIST_HI - DIST_LO), 0.0, 1.0))


class RecognitionService:
    def __init__(self, efficientnet_path: str = None, faiss_index_path: str = None,
                 faiss_metadata_path: str = None, db_host: str = None, db_port: int = None,
                 db_name: str = None, db_user: str = None, db_password: str = None, **kw):
        self.encoder = None
        self.faiss_index = None
        self.metadata = None
        self.sam = None
        self.art = []
        self.by_art = {}
        try:
            torch.set_num_threads(4)
            import timm
            logger.info("Loading DINOv3-base backbone...")
            self.encoder = timm.create_model(
                "vit_base_patch16_dinov3", pretrained=True, num_classes=0,
                dynamic_img_size=True).eval()
            for p in self.encoder.parameters():
                p.requires_grad = False
            logger.info("Loading SAM2 segmenter...")
            from ultralytics import SAM
            self.sam = SAM("sam2_t.pt")
            logger.info("Loading DINOv3 FAISS index...")
            self.faiss_index = faiss.read_index(INDEX_PATH)
            self.metadata = json.load(open(META_PATH))
            self.art = [m["article_id"] for m in self.metadata]
            for m in self.metadata:
                a = m["article_id"]
                if a not in self.by_art:
                    self.by_art[a] = m
            logger.info("✓ DINOv3+SAM2 loaded (fazA): %d vectors, %d articles"
                        % (self.faiss_index.ntotal, len(self.by_art)))
        except Exception as e:
            logger.error("DINOv3+SAM2 load failed: %s" % e, exc_info=True)
            self.encoder = None
            self.faiss_index = None

    # ---- pipeline ----
    def _to_bgr(self, b: bytes):
        return cv2.imdecode(np.frombuffer(b, np.uint8), cv2.IMREAD_COLOR)

    def _segment(self, bgr) -> Tuple[np.ndarray, bool]:
        """Returns (crop, coin_detected). Fallback: center crop, detected=False."""
        h, w = bgr.shape[:2]
        try:
            r = self.sam(bgr, points=[[w // 2, h // 2]], labels=[1], verbose=False)
            m = r[0].masks
            if m is None:
                raise ValueError("no mask")
            a = m.data[0].cpu().numpy().astype(np.uint8)
            if a.sum() < 0.004 * h * w:
                raise ValueError("mask too small")
            ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
            out = bgr.copy()
            out[a == 0] = (235, 235, 235)
            p = int(0.06 * max(x1 - x0, y1 - y0))
            x0, y0 = max(0, x0 - p), max(0, y0 - p)
            x1, y1 = min(w, x1 + p), min(h, y1 + p)
            return out[y0:y1, x0:x1], True
        except Exception:
            s = min(h, w) // 2
            return bgr[max(0, h // 2 - s):h // 2 + s, max(0, w // 2 - s):w // 2 + s], False

    def _sharpness(self, crop) -> float:
        """Detail proxy on the 224px working size (heavy patina/wear -> low)."""
        g = cv2.cvtColor(cv2.resize(crop, (224, 224)), cv2.COLOR_BGR2GRAY)
        return float(cv2.Laplacian(g, cv2.CV_64F).var())

    def _embed(self, bgr):
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        im = cv2.resize(rgb, (224, 224)).astype(np.float32) / 255.0
        x = torch.from_numpy(np.transpose((im - IMN) / IST, (2, 0, 1))[None].astype(np.float32))
        with torch.no_grad():
            f = self.encoder(x).numpy().ravel()
        return (f / (np.linalg.norm(f) + 1e-9)).astype(np.float32)

    def _side(self, image_bytes: bytes):
        """bytes -> {'embs': [raw, seg?], 'detected', 'sharpness'} or None.

        The index was built from RAW (unsegmented) catalog images, while queries
        used to be segmented only — a build/serve mismatch that broke self-match
        on images where SAM grabs a tiny region (mask 1-3%% of frame). Fix: embed
        BOTH the raw frame and the segmented crop and let the best one win per
        article. Raw wins on catalog-style photos; the segmented crop helps on
        real phone photos with backgrounds. Tiny masks (<5%%) are discarded.
        """
        bgr = self._to_bgr(image_bytes)
        if bgr is None:
            return None
        embs = [self._embed(bgr)]
        crop, detected = self._segment(bgr)
        if detected:
            h, w = bgr.shape[:2]
            ch, cw = crop.shape[:2]
            if (ch * cw) < 0.05 * h * w:      # SAM latched onto a tiny region
                detected = False
            else:
                embs.append(self._embed(crop))
        return {
            'embs': embs,
            'detected': detected,
            'sharpness': round(self._sharpness(crop if detected else bgr), 1),
        }

    def _search_side(self, embs) -> Dict[int, float]:
        """Search with every embedding variant of one side -> best cosine per article."""
        best: Dict[int, float] = {}
        for emb in embs:
            D, I = self.faiss_index.search(emb.reshape(1, -1).astype(np.float32), SEARCH_K)
            for d, i in zip(D[0], I[0]):
                if i < 0:
                    continue
                a = self.art[i]
                if a not in best or d > best[a]:
                    best[a] = float(d)
        return best

    async def recognize(self, obverse_bytes: bytes, reverse_bytes: bytes = None) -> Dict[str, Any]:
        if self.encoder is None or self.faiss_index is None:
            return self._stub_response()
        try:
            start = datetime.utcnow()

            obv = self._side(obverse_bytes)
            rev = self._side(reverse_bytes) if reverse_bytes else None
            if obv is None and rev is None:
                return self._stub_response()

            obv_best = self._search_side(obv['embs']) if obv else {}
            rev_best = self._search_side(rev['embs']) if rev else {}

            # article-level fusion (Faz A): weighted when both sides hit, single side as-is
            fused: Dict[int, float] = {}
            for a in set(obv_best) | set(rev_best):
                do, dr = obv_best.get(a), rev_best.get(a)
                if do is not None and dr is not None:
                    fused[a] = W_OBV * do + W_REV * dr
                else:
                    fused[a] = do if do is not None else dr

            ranked = sorted(fused.items(), key=lambda kv: kv[1], reverse=True)

            def _int(v):
                try:
                    return int(v)
                except Exception:
                    return None

            matches = []
            for a, d in ranked:
                conf = _conf(d)
                if conf < MIN_CONF:
                    break
                m = self.by_art.get(a, {})
                oc = _conf(obv_best[a]) if a in obv_best else None
                rc = _conf(rev_best[a]) if a in rev_best else None
                matches.append({
                    'rank': len(matches) + 1,
                    'article_id': int(a),
                    'title': m.get('title_tr') or m.get('title_en') or 'Unknown',
                    'confidence': conf,
                    'visual_score': conf,
                    'ocr_score': None,
                    'obverse_score': oc,
                    'reverse_score': rc,
                    'distance': float(d),
                    'image_type': None,
                    'region': m.get('region_code'),
                    'mint_name': m.get('mint_name'),
                    'authority_name': m.get('authority_name'),
                    'material': m.get('material'),
                    'date_from': _int(m.get('date_from')),
                    'date_to': _int(m.get('date_to')),
                })
                if len(matches) >= TOP_N:
                    break

            # ---- quality + fallback reasons ----
            sides = [s for s in (obv, rev) if s is not None]
            any_detected = any(s['detected'] for s in sides)
            all_low_detail = all(s['sharpness'] < SHARP_MIN for s in sides)
            top = matches[0]['confidence'] if matches else 0.0

            no_match = not matches
            reason = None
            if no_match:
                if not any_detected:
                    reason = 'no_coin_detected'
                elif all_low_detail:
                    reason = 'low_detail_surface'
                else:
                    reason = 'below_confidence'
            elif top < QUALITY_CONF:
                if not any_detected:
                    reason = 'no_coin_detected'
                elif all_low_detail:
                    reason = 'low_detail_surface'
                elif len(matches) > 1 and (top - matches[1]['confidence']) < AMBIG_MARGIN and top < AMBIG_TOP:
                    reason = 'ambiguous_match'

            quality = {}
            if obv:
                quality['obverse'] = {'coin_detected': obv['detected'], 'sharpness': obv['sharpness']}
            if rev:
                quality['reverse'] = {'coin_detected': rev['detected'], 'sharpness': rev['sharpness']}

            end = datetime.utcnow()
            logger.info("recognize(fazA): sides=%d top art=%s conf=%.3f reason=%s" %
                        (len(sides), matches[0]['article_id'] if matches else None, top, reason))
            return {
                'matches': matches,
                'confidence': top,
                'method': 'dinov3_sam2_fazA',
                'processing_time_ms': int((end - start).total_seconds() * 1000),
                'ocr_extracted': None,
                'no_match': no_match,
                'no_match_reason': reason,
                'quality': quality,
                'timestamp': end,
            }
        except Exception as e:
            logger.error("Recognition failed: %s" % e, exc_info=True)
            return self._stub_response()

    def _stub_response(self) -> Dict[str, Any]:
        return {
            'matches': [{
                'rank': 1, 'article_id': 0, 'title': 'Models not loaded (STUB DATA)',
                'confidence': 0.0, 'visual_score': 0.0, 'ocr_score': None,
                'obverse_score': None, 'reverse_score': None, 'distance': 999.0,
                'image_type': None, 'region': 'Unknown', 'mint_name': None,
                'authority_name': None, 'material': None, 'date_from': None, 'date_to': None,
            }],
            'confidence': 0.0, 'method': 'stub', 'processing_time_ms': 0,
            'ocr_extracted': None, 'no_match': True, 'no_match_reason': 'service_unavailable',
            'quality': {}, 'timestamp': datetime.utcnow(),
        }
