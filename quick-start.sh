#!/bin/bash
# Quick start script

# Download and setup
# mkdir -p sftp-sync && cd sftp-sync

# Set your configuration
export SOURCE_HOST="dm.cvlindia.com"
export SOURCE_PORT="4443"
export SOURCE_USER="1100043000_D"
export SOURCE_PASS="Jan_2018"
export DEST_HOST="103.9.13.7"
export DEST_PORT="30087"
export DEST_USER="arihant"
export DEST_PASS="Afl07839@951"
export SOURCE_PATH="/"
export DEST_PATH="/"

# Run setup and start sync
./run.sh setup && ./run.sh run
