"""
Pydantic models for API request/response
"""
from typing import Optional, List, Literal
from pydantic import BaseModel, Field


class ImageGenerationRequest(BaseModel):
    """OpenAI-compatible image generation request"""
    prompt: str = Field(..., description="Text description of the image to generate")
    model: Optional[str] = Field("flux-dev", description="Model to use for generation")
    n: Optional[int] = Field(1, ge=1, le=4, description="Number of images to generate")
    size: Optional[str] = Field(
        "1024x1024",
        description="Image size in format 'widthxheight'"
    )
    response_format: Optional[Literal["b64_json", "url"]] = Field(
        "b64_json",
        description="Format of the response"
    )
    num_inference_steps: Optional[int] = Field(
        20,
        ge=1,
        le=100,
        description="Number of denoising steps"
    )
    guidance_scale: Optional[float] = Field(
        7.5,
        ge=0.0,
        le=20.0,
        description="Guidance scale for classifier-free guidance"
    )
    negative_prompt: Optional[str] = Field(
        None,
        description="Negative prompt for generation"
    )
    seed: Optional[int] = Field(
        None,
        description="Random seed for reproducibility"
    )


class ImageData(BaseModel):
    """Single image in response"""
    b64_json: Optional[str] = None
    url: Optional[str] = None
    revised_prompt: Optional[str] = None


class ImageGenerationResponse(BaseModel):
    """OpenAI-compatible image generation response"""
    created: int
    data: List[ImageData]


class ModelInfo(BaseModel):
    """Model information"""
    id: str
    object: str = "model"
    created: Optional[int] = None
    description: Optional[str] = None


class ModelListResponse(BaseModel):
    """Response for /v1/models endpoint"""
    data: List[ModelInfo]


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    gpu: str
    gpu_memory_used: str
    gpu_memory_total: str
    model_loaded: bool
    current_model: str
    cuda_available: bool
