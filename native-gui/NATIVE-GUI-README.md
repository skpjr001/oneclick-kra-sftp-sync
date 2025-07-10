# SFTP Sync Tool - Native GUI Version

A cross-platform native GUI application for SFTP file synchronization built with the Fyne framework. This provides a modern, responsive desktop interface with real-time logging, progress indicators, and intuitive controls.

## Features

### 🖥️ Native Desktop Experience
- **True Native GUI**: Built with Fyne framework for genuine desktop feel
- **Cross-Platform**: Works on Linux, Windows, and macOS
- **Modern UI**: Clean, responsive interface with material design elements
- **Theme Support**: Automatically adapts to system light/dark themes
- **Resizable Windows**: Flexible layout that adapts to window size

### 🚀 Advanced Functionality
- **Real-time Logging**: Live log display with timestamps and auto-scroll
- **Progress Indicators**: Visual feedback with infinite progress bars
- **Start/Stop Controls**: Immediate response to user actions
- **Configuration Editor**: Built-in JSON config editor with validation
- **Status Updates**: Color-coded status indicators
- **Context Cancellation**: Immediate sync termination when requested

### 🔧 Technical Improvements
- **Log Redirection Fix**: No log leakage to terminal after operations
- **Memory Management**: Automatic log rotation (500 entries max)
- **Error Handling**: Intelligent filtering of cancellation-related errors
- **Resource Cleanup**: Proper cleanup of all background processes
- **Thread Safety**: Safe UI updates from background operations

## Installation

### System Requirements

#### Linux
- X11 or Wayland desktop environment
- OpenGL support
- Required system libraries (auto-installable)

#### Windows
- Windows 7 or later
- No additional dependencies required

#### macOS
- macOS 10.12 or later
- Native Cocoa support

### Quick Install

#### Option 1: Use Pre-built Binaries
```bash
# Download from releases or build locally
./build-native-gui.sh --current
```

#### Option 2: Build from Source
```bash
# Install dependencies (Linux only)
./build-native-gui.sh --deps

# Build for current platform
./build-native-gui.sh --current

# Or build for all platforms
./build-native-gui.sh
```

### Linux Dependencies
The build script can automatically install required libraries:

**Ubuntu/Debian:**
```bash
sudo apt-get install libgl1-mesa-dev libxrandr-dev libxcursor-dev \
                     libxinerama-dev libxi-dev libxext-dev libxfixes-dev \
                     libxxf86vm-dev pkg-config gcc
```

**CentOS/RHEL:**
```bash
sudo yum install mesa-libGL-devel libXrandr-devel libXcursor-devel \
                 libXinerama-devel libXi-devel libXext-devel \
                 libXfixes-devel libXxf86vm-devel pkgconfig gcc
```

**Fedora:**
```bash
sudo dnf install mesa-libGL-devel libXrandr-devel libXcursor-devel \
                 libXinerama-devel libXi-devel libXext-devel \
                 libXfixes-devel libXxf86vm-devel pkgconfig gcc
```

## Usage

### Starting the Application

#### Linux/macOS
```bash
# Using the launcher script
./run-native-gui.sh

# Or directly
./sftp-sync-native --native
```

#### Windows
```batch
# Using the launcher script
run-native-gui.bat

# Or directly
sftp-sync-native.exe --native
```

### Interface Overview

#### Main Window Components

1. **Title Card**
   - Application name and description
   - Version information

2. **Status Section**
   - Current operation status with color coding
   - Infinite progress bar during operations
   - Status indicators: Ready, Running, Completed, Failed, Cancelled

3. **Control Buttons**
   - **Start Sync**: Begin synchronization (green, play icon)
   - **Stop**: Cancel running operation (red, stop icon)
   - **Config**: Open configuration editor (settings icon)
   - **Exit**: Close application (logout icon)

4. **Log Display**
   - Real-time log output with timestamps
   - Auto-scroll to latest entries
   - Automatic log rotation (500 entries max)
   - Read-only text area with scroll support

### Configuration Management

#### Built-in Config Editor
1. Click **Config** button
2. Edit JSON configuration in the popup dialog
3. Click **Save** to apply changes
4. Configuration is validated before saving

#### Configuration Structure
```json
{
  "source": {
    "host": "source-server.com",
    "port": 22,
    "username": "user",
    "password": "pass",
    "keyfile": "/path/to/key",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest-server.com",
    "port": 22,
    "username": "user",
    "password": "pass",
    "keyfile": "/path/to/key",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "/path/to/source",
    "destination_path": "/path/to/dest",
    "exclude_patterns": [".tmp", ".lock", ".part"],
    "max_concurrent_transfers": 10,
    "chunk_size": 65536,
    "retry_attempts": 3,
    "retry_delay": 5,
    "verify_transfers": true,
    "days_to_sync": 2
  }
}
```

## Building from Source

### Build Scripts

#### Cross-Platform Build
```bash
# Build for all supported platforms
./build-native-gui.sh

# Available options:
./build-native-gui.sh --help      # Show help
./build-native-gui.sh --current   # Current platform only
./build-native-gui.sh --clean     # Clean and rebuild
./build-native-gui.sh --deps      # Install dependencies only
```

#### Manual Build
```bash
# Ensure dependencies are installed
go mod tidy

# Build for current platform
go build -o sftp-sync-native

# Cross-compile (CGO_ENABLED=1 required)
GOOS=windows GOARCH=amd64 go build -o sftp-sync-native.exe
```

### Build Outputs
The build process creates executables in `build-native/`:
- `sftp-sync-native-linux-amd64`
- `sftp-sync-native-linux-arm64`
- `sftp-sync-native-windows-amd64.exe`
- `sftp-sync-native-windows-386.exe`
- `sftp-sync-native-darwin-amd64`
- `sftp-sync-native-darwin-arm64`

## Architecture

### GUI Framework
- **Fyne v2.6+**: Modern Go GUI toolkit
- **OpenGL Rendering**: Hardware-accelerated graphics
- **Native Look & Feel**: Platform-appropriate widgets
- **Responsive Layout**: Adaptive to window resizing

### Sync Integration
- **Context-Aware Operations**: Proper cancellation support
- **Background Processing**: Non-blocking UI during sync
- **Real-time Updates**: Live status and log updates
- **Memory Efficient**: Bounded log storage and cleanup

### Error Handling
- **Graceful Degradation**: Continues operation despite minor errors
- **User Feedback**: Clear error messages and recovery suggestions
- **Log Filtering**: Suppresses expected errors after cancellation
- **Resource Cleanup**: Ensures no leaked processes or connections

## Troubleshooting

### Common Issues

#### Build Problems

**Linux: Missing System Libraries**
```bash
# Install dependencies
./build-native-gui.sh --deps

# Or manually install packages listed above
```

**Windows: CGO Build Errors**
```bash
# Ensure CGO is enabled
set CGO_ENABLED=1

# Install TDM-GCC or MinGW-w64 for Windows builds
```

**macOS: Cross-compilation Issues**
- Build directly on macOS for best results
- CGO cross-compilation to macOS requires macOS SDK

#### Runtime Problems

**Linux: Display Not Available**
```bash
# Check X11/Wayland
echo $DISPLAY
echo $WAYLAND_DISPLAY

# For SSH: enable X11 forwarding
ssh -X username@hostname
```

**Application Won't Start**
- Verify executable permissions: `chmod +x sftp-sync-native`
- Check system compatibility with `ldd sftp-sync-native`
- Ensure config.json exists or use built-in editor

**Performance Issues**
- Large log files: Logs auto-rotate at 500 entries
- Memory usage: Restart application periodically for long operations
- Slow sync: Check network connectivity and concurrent transfer settings

#### Configuration Problems

**Config File Not Found**
- Use the built-in config editor (Config button)
- Copy from config-sample.json if available
- Ensure proper JSON syntax

**Connection Failures**
- Verify host connectivity: `ping hostname`
- Check firewall settings and port accessibility
- Test credentials with standard SFTP client first

### Debug Mode
For detailed troubleshooting:
```bash
# Run with verbose output
./sftp-sync-native --native --debug

# Check logs in the GUI log display
# Error details appear in real-time
```

## Performance Notes

### Memory Usage
- Base application: ~10-20MB
- During sync: +5-10MB per concurrent transfer
- Log storage: ~1-2MB for 500 entries
- Total typical usage: 15-35MB

### CPU Usage
- Idle: <1% CPU
- During sync: 5-15% CPU (depends on file count and network)
- UI updates: Minimal overhead with efficient rendering

### Network Efficiency
- Concurrent transfers: Configurable (default: 10)
- Chunk size: Optimized for network conditions (default: 64KB)
- Connection reuse: Single SFTP connection per endpoint
- Resume capability: Built-in retry mechanism

## Security Considerations

### Authentication
- **SSH Keys**: Recommended over passwords
- **Password Storage**: Plain text in config.json (local file)
- **Key Files**: Support for OpenSSH private keys
- **Host Verification**: Standard SSH host key checking

### Network Security
- **SFTP Protocol**: Encrypted file transfer over SSH
- **Connection Timeout**: Configurable to prevent hanging
- **Keep-Alive**: Maintains connection stability

### Local Security
- **Config Protection**: Ensure config.json has proper file permissions
- **Log Content**: May contain file paths and transfer details
- **Temporary Files**: Cleaned up automatically

## Comparison with Web GUI

### Advantages of Native GUI

| Feature | Native GUI | Web GUI |
|---------|------------|---------|
| **Performance** | Better (native rendering) | Good (browser-based) |
| **Integration** | OS notifications, file dialogs | Basic web notifications |
| **Offline Use** | Full functionality | Requires web server |
| **Resource Usage** | Lower memory footprint | Higher (browser overhead) |
| **User Experience** | Native look & feel | Consistent web interface |
| **Installation** | Single executable | Multiple files + server |
| **Remote Access** | Local only | Network accessible |
| **Mobile Support** | Desktop only | Mobile browser compatible |

### When to Choose Native GUI
- **Desktop-focused workflows**
- **Better integration with OS**
- **Lower resource usage**
- **Offline operation**
- **Professional desktop application feel**

### When to Choose Web GUI
- **Remote access requirements**
- **Mobile device access**
- **Consistent cross-platform appearance**
- **No installation of system dependencies**
- **Easy deployment and updates**

## Contributing

### Development Setup
```bash
# Clone repository
git clone <repository-url>
cd oneclick-kra-sftp-sync

# Install dependencies
go mod tidy
./build-native-gui.sh --deps  # Linux only

# Build and test
go build -o sftp-sync-native
./sftp-sync-native --native
```

### Code Structure
- `native_gui.go`: Main GUI implementation
- `main.go`: Application entry point and sync logic
- `run-native-gui.sh/.bat`: Platform launchers
- `build-native-gui.sh`: Cross-platform build script

### Adding Features
1. UI components in `native_gui.go`
2. Sync logic in `main.go`
3. Update build scripts for new dependencies
4. Test on multiple platforms

## Support

### Getting Help
1. Check this documentation first
2. Review error messages in the GUI log display
3. Test with simple configuration
4. Verify system dependencies

### Reporting Issues
Include in bug reports:
- Operating system and version
- Go version used for building
- Complete error messages
- Steps to reproduce
- Configuration file (remove sensitive data)

### Feature Requests
The native GUI supports the same core functionality as the CLI and web versions, with additional desktop integration possibilities.

## License

This project is licensed under the same terms as the main SFTP sync tool. See the main project documentation for details.

---

**SFTP Sync Native GUI** - Professional desktop application for secure file synchronization with modern interface and robust error handling.