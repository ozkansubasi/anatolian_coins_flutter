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

# ---- Asama 1: duplicate catalog records -> exact top ties (2026-09-16) ----
# The same photograph is attached to several catalog records (the same source
# catalogue was imported into three region categories), so FAISS returns bit-identical
# distances for all of them: ranking becomes arbitrary and up to five mutually
# exclusive answers were served at confidence 1.0, with the true record pushed out
# of TOP_N by its own copies.
# Measured 2026-09-16: 3040 of 48284 index vectors (6.30%) are byte-identical copies;
# 781 catalog records (11.0%) are affected. See
# claudedocs/ai-mukerrerlik-temizligi-plani-2026-09-16.md
# NOTE: ties are computed AFTER attribute re-ranking on purpose, so a tie that the
# collector's metal/weight/diameter already resolved is not reported as ambiguous.
# TIE_EPS is calibrated, not guessed: over 120 colliding + 120 clean records the top1-top2
# gap separates cleanly. Colliding: 82.5% exactly 0.0, a further 5.8% within 1e-3 (re-compressed
# near-duplicates that a byte hash cannot see), largest caught gap 0.000273. Clean: smallest gap
# 0.002138, p1 0.005450. 0.001 sits in the empty band between the two -> 88.3% of collisions
# caught, 0/120 false positives on clean records.
TIE_EPS = 0.001                 # fused-distance gap below which candidates are indistinguishable
TIE_CONF_CAP = 0.60             # confidence ceiling while tied (app: yellow band, above the 0.4 filter)
TIE_MIN = 2                     # this many tied candidates before ambiguity is declared
TIE_MAX_SHOW = 10               # a tied group is returned whole, up to this ceiling
SHARP_MIN = 25.0                # Laplacian variance on 224px crop; below = low detail
QUALITY_CONF = 0.50             # quality reasons only claimed when top conf below this

# ---- Faz B: optional collector-provided attributes (metal / weight / diameter) ----
# Small cosine bonus/penalty so attributes re-rank near-ties without overpowering vision.
ATTR_METAL_BONUS, ATTR_METAL_PENALTY = 0.010, -0.015
ATTR_W_TOL, ATTR_W_FAR = 0.12, 0.30          # relative weight tolerance / far bound
ATTR_W_BONUS, ATTR_W_PENALTY = 0.010, -0.012
ATTR_D_TOL, ATTR_D_FAR = 0.08, 0.25          # relative diameter tolerance / far bound
ATTR_D_BONUS, ATTR_D_PENALTY = 0.008, -0.010
METAL_ALIASES = {
    'gumus': 'silver', 'gümüş': 'silver', 'ag': 'silver', 'ar': 'silver', 'silver': 'silver',
    'bronz': 'copper', 'bronze': 'copper', 'ae': 'copper', 'bakir': 'copper', 'bakır': 'copper', 'copper': 'copper',
    'altin': 'gold', 'altın': 'gold', 'au': 'gold', 'av': 'gold', 'gold': 'gold',
    'elektron': 'electrum', 'electrum': 'electrum', 'el': 'electrum',
    'kursun': 'lead', 'kurşun': 'lead', 'lead': 'lead', 'pb': 'lead',
    'billon': 'billon', 'potin': 'potin', 'orichalcum': 'orichalcum', 'orikalkum': 'orichalcum',
}


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
            self.attrs = {}
            for m in self.metadata:
                a = m["article_id"]
                if a not in self.by_art:
                    self.by_art[a] = m
                at = self.attrs.setdefault(a, {'mat': None, 'w': [], 'd': []})
                if m.get('material'):
                    raw = str(m['material']).strip().lower()
                    at['mat'] = METAL_ALIASES.get(raw, raw)
                for src, dst in (('weight', 'w'), ('diameter', 'd')):
                    try:
                        v = float(str(m.get(src, '')).replace(',', '.'))
                        if v > 0:
                            at[dst].append(v)
                    except Exception:
                        pass
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

    def _attr_adjust(self, article_id, metal, weight_g, diameter_mm) -> float:
        """Faz B: cosine adjustment from optional collector attributes. 0 when unknown."""
        at = getattr(self, 'attrs', {}).get(article_id)
        if not at:
            return 0.0
        adj = 0.0
        if metal and at['mat']:
            adj += ATTR_METAL_BONUS if at['mat'] == metal else ATTR_METAL_PENALTY
        for user_v, vals, tol, far, bon, pen in (
            (weight_g, at['w'], ATTR_W_TOL, ATTR_W_FAR, ATTR_W_BONUS, ATTR_W_PENALTY),
            (diameter_mm, at['d'], ATTR_D_TOL, ATTR_D_FAR, ATTR_D_BONUS, ATTR_D_PENALTY),
        ):
            if user_v and vals:
                rel = min(abs(user_v - v) / max(v, 1e-6) for v in vals)
                if rel <= tol:
                    adj += bon
                elif rel >= far:
                    adj += pen
        return adj

    async def recognize(self, obverse_bytes: bytes, reverse_bytes: bytes = None,
                        metal: str = None, weight_g: float = None,
                        diameter_mm: float = None) -> Dict[str, Any]:
        if self.encoder is None or self.faiss_index is None:
            return self._stub_response()
        try:
            start = datetime.utcnow()

            metal = METAL_ALIASES.get(str(metal).strip().lower()) if metal else None
            try:
                weight_g = float(str(weight_g).replace(',', '.')) if weight_g not in (None, '') else None
            except Exception:
                weight_g = None
            try:
                diameter_mm = float(str(diameter_mm).replace(',', '.')) if diameter_mm not in (None, '') else None
            except Exception:
                diameter_mm = None

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

            if metal or weight_g or diameter_mm:
                fused = {a: d + self._attr_adjust(a, metal, weight_g, diameter_mm)
                         for a, d in fused.items()}

            ranked = sorted(fused.items(), key=lambda kv: kv[1], reverse=True)

            # ---- Asama 1: collapse an indistinguishable top group ----
            # Candidates within TIE_EPS of the leader cannot be told apart by the image
            # at all, so no ordering among them is meaningful.
            # Only candidates that survive MIN_CONF can be tied: otherwise tie_size would
            # count articles that never reach the response.
            tied_ids = []
            if ranked and _conf(ranked[0][1]) >= MIN_CONF:
                d_top = ranked[0][1]
                tied_ids = [a for a, d in ranked
                            if (d_top - d) <= TIE_EPS and _conf(d) >= MIN_CONF]
            is_tied = len(tied_ids) >= TIE_MIN
            tied_set = set(tied_ids) if is_tied else set()

            def _int(v):
                try:
                    return int(v)
                except Exception:
                    return None

            # A tied group must be shown whole: otherwise the record the photo actually
            # belongs to can be pushed past TOP_N by its own duplicates (measured).
            limit = min(max(TOP_N, len(tied_ids)), TIE_MAX_SHOW) if is_tied else TOP_N

            matches = []
            for a, d in ranked:
                conf = _conf(d)
                if conf < MIN_CONF:
                    break
                m = self.by_art.get(a, {})
                oc = _conf(obv_best[a]) if a in obv_best else None
                rc = _conf(rev_best[a]) if a in rev_best else None
                # While tied, confidence states how sure we are of the IDENTIFICATION,
                # not of the visual match; visual_score keeps the unmodified value.
                in_tie = a in tied_set
                matches.append({
                    'rank': len(matches) + 1,
                    'article_id': int(a),
                    'title': m.get('title_tr') or m.get('title_en') or 'Unknown',
                    'confidence': min(conf, TIE_CONF_CAP) if in_tie else conf,
                    'visual_score': conf,
                    'tied_with': [int(x) for x in tied_ids if x != a] if in_tie else None,
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
                if len(matches) >= limit:
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
            elif is_tied:
                # An exact tie is the most ambiguous case there is, so it is reported
                # regardless of how high the visual score climbed. The pre-existing
                # AMBIG_TOP gate silently excluded exactly these (top1 was 1.0).
                reason = 'ambiguous_match'
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
            logger.info("recognize(fazA): sides=%d top art=%s conf=%.3f reason=%s tie=%d" %
                        (len(sides), matches[0]['article_id'] if matches else None, top, reason,
                         len(tied_ids) if is_tied else 0))
            return {
                'matches': matches,
                'confidence': top,
                'ambiguous': is_tied,
                'tie_size': len(tied_ids) if is_tied else 0,
                'tied_articles': [int(a) for a in tied_ids] if is_tied else [],
                'method': 'dinov3_sam2_fazAB',
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
