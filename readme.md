# SFTP Sync Tool

A comprehensive cross-platform SFTP file synchronization tool with multiple interface options: CLI, Web GUI, and Native GUI.

## 🚀 Quick Start

### GUI Options (Recommended)

#### Native Desktop GUI
```bash
# Linux/macOS
./run-native-gui.sh

# Windows
run-native-gui.bat
```

#### Web-based GUI
```bash
# Linux/macOS
./run-gui.sh

# Windows
run-gui.bat
```

### Command Line Interface

#### Pre Setup Requisite
Copy and edit the environment file:
```bash
cp .env.example .env
nano .env
```

Load environment variables:
```bash
source .env
```

Make the shell script executable:
```bash
chmod +x run.sh
```

#### First time setup
Run the setup command (this will install dependencies and create config):
```bash
./run.sh setup
```

Build the application:
```bash
./run.sh build
```

Run the sync:
```bash
./run.sh run
```

## 📋 Available Interfaces

### 1. Native Desktop GUI (Recommended)
- **File**: `native_gui.go`
- **Features**: Cross-platform native application using Fyne framework
- **Platforms**: Windows, Linux, macOS
- **Benefits**: Best performance, OS integration, offline operation
- **Usage**: `./sftp-sync-native --native`

### 2. Web GUI
- **File**: `webgui.go`
- **Features**: Browser-based interface accessible at http://localhost:8080
- **Platforms**: Any with web browser
- **Benefits**: Remote access, mobile-friendly, no system dependencies
- **Usage**: `./sftp-sync-gui --gui`

### 3. Command Line Interface
- **File**: `main.go`
- **Features**: Direct command-line execution
- **Platforms**: Any with Go support
- **Benefits**: Scriptable, minimal resources, automation-friendly
- **Usage**: `./sftp-sync` or `./run.sh run`

## 🛠️ Available Commands

### CLI Commands
Run the sync with logging:
```bash
./run.sh run
```

Run the sync without logging:
```bash
./run.sh run --no-log
```

Show project status:
```bash
./run.sh status
```

Clean up files:
```bash
./run.sh clean
```

Show help:
```bash
./run.sh help
```

### GUI Commands
Start native GUI:
```bash
./sftp-sync-native --native
```

Start web GUI:
```bash
./sftp-sync-gui --gui
```


## 🔧 System Service Setup

Create service file:
```bash
sudo nano /etc/systemd/system/sftp-sync.service
```

Enable and start service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable sftp-sync.service
sudo systemctl start sftp-sync.service
```

## ⏰ Scheduled Sync Setup

Edit crontab:
```bash
crontab -e
```

Add entry for daily sync at 2 AM:
```bash
0 2 * * * cd /path/to/oneclick-kra-sftp-sync && ./run.sh run >> /var/log/oneclick-kra-sftp-sync.log 2>&1
```

## 📖 Documentation

- **CLI Usage**: See main documentation above
- **Web GUI**: `GUI-README.md` - Comprehensive web interface guide
- **Native GUI**: `NATIVE-GUI-README.md` - Desktop application guide
- **Configuration**: `CONFIG.md` - Configuration options and examples
- **Build Instructions**: `build-all.sh` and `build-native-gui.sh`

## 🎯 Interface Comparison

| Feature | Native GUI | Web GUI | CLI |
|---------|------------|---------|-----|
| **User Experience** | Best | Good | Basic |
| **Performance** | Excellent | Good | Excellent |
| **Remote Access** | No | Yes | SSH only |
| **Installation** | Single file | Multiple files | Single file |
| **System Integration** | Excellent | Limited | None |
| **Mobile Support** | No | Yes | No |

Choose the interface that best fits your needs:
- **Native GUI**: Desktop users wanting the best experience
- **Web GUI**: Remote access or mobile device usage
- **CLI**: Automation, scripting, or minimal resource usage

## ✨ Features

- ✅ **Cross-platform support** (Windows, Linux, macOS)
- ✅ **Multiple interfaces** (Native GUI, Web GUI, CLI)
- ✅ **Real-time logging** with progress indicators
- ✅ **Configuration management** with built-in editors
- ✅ **Start/Stop controls** with immediate cancellation
- ✅ **Robust error handling** and automatic cleanup
- ✅ **No log leakage** to terminal after operations
- ✅ **Context-aware cancellation** for immediate response
