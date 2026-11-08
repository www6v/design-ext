#!/bin/bash
# Stop script for Diffusers Image Generation API

echo "Stopping Diffusers API server..."

# Find and kill the server process
pids=$(pgrep -f "python.*server.py")

if [ -z "$pids" ]; then
    echo "Server is not running"
else
    echo "Found processes: $pids"
    for pid in $pids; do
        kill $pid 2>/dev/null || true
    done
    echo "Server stopped"
fi
