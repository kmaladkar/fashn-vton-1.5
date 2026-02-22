# Lightweight Linux + PyTorch CPU (no CUDA). Small base, faster pulls.
FROM python:3.12-slim-bookworm

# OpenCV and minimal runtime libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# PyTorch CPU from official index (smaller than CUDA wheels)
RUN pip install --no-cache-dir \
    torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Copy project
COPY pyproject.toml ./
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY app/ ./app/

# App + API deps; force onnxruntime CPU (smaller, no CUDA)
RUN pip install --no-cache-dir -e ".[api]" && \
    pip uninstall -y onnxruntime-gpu 2>/dev/null || true && \
    pip install --no-cache-dir onnxruntime

# Bake model weights into image (~2 GB)
ENV FASHN_WEIGHTS_DIR=/weights
ENV PORT=8080
RUN mkdir -p /weights && python scripts/download_weights.py --weights-dir /weights

EXPOSE 8080

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
