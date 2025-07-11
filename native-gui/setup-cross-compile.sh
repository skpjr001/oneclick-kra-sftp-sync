#!/bin/bash

# SFTP Sync Native GUI - Cross-Compilation Setup Script
# Installs dependencies required for cross-platform builds

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

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release &> /dev/null; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_status "WARNING" "Running as root. This script should be run as a regular user."
        print_status "INFO" "The script will use sudo when needed for package installation."
    fi
}

# Function to check Go installation
check_go() {
    print_status "INFO" "Checking Go installation..."

    if command -v go &> /dev/null; then
        local go_version=$(go version | cut -d' ' -f3)
        print_status "SUCCESS" "Go is installed: $go_version"

        # Check Go version (need 1.18+)
        local version_number=$(echo "$go_version" | sed 's/go//' | cut -d'.' -f1,2)
        if [ "$(printf '%s\n' "1.18" "$version_number" | sort -V | head -n1)" = "1.18" ]; then
            print_status "SUCCESS" "Go version is compatible"
        else
            print_status "WARNING" "Go version $go_version may be too old (need 1.18+)"
        fi

        # Check CGO
        if [ "$(go env CGO_ENABLED)" = "1" ]; then
            print_status "SUCCESS" "CGO is enabled"
        else
            print_status "WARNING" "CGO is disabled - enabling for native GUI builds"
            export CGO_ENABLED=1
        fi
    else
        print_status "ERROR" "Go is not installed"
        print_status "INFO" "Please install Go from https://golang.org/dl/"
        return 1
    fi
}

# Function to install Linux GUI dependencies
install_linux_gui_deps() {
    local os_id=$1

    print_status "INFO" "Installing Linux GUI dependencies..."

    case $os_id in
        "ubuntu"|"debian")
            print_status "INFO" "Installing packages for Ubuntu/Debian..."
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
                gcc \
                libc6-dev
            ;;
        "fedora")
            print_status "INFO" "Installing packages for Fedora..."
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
                gcc \
                glibc-devel
            ;;
        "centos"|"rhel")
            print_status "INFO" "Installing packages for CentOS/RHEL..."
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
                gcc \
                glibc-devel
            ;;
        "arch"|"manjaro")
            print_status "INFO" "Installing packages for Arch Linux..."
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
            ;;
        *)
            print_status "WARNING" "Unknown Linux distribution: $os_id"
            print_status "INFO" "Please install the following packages manually:"
            print_status "INFO" "  - OpenGL development libraries (Mesa)"
            print_status "INFO" "  - X11 development libraries"
            print_status "INFO" "  - pkg-config and GCC"
            return 1
            ;;
    esac

    print_status "SUCCESS" "Linux GUI dependencies installed"
}



# Function to install MinGW for Windows cross-compilation
install_mingw() {
    local os_id=$1

    print_status "INFO" "Installing MinGW for Windows cross-compilation..."

    case $os_id in
        "ubuntu"|"debian")
            print_status "INFO" "Installing MinGW for Ubuntu/Debian..."
            sudo apt-get install -y \
                gcc-mingw-w64 \
                g++-mingw-w64 \
                mingw-w64-tools
            ;;
        "fedora")
            print_status "INFO" "Installing MinGW for Fedora..."
            sudo dnf install -y \
                mingw64-gcc \
                mingw64-gcc-c++ \
                mingw32-gcc \
                mingw32-gcc-c++
            ;;
        "centos"|"rhel")
            print_status "INFO" "Installing MinGW for CentOS/RHEL..."
            # Enable EPEL repository first
            sudo yum install -y epel-release
            sudo yum install -y \
                mingw64-gcc \
                mingw64-gcc-c++ \
                mingw32-gcc \
                mingw32-gcc-c++
            ;;
        "arch"|"manjaro")
            print_status "INFO" "Installing MinGW for Arch Linux..."
            sudo pacman -S --needed \
                mingw-w64-gcc
            ;;
        *)
            print_status "WARNING" "Unknown Linux distribution: $os_id"
            print_status "INFO" "Please install MinGW-w64 manually for Windows cross-compilation"
            return 1
            ;;
    esac

    # Verify MinGW installation
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        print_status "SUCCESS" "MinGW 64-bit compiler installed"
    else
        print_status "WARNING" "MinGW 64-bit compiler not found"
    fi

    if command -v i686-w64-mingw32-gcc &> /dev/null; then
        print_status "SUCCESS" "MinGW dependencies installed"
    else
        print_status "WARNING" "MinGW 32-bit compiler not found"
    fi
}

# Function to install ARM64 cross-compiler
install_arm64_cross_compiler() {
    local os_id=$1

    print_status "INFO" "Installing ARM64 cross-compiler..."

    case $os_id in
        "ubuntu"|"debian")
            print_status "INFO" "Installing ARM64 cross-compiler for Ubuntu/Debian..."
            sudo apt-get install -y \
                gcc-aarch64-linux-gnu \
                g++-aarch64-linux-gnu \
                libc6-dev-arm64-cross
            ;;
        "fedora")
            print_status "INFO" "Installing ARM64 cross-compiler for Fedora..."
            sudo dnf install -y \
                gcc-aarch64-linux-gnu \
                binutils-aarch64-linux-gnu
            ;;
        "centos"|"rhel")
            print_status "INFO" "Installing ARM64 cross-compiler for CentOS/RHEL..."
            sudo yum install -y \
                gcc-aarch64-linux-gnu \
                binutils-aarch64-linux-gnu
            ;;
        "arch"|"manjaro")
            print_status "INFO" "Installing ARM64 cross-compiler for Arch Linux..."
            sudo pacman -S --needed \
                aarch64-linux-gnu-gcc
            ;;
        *)
            print_status "WARNING" "Unknown Linux distribution: $os_id"
            print_status "INFO" "Please install ARM64 cross-compiler manually"
            return 1
            ;;
    esac

    # Verify ARM64 cross-compiler installation
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_status "SUCCESS" "ARM64 cross-compiler installed"
    else
        print_status "WARNING" "ARM64 cross-compiler not found after installation"
    fi
}

# Function to verify installation
verify_installation() {
    print_status "INFO" "Verifying installation..."

    local errors=0

    # Check Go
    if ! command -v go &> /dev/null; then
        print_status "ERROR" "Go not found"
        ((errors++))
    fi

    # Check GCC
    if ! command -v gcc &> /dev/null; then
        print_status "ERROR" "GCC not found"
        ((errors++))
    fi

    # Check pkg-config
    if ! command -v pkg-config &> /dev/null; then
        print_status "ERROR" "pkg-config not found"
        ((errors++))
    fi

    # Check Linux GUI libraries
    local gui_libs=("gl" "x11" "xrandr" "xcursor" "xinerama" "xi")
    for lib in "${gui_libs[@]}"; do
        if ! pkg-config --exists "$lib" 2>/dev/null; then
            print_status "WARNING" "Library $lib not found"
        fi
    done

    # Check MinGW
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        print_status "SUCCESS" "MinGW 64-bit found"
    else
        print_status "WARNING" "MinGW 64-bit not found (Windows builds will be skipped)"
    fi

    if command -v i686-w64-mingw32-gcc &> /dev/null; then
        print_status "SUCCESS" "MinGW 32-bit found"
    else
        print_status "WARNING" "MinGW 32-bit not found (Windows 32-bit builds will be skipped)"
    fi

    # Check ARM64 cross-compiler
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_status "SUCCESS" "ARM64 cross-compiler found"
    else
        print_status "WARNING" "ARM64 cross-compiler not found (ARM64 builds will use fallback)"
    fi

    if [ $errors -eq 0 ]; then
        print_status "SUCCESS" "All essential dependencies verified"
        return 0
    else
        print_status "ERROR" "$errors critical dependencies missing"
        return 1
    fi
}

# Function to test build
test_build() {
    print_status "INFO" "Testing build capability..."

    # Create a simple test program
    local test_dir="test-build-$$"
    mkdir -p "$test_dir"

    cat > "$test_dir/main.go" << 'EOF'
package main

import (
    "fmt"
    "os"
)

func main() {
    fmt.Printf("Build test successful for %s/%s\n", os.Getenv("GOOS"), os.Getenv("GOARCH"))
}
EOF

    cd "$test_dir"

    # Initialize go module
    go mod init test-build

    # Test current platform
    print_status "INFO" "Testing current platform build..."
    if CGO_ENABLED=1 go build -o test-current; then
        print_status "SUCCESS" "Current platform build works"
    else
        print_status "ERROR" "Current platform build failed"
        cd ..
        rm -rf "$test_dir"
        return 1
    fi

    # Test Linux builds
    print_status "INFO" "Testing Linux cross-compilation..."
    if GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -o test-linux-amd64; then
        print_status "SUCCESS" "Linux amd64 build works"
    else
        print_status "WARNING" "Linux amd64 build failed"
    fi

    # Test Windows builds (if MinGW available)
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        print_status "INFO" "Testing Windows cross-compilation..."
        if CC=x86_64-w64-mingw32-gcc GOOS=windows GOARCH=amd64 CGO_ENABLED=1 go build -o test-windows-amd64.exe; then
            print_status "SUCCESS" "Windows amd64 build works"
        else
            print_status "WARNING" "Windows amd64 build failed"
        fi
    fi

    # Test ARM64 builds (if cross-compiler available)
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_status "INFO" "Testing ARM64 cross-compilation..."
        if CC=aarch64-linux-gnu-gcc GOOS=linux GOARCH=arm64 CGO_ENABLED=1 go build -o test-linux-arm64; then
            print_status "SUCCESS" "ARM64 build works"
        else
            print_status "WARNING" "ARM64 build failed, fallback to no-CGO will be used"
        fi
    fi

    # Test macOS builds (if on macOS)
    if [ "$(uname)" = "Darwin" ]; then
        print_status "INFO" "Testing macOS cross-compilation..."
        if GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -o test-darwin-amd64; then
            print_status "SUCCESS" "macOS amd64 build works"
        else
            print_status "WARNING" "macOS amd64 build failed"
        fi
    fi

    cd ..
    rm -rf "$test_dir"

    print_status "SUCCESS" "Build tests completed"
}

# Function to show summary
show_summary() {
    print_status "INFO" "Setup Summary"
    echo "=============="
    echo ""
    echo "✅ What's installed:"
    echo "  • Go compiler with CGO support"
    echo "  • GCC and build tools"
    echo "  • Linux GUI development libraries"
    echo "  • MinGW cross-compiler (if available)"
    echo "  • ARM64 cross-compiler (if available)"
    echo "  • pkg-config and development tools"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Run './package.sh' to create packages for all platforms"
    echo "  2. Run './package.sh --build-only' to just build executables"
    echo "  3. Run './build-native-gui.sh' to build with the original script"
    echo ""
    echo "📋 Supported Platforms:"
    echo "  • Linux (x86_64, ARM64)"
    echo "  • Windows (x86_64, i386) - if MinGW installed"
    echo "  • macOS (x86_64, ARM64) - if running on macOS"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  • If Windows builds fail, check MinGW installation"
    echo "  • If GUI builds fail, verify X11 libraries are installed"
    echo "  • For macOS builds, run this script on macOS"
}

# Function to show usage
show_usage() {
    echo "SFTP Sync Native GUI - Cross-Compilation Setup Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --no-gui-deps       Skip Linux GUI dependencies"
    echo "  --no-mingw          Skip MinGW installation"
    echo "  --no-arm64          Skip ARM64 cross-compiler installation"
    echo "  --test-only         Only run build tests"
    echo "  --verify-only       Only verify existing installation"
    echo ""
    echo "This script installs dependencies required for cross-platform builds:"
    echo "  • Linux GUI development libraries"
    echo "  • MinGW cross-compiler for Windows builds"
    echo "  • ARM64 cross-compiler for Linux ARM64 builds"
    echo "  • Build tools and verification"
}

# Main function
main() {
    local install_gui_deps=true
    local install_mingw=true
    local install_arm64=true
    local test_only=false
    local verify_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --no-gui-deps)
                install_gui_deps=false
                shift
                ;;
            --no-mingw)
                install_mingw=false
                shift
                ;;
            --no-arm64)
                install_arm64=false
                shift
                ;;
            --test-only)
                test_only=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_status "INFO" "SFTP Sync Native GUI - Cross-Compilation Setup"
    echo "================================================="
    echo ""

    check_root

    # Check Go first
    if ! check_go; then
        exit 1
    fi

    # If verify-only, just verify and exit
    if [ "$verify_only" = true ]; then
        verify_installation
        exit $?
    fi

    # If test-only, just test and exit
    if [ "$test_only" = true ]; then
        test_build
        exit $?
    fi

    # Detect OS
    local os_id=$(detect_os)
    print_status "INFO" "Detected OS: $os_id"

    # Check if we're on a supported platform
    case $os_id in
        "ubuntu"|"debian"|"fedora"|"centos"|"rhel"|"arch"|"manjaro")
            print_status "SUCCESS" "Supported platform detected"
            ;;
        *)
            print_status "WARNING" "Unsupported or unknown platform"
            print_status "INFO" "You may need to install dependencies manually"
            ;;
    esac

    # Install Linux GUI dependencies
    if [ "$install_gui_deps" = true ]; then
        install_linux_gui_deps "$os_id"
    fi

    # Install MinGW for Windows cross-compilation
    if [ "$install_mingw" = true ]; then
        install_mingw "$os_id"
    fi

    # Install ARM64 cross-compiler
    if [ "$install_arm64" = true ]; then
        install_arm64_cross_compiler "$os_id"
    fi

    # Verify installation
    if verify_installation; then
        print_status "SUCCESS" "Installation completed successfully"
    else
        print_status "ERROR" "Installation completed with errors"
        exit 1
    fi

    # Test build capability
    test_build

    # Show summary
    show_summary
}

# Run main function with all arguments
main "$@"
