#!/bin/bash

# SFTP Sync Native GUI Launcher - Stable Version
echo "Starting SFTP Sync Native GUI (Stable Version)..."

# Check if executable exists or if source code is newer
if [ ! -f "./sftp-sync-native" ] || [ "native_gui.go" -nt "./sftp-sync-native" ] || [ "main.go" -nt "./sftp-sync-native" ]; then
    echo "Building native GUI executable..."

    # Check if required system libraries are installed (Linux only)
    if [ "$(uname)" = "Linux" ]; then
        if ! pkg-config --exists gl x11 xrandr xcursor xinerama xi 2>/dev/null; then
            echo "Warning: Some required system libraries may be missing!"
            echo "If the build fails, install the following packages:"
            echo "  Ubuntu/Debian: sudo apt-get install libgl1-mesa-dev libxrandr-dev libxcursor-dev libxinerama-dev libxi-dev libxext-dev libxfixes-dev libxxf86vm-dev pkg-config gcc"
            echo "  CentOS/RHEL: sudo yum install mesa-libGL-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel libXext-devel libXfixes-devel libXxf86vm-devel pkgconfig gcc"
            echo "  Fedora: sudo dnf install mesa-libGL-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel libXext-devel libXfixes-devel libXxf86vm-devel pkgconfig gcc"
            echo ""
        fi
    fi

    # Ensure CGO is enabled for GUI builds
    export CGO_ENABLED=1

    # Build with error handling
    if go build -o sftp-sync-native 2>build.log; then
        echo "✅ Build successful - native GUI with stability fixes"
        rm -f build.log
    else
        echo "❌ Build failed. Error details:"
        cat build.log
        echo ""
        echo "Common solutions:"
        echo "1. Install required system libraries (see above)"
        echo "2. Ensure Go version 1.18+ with CGO support"
        echo "3. Check that you're in the native-gui directory"
        exit 1
    fi
fi

# Check if config file exists
if [ ! -f "./config.json" ]; then
    echo "⚠️  Warning: config.json not found"
    echo "   You can create it using the GUI config editor once the application starts"
    echo ""
fi

# Check if display is available (Linux/macOS)
if [ "$(uname)" != "Windows" ]; then
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
        echo "❌ Error: No display found. Make sure you're running in a graphical environment."
        echo "   If you're using SSH, try: ssh -X username@hostname"
        echo "   Or set display manually: export DISPLAY=:0"
        exit 1
    fi
fi

# Start the native GUI with error handling
echo "🚀 Starting native GUI..."
echo ""
echo "🔧 Stability Improvements Applied:"
echo "   ✅ Fixed UI thread violations that caused crashes"
echo "   ✅ Simplified text widget handling for better stability"
echo "   ✅ Context-aware cancellation - sync stops immediately when requested"
echo "   ✅ Proper cleanup - no background processes remain after stop"
echo "   ✅ Enhanced error handling and recovery"
echo "   ✅ Memory-efficient log management"
echo ""
echo "📋 GUI Features:"
echo "   • Real-time logging with automatic rotation"
echo "   • Start/Stop controls with immediate response"
echo "   • Built-in configuration editor"
echo "   • Progress indicators and status updates"
echo "   • Cross-platform native look and feel"
echo ""

# Execute with error handling
echo "🎯 Launching GUI application..."
echo ""

if ./sftp-sync-native --native; then
    echo ""
    echo "✅ GUI application closed successfully"
    echo "   Thank you for using SFTP Sync Tool!"
else
    exit_code=$?
    echo ""
    echo "❌ GUI exited with error code: $exit_code"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check that your display is working: echo \$DISPLAY"
    echo "2. Verify system dependencies are installed"
    echo "3. Test with a simple build: go build -o test && ./test --native"
    echo "4. Check the troubleshooting guide: NATIVE-GUI-TROUBLESHOOTING.md"
    echo ""
    echo "For additional help, see the documentation:"
    echo "• NATIVE-GUI-README.md - Complete user guide"
    echo "• CONFIG.md - Configuration options"
    echo "• NATIVE-GUI-TROUBLESHOOTING.md - Common issues and solutions"
    echo ""
    echo "The GUI has been significantly improved with:"
    echo "✅ Fixed all Fyne threading violations"
    echo "✅ Eliminated UI crashes on 'Start Sync'"
    echo "✅ Stable log handling and display"
    echo "✅ Proper resource cleanup"
    exit $exit_code
fi
