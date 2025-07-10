# SFTP Sync Setup Guide

## Prerequisites

1. **Go Installation** (version 1.18 or later)
   ```bash
   # Check if Go is installed
   go version
   
   # If not installed, download from https://golang.org/dl/
   # Or install via package manager:
   # Ubuntu/Debian: sudo apt install golang-go
   # CentOS/RHEL: sudo yum install golang
   # macOS: brew install go
   ```

2. **Git** (for dependency management)
   ```bash
   git --version
   ```

## Step-by-Step Setup

### Step 1: Create Project Directory
```bash
mkdir sftp-sync
cd sftp-sync
```

### Step 2: Initialize Go Module
```bash
go mod init sftp-sync
```

### Step 3: Install Dependencies
```bash
go get github.com/pkg/sftp
go get golang.org/x/crypto/ssh
```

### Step 4: Create the Main Go File
Save the provided Go code as `main.go` in your project directory.

### Step 5: Create Configuration File
Create a `config.json` file for your SFTP settings:

```json
{
  "source": {
    "host": "source.example.com",
    "port": 22,
    "username": "sourceuser",
    "password": "sourcepass",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest.example.com",
    "port": 22,
    "username": "destuser",
    "password": "destpass",
    "keyfile": "",
    "timeout": 30,
    "keepalive": 30
  },
  "sync": {
    "source_path": "/source/root",
    "destination_path": "/dest/root",
    "exclude_patterns": [".tmp", ".lock", ".part", ".DS_Store"],
    "max_concurrent_transfers": 10,
    "chunk_size": 65536,
    "retry_attempts": 3,
    "retry_delay": 5,
    "verify_transfers": true,
    "days_to_sync": 5
  }
}
```

### Step 6: Build the Application
```bash
go build -o sftp-sync main.go
```

### Step 7: Test Run
```bash
./sftp-sync
```

## Environment Variables (Alternative Configuration)

You can also use environment variables instead of hardcoded values:

```bash
export SOURCE_HOST="source.example.com"
export SOURCE_USER="sourceuser"
export SOURCE_PASS="sourcepass"
export DEST_HOST="dest.example.com"
export DEST_USER="destuser"
export DEST_PASS="destpass"
export SOURCE_PATH="/source/root"
export DEST_PATH="/dest/root"
export DAYS_TO_SYNC="5"
export MAX_CONCURRENT="10"
export VERIFY_TRANSFERS="true"
```

## Running Options

### Option 1: Direct Execution
```bash
./sftp-sync
```

### Option 2: With Go Run
```bash
go run main.go
```

### Option 3: With Custom Config
```bash
./sftp-sync -config=/path/to/custom/config.json
```

## Troubleshooting

### Common Issues:

1. **Permission Denied**
   ```bash
   chmod +x sftp-sync
   ```

2. **Missing Dependencies**
   ```bash
   go mod tidy
   go mod download
   ```

3. **SSH Key Issues**
   ```bash
   # Ensure SSH key has correct permissions
   chmod 600 ~/.ssh/id_rsa
   ```

4. **Connection Timeouts**
   - Increase timeout values in config
   - Check firewall settings
   - Verify network connectivity

### Debug Mode
Add debug logging by setting environment variable:
```bash
export DEBUG=true
./sftp-sync
```

## Performance Tuning

1. **Adjust Concurrent Transfers**
   - Start with 5-10 concurrent transfers
   - Increase based on network capacity and server limits

2. **Optimize Chunk Size**
   - Default: 64KB
   - For high-latency networks: increase to 256KB-1MB
   - For low-latency networks: keep at 64KB

3. **Network Optimization**
   - Enable SSH compression: `Compression yes` in SSH config
   - Use SSH connection multiplexing

## Monitoring and Logging

The application provides detailed logging including:
- Transfer progress
- Error messages
- Performance statistics
- File counts and sizes
- Throughput measurements

Log files are written to stdout by default. To save logs:
```bash
./sftp-sync > sync.log 2>&1
```

## Security Considerations

1. **Use SSH Keys** instead of passwords when possible
2. **Secure Configuration Files** with proper permissions:
   ```bash
   chmod 600 config.json
   ```
3. **Use Environment Variables** for sensitive data in production
4. **Enable Host Key Verification** in production environments
5. **Implement Rate Limiting** to avoid overwhelming servers
