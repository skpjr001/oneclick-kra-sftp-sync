#!/bin/bash

# SFTP Sync Native GUI Launcher
echo "Starting SFTP Sync Native GUI..."

# Check if executable exists or if source code is newer
if [ ! -f "./sftp-sync-native" ] || [ "native_gui.go" -nt "./sftp-sync-native" ] || [ "main.go" -nt "./sftp-sync-native" ]; then
    echo "Building native GUI executable..."

    # Check if required system libraries are installed
    if ! pkg-config --exists gl x11 xrandr xcursor xinerama xi; then
        echo "Error: Required system libraries not found!"
        echo "Please install the following packages:"
        echo "  Ubuntu/Debian: sudo apt-get install libgl1-mesa-dev libxrandr-dev libxcursor-dev libxinerama-dev libxi-dev libxext-dev libxfixes-dev libxxf86vm-dev pkg-config"
        echo "  CentOS/RHEL: sudo yum install mesa-libGL-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel libXext-devel libXfixes-devel libXxf86vm-devel pkgconfig"
        echo "  Fedora: sudo dnf install mesa-libGL-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel libXext-devel libXfixes-devel libXxf86vm-devel pkgconfig"
        exit 1
    fi

    go build -o sftp-sync-native
    if [ $? -ne 0 ]; then
        echo "Build failed. Please check the error messages above."
        echo "Make sure you have the required system libraries installed."
        exit 1
    fi
    echo "Build successful - native GUI with log redirection fix"
fi

# Check if config file exists
if [ ! -f "./config.json" ]; then
    echo "Warning: config.json not found. You can create it using the GUI config editor."
fi

# Check if display is available
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    echo "Error: No display found. Make sure you're running in a graphical environment."
    echo "If you're using SSH, try: ssh -X username@hostname"
    exit 1
fi

# Start the native GUI
echo "Starting native GUI..."
echo ""
echo "✓ Native cross-platform GUI using Fyne framework"
echo "✓ Log redirection fix applied - no logs will leak to terminal after stop"
echo "✓ Context-aware cancellation - sync stops immediately when requested"
echo "✓ Proper cleanup - no background processes remain after stop"
echo "✓ Modern UI with progress indicators and status updates"
echo ""
./sftp-sync-native --native
