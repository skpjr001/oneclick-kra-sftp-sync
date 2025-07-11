#!/bin/bash

# SFTP Sync Native GUI - Kill Hanging Build Processes
# Quick script to stop any hanging build processes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

print_status "INFO" "Killing hanging build processes..."

# Kill Go build processes
if pgrep -f "go build" > /dev/null; then
    print_status "INFO" "Found hanging 'go build' processes, killing..."
    pkill -f "go build"
    print_status "SUCCESS" "Killed 'go build' processes"
else
    print_status "INFO" "No 'go build' processes found"
fi

# Kill MinGW processes
if pgrep -f "mingw" > /dev/null; then
    print_status "INFO" "Found hanging MinGW processes, killing..."
    pkill -f "mingw32-gcc"
    pkill -f "mingw64-gcc"
    pkill -f "x86_64-w64-mingw32-gcc"
    pkill -f "i686-w64-mingw32-gcc"
    print_status "SUCCESS" "Killed MinGW processes"
else
    print_status "INFO" "No MinGW processes found"
fi

# Kill ARM64 cross-compiler processes
if pgrep -f "aarch64-linux-gnu-gcc" > /dev/null; then
    print_status "INFO" "Found hanging ARM64 cross-compiler processes, killing..."
    pkill -f "aarch64-linux-gnu-gcc"
    print_status "SUCCESS" "Killed ARM64 cross-compiler processes"
else
    print_status "INFO" "No ARM64 cross-compiler processes found"
fi

# Kill any gcc processes that might be hanging
if pgrep -f "gcc.*sftp-sync" > /dev/null; then
    print_status "INFO" "Found hanging GCC processes related to sftp-sync, killing..."
    pkill -f "gcc.*sftp-sync"
    print_status "SUCCESS" "Killed hanging GCC processes"
else
    print_status "INFO" "No hanging GCC processes found"
fi

# Kill any timeout processes from our scripts
if pgrep -f "timeout.*go build" > /dev/null; then
    print_status "INFO" "Found hanging timeout processes, killing..."
    pkill -f "timeout.*go build"
    print_status "SUCCESS" "Killed timeout processes"
else
    print_status "INFO" "No timeout processes found"
fi

# Wait a moment for processes to terminate
sleep 2

# Force kill any remaining processes
print_status "INFO" "Force killing any remaining build processes..."
pkill -9 -f "go build" 2>/dev/null || true
pkill -9 -f "mingw" 2>/dev/null || true
pkill -9 -f "aarch64-linux-gnu-gcc" 2>/dev/null || true

print_status "SUCCESS" "All hanging build processes have been terminated"
print_status "INFO" "You can now run your build script again"

# Show remaining processes (for debugging)
if pgrep -f "go\|gcc\|mingw" > /dev/null; then
    print_status "WARNING" "Some processes are still running:"
    ps aux | grep -E "(go|gcc|mingw)" | grep -v grep
else
    print_status "SUCCESS" "No build-related processes remaining"
fi

echo ""
print_status "INFO" "Next steps:"
print_status "INFO" "1. Run './build-emergency.sh' for quick current-platform build"
print_status "INFO" "2. Run './package-simple.sh --quick' for fast multi-platform build"
print_status "INFO" "3. Run './package-simple.sh --current-only' for current platform only"
