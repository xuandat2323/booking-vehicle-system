import io
import numpy as np
import cv2
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse

from ocr_service import ocr_image
from face_service import face_match
from liveness_service import liveness_check, spoof_check

app = FastAPI(title="GoRento eKYC Local Service", version="1.0.0")


def _read_image(file_bytes: bytes) -> np.ndarray:
    arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Cannot decode image")
    return img


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ocr")
async def ocr_endpoint(file: UploadFile = File(...)):
    """OCR CCCD / bằng lái — trả về fields giống ViettelAI format."""
    data = await file.read()
    img = _read_image(data)
    result = ocr_image(img)
    return JSONResponse(content=result)


@app.post("/face-match")
async def face_match_endpoint(
    face: UploadFile = File(...),
    id_image: UploadFile = File(...),
):
    """So khớp khuôn mặt selfie vs ảnh trên giấy tờ."""
    face_bytes = await face.read()
    id_bytes   = await id_image.read()
    face_np = _read_image(face_bytes)
    id_np   = _read_image(id_bytes)
    result = face_match(face_np, id_np)
    return JSONResponse(content=result)


@app.post("/liveness")
async def liveness_endpoint(file: UploadFile = File(...)):
    """Kiểm tra liveness — phát hiện khuôn mặt thật vs ảnh in."""
    data = await file.read()
    img = _read_image(data)
    result = liveness_check(img)
    return JSONResponse(content=result)


@app.post("/spoof-check")
async def spoof_check_endpoint(file: UploadFile = File(...)):
    """Kiểm tra tài liệu giả mạo (printed / screen photo)."""
    data = await file.read()
    img = _read_image(data)
    result = spoof_check(img)
    return JSONResponse(content=result)
