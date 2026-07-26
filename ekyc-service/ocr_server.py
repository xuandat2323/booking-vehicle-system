"""
Lightweight OCR-only eKYC server (no DeepFace).
Run:  python ocr_server.py
Port: 8001
"""
import logging
from contextlib import asynccontextmanager

import numpy as np
import cv2
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import uvicorn

from ocr_service import ocr_image, warmup
from face_lite import face_match, liveness_check

logger = logging.getLogger("ocr_server")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info("Warming up EasyOCR models…")
    warmup()
    logger.info("EasyOCR ready")
    yield


app = FastAPI(title="GoRento OCR", version="1.1.0", lifespan=lifespan)


def _read_image(file_bytes: bytes) -> np.ndarray:
    arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Cannot decode image")
    return img


@app.get("/health")
def health():
    return {"status": "ok", "mode": "ocr-only", "face_engine": "opencv-lite"}


@app.post("/ocr")
async def ocr_endpoint(
    file: UploadFile = File(...),
    doc_type: str | None = Form(None),
):
    """doc_type: cccd | cccd_back | license | license_back — theo đúng bước upload của app."""
    try:
        data = await file.read()
        img = _read_image(data)
        result = ocr_image(img, expected_type=doc_type)
        return JSONResponse(content=result)
    except HTTPException:
        raise
    except Exception as e:
        return JSONResponse(content={
            "code": 422,
            "data": {},
            "message": f"Không xử lý được ảnh — vui lòng thử lại ({type(e).__name__})",
        })


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
    """Liveness thật (OpenCV): mắt / độ nét / kích thước mặt / texture — điểm thay đổi theo ảnh."""
    data = await file.read()
    img = _read_image(data)
    return JSONResponse(content=liveness_check(img))


@app.post("/face-match")
async def face_match_endpoint(
    face: UploadFile = File(...),
    id_image: UploadFile = File(...),
):
    """So khớp selfie vs ảnh CCCD thật (OpenCV lite) — không còn hardcode 72%."""
    face_bytes = await face.read()
    id_bytes = await id_image.read()
    face_np = _read_image(face_bytes)
    id_np = _read_image(id_bytes)
    return JSONResponse(content=face_match(face_np, id_np))


if __name__ == "__main__":
    uvicorn.run("ocr_server:app", host="0.0.0.0", port=8001, reload=False)
