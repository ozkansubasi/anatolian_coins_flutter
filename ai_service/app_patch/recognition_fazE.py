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

Faz C (2026-09-28) — exact two-side scoring:
- Faz A fused an article from BOTH sides only when it appeared in both sides' top
  SEARCH_K hits; otherwise the single side it did appear in was used as-is. A type whose
  obverse is close but whose reverse is a different design (often outside the reverse
  top-K) therefore beat the true type that matched both sides (user report + measured).
- Now every candidate from either side is scored on BOTH sides exactly, against that
  article's own vectors of the matching face (obverse query vs 'on', reverse vs 'arka';
  both faces if the article lacks that face). The swapped assignment (photos taken the
  other way round) is scored too and the better one is kept. Single-side queries are
  unchanged. FUSION_MODE = 'legacy' restores Faz A behaviour (eval / rollback).

Faz D (2026-09-29) — local-feature verification:
- One global vector cannot tell whether a candidate is the SAME coin: the Price/Alexander
  family alone is 23% of the index and looks alike at 224 px. The top VERIFY_K candidates are
  now checked geometrically (SIFT on the query coin crop vs the candidate's catalog photos of
  the matching face, ratio test, RANSAC similarity -> inlier count). A verified candidate is
  promoted and gets a high confidence; when nothing verifies, confidence is capped and the
  answer is flagged as uncertain instead of claiming a match (Faz C: 57% confident-but-wrong
  on different coins of the same type). VERIFY_ENABLED = False restores Faz C.

Faz E (2026-09-29, AI1 — ADAY, canlı değil) — coin-tuned embedding space:
- The stock DINOv3 vector carries lighting, patina, background and photo style as much as type
  identity. A linear map W learned on the catalog's own multi-specimen types (supervised
  contrastive, eval query photos held out) re-weights it toward type identity; optionally a
  fine-tuned encoder (ENCODER_CKPT). Index vectors are E·W (normalised), queries q·W.
- Confidence mapping DIST_LO/HI is re-calibrated by percentile matching to the old scale, and the
  cosine-unit constants (TIE_EPS, attribute bonuses) are scaled by EMB_SCALE. PROJ_PATH = None and
  ENCODER_CKPT = None restore Faz D exactly.

Interface (constructor, recognize(), response dict) stays backward compatible;
new response keys are additive. Index paths hardcoded so a simple `docker
restart` (no recreate) preserves pip installs + model caches.
Rollback: /opt/ai_service/app_patch/recognition.py.backup_fazA_*
"""
import json
import logging
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

import numpy as np
import cv2
import faiss
import torch

logger = logging.getLogger(__name__)
cv2.setNumThreads(1)            # Faz D: parallelism comes from the verification workers

IMN = np.array([0.485, 0.456, 0.406], np.float32)
IST = np.array([0.229, 0.224, 0.225], np.float32)
META_PATH = "/app/index/metadata_dinov3.json"

# ---- Faz E: embedding space (AI1) ----
# Measured on Mac (scripts/ai1/, 150 pairs, pipeline identical to production: cos 1.00000):
#   different coin of same type (B) degraded @5 32.0% -> 53.3%, clean @5 44.7% -> 72.0%;
#   same photo degraded (A) @1 84.0% -> 92.0%; eval types fully held out: B deg @5 50-55%.
PROJ_PATH = "/app/index/proj_W_p1.npy"        # None -> stock DINOv3 space (Faz D)
ENCODER_CKPT = None                           # fine-tuned encoder state dict (None -> stock DINOv3)
INDEX_PATH = "/app/index/coins_dinov3_proj_p1.index" if PROJ_PATH else "/app/index/coins_dinov3_base.index"
EMB_SCALE = 5.202                             # new ~= 5.202 * old - 4.2665 (percentile map, calib_p1.json)
DIST_LO, DIST_HI = (0.1554, 0.8317) if PROJ_PATH else (0.85, 0.98)   # cosine -> confidence
SEARCH_K = 200                  # raw FAISS hits per side before article dedup (Faz C: 60 -> 200)
FUSION_MODE = 'exact'           # 'exact' (Faz C) | 'legacy' (Faz A: missing side skipped)
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
TIE_EPS = 0.001 * (EMB_SCALE if PROJ_PATH else 1.0)   # fused gap below which candidates are indistinguishable
TIE_CONF_CAP = 0.60             # confidence ceiling while tied (app: yellow band, above the 0.4 filter)
TIE_MIN = 2                     # this many tied candidates before ambiguity is declared
TIE_MAX_SHOW = 10               # a tied group is returned whole, up to this ceiling
SHARP_MIN = 25.0                # Laplacian variance on 224px crop; below = low detail
QUALITY_CONF = 0.50             # quality reasons only claimed when top conf below this

# ---- Faz D: local-feature verification (2026-09-29) ----
# Measured (150 pairs, phone-like degradation, separate container, scripts/ai_eval/eval_rerank.py):
#   same photo degraded (A): top-1 83.3% -> 90.0% (ceiling = candidate recall@20, 93.3%);
#   true-match inliers p1 338 / median ~1000; genuinely different coins never reached 100 in
#   5770 comparisons (every >=100 "error" was a parent/subtype record sharing the photo).
#   different coin of the same type (B): not helped (other dies) -> honest confidence instead.
VERIFY_ENABLED = True
VERIFY_K = 20                   # top candidates checked. K=10 was tried (150-pair simulation: same
                                # A/B) but dropped the user's real case (7337 sat at global rank ~11)
VERIFY_ROWS = 2                 # catalog photos per candidate face, closest to the query first
                                # (3 -> 2 for time; the query's own photo is the closest in practice)
VERIFY_SIZE = 512               # longer image side for SIFT
VERIFY_FEATURES = 1000
VERIFY_RATIO = 0.8              # Lowe ratio test
VERIFY_RANSAC_PX = 8.0
VERIFY_WORKERS = 4              # one per core; OpenCV itself single-threaded below (profiled:
                                # SIFT ~125 ms/photo is the cost; nested OpenCV threads oversubscribed)
VERIFIED_MIN = 150              # inliers (both faces) that verify a candidate on their own
# ... or a weaker but clearly singled-out match: one face well photographed, the other poor
# (user's photo-of-screen test 2026-09-28: obverse 112 + reverse 4 = 116 vs best rival 37).
# 150 pairs: no rule variant verified a wrong coin (siblings sharing the photo counted right).
VERIFIED_REL_MIN, VERIFIED_REL_RATIO = 80, 2.5
VERIFY_GROUP_RATIO = 2.0        # verified candidates within 1/2 of the best are promoted together
VERIFIED_CONF_LO, VERIFIED_CONF_HI, VERIFIED_INL_HI = 0.85, 1.0, 600
VERIFIED_REL_CONF = 0.80        # confidence when verified only by the relative rule
UNVERIFIED_CAP = 0.60           # ceiling when nothing verified (app: yellow band, above its 0.4 filter)
UNVERIFIED_REASON = 'ambiguous_match'   # app shows "best match may not be certain"
IMG_DIR = "/app/index/images"   # hardlinks of /opt/ai_service/data/training/train/images (same fs)

# ---- Faz B: optional collector-provided attributes (metal / weight / diameter) ----
# Small cosine bonus/penalty so attributes re-rank near-ties without overpowering vision.
_S = EMB_SCALE if PROJ_PATH else 1.0          # Faz E: bonuses are in cosine units -> rescale
ATTR_METAL_BONUS, ATTR_METAL_PENALTY = 0.010 * _S, -0.015 * _S
ATTR_W_TOL, ATTR_W_FAR = 0.12, 0.30          # relative weight tolerance / far bound
ATTR_W_BONUS, ATTR_W_PENALTY = 0.010 * _S, -0.012 * _S
ATTR_D_TOL, ATTR_D_FAR = 0.08, 0.25          # relative diameter tolerance / far bound
ATTR_D_BONUS, ATTR_D_PENALTY = 0.008 * _S, -0.010 * _S
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
        self.face = []
        self.by_art = {}
        self.rows_by_face = {}
        self._tl = threading.local()
        self._pool = ThreadPoolExecutor(VERIFY_WORKERS) if VERIFY_ENABLED else None
        self.proj = None
        try:
            torch.set_num_threads(4)
            import timm
            logger.info("Loading DINOv3-base backbone...")
            self.encoder = timm.create_model(
                "vit_base_patch16_dinov3", pretrained=True, num_classes=0,
                dynamic_img_size=True).eval()
            if ENCODER_CKPT:
                sd = torch.load(ENCODER_CKPT, map_location="cpu")
                # strict: a mismatched checkpoint must fail loudly, never fall back to stock weights
                self.encoder.load_state_dict(sd.get("encoder", sd), strict=True)
                logger.info("Faz E: fine-tuned encoder %s (epoch %s)" % (ENCODER_CKPT, sd.get("epoch")))
            for p in self.encoder.parameters():
                p.requires_grad = False
            if PROJ_PATH:
                self.proj = np.load(PROJ_PATH).astype(np.float32)
                logger.info("Faz E: projection %s %s" % (PROJ_PATH, self.proj.shape))
            logger.info("Loading SAM2 segmenter...")
            from ultralytics import SAM
            self.sam = SAM("sam2_t.pt")
            logger.info("Loading DINOv3 FAISS index...")
            self.faiss_index = faiss.read_index(INDEX_PATH)
            self.metadata = json.load(open(META_PATH))
            self.art = [m["article_id"] for m in self.metadata]
            self.face = [str(m.get("image_type") or "") for m in self.metadata]
            for i, (a, f) in enumerate(zip(self.art, self.face)):
                self.rows_by_face.setdefault((a, f), []).append(i)
                self.rows_by_face.setdefault((a, '*'), []).append(i)
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
            if VERIFY_ENABLED and not os.path.isdir(IMG_DIR):
                logger.warning("Faz D: %s missing -> verification skipped, Faz C confidence kept" % IMG_DIR)
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
        f = f / (np.linalg.norm(f) + 1e-9)
        if self.proj is not None:                 # Faz E: coin-tuned space (index holds E·W too)
            f = f @ self.proj
            f = f / (np.linalg.norm(f) + 1e-9)
        return f.astype(np.float32)

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
            'vimg': crop if detected else bgr,      # Faz D: local features of the coin
        }

    def _search_side(self, embs, exclude=frozenset()) -> Dict[int, float]:
        """Search with every embedding variant of one side -> best cosine per article.
        `exclude`: index rows to ignore (evaluation: held-out query photos)."""
        best: Dict[int, float] = {}
        for emb in embs:
            D, I = self.faiss_index.search(emb.reshape(1, -1).astype(np.float32), SEARCH_K)
            for d, i in zip(D[0], I[0]):
                if i < 0 or int(i) in exclude:
                    continue
                a = self.art[i]
                if a not in best or d > best[a]:
                    best[a] = float(d)
        return best

    def _face_score(self, embs, a, face, exclude, cache) -> Optional[float]:
        """Exact best cosine between a query side and article `a`'s vectors of `face`
        ('on' / 'arka'); falls back to all of the article's vectors if it has none of
        that face. None if the article has no usable vector."""
        rows = self.rows_by_face.get((a, face)) or self.rows_by_face.get((a, '*')) or []
        best = None
        for r in rows:
            if r in exclude:
                continue
            v = cache.get(r)
            if v is None:
                v = self.faiss_index.reconstruct(int(r))
                cache[r] = v
            for e in embs:
                d = float(np.dot(e, v))
                if best is None or d > best:
                    best = d
        return best

    def _fuse(self, obv, rev, exclude=frozenset(), mode=None, with_swap=False):
        """-> (fused {article: score}, obv_scores {article: cos}, rev_scores {article: cos})
        [+ set of articles whose photos matched the other way round, when `with_swap`]."""
        mode = mode or FUSION_MODE
        obv_best = self._search_side(obv['embs'], exclude) if obv else {}
        rev_best = self._search_side(rev['embs'], exclude) if rev else {}
        fused: Dict[int, float] = {}
        if not (obv and rev) or mode == 'legacy':
            # single side, or Faz A: weighted when both sides hit, single side as-is
            for a in set(obv_best) | set(rev_best):
                do, dr = obv_best.get(a), rev_best.get(a)
                if do is not None and dr is not None:
                    fused[a] = W_OBV * do + W_REV * dr
                else:
                    fused[a] = do if do is not None else dr
            return (fused, obv_best, rev_best, set()) if with_swap else (fused, obv_best, rev_best)

        # Faz C: score every candidate on both sides against its own vectors
        cache: Dict[int, np.ndarray] = {}
        o_sc: Dict[int, float] = {}
        r_sc: Dict[int, float] = {}
        swapped = set()
        for a in set(obv_best) | set(rev_best):
            o_on = self._face_score(obv['embs'], a, 'on', exclude, cache)
            r_ar = self._face_score(rev['embs'], a, 'arka', exclude, cache)
            if o_on is None or r_ar is None:
                continue
            normal = W_OBV * o_on + W_REV * r_ar
            # photos taken the other way round: "obverse" photo shows the reverse
            o_ar = self._face_score(obv['embs'], a, 'arka', exclude, cache)
            r_on = self._face_score(rev['embs'], a, 'on', exclude, cache)
            swap_score = W_OBV * r_on + W_REV * o_ar
            if swap_score > normal:
                fused[a], o_sc[a], r_sc[a] = swap_score, o_ar, r_on
                swapped.add(a)
            else:
                fused[a], o_sc[a], r_sc[a] = normal, o_on, r_ar
        return (fused, o_sc, r_sc, swapped) if with_swap else (fused, o_sc, r_sc)

    # ---- Faz D: local-feature verification ----
    def _lf(self):
        """Per-thread OpenCV objects: SIFT/CLAHE/FLANN are not thread-safe (segfault, measured)."""
        t = self._tl
        if not hasattr(t, 'sift'):
            t.sift = cv2.SIFT_create(nfeatures=VERIFY_FEATURES)
            t.clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            t.flann = cv2.FlannBasedMatcher(dict(algorithm=1, trees=4), dict(checks=32))
        return t

    def _lf_feats(self, bgr):
        """-> (N x 2 points, N x 128 descriptors) or None. No cv2.KeyPoint objects are kept."""
        if bgr is None:
            return None
        t = self._lf()
        g = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        s = VERIFY_SIZE / max(g.shape[:2])
        g = t.clahe.apply(cv2.resize(g, (max(1, int(g.shape[1] * s)), max(1, int(g.shape[0] * s))),
                                     interpolation=cv2.INTER_AREA))
        kp, des = t.sift.detectAndCompute(g, None)
        if des is None or len(kp) < 8:
            return None
        return np.float32([k.pt for k in kp]), des.astype(np.float32)

    def _lf_inliers(self, fq, fc) -> int:
        if fq is None or fc is None:
            return 0
        (pq, dq), (pc, dc) = fq, fc
        pairs = self._lf().flann.knnMatch(dq, dc, k=2)
        good = [m for m, n in (p for p in pairs if len(p) == 2) if m.distance < VERIFY_RATIO * n.distance]
        if len(good) < 6:
            return 0
        _, mask = cv2.estimateAffinePartial2D(pq[[g.queryIdx for g in good]], pc[[g.trainIdx for g in good]],
                                              method=cv2.RANSAC, ransacReprojThreshold=VERIFY_RANSAC_PX)
        return int(mask.sum()) if mask is not None else 0

    def _row_inliers(self, job) -> int:
        """(index row, query features) -> inliers; -1 if the catalog photo is unavailable."""
        r, fq = job
        name = os.path.basename(str(self.metadata[r].get('image_path') or ''))
        img = cv2.imread(os.path.join(IMG_DIR, name), cv2.IMREAD_COLOR) if name else None
        if img is None:
            return -1
        return self._lf_inliers(fq, self._lf_feats(img))

    def _verify(self, obv, rev, cand_ids, swapped, exclude=frozenset()):
        """Local-feature check of `cand_ids`.
        -> ({article: (obverse_photo_inliers, reverse_photo_inliers)}, photos_checked, photos_missing)."""
        q = [(obv, self._lf_feats(obv['vimg'])) if obv else None,
             (rev, self._lf_feats(rev['vimg'])) if rev else None]
        plan, jobs = {}, {}
        for a in cand_ids:
            faces = ('arka', 'on') if a in swapped else ('on', 'arka')
            plan[a] = []
            for k, face in enumerate(faces):
                if q[k] is None or q[k][1] is None:
                    plan[a].append([])
                    continue
                rows = [r for r in (self.rows_by_face.get((a, face)) or self.rows_by_face.get((a, '*')) or [])
                        if r not in exclude]
                if len(rows) > VERIFY_ROWS:
                    embs = q[k][0]['embs']
                    sim = {r: max(float(np.dot(e, self.faiss_index.reconstruct(int(r)))) for e in embs)
                           for r in rows}
                    rows = sorted(rows, key=sim.get, reverse=True)[:VERIFY_ROWS]
                plan[a].append(rows)
                for r in rows:
                    jobs[(k, r)] = (r, q[k][1])
        res = dict(zip(jobs, self._pool.map(self._row_inliers, jobs.values()))) if jobs else {}
        missing = sum(1 for v in res.values() if v < 0)
        out = {a: tuple(max([max(0, res[(k, r)]) for r in rows] or [0]) for k, rows in enumerate(p))
               for a, p in plan.items()}
        return out, len(res) - missing, missing

    @staticmethod
    def _verified_conf(inl: int) -> float:
        if inl < VERIFIED_MIN:
            return VERIFIED_REL_CONF
        f = (inl - VERIFIED_MIN) / max(1, VERIFIED_INL_HI - VERIFIED_MIN)
        return float(np.clip(VERIFIED_CONF_LO + f * (VERIFIED_CONF_HI - VERIFIED_CONF_LO),
                             VERIFIED_CONF_LO, VERIFIED_CONF_HI))

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
                        diameter_mm: float = None, exclude=frozenset()) -> Dict[str, Any]:
        """`exclude`: index rows to ignore — evaluation only (held-out query photos)."""
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

            fused, obv_best, rev_best, swapped = self._fuse(obv, rev, exclude, with_swap=True)

            if metal or weight_g or diameter_mm:
                fused = {a: d + self._attr_adjust(a, metal, weight_g, diameter_mm)
                         for a, d in fused.items()}

            ranked = sorted(fused.items(), key=lambda kv: kv[1], reverse=True)

            # ---- Faz D: verify the top candidates, promote the verified group ----
            inl: Dict[int, Tuple[int, int]] = {}
            verified: Dict[int, int] = {}
            checked = missing = 0
            t_ver = time.time()
            if VERIFY_ENABLED and self._pool is not None and ranked:
                try:
                    inl, checked, missing = self._verify(
                        obv, rev, [a for a, _ in ranked[:VERIFY_K]], swapped, exclude)
                except Exception as e:
                    logger.error("Faz D verification failed: %s" % e, exc_info=True)
                    inl = {}
            verify_ran = checked > 0 and missing <= checked     # photos available -> result is meaningful
            verify_ms = int((time.time() - t_ver) * 1000)
            if verify_ran and inl:
                tot = {a: io + ia for a, (io, ia) in inl.items()}
                best = max(tot, key=lambda a: (tot[a], fused[a]))
                # records sharing the very same photo score identically: they are not rivals
                same = lambda a: abs(fused[a] - fused[best]) <= TIE_EPS  # noqa: E731
                rival = max([v for a, v in tot.items() if not same(a)] or [0])
                if tot[best] >= VERIFIED_MIN or (tot[best] >= VERIFIED_REL_MIN
                                                 and tot[best] >= VERIFIED_REL_RATIO * max(rival, 1)):
                    group = [a for a, v in tot.items() if v >= tot[best] / VERIFY_GROUP_RATIO
                             and (a == best or same(a) or v >= VERIFIED_MIN)]
                    group.sort(key=lambda a: (tot[a], fused[a]), reverse=True)
                    verified = {a: tot[a] for a in group}
                    ranked = [(a, fused[a]) for a in group] + [(a, d) for a, d in ranked if a not in verified]

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
                if a in verified:
                    conf = max(conf, self._verified_conf(verified[a]))
                elif verify_ran:
                    conf = min(conf, UNVERIFIED_CAP)
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
                    'verified': a in verified,
                    'inliers_obverse': inl[a][0] if a in inl else None,
                    'inliers_reverse': inl[a][1] if a in inl else None,
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

            if verify_ran and matches and not verified and reason is None:
                reason = UNVERIFIED_REASON

            quality = {}
            if obv:
                quality['obverse'] = {'coin_detected': obv['detected'], 'sharpness': obv['sharpness']}
            if rev:
                quality['reverse'] = {'coin_detected': rev['detected'], 'sharpness': rev['sharpness']}

            end = datetime.utcnow()
            logger.info("recognize(faz%s%s): sides=%d top art=%s conf=%.3f reason=%s tie=%d "
                        "verified=%d top_inl=%s checked=%d missing=%d verify_ms=%d" %
                        ('C' if (obv and rev and FUSION_MODE == 'exact') else 'A',
                         'D' if verify_ran else '',
                         len(sides), matches[0]['article_id'] if matches else None, top, reason,
                         len(tied_ids) if is_tied else 0, len(verified),
                         max(verified.values()) if verified else None, checked, missing, verify_ms))
            return {
                'matches': matches,
                'confidence': top,
                'ambiguous': is_tied,
                'tie_size': len(tied_ids) if is_tied else 0,
                'tied_articles': [int(a) for a in tied_ids] if is_tied else [],
                'method': ('dinov3_sam2_fazABC' if FUSION_MODE == 'exact' else 'dinov3_sam2_fazAB')
                          + ('D' if verify_ran else '') + ('E' if self.proj is not None else ''),
                'verified': bool(verified),
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
