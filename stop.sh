#!/bin/bash
# Stop script for Log Parser

echo "========================================"
echo "  Log Parser - Stopping Service"
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

PID_FILE="$SCRIPT_DIR/.logparser.pid"

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

# Check if PID file exists
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping Log Parser (PID: $PID)..."
        kill "$PID" 2>/dev/null
        
        # Wait for process to stop
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done
        
        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            print_warning "Process didn't stop gracefully, forcing..."
            kill -9 "$PID" 2>/dev/null
            sleep 1
        fi
        
        if ! ps -p "$PID" > /dev/null 2>&1; then
            print_status "Service stopped successfully"
            rm -f "$PID_FILE"
        else
            print_error "Failed to stop service"
            exit 1
        fi
    else
        print_warning "Service was not running (stale PID file)"
        rm -f "$PID_FILE"
    fi
else
    # Try to find and kill any running instance
    PIDS=$(pgrep -f "python.*app.py" 2>/dev/null || true)
    
    if [ -n "$PIDS" ]; then
        print_warning "Found running Log Parser process(es): $PIDS"
        echo "Stopping..."
        echo "$PIDS" | xargs kill 2>/dev/null || true
        sleep 1
        print_status "Process(es) stopped"
    else
        print_warning "Service is not running"
    fi
fi

echo ""
echo "========================================"
echo -e "  ${GREEN}Log Parser stopped${NC}"
echo "========================================"
echo ""
