# Pre Setup Requisite
## Copy and edit the environment file
cp .env.example .env
nano .env

## Load environment variables
source .env

## Make the shell script executable
chmod +x run.sh

# First time setup
## Run the setup command (this will install dependencies and create config)
./run.sh setup

## Build the application
./run.sh build

## Run the sync
./run.sh run

# Available Commands
### Run the sync with logging
./run.sh run

### Run the sync without logging
./run.sh run --no-log

### Show project status
./run.sh status

### Clean up files
./run.sh clean

### Show help
./run.sh help


# Create service file
sudo nano /etc/systemd/system/sftp-sync.service

sudo systemctl daemon-reload
sudo systemctl enable sftp-sync.service
sudo systemctl start sftp-sync.service

# Edit crontab
crontab -e

# Add entry for daily sync at 2 AM
0 2 * * * cd /path/to/oneclick-kra-sftp-sync && ./run.sh run >> /var/log/oneclick-kra-sftp-sync.log 2>&1
