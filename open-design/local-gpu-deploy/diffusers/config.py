"""
Configuration for Diffusers Image Generation API
"""
import os
from pathlib import Path

# Base paths
BASE_DIR = Path(__file__).parent
MODEL_DIR = Path("/data/models/models")
LOG_DIR = BASE_DIR / "logs"
OUTPUT_DIR = BASE_DIR / "outputs"

# Ensure directories exist
MODEL_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# HuggingFace settings
os.environ.setdefault("HF_HOME", str(MODEL_DIR))
os.environ.setdefault("HF_ENDPOINT", "https://hf-mirror.com")

# Model settings
# RTX 3090 supports fp16 (not fp8 - that requires RTX 4090)
MODELS = {
    "flux-dev": {
        "model_id": "/data/models/models/models/AI-ModelScope--FLUX.1-dev/snapshots/master",  # Local path from ModelScope
        "pipeline_class": "FluxPipeline",
        "torch_dtype": "float16",  # fp16 for RTX 3090
        "default_steps": 20,
        "default_guidance_scale": 7.5,
        "max_resolution": 1024,
        "vram_usage_gb": 12,  # ~12GB with fp16
        "description": "FLUX.1-dev fp16 - High quality, best for RTX 3090"
    },
    "flux-schnell": {
        "model_id": "black-forest-labs/FLUX.1-schnell",
        "pipeline_class": "FluxPipeline",
        "torch_dtype": "float16",  # fp16 for RTX 3090
        "default_steps": 4,
        "default_guidance_scale": 0.0,
        "max_resolution": 1024,
        "vram_usage_gb": 12,  # ~12GB with fp16
        "description": "FLUX.1-schnell fp16 - Fast generation"
    },
    "sdxl": {
        "model_id": "stabilityai/stable-diffusion-xl-base-1.0",
        "pipeline_class": "StableDiffusionXLPipeline",
        "torch_dtype": "float16",
        "default_steps": 20,
        "default_guidance_scale": 7.5,
        "max_resolution": 1024,
        "vram_usage_gb": 7,
        "description": "SDXL 1.0 - Good balance of quality and speed"
    }
}

# Default model
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "flux-dev")

# Server settings
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "7865"))

# Generation settings
MAX_BATCH_SIZE = 4
DEFAULT_NEGATIVE_PROMPT = "low quality, blurry, distorted, deformed, ugly, bad anatomy"

# API settings
API_KEY = os.getenv("API_KEY", "")  # Empty = no authentication
ENABLE_CORS = os.getenv("ENABLE_CORS", "true").lower() == "true"
