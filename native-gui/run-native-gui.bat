@echo off
REM SFTP Sync Native GUI Launcher for Windows
echo Starting SFTP Sync Native GUI...

REM Check if executable exists or if source code is newer
if not exist "sftp-sync-native.exe" (
    echo Building native GUI executable...
    go build -o sftp-sync-native.exe
    if errorlevel 1 (
        echo Build failed. Please check the error messages above.
        echo Make sure you have Go installed and CGO enabled.
        pause
        exit /b 1
    )
    echo Build successful - native GUI with log redirection fix
) else (
    REM Check if source is newer (basic check)
    if exist "native_gui.go" (
        echo Source code detected, checking if rebuild is needed...
        go build -o sftp-sync-native.exe
        if errorlevel 1 (
            echo Build failed. Please check the error messages above.
            pause
            exit /b 1
        )
    )
)

REM Check if config file exists
if not exist "config.json" (
    echo Warning: config.json not found. You can create it using the GUI config editor.
    echo.
)

REM Start the native GUI
echo Starting native GUI...
echo.
echo ✓ Native cross-platform GUI using Fyne framework
echo ✓ Log redirection fix applied - no logs will leak to terminal after stop
echo ✓ Context-aware cancellation - sync stops immediately when requested
echo ✓ Proper cleanup - no background processes remain after stop
echo ✓ Modern UI with progress indicators and status updates
echo.
sftp-sync-native.exe --native
