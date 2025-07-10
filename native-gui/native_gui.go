package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

type NativeGUI struct {
	app         fyne.App
	window      fyne.Window
	startBtn    *widget.Button
	stopBtn     *widget.Button
	configBtn   *widget.Button
	exitBtn     *widget.Button
	statusLabel *widget.Label
	logText     *widget.Entry
	progressBar *widget.ProgressBarInfinite

	ctx         context.Context
	cancel      context.CancelFunc
	isRunning   bool
	mutex       sync.RWMutex
	syncProcess *NativeSyncProcess
	cancelled   bool

	logWriter   *NativeLogWriter
	originalOut io.Writer
}

type NativeSyncProcess struct {
	syncer     *SFTPSync
	cancel     context.CancelFunc
	logRestore func()
	cancelled  bool
}

type NativeLogWriter struct {
	gui   *NativeGUI
	mutex sync.Mutex
}

func (nlw *NativeLogWriter) Write(p []byte) (n int, err error) {
	nlw.mutex.Lock()
	defer nlw.mutex.Unlock()

	msg := string(p)
	msg = strings.TrimSpace(msg)

	// Filter out error messages that happen after cancellation
	if nlw.gui.cancelled {
		if strings.Contains(msg, "connection lost") ||
			strings.Contains(msg, "failed to read directory") ||
			strings.Contains(msg, "Error scanning") {
			// Suppress these error messages after cancellation
			return len(p), nil
		}
	}

	if msg != "" {
		nlw.gui.AddLog(msg)
	}

	return len(p), nil
}

func NewNativeGUI() *NativeGUI {
	myApp := app.New()
	myApp.SetIcon(theme.DocumentIcon())
	myApp.Settings().SetTheme(theme.DefaultTheme())

	window := myApp.NewWindow("SFTP Sync Tool")
	window.Resize(fyne.NewSize(900, 700))
	window.SetFixedSize(false)

	gui := &NativeGUI{
		app:         myApp,
		window:      window,
		originalOut: os.Stdout,
	}

	gui.setupUI()
	gui.setupEventHandlers()

	return gui
}

func (g *NativeGUI) setupUI() {
	// Title
	title := widget.NewCard("SFTP Sync Tool", "Cross-platform file synchronization", nil)
	title.SetTitle("SFTP Sync Tool")
	title.SetSubTitle("Cross-platform file synchronization with real-time logging")

	// Status section
	g.statusLabel = widget.NewLabel("Ready")
	g.statusLabel.Alignment = fyne.TextAlignCenter
	g.statusLabel.TextStyle = fyne.TextStyle{Bold: true}

	g.progressBar = widget.NewProgressBarInfinite()
	g.progressBar.Hide()

	statusContainer := container.NewVBox(
		widget.NewCard("Status", "", container.NewVBox(
			g.statusLabel,
			g.progressBar,
		)),
	)

	// Control buttons
	g.startBtn = widget.NewButton("Start Sync", g.onStartClick)
	g.startBtn.Importance = widget.HighImportance
	g.startBtn.Icon = theme.MediaPlayIcon()

	g.stopBtn = widget.NewButton("Stop", g.onStopClick)
	g.stopBtn.Importance = widget.DangerImportance
	g.stopBtn.Icon = theme.MediaStopIcon()
	g.stopBtn.Disable()

	g.configBtn = widget.NewButton("Config", g.onConfigClick)
	g.configBtn.Icon = theme.SettingsIcon()

	g.exitBtn = widget.NewButton("Exit", g.onExitClick)
	g.exitBtn.Icon = theme.LogoutIcon()

	buttonContainer := container.NewGridWithColumns(4,
		g.startBtn,
		g.stopBtn,
		g.configBtn,
		g.exitBtn,
	)

	// Log display
	g.logText = widget.NewMultiLineEntry()
	g.logText.SetText("SFTP Sync Tool - Ready to start\nClick 'Start Sync' to begin synchronization\n")
	g.logText.Wrapping = fyne.TextWrapWord
	g.logText.Disable() // Make it read-only

	logContainer := container.NewBorder(
		widget.NewLabel("Logs:"),
		nil,
		nil,
		nil,
		container.NewScroll(g.logText),
	)

	// Log writer setup
	g.logWriter = &NativeLogWriter{gui: g}

	// Main layout
	content := container.NewBorder(
		container.NewVBox(
			title,
			statusContainer,
			buttonContainer,
		),
		nil,
		nil,
		nil,
		logContainer,
	)

	g.window.SetContent(content)
}

func (g *NativeGUI) setupEventHandlers() {
	g.window.SetCloseIntercept(func() {
		if g.isRunning {
			dialog.ShowConfirm("Confirm Exit", "Sync is running. Are you sure you want to exit?",
				func(confirm bool) {
					if confirm {
						g.forceExit()
					}
				}, g.window)
		} else {
			g.app.Quit()
		}
	})
}

func (g *NativeGUI) AddLog(msg string) {
	// Clean up the message
	msg = strings.TrimSpace(msg)
	if msg == "" {
		return
	}

	timestamp := time.Now().Format("15:04:05")
	logEntry := fmt.Sprintf("[%s] %s\n", timestamp, msg)

	// Update UI in main thread using content.Refresh()
	go func() {
		// Append to log text
		currentText := g.logText.Text
		lines := strings.Split(currentText, "\n")

		// Keep only last 500 lines for performance
		if len(lines) > 500 {
			lines = lines[len(lines)-500:]
		}

		newText := strings.Join(lines, "\n") + logEntry
		g.logText.SetText(newText)

		// Auto-scroll to bottom
		g.logText.CursorRow = len(strings.Split(newText, "\n")) - 1

		// Refresh the widget to update display
		g.logText.Refresh()
	}()
}

func (g *NativeGUI) SetStatus(status string) {
	g.mutex.Lock()
	defer g.mutex.Unlock()

	g.statusLabel.SetText(status)

	// Update status color based on state
	switch status {
	case "Ready":
		g.statusLabel.TextStyle = fyne.TextStyle{Bold: true}
	case "Running...":
		g.statusLabel.TextStyle = fyne.TextStyle{Bold: true, Italic: true}
	case "Completed":
		g.statusLabel.TextStyle = fyne.TextStyle{Bold: true}
	case "Failed", "Error":
		g.statusLabel.TextStyle = fyne.TextStyle{Bold: true}
	case "Cancelled":
		g.statusLabel.TextStyle = fyne.TextStyle{Bold: true}
	}

	g.statusLabel.Refresh()
}

func (g *NativeGUI) onStartClick() {
	g.mutex.Lock()
	defer g.mutex.Unlock()

	if g.isRunning {
		return
	}

	g.isRunning = true
	g.cancelled = false
	g.ctx, g.cancel = context.WithCancel(context.Background())

	g.startBtn.Disable()
	g.stopBtn.Enable()
	g.SetStatus("Starting...")
	g.progressBar.Show()
	g.progressBar.Start()

	// Redirect log output
	log.SetOutput(g.logWriter)

	go g.runSync()
}

func (g *NativeGUI) onStopClick() {
	g.mutex.Lock()
	defer g.mutex.Unlock()

	if !g.isRunning {
		return
	}

	g.SetStatus("Stopping...")
	g.cancelled = true

	// Cancel the main context
	if g.cancel != nil {
		g.cancel()
	}

	// Also cancel the sync process directly
	if g.syncProcess != nil && g.syncProcess.cancel != nil {
		g.syncProcess.cancel()
		g.syncProcess.cancelled = true
	}
}

func (g *NativeGUI) onConfigClick() {
	configPath := "config.json"

	// Check if config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		dialog.ShowError(fmt.Errorf("Config file not found: %s", configPath), g.window)
		return
	}

	// Read config file
	content, err := os.ReadFile(configPath)
	if err != nil {
		dialog.ShowError(fmt.Errorf("Failed to read config file: %v", err), g.window)
		return
	}

	// Create config editor
	entry := widget.NewMultiLineEntry()
	entry.SetText(string(content))
	entry.Wrapping = fyne.TextWrapWord

	// Create dialog
	dialog.ShowCustomConfirm("Configuration Editor", "Save", "Cancel",
		container.NewBorder(
			widget.NewLabel("Edit your configuration:"),
			nil,
			nil,
			nil,
			container.NewScroll(entry),
		),
		func(save bool) {
			if save {
				if err := os.WriteFile(configPath, []byte(entry.Text), 0644); err != nil {
					dialog.ShowError(fmt.Errorf("Failed to save config: %v", err), g.window)
				} else {
					dialog.ShowInformation("Success", "Configuration saved successfully", g.window)
				}
			}
		}, g.window)
}

func (g *NativeGUI) onExitClick() {
	if g.isRunning {
		dialog.ShowConfirm("Confirm Exit", "Sync is running. Are you sure you want to exit?",
			func(confirm bool) {
				if confirm {
					g.forceExit()
				}
			}, g.window)
	} else {
		g.app.Quit()
	}
}

func (g *NativeGUI) forceExit() {
	if g.isRunning {
		g.cancelled = true
		if g.cancel != nil {
			g.cancel()
		}
		if g.syncProcess != nil && g.syncProcess.cancel != nil {
			g.syncProcess.cancel()
		}
	}
	g.app.Quit()
}

func (g *NativeGUI) runSync() {
	// Ensure cleanup happens no matter what
	defer func() {
		g.mutex.Lock()
		g.isRunning = false
		g.startBtn.Enable()
		g.stopBtn.Disable()
		g.progressBar.Stop()
		g.progressBar.Hide()

		// Clean up sync process
		if g.syncProcess != nil {
			g.cleanupSyncProcess()
		}
		g.mutex.Unlock()

		// Restore original log output
		log.SetOutput(g.originalOut)
	}()

	g.SetStatus("Running...")
	g.AddLog("Starting SFTP Sync...")

	// Create sync process structure
	syncCtx, syncCancel := context.WithCancel(context.Background())
	g.syncProcess = &NativeSyncProcess{
		cancel:    syncCancel,
		cancelled: false,
	}

	// Load configuration
	configPath := "config.json"
	config, err := LoadConfig(configPath)
	if err != nil {
		g.AddLog(fmt.Sprintf("Failed to load configuration: %v", err))
		g.SetStatus("Error - Check config")
		return
	}

	// Convert configs
	sourceConfig := ConvertToSFTPConfig(config.Source)
	destConfig := ConvertToSFTPConfig(config.Destination)
	syncConfig := ConvertToSyncConfig(config.Sync)

	// Validate configuration
	if sourceConfig.Host == "" || sourceConfig.Username == "" {
		g.AddLog("Source SFTP configuration is incomplete")
		g.SetStatus("Error - Source config incomplete")
		return
	}
	if destConfig.Host == "" || destConfig.Username == "" {
		g.AddLog("Destination SFTP configuration is incomplete")
		g.SetStatus("Error - Dest config incomplete")
		return
	}

	g.AddLog(fmt.Sprintf("Source: %s@%s:%d", sourceConfig.Username, sourceConfig.Host, sourceConfig.Port))
	g.AddLog(fmt.Sprintf("Destination: %s@%s:%d", destConfig.Username, destConfig.Host, destConfig.Port))

	// Create syncer
	syncer := NewSFTPSync(sourceConfig, destConfig, syncConfig)
	g.syncProcess.syncer = syncer

	// Run sync with proper cancellation support
	done := make(chan error, 1)
	go func() {
		// This goroutine will handle the sync operation
		defer func() {
			if r := recover(); r != nil {
				done <- fmt.Errorf("sync panic: %v", r)
			}
		}()

		// Check for cancellation before starting
		select {
		case <-syncCtx.Done():
			done <- context.Canceled
			return
		default:
		}

		// Run the sync with context cancellation support
		err := syncer.SyncWithContext(syncCtx)
		done <- err
	}()

	// Wait for completion or cancellation
	select {
	case err := <-done:
		if err != nil {
			if err == context.Canceled {
				g.AddLog("Sync cancelled by user")
				g.SetStatus("Cancelled")
			} else {
				g.AddLog(fmt.Sprintf("Sync failed: %v", err))
				g.SetStatus("Failed")
			}
		} else {
			g.AddLog("Sync completed successfully!")
			g.SetStatus("Completed")
		}
	case <-g.ctx.Done():
		g.AddLog("Sync cancelled by user")
		g.SetStatus("Cancelled")
		// Cancel the sync context
		syncCancel()

		// Wait a bit for graceful shutdown
		select {
		case <-done:
			// Sync completed/failed
		case <-time.After(5 * time.Second):
			g.AddLog("Sync force-stopped after timeout")
		}
	case <-syncCtx.Done():
		g.AddLog("Sync cancelled")
		g.SetStatus("Cancelled")
	}
}

func (g *NativeGUI) cleanupSyncProcess() {
	if g.syncProcess == nil {
		return
	}

	// Cancel the sync context
	if g.syncProcess.cancel != nil {
		g.syncProcess.cancel()
	}

	g.syncProcess = nil
}

func (g *NativeGUI) Run() {
	g.window.ShowAndRun()
}

func mainNativeGUI() {
	gui := NewNativeGUI()
	gui.Run()
}
