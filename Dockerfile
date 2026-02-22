# FASHN VTON v1.5 — Linux only (PyTorch + human parser require Linux/GPU wheels)
FROM python:3.11-slim-bookworm

# OpenCV and other runtime libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project (see .dockerignore)
COPY pyproject.toml ./
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY app/ ./app/

# Install uv and project (PyTorch + deps ~2 GB — first build can take 10–20 min)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install uv && uv pip install --system -e ".[api]"

# Bake model weights into image (~2 GB — no download on container start)
ENV FASHN_WEIGHTS_DIR=/weights
ENV PORT=8080
RUN mkdir -p /weights && python scripts/download_weights.py --weights-dir /weights

EXPOSE 8080

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
