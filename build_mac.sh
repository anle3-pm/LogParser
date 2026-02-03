#!/bin/bash
# Build script for macOS

set -e

echo "=== Building Log Parser for macOS ==="

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
pip install pywebview pyinstaller

# Ensure uploads directory exists
mkdir -p uploads

# Build the app
echo "Building application..."
pyinstaller logparser.spec --clean --noconfirm

echo ""
echo "=== Build complete! ==="
echo "Mac app location: dist/LogParser.app"
echo ""
echo "To run: open dist/LogParser.app"
echo "To distribute: zip the LogParser.app folder"
