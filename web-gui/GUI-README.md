# SFTP Sync Tool - GUI Version

A web-based GUI interface for the SFTP synchronization tool that provides an easy-to-use interface with real-time logging, start/stop controls, and configuration management.

## Features

- **Web-based Interface**: Access through any modern web browser
- **Real-time Logging**: View sync progress and logs in real-time
- **Start/Stop Controls**: Easy control over sync operations
- **Running Indicator**: Visual feedback when sync is active
- **Configuration Editor**: Edit config.json directly through the web interface
- **Responsive Design**: Works on desktop and mobile devices
- **No External Dependencies**: Self-contained executable

## Quick Start

### Linux/macOS
```bash
# Make the script executable
chmod +x run-gui.sh

# Run the GUI
./run-gui.sh
```

### Windows
```batch
# Double-click on run-gui.bat or run from command prompt
run-gui.bat
```

### Manual Start
```bash
# Build the executable
go build -o sftp-sync-gui

# Run with GUI flag
./sftp-sync-gui --gui
```

## Usage

1. **Start the Application**
   - Run the appropriate script for your OS
   - The web interface will be available at `http://localhost:8080`
   - Your default browser may automatically open

2. **Configure Settings**
   - Click the "Config" button to edit configuration
   - Modify the JSON configuration as needed
   - Save changes through the web interface

3. **Run Sync**
   - Click "Start Sync" to begin synchronization
   - Monitor progress through the real-time logs
   - Use "Stop" button to cancel if needed

## Interface Components

### Status Display
- **Ready**: Application is idle and ready to start
- **Starting**: Sync process is initializing
- **Running**: Sync is actively running (with spinning indicator)
- **Completed**: Sync finished successfully
- **Failed**: Sync encountered an error
- **Cancelled**: Sync was stopped by user

### Control Buttons
- **Start Sync**: Begin the synchronization process
- **Stop**: Cancel the running sync operation
- **Config**: Open configuration editor in new tab
- **Exit**: Close the application (CLI version only)

### Log Display
- Real-time log output with timestamps
- Auto-scroll to show latest entries
- Keeps last 500 log entries for performance
- Monospace font for better readability

## Configuration

The GUI uses the same `config.json` file as the CLI version:

```json
{
  "source": {
    "host": "source-server.com",
    "port": 22,
    "username": "user",
    "password": "pass",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest-server.com",
    "port": 22,
    "username": "user",
    "password": "pass",
    "keyfile": "",
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

## Building Executables

### For Current Platform
```bash
go build -o sftp-sync-gui
```

### Cross-Platform Builds
```bash
# Windows
GOOS=windows GOARCH=amd64 go build -o sftp-sync-gui.exe

# Linux
GOOS=linux GOARCH=amd64 go build -o sftp-sync-gui-linux

# macOS
GOOS=darwin GOARCH=amd64 go build -o sftp-sync-gui-mac
```

## Advantages Over CLI Version

1. **User-Friendly**: No need to remember command-line arguments
2. **Real-time Feedback**: Live status updates and progress indication
3. **Easy Configuration**: Visual config editor with validation
4. **Cross-Platform**: Works on any system with a web browser
5. **Remote Access**: Can be accessed from other devices on the network
6. **Log Management**: Automatic log rotation and formatting
7. **Error Handling**: Better error display and user feedback

## Security Considerations

- The web interface runs on localhost by default (port 8080)
- Configuration passwords are stored in plain text in config.json
- Consider using SSH keys instead of passwords for better security
- The web interface is not secured with HTTPS - suitable for local use only

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   - Change the port in `webgui.go` and rebuild
   - Or kill the process using port 8080

2. **Config File Not Found**
   - Create a `config.json` file in the same directory
   - Use the web interface to create/edit configuration

3. **Build Failures**
   - Ensure Go is installed and properly configured
   - Check that all dependencies are available
   - Run `go mod tidy` to resolve dependencies

4. **Browser Not Opening**
   - Manually navigate to `http://localhost:8080`
   - Check if the port is blocked by firewall

### Debug Mode
Add logging to see more details:
```go
log.SetLevel(log.DebugLevel)
```

## API Endpoints

The GUI provides REST endpoints for integration:

- `GET /` - Main web interface
- `GET /api/status` - Get current status and logs
- `POST /api/start` - Start sync operation
- `POST /api/stop` - Stop sync operation
- `GET /config` - Configuration editor page
- `GET /api/config` - Get current configuration
- `POST /api/config` - Update configuration

## Performance Notes

- Log entries are limited to 500 to prevent memory issues
- Status updates occur every 2 seconds
- Large file transfers may take time to show progress
- Multiple concurrent users are supported but not recommended

## Future Enhancements

- Progress bars for individual file transfers
- Email notifications on completion
- Scheduling capabilities
- Multi-profile support
- HTTPS support for remote access
- Real-time transfer statistics
- File filtering and preview