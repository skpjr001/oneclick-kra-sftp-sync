#!/bin/bash

# Test script to verify GUI log redirection fix
echo "Testing SFTP Sync GUI log redirection..."

# Function to test log redirection
test_log_redirection() {
    echo "Starting GUI in background..."
    ./sftp-sync-gui --gui &
    GUI_PID=$!

    echo "GUI PID: $GUI_PID"

    # Wait for GUI to start
    sleep 3

    # Check if GUI is running
    if ! kill -0 $GUI_PID 2>/dev/null; then
        echo "ERROR: GUI failed to start"
        exit 1
    fi

    echo "GUI started successfully"
    echo "Testing API endpoints..."

    # Test status endpoint
    echo "1. Testing status endpoint..."
    STATUS_RESPONSE=$(curl -s http://localhost:8080/api/status)
    if [ $? -eq 0 ]; then
        echo "✓ Status endpoint working"
        echo "Status: $STATUS_RESPONSE"
    else
        echo "✗ Status endpoint failed"
    fi

    # Test start sync (should fail due to config, but logs should appear in GUI)
    echo "2. Testing start sync..."
    START_RESPONSE=$(curl -s -X POST http://localhost:8080/api/start)
    if [ $? -eq 0 ]; then
        echo "✓ Start endpoint working"
        echo "Response: $START_RESPONSE"

        # Wait a bit for logs to appear
        sleep 5

        # Check status again to see logs
        echo "3. Checking logs after start..."
        STATUS_WITH_LOGS=$(curl -s http://localhost:8080/api/status)
        echo "Status with logs: $STATUS_WITH_LOGS"

        # Test stop sync
        echo "4. Testing stop sync..."
        STOP_RESPONSE=$(curl -s -X POST http://localhost:8080/api/stop)
        echo "Stop response: $STOP_RESPONSE"

        # Wait for stop to complete
        sleep 3

        # Check final status
        echo "5. Final status check..."
        FINAL_STATUS=$(curl -s http://localhost:8080/api/status)
        echo "Final status: $FINAL_STATUS"

    else
        echo "✗ Start endpoint failed"
    fi

    # Test that logs don't appear in terminal after stop
    echo "6. Testing terminal output after stop..."
    echo "If you see sync logs in terminal after this point, there's still a bug."

    # Clean up
    echo "Stopping GUI..."
    kill $GUI_PID 2>/dev/null

    # Wait for process to exit
    wait $GUI_PID 2>/dev/null

    echo "Test completed!"
}

# Check if executable exists
if [ ! -f "./sftp-sync-gui" ]; then
    echo "Building GUI executable..."
    go build -o sftp-sync-gui
    if [ $? -ne 0 ]; then
        echo "Build failed!"
        exit 1
    fi
fi

# Run the test
test_log_redirection

# Manual test instructions
echo ""
echo "Manual test instructions:"
echo "1. Run: ./sftp-sync-gui --gui"
echo "2. Open browser to http://localhost:8080"
echo "3. Click 'Start Sync' button"
echo "4. Watch logs appear in web interface"
echo "5. Click 'Stop' button"
echo "6. Verify no more logs appear in terminal"
echo "7. Press Ctrl+C to stop GUI"
echo ""
echo "If logs continue to appear in terminal after step 6, the bug still exists."
