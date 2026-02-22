# FASHN VTON v1.5: Efficient Maskless Virtual Try-On in Pixel Space

<div align="center">
  <a href="https://fashn.ai/research/vton-1-5"><img src='https://img.shields.io/badge/Project-Page-1A1A1A?style=flat' alt='Project Page'></a>&ensp;
  <a href='https://huggingface.co/fashn-ai/fashn-vton-1.5'><img src='https://img.shields.io/badge/Hugging%20Face-Model-FFD21E?style=flat&logo=HuggingFace&logoColor=FFD21E' alt='Hugging Face Model'></a>&ensp;
  <a href="https://huggingface.co/spaces/fashn-ai/fashn-vton-1.5"><img src='https://img.shields.io/badge/Hugging%20Face-Spaces-FFD21E?style=flat&logo=HuggingFace&logoColor=FFD21E' alt='Hugging Face Spaces'></a>&ensp;
  <a href=""><img src='https://img.shields.io/badge/arXiv-Coming%20Soon-b31b1b?style=flat&logo=arXiv&logoColor=b31b1b' alt='arXiv'></a>&ensp;
  <a href="LICENSE"><img src='https://img.shields.io/badge/License-Apache--2.0-gray?style=flat' alt='License'></a>
</div>

by [FASHN AI](https://fashn.ai)

Virtual try-on model that generates photorealistic images directly in pixel space without requiring segmentation masks.

<p align="center">
  <img src="https://static.fashn.ai/repositories/fashn-vton-v15/results/hero_collage.webp" alt="FASHN VTON v1.5 examples" width="900">
</p>

This repo contains minimal inference code to run virtual try-on with the FASHN VTON v1.5 model weights. Given a person image and a garment image, the model generates a photorealistic image of the person wearing the garment. Supports both model photos and flat-lay product shots as garment inputs.

---

## Local Installation

### Using uv (recommended)

[uv](https://docs.astral.sh/uv/) is a fast Python package installer and resolver. Install [uv](https://docs.astral.sh/uv/getting-started/installation/), then:

```bash
git clone https://github.com/fashn-AI/fashn-vton-1.5.git
cd fashn-vton-1.5
uv sync
source .venv/bin/activate   # or on Windows: .venv\Scripts\activate
```

This creates a virtual environment in `.venv` and installs the package in editable mode. Use `uv run` to run commands in that environment without activating it, e.g. `uv run python examples/basic_inference.py ...`. On macOS Intel, the lockfile is resolved for compatible wheels; on Linux and Apple Silicon you get the same locked versions for reproducibility.

### Using pip

```bash
git clone https://github.com/fashn-AI/fashn-vton-1.5.git
cd fashn-vton-1.5
python -m venv .venv && source .venv/bin/activate
pip install -e .
```

**Note:** Installation uses `onnxruntime-gpu` on Linux/Windows for GPU-accelerated pose detection (CUDA required). On macOS, `onnxruntime` (CPU) is used. For CPU-only on Linux/Windows, replace `onnxruntime-gpu` with `onnxruntime` in `pyproject.toml` or install after setup: `pip uninstall onnxruntime-gpu && pip install onnxruntime`.

---

## Model Weights

Download the required model weights (~2 GB total):

```bash
python scripts/download_weights.py --weights-dir ./weights
```

This downloads:
- `model.safetensors` — TryOnModel weights from [HuggingFace](https://huggingface.co/fashn-ai/fashn-vton-1.5)
- `dwpose/` — DWPose ONNX models for pose detection

**Note:** The human parser weights (~244 MB) are automatically downloaded on first use to the HuggingFace cache folder. Set `HF_HOME` to customize the location.

---

## Usage

```python
from fashn_vton import TryOnPipeline
from PIL import Image

# Initialize pipeline (automatically uses GPU if available)
pipeline = TryOnPipeline(weights_dir="./weights")

# Load images
person = Image.open("examples/data/model.webp").convert("RGB")
garment = Image.open("examples/data/garment.webp").convert("RGB")

# Run inference
result = pipeline(
    person_image=person,
    garment_image=garment,
    category="tops",  # "tops" | "bottoms" | "one-pieces"
)

# Save output
result.images[0].save("output.png")
```

### CLI

```bash
python examples/basic_inference.py \
    --weights-dir ./weights \
    --person-image examples/data/model.webp \
    --garment-image examples/data/garment.webp \
    --category tops
```

**Note:** The pipeline automatically uses GPU if available. The try-on model weights are stored in bfloat16 and will run in bf16 precision on Ampere+ GPUs (RTX 30xx/40xx, A100, H100). On older hardware or CPU, weights are converted to float32.

See [`examples/basic_inference.py`](examples/basic_inference.py) for additional options.

---

## Docker + FastAPI (recommended on macOS)

The model and dependencies do not support macOS (PyTorch/human parser require Linux). Run the try-on service in Docker and call it via FastAPI:

```bash
# Build and start (weights are baked into the image at build time; first build ~15–30 min)
docker compose up --build

# API: http://localhost:8080
# Docs: http://localhost:8080/docs
```

- **GET /health** — Check if the service and pipeline are ready.
- **POST /try-on** — Multipart form: `person_image`, `garment_image` (files), `category` (`tops` | `bottoms` | `one-pieces`), optional `garment_photo_type` (`model` | `flat-lay`), `num_timesteps`, `guidance_scale`, `seed`. Returns the generated image as PNG.

Example with curl:

```bash
curl -X POST http://localhost:8080/try-on \
  -F "person_image=@examples/data/model.webp" \
  -F "garment_image=@examples/data/garment.webp" \
  -F "category=tops" \
  -o result.png
```

Model weights (~2 GB) are downloaded during `docker compose build` and baked into the image, so container start is fast (no download at runtime). For GPU, use [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) and uncomment the `deploy.resources.reservations` block in `docker-compose.yml`.

**Why is the first build slow?**
- **First build (15–30 min):** Docker installs PyTorch and deps (~2 GB), then downloads model weights (~2 GB) into the image. Use `docker compose build` and watch the log; subsequent builds use cache.
- **Container start:** No weight download; the API is ready shortly after startup.

---

## Categories

| Category | Description |
|----------|-------------|
| `tops` | Upper body: t-shirts, blouses, jackets |
| `bottoms` | Lower body: pants, skirts, shorts |
| `one-pieces` | Full body: dresses, jumpsuits |

---

## FASHN cloud API

FASHN provides a suite of [fashion AI APIs](https://fashn.ai/products/api) including virtual try-on, model generation, image-to-video, and more. See the [docs](https://docs.fashn.ai/) to get started.

---

## Citation

If you use FASHN VTON v1.5 in your research, please cite:

```bibtex
@article{bochman2026fashnvton,
  title={FASHN VTON v1.5: Efficient Maskless Virtual Try-On in Pixel Space},
  author={Bochman, Dan and Bochman, Aya},
  journal={arXiv preprint},
  year={2026},
  note={Paper coming soon}
}
```

---

## License

Apache-2.0. See [LICENSE](LICENSE) for details.

**Third-party components:**
- [DWPose](https://github.com/IDEA-Research/DWPose) (Apache-2.0)
- [YOLOX](https://github.com/Megvii-BaseDetection/YOLOX) (Apache-2.0)
- [fashn-human-parser](https://github.com/fashn-AI/fashn-human-parser) ([License](https://github.com/fashn-AI/fashn-human-parser?tab=readme-ov-file#license))

# fash_vton
