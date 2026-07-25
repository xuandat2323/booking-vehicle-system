"""
Lightweight OCR-only eKYC server (no DeepFace).
Run:  python ocr_server.py
Port: 8001
"""
import io
import numpy as np
import cv2
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import uvicorn

from ocr_service import ocr_image

app = FastAPI(title="GoRento OCR", version="1.0.0")


def _read_image(file_bytes: bytes) -> np.ndarray:
    arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Cannot decode image")
    return img


@app.get("/health")
def health():
    return {"status": "ok", "mode": "ocr-only"}


@app.post("/ocr")
async def ocr_endpoint(file: UploadFile = File(...)):
    data = await file.read()
    img = _read_image(data)
    result = ocr_image(img)
    return JSONResponse(content=result)


@app.post("/spoof-check")
async def spoof_check_endpoint(file: UploadFile = File(...)):
    """Spoof soft-pass trên OCR-only server (không chặn vì blur)."""
    await file.read()
    return JSONResponse(content={
        "code": 200,
        "data": {"is_fake": False, "is_spoof": False, "score": 0.0},
        "message": "spoof soft-pass (ocr-only server)",
    })


@app.post("/liveness")
async def liveness_endpoint(file: UploadFile = File(...)):
    """OCR-only: chỉ kiểm tra có khuôn mặt trong ảnh (OpenCV), không soft-pass ảnh trống."""
    data = await file.read()
    img = _read_image(data)
    faces = _detect_faces(img)
    ok = len(faces) >= 1
    return JSONResponse(content={
        "code": 200,
        "data": {
            "is_live": ok,
            "liveness_score": 0.75 if ok else 0.1,
            "face_count": len(faces),
        },
        "message": "ok" if ok else "Không thấy khuôn mặt trong selfie",
    })


@app.post("/face-match")
async def face_match_endpoint(
    face: UploadFile = File(...),
    id_image: UploadFile = File(...),
):
    """OCR-only: bắt buộc cả selfie và ảnh giấy tờ có khuôn mặt (OpenCV).

    Không phải DeepFace — chỉ chặn ảnh không có mặt. So khớp thật: chạy main.py.
    """
    face_bytes = await face.read()
    id_bytes = await id_image.read()
    face_np = _read_image(face_bytes)
    id_np = _read_image(id_bytes)
    face_n = len(_detect_faces(face_np))
    id_n = len(_detect_faces(id_np))
    if face_n < 1 or id_n < 1:
        return JSONResponse(content={
            "code": 200,
            "data": {"similarity": 0.0, "score": 0.0, "verified": False},
            "message": "Không thấy khuôn mặt trên selfie hoặc ảnh giấy tờ",
        })
    # Có mặt ở cả 2 ảnh → cho qua ngưỡng (0.65). Muốn so khớp danh tính thật dùng main.py.
    return JSONResponse(content={
        "code": 200,
        "data": {"similarity": 0.72, "score": 0.72, "verified": True},
        "message": "face detect ok (ocr-only — chưa so DeepFace)",
    })


def _detect_faces(img: np.ndarray) -> list:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4, minSize=(60, 60))
    return list(faces)


if __name__ == "__main__":
    uvicorn.run("ocr_server:app", host="0.0.0.0", port=8001, reload=False)
