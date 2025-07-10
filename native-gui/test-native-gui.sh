#!/bin/bash

# SFTP Sync Native GUI - Test Script
# Tests the native GUI functionality and build process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ((TESTS_FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
    ((TESTS_TOTAL++))
}

# Function to test a command
test_command() {
    local description=$1
    local command=$2
    local expected_exit_code=${3:-0}

    print_status "INFO" "Testing: $description"

    if eval "$command" &>/dev/null; then
        if [ $? -eq $expected_exit_code ]; then
            print_status "PASS" "$description"
            return 0
        else
            print_status "FAIL" "$description - Wrong exit code"
            return 1
        fi
    else
        print_status "FAIL" "$description - Command failed"
        return 1
    fi
}

# Function to test file existence
test_file_exists() {
    local description=$1
    local file_path=$2

    if [ -f "$file_path" ]; then
        print_status "PASS" "$description"
        return 0
    else
        print_status "FAIL" "$description - File not found: $file_path"
        return 1
    fi
}

# Function to test directory existence
test_dir_exists() {
    local description=$1
    local dir_path=$2

    if [ -d "$dir_path" ]; then
        print_status "PASS" "$description"
        return 0
    else
        print_status "FAIL" "$description - Directory not found: $dir_path"
        return 1
    fi
}

# Function to check system dependencies
check_system_deps() {
    print_status "INFO" "Checking system dependencies..."

    # Check Go installation
    if command -v go &> /dev/null; then
        local go_version=$(go version)
        print_status "PASS" "Go installation found: $go_version"
    else
        print_status "FAIL" "Go not found in PATH"
        return 1
    fi

    # Check CGO
    if [ "$(go env CGO_ENABLED)" = "1" ]; then
        print_status "PASS" "CGO is enabled"
    else
        print_status "WARN" "CGO is disabled - may affect native GUI builds"
    fi

    # Check for required source files
    test_file_exists "Main source file exists" "main.go"
    test_file_exists "Native GUI source file exists" "native_gui.go"
    test_file_exists "Go module file exists" "go.mod"

    # Check for build scripts
    test_file_exists "Native GUI build script exists" "build-native-gui.sh"
    test_file_exists "Native GUI launcher script exists" "run-native-gui.sh"

    # Check if we're on a supported platform
    local os=$(go env GOOS)
    case $os in
        "linux"|"darwin"|"windows")
            print_status "PASS" "Supported platform detected: $os"
            ;;
        *)
            print_status "WARN" "Unknown platform: $os"
            ;;
    esac
}

# Function to test Linux dependencies
check_linux_deps() {
    print_status "INFO" "Checking Linux GUI dependencies..."

    # Check for required libraries using pkg-config
    local required_libs=("gl" "x11" "xrandr" "xcursor" "xinerama" "xi")
    local missing_libs=()

    for lib in "${required_libs[@]}"; do
        if pkg-config --exists "$lib" 2>/dev/null; then
            print_status "PASS" "Library $lib found"
        else
            print_status "FAIL" "Library $lib not found"
            missing_libs+=("$lib")
        fi
    done

    if [ ${#missing_libs[@]} -gt 0 ]; then
        print_status "WARN" "Missing libraries: ${missing_libs[*]}"
        print_status "INFO" "Install with: sudo apt-get install libgl1-mesa-dev libxrandr-dev libxcursor-dev libxinerama-dev libxi-dev libxext-dev libxfixes-dev libxxf86vm-dev pkg-config"
        return 1
    else
        print_status "PASS" "All required Linux GUI libraries found"
        return 0
    fi
}

# Function to test Go module dependencies
test_go_dependencies() {
    print_status "INFO" "Testing Go dependencies..."

    # Check if go.mod has fyne dependency
    if grep -q "fyne.io/fyne/v2" go.mod; then
        print_status "PASS" "Fyne dependency found in go.mod"
    else
        print_status "FAIL" "Fyne dependency not found in go.mod"
    fi

    # Test go mod tidy
    test_command "Go mod tidy works" "go mod tidy"

    # Test go mod download
    test_command "Go mod download works" "go mod download"
}

# Function to test native GUI build
test_native_build() {
    print_status "INFO" "Testing native GUI build..."

    # Clean any existing builds
    rm -f sftp-sync-native sftp-sync-native.exe
    rm -rf build-native

    # Test build for current platform
    if go build -o sftp-sync-native-test 2>/dev/null; then
        print_status "PASS" "Native GUI builds successfully"

        # Check if executable is created
        test_file_exists "Native GUI executable created" "sftp-sync-native-test"

        # Check executable permissions (Unix-like systems)
        if [ "$(go env GOOS)" != "windows" ]; then
            if [ -x "sftp-sync-native-test" ]; then
                print_status "PASS" "Executable has proper permissions"
            else
                print_status "FAIL" "Executable lacks execute permissions"
            fi
        fi

        # Check executable size (should be reasonable)
        if [ -f "sftp-sync-native-test" ]; then
            local size=$(stat -f%z "sftp-sync-native-test" 2>/dev/null || stat -c%s "sftp-sync-native-test" 2>/dev/null || echo "0")
            if [ "$size" -gt 1000000 ]; then  # > 1MB
                print_status "PASS" "Executable size is reasonable: $(numfmt --to=iec $size)"
            else
                print_status "WARN" "Executable size seems small: $(numfmt --to=iec $size)"
            fi
        fi

        # Clean up test executable
        rm -f sftp-sync-native-test

    else
        print_status "FAIL" "Native GUI build failed"
        return 1
    fi
}

# Function to test build script
test_build_script() {
    print_status "INFO" "Testing build script functionality..."

    # Test build script help
    test_command "Build script help works" "./build-native-gui.sh --help"

    # Test current platform build
    if ./build-native-gui.sh --current &>/dev/null; then
        print_status "PASS" "Build script current platform build works"

        # Check if build directory is created
        test_dir_exists "Build directory created" "build-native"

        # Check if executable is created in build directory
        local os=$(go env GOOS)
        local arch=$(go env GOARCH)
        local exe_name="sftp-sync-native-current"
        if [ "$os" = "windows" ]; then
            exe_name="${exe_name}.exe"
        fi

        test_file_exists "Executable created in build directory" "build-native/$exe_name"

    else
        print_status "FAIL" "Build script current platform build failed"
    fi
}

# Function to test launcher scripts
test_launcher_scripts() {
    print_status "INFO" "Testing launcher scripts..."

    # Check script permissions
    if [ -x "run-native-gui.sh" ]; then
        print_status "PASS" "Native GUI launcher script is executable"
    else
        print_status "FAIL" "Native GUI launcher script lacks execute permissions"
    fi

    # Test script syntax (basic check)
    if bash -n run-native-gui.sh 2>/dev/null; then
        print_status "PASS" "Launcher script syntax is valid"
    else
        print_status "FAIL" "Launcher script has syntax errors"
    fi
}

# Function to test configuration handling
test_config_handling() {
    print_status "INFO" "Testing configuration handling..."

    # Create a test config file
    local test_config="test-config.json"
    cat > "$test_config" << 'EOF'
{
  "source": {
    "host": "test-source.example.com",
    "port": 22,
    "username": "testuser",
    "password": "testpass",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "test-dest.example.com",
    "port": 22,
    "username": "testuser",
    "password": "testpass",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "/test/source",
    "destination_path": "/test/dest",
    "exclude_patterns": [".tmp", ".lock"],
    "max_concurrent_transfers": 5,
    "chunk_size": 32768,
    "retry_attempts": 2,
    "retry_delay": 3,
    "verify_transfers": true,
    "days_to_sync": 1
  }
}
EOF

    if [ -f "$test_config" ]; then
        print_status "PASS" "Test configuration file created successfully"

        # Validate JSON syntax
        if python3 -m json.tool "$test_config" &>/dev/null || jq . "$test_config" &>/dev/null; then
            print_status "PASS" "Test configuration has valid JSON syntax"
        else
            print_status "FAIL" "Test configuration has invalid JSON syntax"
        fi

        # Clean up
        rm -f "$test_config"
    else
        print_status "FAIL" "Failed to create test configuration file"
    fi
}

# Function to test executable functionality (basic)
test_executable_basic() {
    print_status "INFO" "Testing executable basic functionality..."

    # Build a test executable
    if go build -o sftp-sync-native-test 2>/dev/null; then

        # Test help output (should exit cleanly)
        if ./sftp-sync-native-test --help &>/dev/null; then
            print_status "PASS" "Executable accepts --help flag"
        else
            print_status "WARN" "Executable doesn't support --help flag"
        fi

        # Test version output (if available)
        if ./sftp-sync-native-test --version &>/dev/null; then
            print_status "PASS" "Executable accepts --version flag"
        else
            print_status "WARN" "Executable doesn't support --version flag"
        fi

        # Test invalid flag handling
        if ! ./sftp-sync-native-test --invalid-flag &>/dev/null; then
            print_status "PASS" "Executable properly handles invalid flags"
        else
            print_status "WARN" "Executable doesn't properly reject invalid flags"
        fi

        # Clean up
        rm -f sftp-sync-native-test
    else
        print_status "FAIL" "Cannot build test executable for functionality testing"
    fi
}

# Function to run comprehensive tests
run_comprehensive_tests() {
    print_status "INFO" "Starting comprehensive native GUI tests..."
    echo ""

    # System and dependency checks
    echo "=== System Dependencies ==="
    check_system_deps

    # Platform-specific checks
    if [ "$(go env GOOS)" = "linux" ]; then
        echo ""
        echo "=== Linux Dependencies ==="
        check_linux_deps
    fi

    # Go dependencies
    echo ""
    echo "=== Go Dependencies ==="
    test_go_dependencies

    # Build tests
    echo ""
    echo "=== Build Tests ==="
    test_native_build

    # Build script tests
    echo ""
    echo "=== Build Script Tests ==="
    test_build_script

    # Launcher script tests
    echo ""
    echo "=== Launcher Script Tests ==="
    test_launcher_scripts

    # Configuration tests
    echo ""
    echo "=== Configuration Tests ==="
    test_config_handling

    # Basic executable tests
    echo ""
    echo "=== Executable Tests ==="
    test_executable_basic
}

# Function to show test summary
show_test_summary() {
    echo ""
    echo "=== Test Summary ==="
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"

    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi

    echo "Success rate: ${success_rate}%"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        print_status "PASS" "All tests passed! Native GUI is ready for use."
        return 0
    else
        print_status "FAIL" "$TESTS_FAILED test(s) failed. Please review the output above."
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "SFTP Sync Native GUI Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --deps              Test dependencies only"
    echo "  --build             Test build process only"
    echo "  --quick             Run quick tests only"
    echo "  --comprehensive     Run all tests (default)"
    echo ""
    echo "Examples:"
    echo "  $0                  Run all tests"
    echo "  $0 --quick          Run quick tests"
    echo "  $0 --deps           Test dependencies only"
    echo "  $0 --build          Test build process only"
}

# Main execution
main() {
    echo "SFTP Sync Native GUI Test Suite"
    echo "==============================="
    echo ""

    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        --deps)
            check_system_deps
            if [ "$(go env GOOS)" = "linux" ]; then
                check_linux_deps
            fi
            test_go_dependencies
            ;;
        --build)
            test_native_build
            test_build_script
            ;;
        --quick)
            check_system_deps
            test_go_dependencies
            test_native_build
            ;;
        --comprehensive|"")
            run_comprehensive_tests
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac

    show_test_summary
}

# Run main function with all arguments
main "$@"
