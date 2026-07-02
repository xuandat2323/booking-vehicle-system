import tempfile
import os
import numpy as np
import cv2
from deepface import DeepFace

MODEL_NAME = 'Facenet512'
DISTANCE_METRIC = 'cosine'
# cosine distance < 0.30 → same person (similarity > 0.70)
VERIFY_THRESHOLD = 0.30


def _save_temp(image_np: np.ndarray, suffix='.jpg') -> str:
    fd, path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    cv2.imwrite(path, image_np)
    return path


def face_match(face_np: np.ndarray, id_np: np.ndarray) -> dict:
    face_path = _save_temp(face_np)
    id_path = _save_temp(id_np)
    try:
        result = DeepFace.verify(
            img1_path=face_path,
            img2_path=id_path,
            model_name=MODEL_NAME,
            distance_metric=DISTANCE_METRIC,
            enforce_detection=False,
            silent=True,
        )
        distance = float(result.get('distance', 1.0))
        similarity = max(0.0, 1.0 - distance)
        verified = distance < VERIFY_THRESHOLD
        return {
            'code': 200,
            'data': {
                'similarity': round(similarity, 4),
                'score': round(similarity, 4),
                'verified': verified,
                'distance': round(distance, 4),
            }
        }
    except Exception as e:
        return {'code': 500, 'message': str(e)}
    finally:
        for p in (face_path, id_path):
            try:
                os.unlink(p)
            except OSError:
                pass
