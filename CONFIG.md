# Configuration Guide

This document explains how to configure the SFTP Sync Tool using either a JSON configuration file or environment variables.

## Configuration Priority

The tool loads configuration in the following order:
1. First, it tries to load from `config.json` (or a specified JSON file)
2. Then, it overrides any values with environment variables if they exist
3. Environment variables take precedence over JSON configuration

## JSON Configuration

### Default Configuration File

The tool looks for `config.json` in the current directory by default. You can specify a different file:

```bash
./sftp-sync /path/to/custom-config.json
```

### JSON Configuration Format

```json
{
  "source": {
    "host": "source.example.com",
    "port": 22,
    "username": "sourceuser",
    "password": "sourcepass",
    "keyfile": "/path/to/private/key",
    "timeout": 30,
    "keepalive": 30
  },
  "destination": {
    "host": "dest.example.com",
    "port": 22,
    "username": "destuser",
    "password": "destpass",
    "keyfile": "/path/to/private/key",
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

## Environment Variables

### Source SFTP Server Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SOURCE_HOST` | Source SFTP server hostname | - | Yes |
| `SOURCE_PORT` | Source SFTP server port | 22 | No |
| `SOURCE_USERNAME` | Source SFTP username | - | Yes |
| `SOURCE_PASSWORD` | Source SFTP password | - | Yes* |
| `SOURCE_KEYFILE` | Path to private key file | - | Yes* |
| `SOURCE_TIMEOUT` | Connection timeout (seconds) | 30 | No |
| `SOURCE_KEEPALIVE` | Keep-alive interval (seconds) | 30 | No |

*Either `SOURCE_PASSWORD` or `SOURCE_KEYFILE` must be provided.

### Destination SFTP Server Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DEST_HOST` | Destination SFTP server hostname | - | Yes |
| `DEST_PORT` | Destination SFTP server port | 22 | No |
| `DEST_USERNAME` | Destination SFTP username | - | Yes |
| `DEST_PASSWORD` | Destination SFTP password | - | Yes* |
| `DEST_KEYFILE` | Path to private key file | - | Yes* |
| `DEST_TIMEOUT` | Connection timeout (seconds) | 30 | No |
| `DEST_KEEPALIVE` | Keep-alive interval (seconds) | 30 | No |

*Either `DEST_PASSWORD` or `DEST_KEYFILE` must be provided.

### Sync Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SOURCE_PATH` | Source directory path | - | Yes |
| `DEST_PATH` | Destination directory path | - | Yes |
| `EXCLUDE_PATTERNS` | Comma-separated exclude patterns | - | No |
| `MAX_CONCURRENT_TRANSFERS` | Maximum concurrent file transfers | 10 | No |
| `CHUNK_SIZE` | Transfer chunk size in bytes | 65536 | No |
| `RETRY_ATTEMPTS` | Number of retry attempts | 3 | No |
| `RETRY_DELAY` | Delay between retries (seconds) | 5 | No |
| `VERIFY_TRANSFERS` | Verify file transfers with checksums | true | No |
| `DAYS_TO_SYNC` | Number of days to sync backwards | 5 | No |

## Usage Examples

### Using JSON Configuration

1. Edit `config.json` with your settings
2. Run the tool:
   ```bash
   ./sftp-sync
   ```

### Using Environment Variables

1. Create a `.env` file from the sample:
   ```bash
   cp .env.sample .env
   ```

2. Edit `.env` with your settings:
   ```bash
   nano .env
   ```

3. Run with environment variables:
   ```bash
   ./load-env.sh
   ```

### Using Custom JSON File

```bash
./sftp-sync /path/to/production-config.json
```

### Mixed Configuration

You can use both JSON and environment variables. Environment variables will override JSON values:

```bash
# Use JSON as base config, override with environment variables
SOURCE_HOST=production.example.com ./sftp-sync config.json
```

## Security Best Practices

### 1. Private Key Authentication (Recommended)

Use SSH private keys instead of passwords:

```json
{
  "source": {
    "host": "source.example.com",
    "username": "sourceuser",
    "keyfile": "/home/user/.ssh/id_rsa",
    "password": ""
  }
}
```

### 2. Environment Variables for Sensitive Data

Store sensitive information in environment variables:

```bash
# Set sensitive data as environment variables
export SOURCE_PASSWORD="your-secret-password"
export DEST_PASSWORD="your-secret-password"

# Use JSON for non-sensitive configuration
./sftp-sync config.json
```

### 3. File Permissions

Secure your configuration files:

```bash
# Restrict access to configuration files
chmod 600 config.json
chmod 600 .env
```

## Configuration Validation

The tool validates configuration at startup:

- **Required fields**: Host and username for both source and destination
- **Authentication**: Either password or key file must be provided
- **Paths**: Source and destination paths must be specified
- **Numeric values**: Ports, timeouts, etc. must be valid integers
- **Boolean values**: Must be `true` or `false`

## Troubleshooting

### Common Configuration Issues

1. **"Configuration incomplete" error**
   - Ensure all required fields are provided
   - Check that either password or keyfile is specified

2. **"Failed to load configuration" error**
   - Verify JSON syntax is correct
   - Check file permissions and existence

3. **Connection failures**
   - Verify host, port, username, and credentials
   - Check network connectivity
   - Validate SSH key permissions (600 for private keys)

4. **Environment variable not recognized**
   - Ensure variable names match exactly (case-sensitive)
   - For boolean values, use `true` or `false` (lowercase)
   - For comma-separated lists, don't include spaces

### Debug Configuration Loading

Run with verbose logging to see which configuration values are loaded:

```bash
# The tool will log configuration source and values
./sftp-sync config.json
```

Look for log messages like:
- "Loading configuration from config.json"
- "Configuration loaded from JSON file"
- "Configuration loaded from environment variables"

## Advanced Configuration

### Custom Exclude Patterns

Exclude patterns support shell-style wildcards:

```json
{
  "sync": {
    "exclude_patterns": [
      "*.tmp",
      "*.lock",
      ".DS_Store",
      "node_modules/*",
      "*.log"
    ]
  }
}
```

### Performance Tuning

Adjust these settings based on your network and system:

```json
{
  "sync": {
    "max_concurrent_transfers": 20,
    "chunk_size": 131072,
    "retry_attempts": 5,
    "retry_delay": 2
  }
}
```

- **Higher `max_concurrent_transfers`**: Faster sync but more resource usage
- **Larger `chunk_size`**: Better for large files, worse for small files
- **More `retry_attempts`**: Better reliability for unstable connections
- **Lower `retry_delay`**: Faster retries but may overwhelm servers