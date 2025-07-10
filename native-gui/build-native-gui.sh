#!/bin/bash

# SFTP Sync Native GUI - Cross-Platform Build Script
# This script builds native GUI executables for Windows, Linux, and macOS

echo "Building SFTP Sync Native GUI for multiple platforms..."

# Create build directory
mkdir -p build-native

# Function to check if system dependencies are available
check_system_deps() {
    echo "Checking system dependencies for native builds..."

    # Check if we have the basic build tools
    if ! command -v go &> /dev/null; then
        echo "Error: Go is not installed or not in PATH"
        exit 1
    fi

    # Check CGO
    if [ "$CGO_ENABLED" = "0" ]; then
        echo "Warning: CGO is disabled. Native GUI requires CGO to be enabled."
        echo "Setting CGO_ENABLED=1"
        export CGO_ENABLED=1
    fi

    echo "✓ Go found: $(go version)"
    echo "✓ CGO enabled"
}

# Function to install Linux dependencies
install_linux_deps() {
    echo "Installing Linux dependencies for native GUI..."

    # Detect Linux distribution
    if command -v apt-get &> /dev/null; then
        echo "Detected Debian/Ubuntu system"
        echo "Installing dependencies with apt-get..."
        sudo apt-get update
        sudo apt-get install -y \
            libgl1-mesa-dev \
            libxrandr-dev \
            libxcursor-dev \
            libxinerama-dev \
            libxi-dev \
            libxext-dev \
            libxfixes-dev \
            libxxf86vm-dev \
            pkg-config \
            gcc
    elif command -v yum &> /dev/null; then
        echo "Detected RHEL/CentOS system"
        echo "Installing dependencies with yum..."
        sudo yum install -y \
            mesa-libGL-devel \
            libXrandr-devel \
            libXcursor-devel \
            libXinerama-devel \
            libXi-devel \
            libXext-devel \
            libXfixes-devel \
            libXxf86vm-devel \
            pkgconfig \
            gcc
    elif command -v dnf &> /dev/null; then
        echo "Detected Fedora system"
        echo "Installing dependencies with dnf..."
        sudo dnf install -y \
            mesa-libGL-devel \
            libXrandr-devel \
            libXcursor-devel \
            libXinerama-devel \
            libXi-devel \
            libXext-devel \
            libXfixes-devel \
            libXxf86vm-devel \
            pkgconfig \
            gcc
    elif command -v pacman &> /dev/null; then
        echo "Detected Arch Linux system"
        echo "Installing dependencies with pacman..."
        sudo pacman -S --needed \
            mesa \
            libxrandr \
            libxcursor \
            libxinerama \
            libxi \
            libxext \
            libxfixes \
            libxxf86vm \
            pkgconf \
            gcc
    else
        echo "Warning: Unknown Linux distribution. Please install the following manually:"
        echo "  - OpenGL development libraries (Mesa)"
        echo "  - X11 development libraries (Xrandr, Xcursor, Xinerama, Xi, Xext, Xfixes, Xxf86vm)"
        echo "  - pkg-config"
        echo "  - GCC compiler"
    fi
}

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local goos=$2
    local goarch=$3
    local executable=$4
    local cgo_enabled=$5

    echo "Building for ${platform} (${goos}/${goarch})..."

    # Set environment variables
    export GOOS=$goos
    export GOARCH=$goarch
    export CGO_ENABLED=$cgo_enabled

    # Special handling for cross-compilation
    if [ "$goos" != "$(go env GOOS)" ] || [ "$goarch" != "$(go env GOARCH)" ]; then
        if [ "$cgo_enabled" = "1" ]; then
            echo "Warning: Cross-compiling with CGO enabled for $platform"
            echo "This may require cross-compilation toolchain for $goos/$goarch"

            # Try to set appropriate CC for cross-compilation
            case "$goos-$goarch" in
                "windows-amd64")
                    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
                        export CC=x86_64-w64-mingw32-gcc
                        echo "Using MinGW-w64 for Windows cross-compilation"
                    else
                        echo "MinGW-w64 not found. Install with:"
                        echo "  Ubuntu/Debian: sudo apt-get install gcc-mingw-w64"
                        echo "  Fedora: sudo dnf install mingw64-gcc"
                        return 1
                    fi
                    ;;
                "windows-386")
                    if command -v i686-w64-mingw32-gcc &> /dev/null; then
                        export CC=i686-w64-mingw32-gcc
                    else
                        echo "MinGW-w64 32-bit not found"
                        return 1
                    fi
                    ;;
                "darwin-amd64"|"darwin-arm64")
                    # macOS cross-compilation is complex, disable for now
                    echo "macOS cross-compilation with CGO not supported in this script"
                    echo "Build on macOS directly or disable CGO"
                    return 1
                    ;;
            esac
        fi
    fi

    # Build the executable
    if go build -o "build-native/${executable}"; then
        echo "✓ ${platform} build successful"

        # Get file size
        local size=$(du -sh "build-native/${executable}" | cut -f1)
        echo "  File size: $size"

        return 0
    else
        echo "✗ ${platform} build failed"
        return 1
    fi
}

# Main build function
main() {
    check_system_deps

    # Install dependencies if building on Linux for Linux
    if [ "$(go env GOOS)" = "linux" ]; then
        read -p "Install Linux GUI dependencies? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_linux_deps
        fi
    fi

    echo ""
    echo "Starting cross-platform builds..."
    echo ""

    # Build for current platform first (most likely to succeed)
    echo "Building for current platform..."
    current_os=$(go env GOOS)
    current_arch=$(go env GOARCH)

    case "$current_os" in
        "linux")
            build_platform "Current-Linux" "$current_os" "$current_arch" "sftp-sync-native-current" "1"
            ;;
        "darwin")
            build_platform "Current-macOS" "$current_os" "$current_arch" "sftp-sync-native-current" "1"
            ;;
        "windows")
            build_platform "Current-Windows" "$current_os" "$current_arch" "sftp-sync-native-current.exe" "1"
            ;;
    esac

    echo ""
    echo "Building for other platforms..."

    # Linux builds
    build_platform "Linux-amd64" "linux" "amd64" "sftp-sync-native-linux-amd64" "1"
    build_platform "Linux-arm64" "linux" "arm64" "sftp-sync-native-linux-arm64" "1"

    # Windows builds (requires MinGW for cross-compilation)
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        build_platform "Windows-amd64" "windows" "amd64" "sftp-sync-native-windows-amd64.exe" "1"
        build_platform "Windows-386" "windows" "386" "sftp-sync-native-windows-386.exe" "1"
    else
        echo "Skipping Windows builds (MinGW not available)"
        echo "To build for Windows, install MinGW-w64:"
        echo "  Ubuntu/Debian: sudo apt-get install gcc-mingw-w64"
        echo "  Fedora: sudo dnf install mingw64-gcc"
    fi

    # macOS builds (only work when building on macOS)
    if [ "$(go env GOOS)" = "darwin" ]; then
        build_platform "macOS-amd64" "darwin" "amd64" "sftp-sync-native-darwin-amd64" "1"
        build_platform "macOS-arm64" "darwin" "arm64" "sftp-sync-native-darwin-arm64" "1"
    else
        echo "Skipping macOS builds (requires macOS host)"
    fi

    # Reset environment
    unset GOOS GOARCH CGO_ENABLED CC

    echo ""
    echo "Build summary:"
    echo "=============="

    if [ -d "build-native" ] && [ "$(ls -A build-native)" ]; then
        echo "Built executables:"
        ls -la build-native/
        echo ""
        echo "File sizes:"
        du -sh build-native/*
        echo ""
        echo "Total build directory size:"
        du -sh build-native/
    else
        echo "No executables were built successfully."
        exit 1
    fi

    echo ""
    echo "Usage instructions:"
    echo "=================="
    echo "Linux:   ./build-native/sftp-sync-native-linux-amd64 --native"
    echo "Windows: build-native\\sftp-sync-native-windows-amd64.exe --native"
    echo "macOS:   ./build-native/sftp-sync-native-darwin-amd64 --native"
    echo ""
    echo "Or use the platform-specific launchers:"
    echo "  run-native-gui.sh (Linux/macOS)"
    echo "  run-native-gui.bat (Windows)"
    echo ""
    echo "Requirements:"
    echo "============="
    echo "Linux:   X11 or Wayland desktop environment"
    echo "Windows: Windows 7 or later"
    echo "macOS:   macOS 10.12 or later"
    echo ""
    echo "All builds include:"
    echo "✓ Native GUI using Fyne framework"
    echo "✓ Cross-platform compatibility"
    echo "✓ Log redirection fix"
    echo "✓ Context-aware cancellation"
    echo "✓ Modern UI with progress indicators"
}

# Help function
show_help() {
    echo "SFTP Sync Native GUI Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --deps         Install Linux dependencies only"
    echo "  --current      Build for current platform only"
    echo "  --clean        Clean build directory before building"
    echo ""
    echo "Examples:"
    echo "  $0                Build for all supported platforms"
    echo "  $0 --current     Build for current platform only"
    echo "  $0 --clean       Clean and build for all platforms"
    echo "  $0 --deps        Install Linux dependencies only"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --deps)
        check_system_deps
        if [ "$(go env GOOS)" = "linux" ]; then
            install_linux_deps
        else
            echo "Dependency installation only supported on Linux"
        fi
        exit 0
        ;;
    --current)
        check_system_deps
        mkdir -p build-native
        current_os=$(go env GOOS)
        current_arch=$(go env GOARCH)
        case "$current_os" in
            "linux")
                build_platform "Current-Linux" "$current_os" "$current_arch" "sftp-sync-native-current" "1"
                ;;
            "darwin")
                build_platform "Current-macOS" "$current_os" "$current_arch" "sftp-sync-native-current" "1"
                ;;
            "windows")
                build_platform "Current-Windows" "$current_os" "$current_arch" "sftp-sync-native-current.exe" "1"
                ;;
        esac
        exit 0
        ;;
    --clean)
        echo "Cleaning build directory..."
        rm -rf build-native
        main
        exit 0
        ;;
    "")
        main
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
