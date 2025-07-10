#!/bin/bash

# SFTP Sync GUI - Deployment Package Script
# Creates distribution packages for different platforms

echo "Creating deployment packages for SFTP Sync GUI..."

# Check if build directory exists
if [ ! -d "build" ]; then
    echo "Build directory not found. Running build script first..."
    ./build-all.sh
fi

# Create packages directory
mkdir -p packages

# Package version (you can modify this)
VERSION="1.0.0"

# Function to create package
create_package() {
    local platform=$1
    local executable=$2
    local package_name="sftp-sync-gui-${platform}-${VERSION}"
    local temp_dir="packages/temp-${platform}"

    echo "Creating package for ${platform}..."

    # Create temporary directory
    mkdir -p "${temp_dir}"

    # Copy executable
    cp "build/${executable}" "${temp_dir}/"

    # Copy configuration files
    cp config.json "${temp_dir}/" 2>/dev/null || echo "config.json not found, skipping..."

    # Copy documentation
    cp GUI-README.md "${temp_dir}/README.md"
    cp CONFIG.md "${temp_dir}/" 2>/dev/null || true

    # Create platform-specific launcher
    if [[ "$platform" == "windows"* ]]; then
        # Windows batch file
        cat > "${temp_dir}/run-gui.bat" << 'EOF'
@echo off
echo Starting SFTP Sync GUI...
echo Web interface will be available at: http://localhost:8080
echo Press Ctrl+C to stop
echo.
start http://localhost:8080
sftp-sync-gui-windows-amd64.exe --gui
EOF

        # Create sample config for Windows
        cat > "${temp_dir}/config-sample.json" << 'EOF'
{
  "source": {
    "host": "source-server.com",
    "port": 22,
    "username": "your-username",
    "password": "your-password",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest-server.com",
    "port": 22,
    "username": "your-username",
    "password": "your-password",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "/path/to/source",
    "destination_path": "/path/to/dest",
    "exclude_patterns": [".tmp", ".lock", ".part", ".DS_Store"],
    "max_concurrent_transfers": 10,
    "chunk_size": 65536,
    "retry_attempts": 3,
    "retry_delay": 5,
    "verify_transfers": true,
    "days_to_sync": 2
  }
}
EOF

        # Create zip package
        cd packages
        zip -r "${package_name}.zip" "temp-${platform}"
        cd ..

    else
        # Unix shell script
        cat > "${temp_dir}/run-gui.sh" << 'EOF'
#!/bin/bash
echo "Starting SFTP Sync GUI..."
echo "Web interface will be available at: http://localhost:8080"
echo "Press Ctrl+C to stop"
echo ""

# Make executable if needed
chmod +x sftp-sync-gui-*

# Find the executable
if [ -f "sftp-sync-gui-linux-amd64" ]; then
    EXECUTABLE="sftp-sync-gui-linux-amd64"
elif [ -f "sftp-sync-gui-linux-arm64" ]; then
    EXECUTABLE="sftp-sync-gui-linux-arm64"
elif [ -f "sftp-sync-gui-darwin-amd64" ]; then
    EXECUTABLE="sftp-sync-gui-darwin-amd64"
elif [ -f "sftp-sync-gui-darwin-arm64" ]; then
    EXECUTABLE="sftp-sync-gui-darwin-arm64"
else
    echo "Error: No executable found!"
    exit 1
fi

echo "Using executable: $EXECUTABLE"
./$EXECUTABLE --gui
EOF

        chmod +x "${temp_dir}/run-gui.sh"

        # Create sample config for Unix
        cat > "${temp_dir}/config-sample.json" << 'EOF'
{
  "source": {
    "host": "source-server.com",
    "port": 22,
    "username": "your-username",
    "password": "your-password",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest-server.com",
    "port": 22,
    "username": "your-username",
    "password": "your-password",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "/path/to/source",
    "destination_path": "/path/to/dest",
    "exclude_patterns": [".tmp", ".lock", ".part", ".DS_Store"],
    "max_concurrent_transfers": 10,
    "chunk_size": 65536,
    "retry_attempts": 3,
    "retry_delay": 5,
    "verify_transfers": true,
    "days_to_sync": 2
  }
}
EOF

        # Create tar.gz package
        cd packages
        tar -czf "${package_name}.tar.gz" "temp-${platform}"
        cd ..
    fi

    # Clean up temporary directory
    rm -rf "${temp_dir}"

    echo "✓ Package created: packages/${package_name}.*"
}

# Create installation instructions
cat > packages/INSTALL.txt << 'EOF'
SFTP Sync GUI - Installation Instructions
==========================================

1. Extract the package to your desired location
2. Copy config-sample.json to config.json
3. Edit config.json with your SFTP server details
4. Run the appropriate launcher:
   - Windows: Double-click run-gui.bat
   - Linux/macOS: Run ./run-gui.sh

The web interface will be available at http://localhost:8080

For detailed documentation, see README.md
EOF

# Create packages for each platform
create_package "windows-amd64" "sftp-sync-gui-windows-amd64.exe"
create_package "linux-amd64" "sftp-sync-gui-linux-amd64"
create_package "linux-arm64" "sftp-sync-gui-linux-arm64"
create_package "darwin-amd64" "sftp-sync-gui-darwin-amd64"
create_package "darwin-arm64" "sftp-sync-gui-darwin-arm64"

echo ""
echo "All packages created successfully!"
echo "Available packages:"
ls -la packages/*.zip packages/*.tar.gz 2>/dev/null
echo ""
echo "Package sizes:"
du -sh packages/*.zip packages/*.tar.gz 2>/dev/null
echo ""
echo "Deployment packages are ready in the 'packages' directory"
echo "Each package contains:"
echo "  - Executable file"
echo "  - Platform-specific launcher script"
echo "  - Sample configuration file"
echo "  - Documentation"
echo "  - Installation instructions"
