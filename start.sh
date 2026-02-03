#!/bin/bash
# Start script for Log Parser
# Checks prerequisites and starts the web service

set -e

echo "========================================"
echo "  Log Parser - Starting Service"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check for Python 3
echo "Checking prerequisites..."
echo ""

if command_exists python3; then
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 --version 2>&1)
    print_status "Python found: $PYTHON_VERSION"
elif command_exists python; then
    # Check if python is Python 3
    PYTHON_VERSION=$(python --version 2>&1)
    if [[ $PYTHON_VERSION == *"Python 3"* ]]; then
        PYTHON_CMD="python"
        print_status "Python found: $PYTHON_VERSION"
    else
        print_error "Python 3 is required but Python 2 was found"
        echo ""
        echo "Please install Python 3:"
        echo "  macOS:   brew install python3"
        echo "  Ubuntu:  sudo apt-get install python3 python3-pip python3-venv"
        echo "  Fedora:  sudo dnf install python3 python3-pip"
        exit 1
    fi
else
    print_error "Python 3 is not installed"
    echo ""
    echo "Please install Python 3:"
    echo "  macOS:   brew install python3"
    echo "  Ubuntu:  sudo apt-get install python3 python3-pip python3-venv"
    echo "  Fedora:  sudo dnf install python3 python3-pip"
    exit 1
fi

# Check for pip
if command_exists pip3; then
    PIP_CMD="pip3"
    print_status "pip3 found"
elif command_exists pip; then
    PIP_CMD="pip"
    print_status "pip found"
else
    print_warning "pip not found, attempting to install..."
    $PYTHON_CMD -m ensurepip --upgrade 2>/dev/null || {
        print_error "Could not install pip"
        echo "Please install pip manually:"
        echo "  macOS:   brew install python3"
        echo "  Ubuntu:  sudo apt-get install python3-pip"
        exit 1
    }
    PIP_CMD="$PYTHON_CMD -m pip"
    print_status "pip installed"
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    print_warning "Virtual environment not found, creating..."
    $PYTHON_CMD -m venv venv
    print_status "Virtual environment created"
else
    print_status "Virtual environment found"
fi

# Activate virtual environment
source venv/bin/activate
print_status "Virtual environment activated"

# Install/upgrade dependencies
echo ""
echo "Checking dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
print_status "Dependencies installed"

# Create uploads directory if it doesn't exist
mkdir -p uploads
print_status "Uploads directory ready"

# Check if service is already running
PID_FILE="$SCRIPT_DIR/.logparser.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        print_warning "Service is already running (PID: $OLD_PID)"
        echo ""
        echo "To restart, run: ./stop.sh && ./start.sh"
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# Start the service
echo ""
echo "========================================"
echo "  Starting Log Parser Service..."
echo "========================================"
echo ""

# Run in background and save PID
nohup $PYTHON_CMD app.py > logparser.log 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

# Wait a moment for the server to start
sleep 2

# Check if it started successfully
if ps -p $PID > /dev/null 2>&1; then
    print_status "Service started successfully!"
    echo ""
    echo "========================================"
    echo -e "  ${GREEN}Log Parser is running${NC}"
    echo "========================================"
    echo ""
    echo "  URL:      http://localhost:5000"
    echo "  PID:      $PID"
    echo "  Log file: $SCRIPT_DIR/logparser.log"
    echo ""
    echo "  To stop:  ./stop.sh"
    echo ""
    
    # Try to open in browser (macOS)
    if command_exists open; then
        echo "Opening browser..."
        sleep 1
        open "http://localhost:5000"
    fi
else
    print_error "Failed to start service"
    echo ""
    echo "Check the log file for errors:"
    echo "  cat $SCRIPT_DIR/logparser.log"
    rm -f "$PID_FILE"
    exit 1
fi
