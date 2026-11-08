#!/bin/bash
# Start script for Diffusers Image Generation API
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-7865}"
MODEL="${MODEL:-flux-dev}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host=*)
            HOST="${1#*=}"
            shift
            ;;
        --port=*)
            PORT="${1#*=}"
            shift
            ;;
        --model=*)
            MODEL="${1#*=}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check virtual environment
if [ ! -d "venv" ]; then
    echo "ERROR: Virtual environment not found. Run ./install.sh first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export HF_HOME=/data/models/models
export HF_ENDPOINT=https://hf-mirror.com

echo "=========================================="
echo "Diffusers Image Generation API"
echo "=========================================="
echo "Host: $HOST"
echo "Port: $PORT"
echo "Model: $MODEL"
echo "Model cache: /data/models/models"
echo "=========================================="
echo ""

# Start server
python server.py --host "$HOST" --port "$PORT" --model "$MODEL"
