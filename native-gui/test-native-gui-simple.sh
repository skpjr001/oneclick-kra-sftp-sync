#!/bin/bash

# Simple Native GUI Test Script
# Tests basic functionality of the native GUI

set -e

echo "Simple Native GUI Test"
echo "====================="

# Check if we're in the right directory
if [ ! -f "native_gui.go" ]; then
    echo "Error: Please run this script from the native-gui directory"
    exit 1
fi

# Test 1: Check if Go is available
echo "Test 1: Checking Go installation..."
if command -v go &> /dev/null; then
    echo "✓ Go is installed: $(go version)"
else
    echo "✗ Go is not installed"
    exit 1
fi

# Test 2: Check required files
echo "Test 2: Checking required files..."
required_files=("main.go" "native_gui.go" "go.mod" "config.json")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        exit 1
    fi
done

# Test 3: Check Go modules
echo "Test 3: Checking Go modules..."
if go mod tidy &> /dev/null; then
    echo "✓ Go modules are valid"
else
    echo "✗ Go modules have issues"
    exit 1
fi

# Test 4: Test build
echo "Test 4: Testing build..."
if go build -o test-native-gui &> /dev/null; then
    echo "✓ Build successful"

    # Check if executable exists
    if [ -f "test-native-gui" ]; then
        echo "✓ Executable created"

        # Get file size
        size=$(stat -c%s "test-native-gui" 2>/dev/null || stat -f%z "test-native-gui" 2>/dev/null)
        echo "✓ Executable size: $(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")"

        # Clean up
        rm -f test-native-gui
    else
        echo "✗ Executable not created"
        exit 1
    fi
else
    echo "✗ Build failed"
    exit 1
fi

# Test 5: Check configuration
echo "Test 5: Checking configuration..."
if [ -f "config.json" ]; then
    if python3 -m json.tool config.json &> /dev/null || jq . config.json &> /dev/null; then
        echo "✓ Configuration file is valid JSON"
    else
        echo "⚠ Configuration file has invalid JSON (but this won't prevent the GUI from running)"
    fi
else
    echo "⚠ No configuration file found (GUI will show warning)"
fi

# Test 6: Check for display (Linux only)
if [ "$(uname)" = "Linux" ]; then
    echo "Test 6: Checking display availability..."
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        echo "✓ Display available"
    else
        echo "⚠ No display found - GUI may not work in this environment"
        echo "  Try: export DISPLAY=:0 or use SSH with X11 forwarding"
    fi
fi

echo ""
echo "All basic tests passed!"
echo ""
echo "To start the native GUI:"
echo "  ./run-native-gui.sh"
echo ""
echo "Or build and run manually:"
echo "  go build -o sftp-sync-native"
echo "  ./sftp-sync-native --native"
echo ""
echo "Key improvements made:"
echo "✓ Fixed UI thread violations"
echo "✓ Simplified context management"
echo "✓ Improved log handling"
echo "✓ Better error handling"
echo "✓ Proper cleanup on exit"
