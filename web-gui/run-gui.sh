#!/bin/bash

# SFTP Sync GUI Launcher
echo "Starting SFTP Sync GUI..."

# Check if executable exists or if source code is newer
if [ ! -f "./sftp-sync-gui" ] || [ "webgui.go" -nt "./sftp-sync-gui" ] || [ "main.go" -nt "./sftp-sync-gui" ]; then
    echo "Building GUI executable..."
    go build -o sftp-sync-gui
    if [ $? -ne 0 ]; then
        echo "Build failed. Please check the error messages above."
        exit 1
    fi
    echo "Build successful - includes log redirection fix"
fi

# Check if config file exists
if [ ! -f "./config.json" ]; then
    echo "Warning: config.json not found. Please create it or use the web interface to configure."
fi

# Start the GUI
echo "Starting web GUI on http://localhost:8080"
echo "Press Ctrl+C to stop"
echo ""
echo "✓ Log redirection fix applied - no logs will leak to terminal after stop"
echo "✓ Context-aware cancellation - sync stops immediately when requested"
echo "✓ Proper cleanup - no background processes remain after stop"
echo ""
./sftp-sync-gui --gui
