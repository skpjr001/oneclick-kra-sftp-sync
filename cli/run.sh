#!/bin/bash

# SFTP Sync Script
# This script sets up and runs the SFTP synchronization tool

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="sftp-sync"
BINARY_NAME="sftp-sync"
CONFIG_FILE="config.json"
LOG_FILE="sync.log"

# Default configuration
DEFAULT_SOURCE_HOST="${SOURCE_HOST:-source.example.com}"
DEFAULT_SOURCE_USER="${SOURCE_USER:-sourceuser}"
DEFAULT_SOURCE_PASS="${SOURCE_PASS:-sourcepass}"
DEFAULT_DEST_HOST="${DEST_HOST:-dest.example.com}"
DEFAULT_DEST_USER="${DEST_USER:-destuser}"
DEFAULT_DEST_PASS="${DEST_PASS:-destpass}"
DEFAULT_SOURCE_PATH="${SOURCE_PATH:-/source/root}"
DEFAULT_DEST_PATH="${DEST_PATH:-/dest/root}"
DEFAULT_DAYS_TO_SYNC="${DAYS_TO_SYNC:-1}"
DEFAULT_MAX_CONCURRENT="${MAX_CONCURRENT:-10}"
DEFAULT_VERIFY_TRANSFERS="${VERIFY_TRANSFERS:-true}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check Go installation
    if ! command_exists go; then
        print_error "Go is not installed. Please install Go 1.18 or later."
        print_status "Visit: https://golang.org/dl/"
        exit 1
    fi

    # Check Go version
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    print_success "Go version: $GO_VERSION"

    # Check Git
    if ! command_exists git; then
        print_warning "Git is not installed. Some features may not work properly."
    fi

    print_success "Prerequisites check completed"
}

# Function to setup project
setup_project() {
    print_status "Setting up project in $SCRIPT_DIR..."

    cd "$SCRIPT_DIR"

    # Initialize Go module if not exists
    if [ ! -f "go.mod" ]; then
        print_status "Initializing Go module..."
        go mod init "$PROJECT_NAME"
    fi

    # Install dependencies
    print_status "Installing dependencies..."
    go get github.com/pkg/sftp
    go get golang.org/x/crypto/ssh

    # Tidy up dependencies
    go mod tidy

    print_success "Project setup completed"
}

# Function to create configuration file
create_config() {
    print_status "Creating configuration file..."

    if [ -f "$CONFIG_FILE" ]; then
        print_warning "Configuration file already exists. Skipping creation."
        return
    fi

    cat > "$CONFIG_FILE" << EOF
{
  "source": {
    "host": "$DEFAULT_SOURCE_HOST",
    "port": 22,
    "username": "$DEFAULT_SOURCE_USER",
    "password": "$DEFAULT_SOURCE_PASS",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "$DEFAULT_DEST_HOST",
    "port": 22,
    "username": "$DEFAULT_DEST_USER",
    "password": "$DEFAULT_DEST_PASS",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "$DEFAULT_SOURCE_PATH",
    "destination_path": "$DEFAULT_DEST_PATH",
    "exclude_patterns": [".tmp", ".lock", ".part", ".DS_Store"],
    "max_concurrent_transfers": $DEFAULT_MAX_CONCURRENT,
    "chunk_size": 65536,
    "retry_attempts": 3,
    "retry_delay": 5,
    "verify_transfers": $DEFAULT_VERIFY_TRANSFERS,
    "days_to_sync": $DEFAULT_DAYS_TO_SYNC
  }
}
EOF

    chmod 600 "$CONFIG_FILE"
    print_success "Configuration file created: $CONFIG_FILE"
    print_warning "Please edit $CONFIG_FILE with your actual SFTP server details"
}

# Function to build the application
build_app() {
    print_status "Building application..."

    if [ ! -f "main.go" ]; then
        print_error "main.go not found. Please ensure the Go source code is in the current directory."
        exit 1
    fi

    go build -o "$BINARY_NAME" main.go
    chmod +x "$BINARY_NAME"

    print_success "Application built successfully: $BINARY_NAME"
}

# Function to run the sync
run_sync() {
    print_status "Starting SFTP synchronization..."

    if [ ! -f "$BINARY_NAME" ]; then
        print_error "Binary not found. Please build the application first."
        exit 1
    fi

    # Set up log file
    LOG_FILE_PATH="$SCRIPT_DIR/$LOG_FILE"

    # Export environment variables if set
    export SOURCE_HOST="$DEFAULT_SOURCE_HOST"
    export SOURCE_USER="$DEFAULT_SOURCE_USER"
    export SOURCE_PASS="$DEFAULT_SOURCE_PASS"
    export DEST_HOST="$DEFAULT_DEST_HOST"
    export DEST_USER="$DEFAULT_DEST_USER"
    export DEST_PASS="$DEFAULT_DEST_PASS"
    export SOURCE_PATH="$DEFAULT_SOURCE_PATH"
    export DEST_PATH="$DEFAULT_DEST_PATH"
    export DAYS_TO_SYNC="$DEFAULT_DAYS_TO_SYNC"
    export MAX_CONCURRENT="$DEFAULT_MAX_CONCURRENT"
    export VERIFY_TRANSFERS="$DEFAULT_VERIFY_TRANSFERS"

    # Run the sync with logging
    print_status "Logs will be written to: $LOG_FILE_PATH"

    if [ "$1" = "--no-log" ]; then
        "./$BINARY_NAME"
    else
        "./$BINARY_NAME" 2>&1 | tee "$LOG_FILE_PATH"
    fi

    SYNC_EXIT_CODE=$?

    if [ $SYNC_EXIT_CODE -eq 0 ]; then
        print_success "SFTP synchronization completed successfully!"
    else
        print_error "SFTP synchronization failed with exit code: $SYNC_EXIT_CODE"
        print_status "Check the log file for details: $LOG_FILE_PATH"
        exit $SYNC_EXIT_CODE
    fi
}

# Function to show status
show_status() {
    print_status "SFTP Sync Status:"
    echo "  Project Directory: $SCRIPT_DIR"
    echo "  Binary: $([[ -f "$BINARY_NAME" ]] && echo "✓ Built" || echo "✗ Not built")"
    echo "  Config: $([[ -f "$CONFIG_FILE" ]] && echo "✓ Present" || echo "✗ Missing")"
    echo "  Log File: $([[ -f "$LOG_FILE" ]] && echo "✓ Present" || echo "✗ Not found")"

    if [ -f "$LOG_FILE" ]; then
        echo "  Last Log Entry: $(tail -1 "$LOG_FILE" 2>/dev/null || echo "Unable to read")"
    fi
}

# Function to clean up
clean_up() {
    print_status "Cleaning up..."

    [ -f "$BINARY_NAME" ] && rm -f "$BINARY_NAME" && print_success "Binary removed"
    [ -f "$LOG_FILE" ] && rm -f "$LOG_FILE" && print_success "Log file removed"
    [ -f "go.mod" ] && rm -f "go.mod" && print_success "Go module removed"
    [ -f "go.sum" ] && rm -f "go.sum" && print_success "Go sum removed"

    print_success "Cleanup completed"
}

# Function to show help
show_help() {
    cat << EOF
SFTP Sync Script - Help

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  setup           Setup project and dependencies
  build           Build the application
  run             Run the SFTP synchronization
  status          Show project status
  clean           Clean up generated files
  help            Show this help message

Options:
  --no-log        Run without logging to file (only with 'run' command)

Environment Variables:
  SOURCE_HOST     Source SFTP server hostname
  SOURCE_USER     Source SFTP username
  SOURCE_PASS     Source SFTP password
  DEST_HOST       Destination SFTP server hostname
  DEST_USER       Destination SFTP username
  DEST_PASS       Destination SFTP password
  SOURCE_PATH     Source path on SFTP server
  DEST_PATH       Destination path on SFTP server
  DAYS_TO_SYNC    Number of days to sync (default: 5)
  MAX_CONCURRENT  Maximum concurrent transfers (default: 10)
  VERIFY_TRANSFERS Enable transfer verification (default: true)

Examples:
  $0 setup        # Setup project for first time
  $0 build        # Build the application
  $0 run          # Run synchronization with logging
  $0 run --no-log # Run without logging to file
  $0 status       # Show project status
  $0 clean        # Clean up all generated files

Files:
  main.go         Go source code (must be present)
  config.json     Configuration file (auto-generated)
  sync.log        Log file (generated during sync)
  sftp-sync       Compiled binary
EOF
}

# Main script logic
main() {
    cd "$SCRIPT_DIR"

    case "${1:-}" in
        setup)
            check_prerequisites
            setup_project
            create_config
            build_app
            print_success "Setup completed! Edit $CONFIG_FILE and run '$0 run' to start syncing."
            ;;
        build)
            check_prerequisites
            setup_project
            build_app
            ;;
        run)
            check_prerequisites
            run_sync "$2"
            ;;
        status)
            show_status
            ;;
        clean)
            clean_up
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            print_status "SFTP Sync Script"
            print_status "Run '$0 help' for usage information"
            print_status "Run '$0 setup' to get started"
            ;;
        *)
            print_error "Unknown command: $1"
            print_status "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
