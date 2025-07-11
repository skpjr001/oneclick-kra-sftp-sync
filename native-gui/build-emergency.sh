#!/bin/bash

# SFTP Sync Native GUI - Emergency Build Script
# Quick solution for immediate working executable

set -e

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

# Function to kill hanging processes
kill_hanging_processes() {
    print_status "INFO" "Checking for hanging build processes..."

    # Kill any hanging go build processes
    pkill -f "go build" 2>/dev/null || true

    # Kill any hanging MinGW processes
    pkill -f "mingw32-gcc" 2>/dev/null || true
    pkill -f "mingw64-gcc" 2>/dev/null || true

    # Kill any hanging cross-compiler processes
    pkill -f "aarch64-linux-gnu-gcc" 2>/dev/null || true

    print_status "SUCCESS" "Cleaned up any hanging processes"
}

# Function to detect current platform
detect_platform() {
    local os=$(go env GOOS)
    local arch=$(go env GOARCH)
    echo "${os}-${arch}"
}

# Function to build for current platform only
build_current_only() {
    print_status "INFO" "Building for current platform only..."

    local current_platform=$(detect_platform)
    local executable="sftp-sync-native-${current_platform}"

    if [ "$(go env GOOS)" = "windows" ]; then
        executable="${executable}.exe"
    fi

    print_status "INFO" "Platform: $current_platform"
    print_status "INFO" "Executable: $executable"

    # Set environment for stable build
    export CGO_ENABLED=1
    export GOOS=$(go env GOOS)
    export GOARCH=$(go env GOARCH)

    # Build with progress indication
    print_status "INFO" "Starting build... (this may take 1-2 minutes)"

    if go build -o "$executable" -v; then
        print_status "SUCCESS" "Build completed successfully!"
        print_status "SUCCESS" "Executable: $executable"

        # Check file size
        local size=$(stat -c%s "$executable" 2>/dev/null || stat -f%z "$executable" 2>/dev/null || echo "0")
        local size_human=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")
        print_status "INFO" "File size: $size_human"

        # Make executable
        chmod +x "$executable"

        return 0
    else
        print_status "ERROR" "Build failed"
        return 1
    fi
}

# Function to test the built executable
test_executable() {
    local executable=$1

    print_status "INFO" "Testing executable..."

    if [ -f "$executable" ]; then
        print_status "SUCCESS" "Executable exists: $executable"

        # Test if it can run (basic check)
        if [ "$(go env GOOS)" = "windows" ]; then
            print_status "INFO" "Windows executable created (cannot test on Linux)"
        else
            # Try to run with --help flag (if supported)
            if timeout 5s "./$executable" --help &>/dev/null; then
                print_status "SUCCESS" "Executable appears to be working"
            else
                print_status "WARNING" "Executable created but basic test failed (may still work)"
            fi
        fi

        return 0
    else
        print_status "ERROR" "Executable not found: $executable"
        return 1
    fi
}

# Function to create simple package
create_simple_package() {
    local executable=$1
    local current_platform=$(detect_platform)

    print_status "INFO" "Creating simple package..."

    # Create package directory
    local package_name="sftp-sync-native-gui-${current_platform}"
    mkdir -p "$package_name"

    # Copy executable
    cp "$executable" "$package_name/sftp-sync-native-gui$(echo $executable | sed 's/.*\(\.[^.]*\)$/\1/' | sed 's/^[^.]*$//')"

    # Copy essential files
    if [ -f "config.json" ]; then
        cp "config.json" "$package_name/"
    fi

    if [ -f "README.md" ]; then
        cp "README.md" "$package_name/"
    fi

    # Copy launcher scripts
    if [ -f "run-native-gui.sh" ]; then
        cp "run-native-gui.sh" "$package_name/"
    fi

    if [ -f "run-native-gui.bat" ]; then
        cp "run-native-gui.bat" "$package_name/"
    fi

    # Create simple instructions
    cat > "$package_name/QUICK-START.txt" << EOF
SFTP Sync Native GUI - Quick Start

1. Edit config.json with your SFTP server details
2. Run the application:
   - Linux/macOS: ./run-native-gui.sh or ./sftp-sync-native-gui
   - Windows: run-native-gui.bat or sftp-sync-native-gui.exe

The GUI provides:
- Real-time logging and progress indicators
- Built-in configuration editor (Config button)
- Start/Stop controls for sync operations
- Modern cross-platform interface

Built for: $current_platform
EOF

    # Create archive
    if [ "$(go env GOOS)" = "windows" ]; then
        if command -v zip &> /dev/null; then
            zip -r "${package_name}.zip" "$package_name"
            print_status "SUCCESS" "Package created: ${package_name}.zip"
        else
            print_status "WARNING" "zip not found, package directory created: $package_name"
        fi
    else
        tar -czf "${package_name}.tar.gz" "$package_name"
        print_status "SUCCESS" "Package created: ${package_name}.tar.gz"
    fi

    return 0
}

# Function to show usage
show_usage() {
    echo "SFTP Sync Native GUI - Emergency Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  --clean         Clean any existing builds first"
    echo "  --no-package    Don't create package, just build executable"
    echo "  --test          Test the executable after building"
    echo ""
    echo "This script provides a quick solution when other build scripts hang:"
    echo "  • Kills any hanging build processes"
    echo "  • Builds only for current platform (most reliable)"
    echo "  • Creates a working executable quickly"
    echo "  • Optionally creates a simple package"
}

# Main function
main() {
    local clean=false
    local no_package=false
    local test_exe=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --clean)
                clean=true
                shift
                ;;
            --no-package)
                no_package=true
                shift
                ;;
            --test)
                test_exe=true
                shift
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_status "INFO" "SFTP Sync Native GUI - Emergency Build Script"
    print_status "INFO" "Current platform: $(detect_platform)"
    echo ""

    # Check Go installation
    if ! command -v go &> /dev/null; then
        print_status "ERROR" "Go is not installed or not in PATH"
        exit 1
    fi

    print_status "INFO" "Go version: $(go version)"

    # Kill hanging processes
    kill_hanging_processes

    # Clean if requested
    if [ "$clean" = true ]; then
        print_status "INFO" "Cleaning existing builds..."
        rm -f sftp-sync-native-*
        rm -rf build-*
        rm -rf sftp-sync-native-gui-*
        print_status "SUCCESS" "Cleaned up existing builds"
    fi

    # Build for current platform
    if build_current_only; then
        local current_platform=$(detect_platform)
        local executable="sftp-sync-native-${current_platform}"

        if [ "$(go env GOOS)" = "windows" ]; then
            executable="${executable}.exe"
        fi

        # Test if requested
        if [ "$test_exe" = true ]; then
            test_executable "$executable"
        fi

        # Create package if requested
        if [ "$no_package" = false ]; then
            create_simple_package "$executable"
        fi

        echo ""
        print_status "SUCCESS" "Emergency build completed successfully!"
        print_status "INFO" "Your executable is ready: $executable"

        if [ "$no_package" = false ]; then
            print_status "INFO" "Package created for easy distribution"
        fi

        echo ""
        print_status "INFO" "To run the native GUI:"
        print_status "INFO" "  ./$executable --native"
        print_status "INFO" "Or use the launcher script:"
        print_status "INFO" "  ./run-native-gui.sh"

    else
        print_status "ERROR" "Emergency build failed"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
