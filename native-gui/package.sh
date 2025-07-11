#!/bin/bash

# SFTP Sync Native GUI - Package Creation Script
# Creates distribution packages for multiple platforms

set -e

# Configuration
PACKAGE_NAME="sftp-sync-native-gui"
VERSION="1.0.0"
BUILD_DIR="build-native"
PACKAGE_DIR="packages"
TEMP_DIR="temp-package"

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
    echo "SFTP Sync Native GUI Package Creation Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version VER   Set version number (default: $VERSION)"
    echo "  -b, --build-only    Only build executables, don't create packages"
    echo "  -p, --package-only  Only create packages (skip build)"
    echo "  -c, --clean         Clean build and package directories before starting"
    echo "  --no-docs           Skip documentation in packages"
    echo "  --minimal           Create minimal packages (executable + config only)"
    echo ""
    echo "Examples:"
    echo "  $0                  Create packages for all platforms"
    echo "  $0 -v 2.0.0         Create packages with version 2.0.0"
    echo "  $0 -c               Clean and create packages"
    echo "  $0 --build-only     Only build executables"
    echo ""
    echo "Prerequisites:"
    echo "  • Go 1.18+ with CGO enabled"
    echo "  • Linux GUI libraries (for native builds)"
    echo "  • MinGW-w64 (for Windows cross-compilation)"
    echo ""
    echo "Setup:"
    echo "  Run './setup-cross-compile.sh' to install dependencies"
    echo "  Or manually install:"
    echo "    Ubuntu/Debian: sudo apt-get install gcc-mingw-w64 libgl1-mesa-dev"
    echo "    Fedora: sudo dnf install mingw64-gcc mesa-libGL-devel"
}

# Function to clean directories
clean_directories() {
    print_status "INFO" "Cleaning build and package directories..."
    rm -rf "$BUILD_DIR" "$PACKAGE_DIR" "$TEMP_DIR"
    print_status "SUCCESS" "Directories cleaned"
}

# Function to create directory structure
create_directories() {
    print_status "INFO" "Creating directory structure..."
    mkdir -p "$BUILD_DIR" "$PACKAGE_DIR" "$TEMP_DIR"
    print_status "SUCCESS" "Directory structure created"
}

# Function to check if MinGW is available for Windows builds
check_mingw_availability() {
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        return 0
    elif command -v i686-w64-mingw32-gcc &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to build executables with better error handling
build_executables() {
    print_status "INFO" "Building executables for all platforms..."

    # Check if we can build for Windows
    local can_build_windows=false
    if check_mingw_availability; then
        can_build_windows=true
        print_status "INFO" "MinGW detected - Windows builds will be included"
    else
        print_status "WARNING" "MinGW not found - Windows builds will be skipped"
        print_status "INFO" "To build for Windows, install MinGW-w64:"
        print_status "INFO" "  Ubuntu/Debian: sudo apt-get install gcc-mingw-w64"
        print_status "INFO" "  Fedora: sudo dnf install mingw64-gcc"
    fi

    # Build for current platform first
    print_status "INFO" "Building for current platform..."
    export CGO_ENABLED=1
    if go build -o "$BUILD_DIR/sftp-sync-native-current"; then
        print_status "SUCCESS" "Current platform build completed"
    else
        print_status "ERROR" "Current platform build failed"
        exit 1
    fi

    # Build for Linux platforms
    print_status "INFO" "Building for Linux platforms..."

    # Linux amd64
    if GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-linux-amd64"; then
        print_status "SUCCESS" "Linux amd64 build completed"
    else
        print_status "WARNING" "Linux amd64 build failed"
    fi

    # Linux arm64
    if GOOS=linux GOARCH=arm64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-linux-arm64"; then
        print_status "SUCCESS" "Linux arm64 build completed"
    else
        print_status "WARNING" "Linux arm64 build failed"
    fi

    # Build for Windows platforms (only if MinGW is available)
    if [ "$can_build_windows" = true ]; then
        print_status "INFO" "Building for Windows platforms..."

        # Windows amd64
        if CC=x86_64-w64-mingw32-gcc GOOS=windows GOARCH=amd64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-windows-amd64.exe"; then
            print_status "SUCCESS" "Windows amd64 build completed"
        else
            print_status "WARNING" "Windows amd64 build failed"
        fi

        # Windows 386
        if CC=i686-w64-mingw32-gcc GOOS=windows GOARCH=386 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-windows-386.exe"; then
            print_status "SUCCESS" "Windows 386 build completed"
        else
            print_status "WARNING" "Windows 386 build failed"
        fi
    fi

    # Build for macOS platforms (only if on macOS)
    if [ "$(uname)" = "Darwin" ]; then
        print_status "INFO" "Building for macOS platforms..."

        # macOS amd64
        if GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-darwin-amd64"; then
            print_status "SUCCESS" "macOS amd64 build completed"
        else
            print_status "WARNING" "macOS amd64 build failed"
        fi

        # macOS arm64
        if GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 go build -o "$BUILD_DIR/sftp-sync-native-darwin-arm64"; then
            print_status "SUCCESS" "macOS arm64 build completed"
        else
            print_status "WARNING" "macOS arm64 build failed"
        fi
    else
        print_status "INFO" "Skipping macOS builds (not running on macOS)"
    fi

    # Reset environment
    unset GOOS GOARCH CGO_ENABLED CC

    # Verify at least one executable was created
    if [ ! -d "$BUILD_DIR" ] || [ -z "$(ls -A $BUILD_DIR)" ]; then
        print_status "ERROR" "No executables found in $BUILD_DIR"
        exit 1
    fi

    # Count successful builds
    local build_count=$(ls -1 "$BUILD_DIR" | wc -l)
    print_status "SUCCESS" "Build completed: $build_count executable(s) created"
}

# Function to get file list for packaging
get_package_files() {
    local include_docs=$1
    local minimal=$2

    # Essential files
    local files=(
        "config.json"
        "README.md"
    )

    # Platform-specific launchers
    if [ -f "run-native-gui.sh" ]; then
        files+=("run-native-gui.sh")
    fi
    if [ -f "run-native-gui.bat" ]; then
        files+=("run-native-gui.bat")
    fi

    # Documentation (if requested)
    if [ "$include_docs" = true ] && [ "$minimal" = false ]; then
        local doc_files=(
            "NATIVE-GUI-README.md"
            "CONFIG.md"
            "NATIVE-GUI-TROUBLESHOOTING.md"
            "NATIVE-GUI-SUCCESS-SUMMARY.md"
            "NATIVE-GUI-SUMMARY.md"
            "FYNE-THREADING-FIXES.md"
            "NATIVE-GUI-CRASH-FIXES.md"
            "PROJECT-SUMMARY.md"
        )

        for doc in "${doc_files[@]}"; do
            if [ -f "$doc" ]; then
                files+=("$doc")
            fi
        done
    fi

    # Additional scripts (if not minimal)
    if [ "$minimal" = false ]; then
        local script_files=(
            "build-native-gui.sh"
            "test-native-gui.sh"
            "test-native-gui-simple.sh"
        )

        for script in "${script_files[@]}"; do
            if [ -f "$script" ]; then
                files+=("$script")
            fi
        done
    fi

    printf '%s\n' "${files[@]}"
}

# Function to create installation guide
create_install_guide() {
    local platform=$1
    local executable=$2
    local install_file="$TEMP_DIR/INSTALLATION.md"

    cat > "$install_file" << EOF
# SFTP Sync Native GUI - Installation Guide

## Version: $VERSION
## Platform: $platform

### Quick Start

1. **Extract the package** to your desired location
2. **Run the application**:
   - Linux/macOS: \`./run-native-gui.sh\` or \`./sftp-sync-native-gui\`
   - Windows: \`run-native-gui.bat\` or \`sftp-sync-native-gui.exe\`

### Configuration

- The application uses \`config.json\` for configuration
- Use the built-in configuration editor (Config button in GUI)
- Or edit \`config.json\` manually with your SFTP settings

### System Requirements

#### Linux
- X11 or Wayland desktop environment
- OpenGL support
- Required libraries (usually pre-installed):
  - libgl1-mesa-dev
  - libxrandr-dev, libxcursor-dev, libxinerama-dev, libxi-dev

#### Windows
- Windows 7 or later
- No additional dependencies required

#### macOS
- macOS 10.12 or later
- Native Cocoa support

### Features

- **Real-time Logging**: Live log display with timestamps
- **Progress Indicators**: Visual feedback during sync operations
- **Configuration Editor**: Built-in JSON config editor
- **Cross-platform**: Native look and feel on all platforms
- **Context Cancellation**: Immediate sync termination when requested

### Troubleshooting

1. **GUI won't start**: Check display availability and system dependencies
2. **Build issues**: Ensure Go 1.18+ with CGO enabled
3. **Connection failures**: Verify SFTP credentials and network connectivity

### Documentation

- \`NATIVE-GUI-README.md\` - Complete user guide
- \`CONFIG.md\` - Configuration options
- \`NATIVE-GUI-TROUBLESHOOTING.md\` - Common issues and solutions

### Support

For issues and questions, refer to the included documentation or check the project repository.

---

**SFTP Sync Native GUI v$VERSION**
Cross-platform file synchronization with modern interface
EOF
}

# Function to create package for a specific platform
create_package() {
    local platform=$1
    local executable=$2
    local archive_format=$3
    local include_docs=$4
    local minimal=$5

    print_status "INFO" "Creating $platform package..."

    # Create temporary directory for this package
    local temp_package_dir="$TEMP_DIR/$PACKAGE_NAME-$VERSION-$platform"
    mkdir -p "$temp_package_dir"

    # Copy executable
    if [ -f "$BUILD_DIR/$executable" ]; then
        cp "$BUILD_DIR/$executable" "$temp_package_dir/sftp-sync-native-gui$(echo $executable | sed 's/.*\(\.[^.]*\)$/\1/')"
        chmod +x "$temp_package_dir/sftp-sync-native-gui"* 2>/dev/null || true
    else
        print_status "ERROR" "Executable not found: $BUILD_DIR/$executable"
        return 1
    fi

    # Copy package files
    local files
    readarray -t files < <(get_package_files "$include_docs" "$minimal")

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$temp_package_dir/"
        fi
    done

    # Create installation guide
    create_install_guide "$platform" "$executable"
    cp "$TEMP_DIR/INSTALLATION.md" "$temp_package_dir/"

    # Create package-specific readme
    cat > "$temp_package_dir/README-PACKAGE.md" << EOF
# SFTP Sync Native GUI - $platform Package

## Version: $VERSION
## Platform: $platform

### What's Included

- **Executable**: Native GUI application
- **Configuration**: Sample config.json
- **Launchers**: Platform-specific startup scripts
- **Documentation**: User guides and troubleshooting
- **Installation Guide**: Quick start instructions

### Quick Start

See \`INSTALLATION.md\` for detailed installation instructions.

### Package Contents

EOF

    # List package contents
    ls -la "$temp_package_dir" >> "$temp_package_dir/README-PACKAGE.md"

    # Create archive
    local archive_name="$PACKAGE_NAME-$VERSION-$platform"

    case $archive_format in
        "zip")
            cd "$TEMP_DIR"
            zip -r "$archive_name.zip" "$PACKAGE_NAME-$VERSION-$platform"
            mv "$archive_name.zip" "../$PACKAGE_DIR/"
            cd ..
            ;;
        "tar.gz")
            cd "$TEMP_DIR"
            tar -czf "$archive_name.tar.gz" "$PACKAGE_NAME-$VERSION-$platform"
            mv "$archive_name.tar.gz" "../$PACKAGE_DIR/"
            cd ..
            ;;
        *)
            print_status "ERROR" "Unknown archive format: $archive_format"
            return 1
            ;;
    esac

    print_status "SUCCESS" "Package created: $PACKAGE_DIR/$archive_name.$archive_format"

    # Calculate file size
    local package_file="$PACKAGE_DIR/$archive_name.$archive_format"
    local size=$(stat -c%s "$package_file" 2>/dev/null || stat -f%z "$package_file" 2>/dev/null || echo "0")
    print_status "INFO" "Package size: $(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")"
}

# Function to create all packages
create_all_packages() {
    local include_docs=$1
    local minimal=$2

    print_status "INFO" "Creating packages for all platforms..."

    # Platform configurations: "display_name:executable_name:archive_format"
    local platforms=(
        "linux-amd64:sftp-sync-native-linux-amd64:tar.gz"
        "linux-arm64:sftp-sync-native-linux-arm64:tar.gz"
        "windows-amd64:sftp-sync-native-windows-amd64.exe:zip"
        "windows-386:sftp-sync-native-windows-386.exe:zip"
        "darwin-amd64:sftp-sync-native-darwin-amd64:tar.gz"
        "darwin-arm64:sftp-sync-native-darwin-arm64:tar.gz"
    )

    # Also check for current platform build
    if [ -f "$BUILD_DIR/sftp-sync-native-current" ]; then
        platforms+=("current:sftp-sync-native-current:tar.gz")
    fi
    if [ -f "$BUILD_DIR/sftp-sync-native-current.exe" ]; then
        platforms+=("current:sftp-sync-native-current.exe:zip")
    fi

    # Filter out unavailable platforms
    local available_platforms=()
    for platform_config in "${platforms[@]}"; do
        IFS=':' read -r platform executable archive_format <<< "$platform_config"
        if [ -f "$BUILD_DIR/$executable" ]; then
            available_platforms+=("$platform_config")
        fi
    done

    if [ ${#available_platforms[@]} -eq 0 ]; then
        print_status "ERROR" "No executables found for packaging"
        return 1
    fi

    print_status "INFO" "Found ${#available_platforms[@]} platforms to package"

    local created_count=0

    for platform_config in "${available_platforms[@]}"; do
        IFS=':' read -r platform executable archive_format <<< "$platform_config"

        if create_package "$platform" "$executable" "$archive_format" "$include_docs" "$minimal"; then
            ((created_count++))
        fi
    done

    if [ $created_count -eq 0 ]; then
        print_status "ERROR" "No packages were created successfully"
        return 1
    fi

    print_status "SUCCESS" "Created $created_count packages"
}

# Function to generate checksums
generate_checksums() {
    print_status "INFO" "Generating checksums..."

    cd "$PACKAGE_DIR"

    # Create checksums file
    local checksum_file="checksums.txt"
    echo "# SFTP Sync Native GUI v$VERSION - Package Checksums" > "$checksum_file"
    echo "# Generated on: $(date)" >> "$checksum_file"
    echo "" >> "$checksum_file"

    # Generate SHA256 checksums
    if command -v sha256sum &> /dev/null; then
        sha256sum *.zip *.tar.gz 2>/dev/null >> "$checksum_file" || true
    elif command -v shasum &> /dev/null; then
        shasum -a 256 *.zip *.tar.gz 2>/dev/null >> "$checksum_file" || true
    else
        print_status "WARNING" "No checksum tool found (sha256sum or shasum)"
    fi

    cd ..

    print_status "SUCCESS" "Checksums generated: $PACKAGE_DIR/$checksum_file"
}

# Function to create package summary
create_package_summary() {
    print_status "INFO" "Creating package summary..."

    local summary_file="$PACKAGE_DIR/PACKAGES.md"

    cat > "$summary_file" << EOF
# SFTP Sync Native GUI - Package Summary

## Version: $VERSION
## Build Date: $(date)

### Available Packages

EOF

    # List all packages with sizes
    cd "$PACKAGE_DIR"
    for file in *.zip *.tar.gz; do
        if [ -f "$file" ]; then
            local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
            local size_human=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")
            echo "- **$file** - $size_human" >> "$summary_file"
        fi
    done
    cd ..

    cat >> "$summary_file" << EOF

### Installation

1. Download the appropriate package for your platform
2. Extract the archive
3. Run the installation guide: \`INSTALLATION.md\`
4. Start the application using the launcher script or executable

### Platform Support

- **Linux**: x86_64 and ARM64 architectures
- **Windows**: 64-bit and 32-bit
- **macOS**: Intel and Apple Silicon

### What's Included

- Native GUI executable
- Configuration file (\`config.json\`)
- Launcher scripts
- Documentation and troubleshooting guides
- Installation instructions

### Verification

Use the checksums in \`checksums.txt\` to verify package integrity.

### Support

For installation help and troubleshooting, see the included documentation.
EOF

    print_status "SUCCESS" "Package summary created: $summary_file"
}

# Function to show package results
show_results() {
    print_status "INFO" "Package creation completed!"
    echo ""
    echo "📦 Package Summary:"
    echo "=================="

    if [ -d "$PACKAGE_DIR" ]; then
        echo "📁 Package directory: $PACKAGE_DIR"
        echo ""
        echo "📋 Created packages:"

        cd "$PACKAGE_DIR"
        for file in *.zip *.tar.gz; do
            if [ -f "$file" ]; then
                local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
                local size_human=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")
                echo "  • $file ($size_human)"
            fi
        done
        cd ..

        echo ""
        echo "📄 Additional files:"
        echo "  • checksums.txt - Package integrity verification"
        echo "  • PACKAGES.md - Package summary and installation guide"

        # Calculate total size
        local total_size=$(du -sh "$PACKAGE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        echo ""
        echo "💾 Total package size: $total_size"
    else
        print_status "ERROR" "Package directory not found"
    fi

    echo ""
    echo "🚀 Next Steps:"
    echo "=============="
    echo "1. Test packages on target platforms"
    echo "2. Verify checksums for integrity"
    echo "3. Distribute packages to users"
    echo "4. Refer to PACKAGES.md for distribution notes"
}

# Main function
main() {
    local version="$VERSION"
    local build_only=false
    local package_only=false
    local clean=false
    local include_docs=true
    local minimal=false

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
            -b|--build-only)
                build_only=true
                shift
                ;;
            -p|--package-only)
                package_only=true
                shift
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            --no-docs)
                include_docs=false
                shift
                ;;
            --minimal)
                minimal=true
                shift
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Update version if provided
    VERSION="$version"

    print_status "INFO" "Starting package creation for SFTP Sync Native GUI v$VERSION"

    # Check prerequisites
    if ! command -v go &> /dev/null; then
        print_status "ERROR" "Go is not installed or not in PATH"
        print_status "INFO" "Install Go from https://golang.org/dl/"
        exit 1
    fi

    # Check if MinGW is available for Windows builds
    if ! check_mingw_availability; then
        print_status "WARNING" "MinGW not found - Windows builds will be skipped"
        print_status "INFO" "To enable Windows builds, run: ./setup-cross-compile.sh"
        print_status "INFO" "Or install manually:"
        print_status "INFO" "  Ubuntu/Debian: sudo apt-get install gcc-mingw-w64"
        print_status "INFO" "  Fedora: sudo dnf install mingw64-gcc"
        echo ""
    fi

    # Clean if requested
    if [ "$clean" = true ]; then
        clean_directories
    fi

    # Create directories
    create_directories

    # Build executables (unless package-only)
    if [ "$package_only" = false ]; then
        build_executables
    else
        # Verify executables exist if package-only
        if [ ! -d "$BUILD_DIR" ] || [ -z "$(ls -A $BUILD_DIR)" ]; then
            print_status "ERROR" "No executables found in $BUILD_DIR for packaging"
            print_status "INFO" "Run without --package-only to build first, or run build separately"
            exit 1
        fi
    fi

    # Exit if build-only
    if [ "$build_only" = true ]; then
        print_status "SUCCESS" "Build completed successfully"
        exit 0
    fi

    # Create packages
    create_all_packages "$include_docs" "$minimal"

    # Generate checksums
    generate_checksums

    # Create package summary
    create_package_summary

    # Show results
    show_results

    # Cleanup temporary directory
    rm -rf "$TEMP_DIR"

    print_status "SUCCESS" "Package creation completed successfully!"
}

# Run main function with all arguments
main "$@"
