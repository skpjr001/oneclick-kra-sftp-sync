package main

import (
	"context"
	"fmt"
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

// NativeGUI implements a native GUI for SFTP synchronization
type NativeGUI struct {
	// Fyne components
	app         fyne.App
	window      fyne.Window
	startBtn    *widget.Button
	stopBtn     *widget.Button
	configBtn   *widget.Button
	exitBtn     *widget.Button
	statusLabel *widget.Label
	logText     *widget.Label
	progressBar *widget.ProgressBarInfinite

	// Sync state
	syncCtx    context.Context
	syncCancel context.CancelFunc
	isRunning  bool
	cancelled  bool
	mutex      sync.RWMutex

	// Log entries
	logs      []string
	logsMutex sync.RWMutex

	// UI update state
	logDisplay string
	logMutex   sync.RWMutex
}

// NewNativeGUI creates a new native GUI instance
func NewNativeGUI() *NativeGUI {
	myApp := app.New()
	myWindow := myApp.NewWindow("SFTP Sync Tool")
	myWindow.Resize(fyne.NewSize(900, 700))

	gui := &NativeGUI{
		app:        myApp,
		window:     myWindow,
		logs:       make([]string, 0, 50),
		logDisplay: "SFTP Sync Tool - Ready to start\nClick 'Start Sync' to begin synchronization",
	}

	gui.setupUI()
	gui.setupEventHandlers()

	return gui
}

// setupUI creates the user interface
func (g *NativeGUI) setupUI() {
	// Title and header
	title := widget.NewLabel("SFTP Sync Tool")
	title.TextStyle = fyne.TextStyle{Bold: true}
	title.Alignment = fyne.TextAlignCenter

	subtitle := widget.NewLabel("Cross-platform file synchronization with real-time logging")
	subtitle.Alignment = fyne.TextAlignCenter

	// Status section
	g.statusLabel = widget.NewLabel("Ready")
	g.statusLabel.Alignment = fyne.TextAlignCenter
	g.statusLabel.TextStyle = fyne.TextStyle{Bold: true}

	g.progressBar = widget.NewProgressBarInfinite()
	g.progressBar.Hide()

	// Control buttons
	g.startBtn = widget.NewButton("Start Sync", func() {
		// Button action handled in event handler to avoid multiple registrations
	})
	g.startBtn.Importance = widget.HighImportance
	g.startBtn.SetIcon(theme.MediaPlayIcon())

	g.stopBtn = widget.NewButton("Stop", func() {
		// Button action handled in event handler to avoid multiple registrations
	})
	g.stopBtn.Importance = widget.DangerImportance
	g.stopBtn.SetIcon(theme.MediaStopIcon())
	g.stopBtn.Disable()

	g.configBtn = widget.NewButton("Config", func() {
		// Button action handled in event handler to avoid multiple registrations
	})
	g.configBtn.SetIcon(theme.SettingsIcon())

	g.exitBtn = widget.NewButton("Exit", func() {
		// Button action handled in event handler to avoid multiple registrations
	})
	g.exitBtn.SetIcon(theme.LogoutIcon())

	// Log display - use Entry for better text handling
	g.logText = widget.NewLabel("SFTP Sync Tool - Ready to start\nClick 'Start Sync' to begin synchronization")
	g.logText.Wrapping = fyne.TextWrapWord

	// Layout components
	headerContainer := container.NewVBox(
		title,
		subtitle,
	)

	statusContainer := container.NewVBox(
		widget.NewCard("Status", "", container.NewVBox(
			g.statusLabel,
			g.progressBar,
		)),
	)

	buttonContainer := container.NewGridWithColumns(4,
		g.startBtn,
		g.stopBtn,
		g.configBtn,
		g.exitBtn,
	)

	logContainer := container.NewBorder(
		widget.NewLabel("Logs:"),
		nil, nil, nil,
		container.NewScroll(g.logText),
	)

	// Main layout
	content := container.NewBorder(
		container.NewVBox(
			headerContainer,
			statusContainer,
			buttonContainer,
		),
		nil, nil, nil,
		logContainer,
	)

	g.window.SetContent(content)
}

// setupEventHandlers connects UI events to handlers
func (g *NativeGUI) setupEventHandlers() {
	g.startBtn.OnTapped = g.onStartClick
	g.stopBtn.OnTapped = g.onStopClick
	g.configBtn.OnTapped = g.onConfigClick
	g.exitBtn.OnTapped = g.onExitClick

	g.window.SetCloseIntercept(func() {
		g.onExitClick()
	})
}

// updateUI schedules UI updates to run on the main thread
func (g *NativeGUI) updateUI(f func()) {
	// Use fyne.Do to safely update UI from any goroutine
	fyne.Do(f)
}

// AddLog adds a log entry and updates the display
func (g *NativeGUI) AddLog(msg string) {
	msg = strings.TrimSpace(msg)
	if msg == "" {
		return
	}

	// Filter out noise after cancellation
	if g.cancelled {
		if strings.Contains(msg, "connection lost") ||
			strings.Contains(msg, "failed to read directory") ||
			strings.Contains(msg, "Error scanning") ||
			strings.Contains(msg, "context canceled") ||
			strings.Contains(msg, "EOF") {
			return
		}
	}

	// Limit message length to prevent UI issues
	if len(msg) > 200 {
		msg = msg[:200] + "..."
	}

	// Create timestamped log entry
	timestamp := time.Now().Format("15:04:05")
	logEntry := fmt.Sprintf("[%s] %s", timestamp, msg)

	// Update display text safely
	g.logMutex.Lock()
	defer g.logMutex.Unlock()

	if g.logDisplay == "SFTP Sync Tool - Ready to start\nClick 'Start Sync' to begin synchronization" {
		g.logDisplay = logEntry
	} else {
		g.logDisplay += "\n" + logEntry
	}

	// Keep only the last 15 lines and limit total length
	lines := strings.Split(g.logDisplay, "\n")
	if len(lines) > 50 {
		lines = lines[len(lines)-15:]
		g.logDisplay = strings.Join(lines, "\n")
	}

	// Limit total display text length to prevent UI crashes
	if len(g.logDisplay) > 2000 {
		lines = strings.Split(g.logDisplay, "\n")
		if len(lines) > 5 {
			lines = lines[len(lines)-5:]
			g.logDisplay = strings.Join(lines, "\n")
		}
	}

	displayText := g.logDisplay

	// Queue UI update with safety check
	g.updateUI(func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("UI update panic recovered: %v", r)
			}
		}()
		if g.logText != nil && displayText != "" {
			// Additional safety check for text length
			if len(displayText) > 1500 {
				displayText = displayText[len(displayText)-1500:]
			}
			g.logText.SetText(displayText)
		}
	})
}

// SetStatus updates the status display
func (g *NativeGUI) SetStatus(status string) {
	// Limit status length to prevent UI issues
	if len(status) > 100 {
		status = status[:100] + "..."
	}

	g.updateUI(func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Status update panic recovered: %v", r)
			}
		}()
		if g.statusLabel != nil {
			g.statusLabel.SetText(status)
		}
	})
}

// UpdateRunningState updates the UI elements based on running state
func (g *NativeGUI) UpdateRunningState(running bool) {
	g.updateUI(func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Button state update panic recovered: %v", r)
			}
		}()
		if running {
			if g.startBtn != nil {
				g.startBtn.Disable()
			}
			if g.stopBtn != nil {
				g.stopBtn.Enable()
			}
			if g.progressBar != nil {
				g.progressBar.Show()
				g.progressBar.Start()
			}
		} else {
			if g.startBtn != nil {
				g.startBtn.Enable()
			}
			if g.stopBtn != nil {
				g.stopBtn.Disable()
			}
			if g.progressBar != nil {
				g.progressBar.Stop()
				g.progressBar.Hide()
			}
		}
	})
}

// onStartClick handles the Start button click
func (g *NativeGUI) onStartClick() {
	g.mutex.Lock()
	if g.isRunning {
		g.mutex.Unlock()
		return
	}

	g.isRunning = true
	g.cancelled = false
	g.syncCtx, g.syncCancel = context.WithCancel(context.Background())
	g.mutex.Unlock()

	// Update UI
	g.UpdateRunningState(true)
	g.SetStatus("Starting...")

	// Start sync in background
	go g.runSync()
}

// onStopClick handles the Stop button click
func (g *NativeGUI) onStopClick() {
	g.mutex.Lock()
	if !g.isRunning {
		g.mutex.Unlock()
		return
	}

	g.cancelled = true
	g.mutex.Unlock()

	g.SetStatus("Stopping...")
	g.AddLog("Stop requested by user")

	// Cancel the sync context
	if g.syncCancel != nil {
		g.syncCancel()
	}
}

// onConfigClick handles the Config button click
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
			nil, nil, nil,
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

// onExitClick handles the Exit button click
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

// forceExit forces the application to exit
func (g *NativeGUI) forceExit() {
	if g.isRunning {
		g.cancelled = true
		if g.syncCancel != nil {
			g.syncCancel()
		}
		// Give it a moment to cleanup
		time.Sleep(500 * time.Millisecond)
	}
	g.app.Quit()
}

// SafeLogWriter is a custom log writer that captures logs safely
type SafeLogWriter struct {
	gui *NativeGUI
}

// Write implements io.Writer interface
func (w *SafeLogWriter) Write(p []byte) (n int, err error) {
	msg := string(p)
	msg = strings.TrimSpace(msg)

	if msg != "" {
		w.gui.AddLog(msg)
	}

	return len(p), nil
}

// runSync runs the synchronization process
func (g *NativeGUI) runSync() {
	// Ensure cleanup happens
	defer func() {
		if r := recover(); r != nil {
			g.AddLog(fmt.Sprintf("Sync crashed: %v", r))
		}

		g.mutex.Lock()
		g.isRunning = false
		g.mutex.Unlock()

		// Update UI
		g.UpdateRunningState(false)

		// Restore original log output
		log.SetOutput(os.Stdout)
	}()

	g.SetStatus("Running...")
	g.AddLog("Starting SFTP Sync...")

	// Set up log redirection
	originalOutput := log.Writer()
	logWriter := &SafeLogWriter{gui: g}
	log.SetOutput(logWriter)

	// Ensure we restore original output
	defer func() {
		log.SetOutput(originalOutput)
	}()

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

	// Run sync with context cancellation support
	err = syncer.SyncWithContext(g.syncCtx)

	// Update final status
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
}

// Run starts the GUI application
func (g *NativeGUI) Run() {
	g.window.ShowAndRun()
}

// mainNativeGUI is the entry point for the native GUI
func mainNativeGUI() {
	gui := NewNativeGUI()
	gui.Run()
}
