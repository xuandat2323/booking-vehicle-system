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
    await file.read()
    return JSONResponse(content={
        "code": 200,
        "data": {"is_fake": False, "is_spoof": False, "score": 0.0},
        "message": "spoof soft-pass (ocr-only server)",
    })


@app.post("/liveness")
async def liveness_endpoint(file: UploadFile = File(...)):
    await file.read()
    return JSONResponse(content={
        "code": 200,
        "data": {"is_live": True, "liveness_score": 0.85},
        "message": "liveness soft-pass (ocr-only server)",
    })


@app.post("/face-match")
async def face_match_endpoint(
    face: UploadFile = File(...),
    id_image: UploadFile = File(...),
):
    await face.read()
    await id_image.read()
    return JSONResponse(content={
        "code": 200,
        "data": {"similarity": 0.82, "score": 0.82},
        "message": "face soft-pass (ocr-only server — enable full ekyc for real match)",
    })


if __name__ == "__main__":
    uvicorn.run("ocr_server:app", host="0.0.0.0", port=8001, reload=False)
