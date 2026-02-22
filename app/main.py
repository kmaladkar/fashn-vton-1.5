"""FastAPI server for FASHN VTON v1.5 virtual try-on."""

import io
import os
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image

from fashn_vton import TryOnPipeline

WEIGHTS_DIR = os.environ.get("FASHN_WEIGHTS_DIR", "/weights")
_pipeline: TryOnPipeline | None = None


def get_pipeline() -> TryOnPipeline:
    if _pipeline is None:
        raise HTTPException(
            status_code=503,
            detail="Pipeline not loaded. Ensure weights are in FASHN_WEIGHTS_DIR.",
        )
    return _pipeline


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the try-on pipeline once at startup."""
    global _pipeline
    if os.path.isdir(WEIGHTS_DIR):
        try:
            _pipeline = TryOnPipeline(weights_dir=WEIGHTS_DIR)
        except Exception as e:
            raise RuntimeError(f"Failed to load pipeline from {WEIGHTS_DIR}: {e}") from e
    yield
    _pipeline = None


app = FastAPI(
    title="FASHN VTON v1.5 API",
    description="Virtual try-on: person image + garment image → result image",
    version="1.5.0",
    lifespan=lifespan,
)


@app.get("/health")
async def health():
    """Health check. Returns 200 if the service and pipeline are ready."""
    try:
        get_pipeline()
        return {"status": "ok", "weights_dir": WEIGHTS_DIR}
    except HTTPException:
        return Response(
            content='{"status":"unhealthy","detail":"Pipeline not loaded"}',
            status_code=503,
            media_type="application/json",
        )


@app.post("/try-on")
async def try_on(
    person_image: UploadFile = File(..., description="Person/model image"),
    garment_image: UploadFile = File(..., description="Garment image (worn or flat-lay)"),
    category: Literal["tops", "bottoms", "one-pieces"] = Form("tops"),
    garment_photo_type: Literal["model", "flat-lay"] = Form("model"),
    num_timesteps: int = Form(30, ge=10, le=50),
    guidance_scale: float = Form(1.5, ge=1.0, le=3.0),
    seed: int = Form(42),
):
    """
    Run virtual try-on: person wearing the garment.
    Returns the generated image as PNG.
    """
    pipeline = get_pipeline()

    def load_image(upload: UploadFile) -> Image.Image:
        content = upload.file.read()
        upload.file.seek(0)
        return Image.open(io.BytesIO(content)).convert("RGB")

    try:
        person = load_image(person_image)
        garment = load_image(garment_image)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}") from e

    result = pipeline(
        person_image=person,
        garment_image=garment,
        category=category,
        garment_photo_type=garment_photo_type,
        num_samples=1,
        num_timesteps=num_timesteps,
        guidance_scale=guidance_scale,
        seed=seed,
    )

    if not result.images:
        raise HTTPException(status_code=500, detail="No image generated")

    buf = io.BytesIO()
    result.images[0].save(buf, format="PNG")
    buf.seek(0)
    return Response(content=buf.getvalue(), media_type="image/png")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(os.environ.get("PORT", "8080")),
        reload=False,
    )
