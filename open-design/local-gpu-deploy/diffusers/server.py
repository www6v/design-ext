#!/usr/bin/env python3
"""
FastAPI server for Diffusers image generation
OpenAI-compatible API: /v1/images/generations
"""
import argparse
import base64
import io
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
from PIL import Image

from config import (
    DEFAULT_MODEL, HOST, PORT, MODELS,
    ENABLE_CORS, API_KEY, DEFAULT_NEGATIVE_PROMPT
)
from models import model_manager
from schemas import (
    ImageGenerationRequest,
    ImageGenerationResponse,
    ImageData,
    ModelInfo,
    ModelListResponse,
    HealthResponse
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    logger.info("Starting Diffusers API server...")
    logger.info(f"Default model: {DEFAULT_MODEL}")
    logger.info(f"Available models: {list(MODELS.keys())}")

    # Pre-load default model
    logger.info(f"Pre-loading model: {DEFAULT_MODEL}")
    if not model_manager.load_model(DEFAULT_MODEL):
        logger.warning(f"Failed to pre-load model: {DEFAULT_MODEL}")

    yield

    # Cleanup
    logger.info("Shutting down, unloading model...")
    model_manager.unload_model()


# Create FastAPI app
app = FastAPI(
    title="Diffusers Image Generation API",
    description="OpenAI-compatible image generation API using HuggingFace Diffusers",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS if configured
if ENABLE_CORS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.middleware("http")
async def verify_api_key(request: Request, call_next):
    """Optional API key verification"""
    if API_KEY and request.url.path.startswith("/v1/"):
        api_key = request.headers.get("Authorization", "").replace("Bearer ", "")
        if api_key != API_KEY:
            from fastapi.responses import JSONResponse
            return JSONResponse(
                {"error": {"message": "Unauthorized", "type": "auth_error"}},
                status_code=401
            )
    return await call_next(request)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    gpu_info = model_manager.get_gpu_info()

    return HealthResponse(
        status="ok",
        gpu=gpu_info["gpu"],
        gpu_memory_used=gpu_info["gpu_memory_used"],
        gpu_memory_total=gpu_info["gpu_memory_total"],
        model_loaded=model_manager.pipeline is not None,
        current_model=model_manager.current_model or "none",
        cuda_available=gpu_info["cuda_available"]
    )


@app.get("/v1/models", response_model=ModelListResponse)
async def list_models():
    """List available models"""
    models = []
    for name, config in MODELS.items():
        models.append(ModelInfo(
            id=name,
            description=config["description"]
        ))

    return ModelListResponse(data=models)


@app.post("/v1/images/generations", response_model=ImageGenerationResponse)
async def generate_images(request: ImageGenerationRequest):
    """Generate images - OpenAI compatible endpoint"""
    try:
        # Validate model
        if request.model not in MODELS:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown model: {request.model}. Available: {list(MODELS.keys())}"
            )

        # Parse size
        try:
            width, height = map(int, request.size.split("x"))
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid size format: {request.size}. Use 'widthxheight'"
            )

        # Validate size
        if width < 256 or width > 2048 or height < 256 or height > 2048:
            raise HTTPException(
                status_code=400,
                detail="Size must be between 256x256 and 2048x2048"
            )

        # Generate images
        images = model_manager.generate(
            prompt=request.prompt,
            model_name=request.model,
            num_images=request.n,
            width=width,
            height=height,
            num_inference_steps=request.num_inference_steps,
            guidance_scale=request.guidance_scale,
            negative_prompt=request.negative_prompt or DEFAULT_NEGATIVE_PROMPT,
            seed=request.seed
        )

        # Convert to response format
        data = []
        for img in images:
            if request.response_format == "b64_json":
                # Convert to base64
                buffered = io.BytesIO()
                img.save(buffered, format="PNG")
                img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
                data.append(ImageData(b64_json=img_str))
            else:
                # Save to file and return URL
                filename = f"output_{int(time.time() * 1000)}.png"
                filepath = Path("outputs") / filename
                img.save(filepath)
                data.append(ImageData(url=f"/outputs/{filename}"))

        return ImageGenerationResponse(
            created=int(time.time()),
            data=data
        )

    except Exception as e:
        logger.exception("Error generating image")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/images/edits")
async def edit_image():
    """Image editing endpoint - not implemented"""
    raise HTTPException(status_code=501, detail="Image editing not implemented yet")


@app.post("/v1/images/variations")
async def image_variations():
    """Image variations endpoint - not implemented"""
    raise HTTPException(status_code=501, detail="Image variations not implemented yet")


def main():
    parser = argparse.ArgumentParser(description="Diffusers Image Generation API")
    parser.add_argument("--host", type=str, default=HOST, help="Host to bind to")
    parser.add_argument("--port", type=int, default=PORT, help="Port to bind to")
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL, help="Default model to load")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload for development")
    args = parser.parse_args()

    # Update config
    import config
    config.DEFAULT_MODEL = args.model

    logger.info(f"Starting server on {args.host}:{args.port}")
    logger.info(f"API docs: http://{args.host}:{args.port}/docs")

    uvicorn.run(
        "server:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
        log_level="info"
    )


if __name__ == "__main__":
    main()
