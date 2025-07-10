#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    set -a  # automatically export all variables
    source .env
    set +a  # disable automatic export
    echo "Environment variables loaded successfully"
else
    echo ".env file not found. Using existing environment variables or config.json"
fi

# Run the SFTP sync tool
echo "Starting SFTP sync..."
./sftp-sync "$@"
