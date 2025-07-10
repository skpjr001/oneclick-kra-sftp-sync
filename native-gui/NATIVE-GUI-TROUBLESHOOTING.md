# Native GUI Troubleshooting Guide

This guide helps you diagnose and fix common issues with the SFTP Sync Native GUI application.

## Quick Fixes

### 1. Application Won't Start
```bash
# Check if executable exists
ls -la sftp-sync-native*

# If not, build it
go build -o sftp-sync-native

# Check permissions
chmod +x sftp-sync-native

# Try running directly
./sftp-sync-native --native
```

### 2. Application Crashes on "Start Sync"
The recent fixes address the main causes of crashes:

**Issue**: UI thread violations
**Fix**: ✅ **FIXED** - UI updates now happen on proper threads

**Issue**: Context management problems
**Fix**: ✅ **FIXED** - Simplified to single context per sync operation

**Issue**: Log redirection issues
**Fix**: ✅ **FIXED** - Cleaner log handling with proper cleanup

### 3. No Display Available (Linux)
```bash
# Check if display is available
echo $DISPLAY
echo $WAYLAND_DISPLAY

# For SSH connections, enable X11 forwarding
ssh -X username@hostname

# Or try setting display manually
export DISPLAY=:0
```

## Build Issues

### Missing System Dependencies (Linux)
```bash
# Ubuntu/Debian
sudo apt-get install libgl1-mesa-dev libxrandr-dev libxcursor-dev \
    libxinerama-dev libxi-dev libxext-dev libxfixes-dev \
    libxxf86vm-dev pkg-config gcc

# Fedora
sudo dnf install mesa-libGL-devel libXrandr-devel libXcursor-devel \
    libXinerama-devel libXi-devel libXext-devel \
    libXfixes-devel libXxf86vm-devel pkgconfig gcc

# CentOS/RHEL
sudo yum install mesa-libGL-devel libXrandr-devel libXcursor-devel \
    libXinerama-devel libXi-devel libXext-devel \
    libXfixes-devel libXxf86vm-devel pkgconfig gcc
```

### CGO Issues
```bash
# Ensure CGO is enabled
export CGO_ENABLED=1

# Check CGO status
go env CGO_ENABLED

# If still having issues, try
go clean -cache
go build -o sftp-sync-native
```

## Runtime Issues

### 1. Config File Problems
```bash
# Check if config.json exists
ls -la config.json

# Validate JSON syntax
python3 -m json.tool config.json
# or
jq . config.json

# If missing, create basic config
cat > config.json << 'EOF'
{
  "source": {
    "host": "source-server.com",
    "port": 22,
    "username": "username",
    "password": "password",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest-server.com",
    "port": 22,
    "username": "username",
    "password": "password",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "/source/path",
    "destination_path": "/dest/path",
    "exclude_patterns": [".tmp", ".lock"],
    "max_concurrent_transfers": 10,
    "chunk_size": 65536,
    "retry_attempts": 3,
    "retry_delay": 5,
    "verify_transfers": true,
    "days_to_sync": 5
  }
}
EOF
```

### 2. Connection Issues
```bash
# Test SFTP connections manually
sftp -P 22 username@hostname

# Check firewall/network
ping hostname
telnet hostname 22

# Test SSH key (if using key authentication)
ssh -i /path/to/key username@hostname
```

### 3. Sync Stops/Fails
Check the logs in the GUI for specific error messages:

**Common Issues**:
- **Authentication failed**: Check username/password or SSH keys
- **Connection timeout**: Increase timeout values in config
- **Path not found**: Verify source and destination paths exist
- **Permission denied**: Check file/directory permissions

## Performance Issues

### 1. Slow Sync
```json
{
  "sync": {
    "max_concurrent_transfers": 20,
    "chunk_size": 131072,
    "retry_attempts": 2,
    "retry_delay": 2
  }
}
```

### 2. High Memory Usage
```json
{
  "sync": {
    "max_concurrent_transfers": 5,
    "chunk_size": 32768
  }
}
```

### 3. GUI Responsiveness
- The GUI should remain responsive even during large syncs
- Logs are automatically rotated (500 entries max)
- Progress indicators show sync status

## Debug Mode

### Enable Verbose Logging
```bash
# Run with more verbose output
./sftp-sync-native --native --debug  # if implemented

# Or check system logs
journalctl -f | grep sftp-sync
```

### Check Process Status
```bash
# While GUI is running
ps aux | grep sftp-sync
netstat -an | grep :22  # Check SFTP connections
```

## Known Issues & Solutions

### 1. "Context Canceled" Errors
**Status**: ✅ **FIXED** in latest version
- Context cancellation is now properly handled
- Error messages are filtered after cancellation

### 2. Log Redirection Problems
**Status**: ✅ **FIXED** in latest version  
- Logs no longer leak to terminal after stopping
- Proper cleanup of log handlers

### 3. UI Thread Violations
**Status**: ✅ **FIXED** in latest version
- UI updates now happen on correct threads
- No more GUI freezing or crashes

### 4. Multiple Context Confusion
**Status**: ✅ **FIXED** in latest version
- Simplified to single context per sync operation
- Clear cancellation handling

## Testing Your Installation

### Quick Test
```bash
# Navigate to native-gui directory
cd native-gui

# Run the simple test
../test-native-gui-simple.sh

# If all tests pass, try running the GUI
./run-native-gui.sh
```

### Comprehensive Test
```bash
# Run full test suite
./test-native-gui.sh

# Check build system
./build-native-gui.sh --current
```

## Getting Help

### Information to Include in Bug Reports
1. **Operating System**: `uname -a`
2. **Go Version**: `go version`
3. **Build Command Used**: e.g., `go build -o sftp-sync-native`
4. **Error Messages**: Complete error output
5. **Config File**: (remove sensitive data)
6. **Display Info**: `echo $DISPLAY` (Linux)

### Common Error Messages

**"failed to initialize OpenGL"**
- Missing OpenGL libraries
- Install mesa-libGL-devel or equivalent

**"connection failed"**
- Network connectivity issue
- Check hostname, port, credentials

**"permission denied"**
- File system permissions
- SFTP server permissions
- Check user access rights

**"context canceled"**
- Normal when stopping sync
- Should not appear during normal operation

## Recovery Procedures

### 1. Reset to Clean State
```bash
# Stop any running processes
pkill -f sftp-sync

# Clean build artifacts
rm -f sftp-sync-native*
go clean -cache

# Rebuild
go build -o sftp-sync-native
```

### 2. Reset Configuration
```bash
# Backup current config
cp config.json config.json.backup

# Reset to defaults (edit as needed)
cp config.json.sample config.json
```

### 3. Force GUI Restart
```bash
# Kill any hung processes
pkill -f sftp-sync

# Clear any temp files
rm -f /tmp/sftp-sync-*

# Restart GUI
./sftp-sync-native --native
```

## Version Information

**Current Version**: Latest with crash fixes
**Key Improvements**:
- ✅ Fixed UI thread violations
- ✅ Simplified context management  
- ✅ Improved log handling
- ✅ Better error handling
- ✅ Proper cleanup on exit

**Previous Issues Resolved**:
- Application crashing on "Start Sync"
- Logs leaking to terminal after stop
- UI freezing during operations
- Context cancellation errors
- Memory leaks in log handling

## Contact & Support

For additional help:
1. Check the main README files
2. Review the configuration guide (CONFIG.md)
3. Test with the provided test scripts
4. Check system dependencies and permissions

The native GUI has been significantly improved and should now run reliably without crashes when clicking "Start Sync".