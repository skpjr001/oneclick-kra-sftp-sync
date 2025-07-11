#!/bin/bash

# SFTP Sync Native GUI - Simple Package Script
# A simplified version that handles cross-compilation gracefully

set -e

# Configuration
PACKAGE_NAME="sftp-sync-native-gui"
VERSION="1.0.0"
BUILD_DIR="build-simple"
PACKAGE_DIR="packages"

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

# Function to show usage
show_usage() {
    echo "SFTP Sync Native GUI - Simple Package Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version VER   Set version number (default: $VERSION)"
    echo "  -c, --clean         Clean build directory first"
    echo "  --current-only      Only build for current platform"
    echo "  --skip-windows      Skip Windows builds"
    echo "  --skip-arm64        Skip ARM64 builds"
    echo "  --quick             Use shorter timeouts (for testing)"
    echo ""
    echo "This script builds native GUI executables and creates packages."
    echo "It handles cross-compilation issues gracefully by:"
    echo "  • Building current platform first (always works)"
    echo "  • Trying cross-compilation with fallbacks"
    echo "  • Skipping platforms that fail to build"
    echo "  • Creating packages for successful builds only"
}

# Function to detect current platform
detect_platform() {
    local os=$(go env GOOS)
    local arch=$(go env GOARCH)
    echo "${os}-${arch}"
}

# Function to build for current platform
build_current_platform() {
    print_status "INFO" "Building for current platform..."

    export CGO_ENABLED=1

    local current_platform=$(detect_platform)
    local executable="sftp-sync-native-${current_platform}"

    if [ "$(go env GOOS)" = "windows" ]; then
        executable="${executable}.exe"
    fi

    if go build -o "$BUILD_DIR/$executable" 2>/dev/null; then
        print_status "SUCCESS" "Current platform ($current_platform) build completed"
        echo "$executable"
        return 0
    else
        print_status "ERROR" "Current platform build failed"
        return 1
    fi
}

# Function to run command with timeout
run_with_timeout() {
    local timeout_duration=$1
    local description=$2
    shift 2

    print_status "INFO" "$description (timeout: ${timeout_duration}s)"

    if timeout "$timeout_duration" "$@" 2>/dev/null; then
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            print_status "WARNING" "$description timed out after ${timeout_duration}s"
        else
            print_status "WARNING" "$description failed"
        fi
        return $exit_code
    fi
}

# Function to try building for Linux AMD64
build_linux_amd64() {
    print_status "INFO" "Attempting Linux AMD64 build..."

    if run_with_timeout 120 "Linux AMD64 build" \
       env GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-linux-amd64"; then
        print_status "SUCCESS" "Linux AMD64 build completed"
        echo "sftp-sync-native-linux-amd64"
        return 0
    else
        print_status "WARNING" "Linux AMD64 build failed"
        return 1
    fi
}

# Function to try building for Linux ARM64
build_linux_arm64() {
    if [ "$SKIP_ARM64" = true ]; then
        print_status "INFO" "Skipping ARM64 build as requested"
        return 1
    fi

    print_status "INFO" "Attempting Linux ARM64 build..."

    # Try with cross-compiler first
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_status "INFO" "Using ARM64 cross-compiler..."
        if run_with_timeout 180 "ARM64 build with cross-compiler" \
           env CC=aarch64-linux-gnu-gcc GOOS=linux GOARCH=arm64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-linux-arm64"; then
            print_status "SUCCESS" "Linux ARM64 build completed (with CGO)"
            echo "sftp-sync-native-linux-arm64"
            return 0
        fi
    fi

    # Fallback to no-CGO build
    print_status "INFO" "Trying ARM64 build without CGO..."
    if run_with_timeout 120 "ARM64 build without CGO" \
       env GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o "$BUILD_DIR/sftp-sync-native-linux-arm64"; then
        print_status "SUCCESS" "Linux ARM64 build completed (without CGO)"
        echo "sftp-sync-native-linux-arm64"
        return 0
    else
        print_status "WARNING" "Linux ARM64 build failed"
        return 1
    fi
}

# Function to try building for Windows
build_windows() {
    if [ "$SKIP_WINDOWS" = true ]; then
        print_status "INFO" "Skipping Windows builds as requested"
        return 1
    fi

    print_status "INFO" "Attempting Windows builds..."

    local built_count=0

    # Windows AMD64
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        print_status "INFO" "Building Windows AMD64..."
        if run_with_timeout 300 "Windows AMD64 build" \
           env CC=x86_64-w64-mingw32-gcc GOOS=windows GOARCH=amd64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-windows-amd64.exe"; then
            print_status "SUCCESS" "Windows AMD64 build completed"
            echo "sftp-sync-native-windows-amd64.exe"
            ((built_count++))
        else
            print_status "WARNING" "Windows AMD64 build failed or timed out"
        fi
    else
        print_status "WARNING" "MinGW 64-bit not found, skipping Windows AMD64"
    fi

    # Windows 386
    if command -v i686-w64-mingw32-gcc &> /dev/null; then
        print_status "INFO" "Building Windows 386..."
        if run_with_timeout 300 "Windows 386 build" \
           env CC=i686-w64-mingw32-gcc GOOS=windows GOARCH=386 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-windows-386.exe"; then
            print_status "SUCCESS" "Windows 386 build completed"
            echo "sftp-sync-native-windows-386.exe"
            ((built_count++))
        else
            print_status "WARNING" "Windows 386 build failed or timed out"
        fi
    else
        print_status "WARNING" "MinGW 32-bit not found, skipping Windows 386"
    fi

    if [ $built_count -eq 0 ]; then
        print_status "WARNING" "No Windows builds succeeded"
        print_status "INFO" "Install MinGW with: sudo apt-get install gcc-mingw-w64"
        return 1
    fi

    return 0
}

# Function to try building for macOS
build_macos() {
    if [ "$(uname)" != "Darwin" ]; then
        print_status "INFO" "Skipping macOS builds (not running on macOS)"
        return 1
    fi

    print_status "INFO" "Attempting macOS builds..."

    local built_count=0

    # macOS AMD64
    if run_with_timeout 180 "macOS AMD64 build" \
       env GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-darwin-amd64"; then
        print_status "SUCCESS" "macOS AMD64 build completed"
        echo "sftp-sync-native-darwin-amd64"
        ((built_count++))
    else
        print_status "WARNING" "macOS AMD64 build failed"
    fi

    # macOS ARM64
    if run_with_timeout 180 "macOS ARM64 build" \
       env GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-darwin-arm64"; then
        print_status "SUCCESS" "macOS ARM64 build completed"
        echo "sftp-sync-native-darwin-arm64"
        ((built_count++))
    else
        print_status "WARNING" "macOS ARM64 build failed"
    fi

    if [ $built_count -eq 0 ]; then
        return 1
    fi

    return 0
}

# Function to create a package
create_package() {
    local executable=$1
    local platform=$2

    print_status "INFO" "Creating package for $platform..."

    # Determine archive format
    local archive_format="tar.gz"
    if [[ "$executable" == *.exe ]]; then
        archive_format="zip"
    fi

    # Create temp directory
    local temp_dir="temp-${platform}"
    mkdir -p "$temp_dir"

    # Copy executable
    cp "$BUILD_DIR/$executable" "$temp_dir/sftp-sync-native-gui$(echo $executable | sed 's/.*\(\.[^.]*\)$/\1/' | sed 's/^[^.]*$//')"
    chmod +x "$temp_dir/sftp-sync-native-gui"* 2>/dev/null || true

    # Copy essential files
    local files=("config.json" "README.md")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$temp_dir/"
        fi
    done

    # Copy launcher scripts
    if [ -f "run-native-gui.sh" ]; then
        cp "run-native-gui.sh" "$temp_dir/"
    fi
    if [ -f "run-native-gui.bat" ]; then
        cp "run-native-gui.bat" "$temp_dir/"
    fi

    # Create simple installation guide
    cat > "$temp_dir/INSTALL.txt" << EOF
SFTP Sync Native GUI v$VERSION - $platform

Quick Start:
1. Extract this package
2. Edit config.json with your SFTP settings
3. Run the application:
   - Linux/macOS: ./run-native-gui.sh or ./sftp-sync-native-gui
   - Windows: run-native-gui.bat or sftp-sync-native-gui.exe

The application provides a modern GUI for SFTP synchronization with:
- Real-time logging and progress indicators
- Built-in configuration editor
- Start/stop controls with immediate response
- Cross-platform native look and feel

For detailed documentation, see the project repository.
EOF

    # Create archive
    local archive_name="$PACKAGE_NAME-$VERSION-$platform"
    mkdir -p "$PACKAGE_DIR"

    if [ "$archive_format" = "zip" ]; then
        (cd "$temp_dir" && zip -r "../$PACKAGE_DIR/$archive_name.zip" .)
    else
        tar -czf "$PACKAGE_DIR/$archive_name.tar.gz" -C "$temp_dir" .
    fi

    # Clean up temp directory
    rm -rf "$temp_dir"

    # Get file size
    local package_file="$PACKAGE_DIR/$archive_name.$archive_format"
    local size=$(stat -c%s "$package_file" 2>/dev/null || stat -f%z "$package_file" 2>/dev/null || echo "0")
    local size_human=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")

    print_status "SUCCESS" "Package created: $archive_name.$archive_format ($size_human)"

    return 0
}

# Function to show results
show_results() {
    print_status "INFO" "Build and package results:"
    echo ""

    if [ -d "$BUILD_DIR" ]; then
        print_status "INFO" "Built executables:"
        ls -la "$BUILD_DIR"
        echo ""
    fi

    if [ -d "$PACKAGE_DIR" ] && [ -n "$(ls -A "$PACKAGE_DIR" 2>/dev/null)" ]; then
        print_status "INFO" "Created packages:"
        for file in "$PACKAGE_DIR"/*; do
            if [ -f "$file" ]; then
                local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
                local size_human=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")
                echo "  • $(basename "$file") ($size_human)"
            fi
        done
        echo ""

        print_status "SUCCESS" "Packages ready for distribution!"
    else
        print_status "WARNING" "No packages were created"
    fi
}

# Main function
main() {
    local version="$VERSION"
    local clean=false
    local current_only=false
    local skip_windows=false
    local skip_arm64=false
    local quick=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            --current-only)
                current_only=true
                shift
                ;;
            --skip-windows)
                skip_windows=true
                shift
                ;;
            --skip-arm64)
                skip_arm64=true
                shift
                ;;
            --quick)
                quick=true
                shift
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Export variables for use in functions
    export SKIP_WINDOWS=$skip_windows
    export SKIP_ARM64=$skip_arm64
    VERSION="$version"

    # Adjust timeouts for quick mode
    if [ "$quick" = true ]; then
        print_status "INFO" "Quick mode enabled - using shorter timeouts"
        # Override timeout function for quick mode
        run_with_timeout() {
            local timeout_duration=$(($1 / 3))  # Use 1/3 of normal timeout
            local description=$2
            shift 2

            print_status "INFO" "$description (quick timeout: ${timeout_duration}s)"

            if timeout "$timeout_duration" "$@" 2>/dev/null; then
                return 0
            else
                local exit_code=$?
                if [ $exit_code -eq 124 ]; then
                    print_status "WARNING" "$description timed out after ${timeout_duration}s (quick mode)"
                else
                    print_status "WARNING" "$description failed"
                fi
                return $exit_code
            fi
        }
    fi

    print_status "INFO" "SFTP Sync Native GUI Simple Package Script v$VERSION"
    print_status "INFO" "Current platform: $(detect_platform)"
    echo ""

    # Check Go installation
    if ! command -v go &> /dev/null; then
        print_status "ERROR" "Go is not installed or not in PATH"
        exit 1
    fi

    print_status "INFO" "Go version: $(go version)"
    echo ""

    # Clean if requested
    if [ "$clean" = true ]; then
        print_status "INFO" "Cleaning build directory..."
        rm -rf "$BUILD_DIR" "$PACKAGE_DIR"
    fi

    # Create directories
    mkdir -p "$BUILD_DIR" "$PACKAGE_DIR"

    # Track successful builds
    local built_executables=()
    local built_platforms=()

    # Build for current platform (this should always work)
    print_status "INFO" "=== Building Current Platform ==="
    if executable=$(build_current_platform); then
        built_executables+=("$executable")
        built_platforms+=("$(detect_platform)")
    else
        print_status "ERROR" "Current platform build failed - cannot continue"
        exit 1
    fi

    # If current-only mode, skip other platforms
    if [ "$current_only" = true ]; then
        print_status "INFO" "Current-only mode - skipping other platforms"
    else
        # Try building for other platforms
        print_status "INFO" "=== Building Other Platforms ==="

        # Linux AMD64 (if not current platform)
        if [ "$(detect_platform)" != "linux-amd64" ]; then
            if executable=$(build_linux_amd64); then
                built_executables+=("$executable")
                built_platforms+=("linux-amd64")
            fi
        fi

        # Linux ARM64
        if executable=$(build_linux_arm64); then
            built_executables+=("$executable")
            built_platforms+=("linux-arm64")
        fi

        # Windows builds
        if build_windows; then
            # Check what was built
            if [ -f "$BUILD_DIR/sftp-sync-native-windows-amd64.exe" ]; then
                built_executables+=("sftp-sync-native-windows-amd64.exe")
                built_platforms+=("windows-amd64")
            fi
            if [ -f "$BUILD_DIR/sftp-sync-native-windows-386.exe" ]; then
                built_executables+=("sftp-sync-native-windows-386.exe")
                built_platforms+=("windows-386")
            fi
        fi

        # macOS builds
        if build_macos; then
            # Check what was built
            if [ -f "$BUILD_DIR/sftp-sync-native-darwin-amd64" ]; then
                built_executables+=("sftp-sync-native-darwin-amd64")
                built_platforms+=("darwin-amd64")
            fi
            if [ -f "$BUILD_DIR/sftp-sync-native-darwin-arm64" ]; then
                built_executables+=("sftp-sync-native-darwin-arm64")
                built_platforms+=("darwin-arm64")
            fi
        fi
    fi

    # Create packages for successful builds
    print_status "INFO" "=== Creating Packages ==="
    echo ""

    if [ ${#built_executables[@]} -eq 0 ]; then
        print_status "ERROR" "No executables were built successfully"
        exit 1
    fi

    print_status "SUCCESS" "Built ${#built_executables[@]} executables"

    # Create packages
    local package_count=0
    for i in "${!built_executables[@]}"; do
        local executable="${built_executables[$i]}"
        local platform="${built_platforms[$i]}"

        if create_package "$executable" "$platform"; then
            ((package_count++))
        fi
    done

    echo ""
    print_status "SUCCESS" "Created $package_count packages"

    # Show results
    show_results

    # Provide next steps
    echo ""
    print_status "INFO" "Next Steps:"
    echo "  1. Test the packages on target platforms"
    echo "  2. Distribute the packages to users"
    echo "  3. Users can extract and run with the included scripts"
    echo ""
    print_status "SUCCESS" "Simple packaging completed!"
}

# Run main function with all arguments
main "$@"
