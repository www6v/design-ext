"""
Model management for Diffusers API
"""
import torch
from typing import Dict, Any, Optional
from diffusers import FluxPipeline, StableDiffusionXLPipeline
from loguru import logger
import gc

from config import MODELS, MODEL_DIR


class ModelManager:
    """Manages model loading and inference"""

    def __init__(self):
        self.current_model: Optional[str] = None
        self.pipeline = None
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    def get_gpu_info(self) -> Dict[str, Any]:
        """Get GPU information"""
        if not torch.cuda.is_available():
            return {
                "gpu": "N/A",
                "gpu_memory_used": "N/A",
                "gpu_memory_total": "N/A",
                "cuda_available": False
            }

        gpu_name = torch.cuda.get_device_name(0)
        gpu_memory_used = torch.cuda.memory_allocated(0) / 1024**3
        gpu_memory_total = torch.cuda.get_device_properties(0).total_memory / 1024**3

        return {
            "gpu": gpu_name,
            "gpu_memory_used": f"{gpu_memory_used:.2f}GiB",
            "gpu_memory_total": f"{gpu_memory_total:.2f}GiB",
            "cuda_available": True
        }

    def load_model(self, model_name: str) -> bool:
        """Load a model into memory"""
        if model_name not in MODELS:
            logger.error(f"Unknown model: {model_name}")
            return False

        if self.current_model == model_name and self.pipeline is not None:
            logger.info(f"Model {model_name} already loaded")
            return True

        # Unload current model if different
        if self.pipeline is not None and self.current_model != model_name:
            self.unload_model()

        try:
            model_config = MODELS[model_name]
            model_id = model_config["model_id"]
            torch_dtype = getattr(torch, model_config["torch_dtype"])

            logger.info(f"Loading model: {model_id}")

            # Determine cache directory
            cache_dir = MODEL_DIR / model_name.replace("-", "_")
            cache_dir.mkdir(parents=True, exist_ok=True)

            # Load pipeline based on model type
            if model_config["pipeline_class"] == "FluxPipeline":
                self.pipeline = FluxPipeline.from_pretrained(
                    model_id,
                    torch_dtype=torch_dtype
                )
            elif model_config["pipeline_class"] == "StableDiffusionXLPipeline":
                self.pipeline = StableDiffusionXLPipeline.from_pretrained(
                    model_id,
                    torch_dtype=torch_dtype,
                    use_safetensors=True
                )
            else:
                raise ValueError(f"Unknown pipeline class: {model_config['pipeline_class']}")

            # Move to GPU with optimizations for 3090
            # Use enable_model_cpu_offload to reduce VRAM usage
            self.pipeline.enable_model_cpu_offload()

            # Enable attention slicing for further memory savings
            self.pipeline.enable_attention_slicing()

            # Try xformers if available
            if hasattr(self.pipeline, 'enable_xformers_memory_efficient_attention'):
                try:
                    self.pipeline.enable_xformers_memory_efficient_attention()
                except Exception as e:
                    logger.warning(f"Could not enable xformers: {e}")

            self.current_model = model_name
            logger.info(f"Model {model_name} loaded successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to load model {model_name}: {e}")
            return False

    def unload_model(self):
        """Unload current model from memory"""
        if self.pipeline is not None:
            logger.info(f"Unloading model: {self.current_model}")
            del self.pipeline
            self.pipeline = None
            self.current_model = None
            gc.collect()
            torch.cuda.empty_cache()
            logger.info("Model unloaded")

    def generate(
        self,
        prompt: str,
        model_name: str,
        num_images: int = 1,
        width: int = 1024,
        height: int = 1024,
        num_inference_steps: int = 20,
        guidance_scale: float = 7.5,
        negative_prompt: Optional[str] = None,
        seed: Optional[int] = None
    ) -> list:
        """Generate images"""
        # Load model if not loaded or different
        if not self.load_model(model_name):
            raise RuntimeError(f"Failed to load model: {model_name}")

        # Set seed for reproducibility
        if seed is not None:
            generator = torch.Generator(device=self.device).manual_seed(seed)
        else:
            generator = None

        # Get model config
        model_config = MODELS[model_name]

        logger.info(f"Generating {num_images} image(s) with {model_name}")
        logger.info(f"Prompt: {prompt[:100]}...")
        logger.info(f"Size: {width}x{height}, Steps: {num_inference_steps}")

        # Generate images
        images = []
        for i in range(num_images):
            if self.current_model and MODELS[self.current_model]["pipeline_class"] == "FluxPipeline":
                # FLUX models don't use negative prompts
                output = self.pipeline(
                    prompt=prompt,
                    width=width,
                    height=height,
                    num_inference_steps=num_inference_steps,
                    guidance_scale=guidance_scale,
                    generator=generator
                )
            else:
                # SDXL and others support negative prompts
                output = self.pipeline(
                    prompt=prompt,
                    negative_prompt=negative_prompt or "low quality, blurry",
                    width=width,
                    height=height,
                    num_inference_steps=num_inference_steps,
                    guidance_scale=guidance_scale,
                    generator=generator
                )

            images.extend(output.images)
            logger.info(f"Generated image {i+1}/{num_images}")

        return images


# Global model manager instance
model_manager = ModelManager()
