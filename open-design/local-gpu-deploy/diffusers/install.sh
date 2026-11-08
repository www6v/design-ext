#!/bin/bash
# Install script for Diffusers Image Generation API
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Diffusers Image Generation API - Install"
echo "=========================================="

# Check GPU
echo ""
echo ">>> Checking GPU..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found. Please install NVIDIA drivers."
    exit 1
fi

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo "✓ GPU detected"

# Check Python version
echo ""
echo ">>> Checking Python..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $PYTHON_VERSION"

# Create virtual environment
echo ""
echo ">>> Creating virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
echo ""
echo ">>> Upgrading pip..."
pip install --upgrade pip

# Install PyTorch with CUDA 12.1
echo ""
echo ">>> Installing PyTorch with CUDA 12.1..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install other dependencies
echo ""
echo ">>> Installing dependencies..."
pip install -r requirements.txt

# Create directories
echo ""
echo ">>> Creating directories..."
mkdir -p logs outputs
mkdir -p /data/models/models

# Test installation
echo ""
echo ">>> Testing installation..."
python3 -c "
import torch
from diffusers import __version__ as diffusers_version

print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU: {torch.cuda.get_device_name(0)}')
print(f'Diffusers version: {diffusers_version}')
"

echo ""
echo "=========================================="
echo "Installation completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start the server: ./start.sh"
echo "2. Test the API: curl http://localhost:7865/health"
echo ""
echo "Model will be downloaded on first run."
echo "Models are cached in: /data/models/models"
