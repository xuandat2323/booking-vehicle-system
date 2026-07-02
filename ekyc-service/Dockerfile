FROM python:3.11-slim

WORKDIR /app

# System deps for OpenCV + MediaPipe
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download models during build (avoids cold-start delay at runtime)
RUN python -c "from deepface import DeepFace; DeepFace.build_model('Facenet512')" || true
RUN python -c "import mediapipe as mp; mp.solutions.face_mesh.FaceMesh(static_image_mode=True)" || true
RUN python -c "import easyocr; easyocr.Reader(['vi','en'], gpu=False)" || true

COPY . .

EXPOSE 8001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
