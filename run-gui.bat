@echo off
REM SFTP Sync GUI Launcher for Windows
echo Starting SFTP Sync GUI...

REM Check if executable exists
if not exist "sftp-sync-gui.exe" (
    echo Building GUI executable...
    go build -o sftp-sync-gui.exe
    if errorlevel 1 (
        echo Build failed. Please check the error messages above.
        pause
        exit /b 1
    )
)

REM Check if config file exists
if not exist "config.json" (
    echo Warning: config.json not found. Please create it or use the web interface to configure.
    echo.
)

REM Start the GUI
echo Starting web GUI on http://localhost:8080
echo Press Ctrl+C to stop
echo.
echo Opening browser...
start http://localhost:8080
sftp-sync-gui.exe --gui
