#!/bin/bash

# SFTP Sync GUI - Multi-Platform Build Script
# This script builds executables for Windows, Linux, and macOS

echo "Building SFTP Sync GUI for multiple platforms..."

# Create build directory
mkdir -p build

# Build for Windows (64-bit)
echo "Building for Windows (amd64)..."
GOOS=windows GOARCH=amd64 go build -o build/sftp-sync-gui-windows-amd64.exe
if [ $? -eq 0 ]; then
    echo "✓ Windows build successful"
else
    echo "✗ Windows build failed"
    exit 1
fi

# Build for Linux (64-bit)
echo "Building for Linux (amd64)..."
GOOS=linux GOARCH=amd64 go build -o build/sftp-sync-gui-linux-amd64
if [ $? -eq 0 ]; then
    echo "✓ Linux build successful"
else
    echo "✗ Linux build failed"
    exit 1
fi

# Build for macOS (64-bit Intel)
echo "Building for macOS (amd64)..."
GOOS=darwin GOARCH=amd64 go build -o build/sftp-sync-gui-darwin-amd64
if [ $? -eq 0 ]; then
    echo "✓ macOS (Intel) build successful"
else
    echo "✗ macOS (Intel) build failed"
    exit 1
fi

# Build for macOS (ARM64 - M1/M2)
echo "Building for macOS (arm64)..."
GOOS=darwin GOARCH=arm64 go build -o build/sftp-sync-gui-darwin-arm64
if [ $? -eq 0 ]; then
    echo "✓ macOS (ARM64) build successful"
else
    echo "✗ macOS (ARM64) build failed"
    exit 1
fi

# Build for Linux (ARM64)
echo "Building for Linux (arm64)..."
GOOS=linux GOARCH=arm64 go build -o build/sftp-sync-gui-linux-arm64
if [ $? -eq 0 ]; then
    echo "✓ Linux (ARM64) build successful"
else
    echo "✗ Linux (ARM64) build failed"
    exit 1
fi

# Build for current platform
echo "Building for current platform..."
go build -o build/sftp-sync-gui
if [ $? -eq 0 ]; then
    echo "✓ Current platform build successful"
else
    echo "✗ Current platform build failed"
    exit 1
fi

echo ""
echo "All builds completed successfully!"
echo "Executables are available in the 'build' directory:"
echo ""
ls -la build/
echo ""
echo "File sizes:"
du -sh build/*
echo ""
echo "To run the GUI:"
echo "  Windows: build/sftp-sync-gui-windows-amd64.exe --gui"
echo "  Linux:   build/sftp-sync-gui-linux-amd64 --gui"
echo "  macOS:   build/sftp-sync-gui-darwin-amd64 --gui"
echo ""
echo "Or use the platform-specific scripts:"
echo "  run-gui.sh (Linux/macOS)"
echo "  run-gui.bat (Windows)"
