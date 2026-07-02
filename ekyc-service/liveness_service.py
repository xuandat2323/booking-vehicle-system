"""
Liveness & spoof detection.
- Liveness : MediaPipe FaceMesh (468 landmarks) — replaces Haar cascade.
- Spoof    : DFT frequency analysis + local texture variance + color stats.
"""
import math
import numpy as np
import cv2
import mediapipe as mp

# ── MediaPipe setup ───────────────────────────────────────────────────────────

_face_mesh = mp.solutions.face_mesh.FaceMesh(
    static_image_mode=True,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
)

# Eye Aspect Ratio landmark indices (MediaPipe FaceMesh)
_LEFT_EAR_IDX  = [362, 385, 387, 263, 373, 380]
_RIGHT_EAR_IDX = [33,  160, 158, 133, 153, 144]


# ── Math helpers ──────────────────────────────────────────────────────────────

def _dist(a: tuple, b: tuple) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def _ear(landmarks, indices: list, w: int, h: int) -> float:
    """
    Eye Aspect Ratio.  Open eye ≈ 0.25+, closed ≈ 0.15.
    indices: [p0, p1, p2, p3, p4, p5] — p0/p3 horizontal, rest vertical.
    """
    pts = [(landmarks[i].x * w, landmarks[i].y * h) for i in indices]
    A = _dist(pts[1], pts[5])
    B = _dist(pts[2], pts[4])
    C = _dist(pts[0], pts[3])
    return (A + B) / (2.0 * C) if C > 0 else 0.0


def _blur_score(gray: np.ndarray) -> float:
    """Laplacian variance — higher = sharper."""
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def _local_variance(gray: np.ndarray) -> float:
    """Mean local pixel variance over 7×7 neighbourhoods — skin texture proxy."""
    k = np.ones((7, 7), np.float32) / 49
    gf = gray.astype(np.float32)
    mean_sq = cv2.filter2D(gf ** 2, -1, k)
    sq_mean = cv2.filter2D(gf, -1, k) ** 2
    return float((mean_sq - sq_mean).mean())


# ── Liveness check ────────────────────────────────────────────────────────────

def liveness_check(image_np: np.ndarray) -> dict:
    """
    Passive liveness using MediaPipe FaceMesh.
    Scores 5 signals; passes at ≥ 0.55.
    """
    h, w = image_np.shape[:2]
    rgb = cv2.cvtColor(image_np, cv2.COLOR_BGR2RGB)
    result = _face_mesh.process(rgb)

    if not result.multi_face_landmarks:
        return {
            'code': 200,
            'data': {
                'is_live':       False,
                'liveness_score': 0.0,
                'reason':        'no_face_detected',
            },
        }

    lm    = result.multi_face_landmarks[0].landmark
    score = 0.0

    # 1. Eyes open — EAR ≥ 0.18 → eyes are naturally open
    left_ear  = _ear(lm, _LEFT_EAR_IDX,  w, h)
    right_ear = _ear(lm, _RIGHT_EAR_IDX, w, h)
    avg_ear   = (left_ear + right_ear) / 2
    if avg_ear >= 0.18:
        score += 0.30
    elif avg_ear >= 0.12:
        score += 0.12

    # 2. Face occupies enough of the frame
    xs = [l.x for l in lm]
    ys = [l.y for l in lm]
    face_area = (max(xs) - min(xs)) * (max(ys) - min(ys))
    if face_area >= 0.06:
        score += 0.20
    if face_area >= 0.15:
        score += 0.10   # bonus for close-up shot

    # 3. Image sharpness
    gray = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY)
    blur = _blur_score(gray)
    if blur >= 80:
        score += 0.20
    elif blur >= 40:
        score += 0.08

    # 4. Skin texture — real skin has higher local variance than printed photo
    texture = _local_variance(gray)
    if texture >= 40:
        score += 0.15
    elif texture >= 15:
        score += 0.05

    # 5. Bilateral symmetry of facial landmarks
    mid_x       = (max(xs) + min(xs)) / 2
    left_count  = sum(1 for x in xs if x < mid_x)
    right_count = sum(1 for x in xs if x >= mid_x)
    if max(left_count, right_count) > 0:
        symmetry = min(left_count, right_count) / max(left_count, right_count)
        if symmetry >= 0.85:
            score += 0.05

    score    = min(score, 1.0)
    is_live  = score >= 0.55
    return {
        'code': 200,
        'data': {
            'is_live':        is_live,
            'liveness_score': round(score, 3),
            'avg_ear':        round(avg_ear, 3),
            'face_area':      round(face_area, 3),
            'blur_score':     round(blur, 1),
            'texture_score':  round(texture, 1),
        },
    }


# ── Spoof check ───────────────────────────────────────────────────────────────

def spoof_check(image_np: np.ndarray) -> dict:
    """
    Anti-spoofing for document images (CCCD / bằng lái).
    Combines DFT frequency + local texture + colour variance + resolution.
    """
    gray  = cv2.cvtColor(image_np, cv2.COLOR_BGR2GRAY)
    h_i, w_i = gray.shape
    score = 0.0

    # 1. Sharpness in natural range
    blur = _blur_score(gray)
    if 30 <= blur <= 3000:
        score += 0.25

    # 2. DFT — screen/projector moiré shifts energy toward edges
    dft  = np.fft.fft2(gray.astype(np.float32))
    mag  = 20 * np.log(np.abs(np.fft.fftshift(dft)) + 1)
    cy, cx = h_i // 2, w_i // 2
    qy, qx = h_i // 4, w_i // 4
    center_e = mag[cy - qy:cy + qy, cx - qx:cx + qx].mean()
    if center_e / (mag.mean() + 1e-6) >= 1.4:
        score += 0.25

    # 3. Colour / saturation variance
    hsv     = cv2.cvtColor(image_np, cv2.COLOR_BGR2HSV)
    sat_std = float(hsv[:, :, 1].std())
    if 8 <= sat_std <= 90:
        score += 0.25

    # 4. Texture — printed fakes are too smooth
    texture = _local_variance(gray)
    if texture >= 25:
        score += 0.15

    # 5. Resolution sanity
    if h_i >= 200 and w_i >= 300:
        score += 0.10

    is_fake = score < 0.50
    return {
        'code': 200,
        'data': {
            'is_fake':    is_fake,
            'is_spoof':   is_fake,
            'confidence': round(score, 3),
        },
    }
