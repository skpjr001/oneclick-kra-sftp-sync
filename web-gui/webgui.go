package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

type WebGUI struct {
	ctx         context.Context
	cancel      context.CancelFunc
	isRunning   bool
	mutex       sync.RWMutex
	logs        []string
	logsMutex   sync.RWMutex
	status      string
	port        string
	syncProcess *SyncProcess
	cancelled   bool
}

type SyncProcess struct {
	syncer     *SFTPSync
	cancel     context.CancelFunc
	logRestore func()
	logPipe    *io.PipeWriter
	logReader  *io.PipeReader
	cancelled  bool
}

type StatusResponse struct {
	IsRunning bool     `json:"isRunning"`
	Status    string   `json:"status"`
	Logs      []string `json:"logs"`
}

type LogWriter struct {
	webGui *WebGUI
}

func (lw *LogWriter) Write(p []byte) (n int, err error) {
	msg := string(p)
	msg = strings.TrimSpace(msg)

	// Filter out error messages that happen after cancellation
	if lw.webGui.cancelled {
		if strings.Contains(msg, "connection lost") ||
			strings.Contains(msg, "failed to read directory") ||
			strings.Contains(msg, "Error scanning") {
			// Suppress these error messages after cancellation
			return len(p), nil
		}
	}

	if msg != "" {
		lw.webGui.AddLog(msg)
	}

	return len(p), nil
}

func NewWebGUI() *WebGUI {
	return &WebGUI{
		logs:   make([]string, 0),
		status: "Ready",
		port:   "8080",
	}
}

func (w *WebGUI) AddLog(msg string) {
	w.logsMutex.Lock()
	defer w.logsMutex.Unlock()

	// Clean up the message - remove extra newlines and timestamps
	msg = strings.TrimSpace(msg)
	if msg == "" {
		return
	}

	timestamp := time.Now().Format("15:04:05")
	logEntry := fmt.Sprintf("[%s] %s", timestamp, msg)
	w.logs = append(w.logs, logEntry)

	// Keep only last 500 log entries
	if len(w.logs) > 500 {
		w.logs = w.logs[len(w.logs)-500:]
	}
}

func (w *WebGUI) SetStatus(status string) {
	w.mutex.Lock()
	defer w.mutex.Unlock()
	w.status = status
}

func (w *WebGUI) GetStatus() StatusResponse {
	w.mutex.RLock()
	w.logsMutex.RLock()
	defer w.mutex.RUnlock()
	defer w.logsMutex.RUnlock()

	return StatusResponse{
		IsRunning: w.isRunning,
		Status:    w.status,
		Logs:      w.logs,
	}
}

func (w *WebGUI) indexHandler(rw http.ResponseWriter, r *http.Request) {
	htmlTemplate := `
<!DOCTYPE html>
<html>
<head>
    <title>SFTP Sync Tool</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .status { text-align: center; margin: 20px 0; }
        .status-text { font-size: 18px; font-weight: bold; padding: 10px; border-radius: 4px; }
        .status-ready { background-color: #d4edda; color: #155724; }
        .status-running { background-color: #d1ecf1; color: #0c5460; }
        .status-error { background-color: #f8d7da; color: #721c24; }
        .status-completed { background-color: #d4edda; color: #155724; }
        .buttons { text-align: center; margin: 20px 0; }
        button { padding: 10px 20px; margin: 0 5px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
        .btn-start { background-color: #28a745; color: white; }
        .btn-stop { background-color: #dc3545; color: white; }
        .btn-config { background-color: #17a2b8; color: white; }
        .btn-disabled { background-color: #6c757d; color: white; cursor: not-allowed; }
        .logs { margin-top: 20px; }
        .log-container { background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px; padding: 10px; height: 400px; overflow-y: auto; font-family: monospace; font-size: 14px; }
        .spinner { display: none; border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 20px; height: 20px; animation: spin 1s linear infinite; margin: 0 auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="container">
        <h1>SFTP Sync Tool</h1>

        <div class="status">
            <div id="status-text" class="status-text status-ready">Ready</div>
            <div id="spinner" class="spinner"></div>
        </div>

        <div class="buttons">
            <button id="start-btn" class="btn-start" onclick="startSync()">Start Sync</button>
            <button id="stop-btn" class="btn-stop btn-disabled" onclick="stopSync()" disabled>Stop</button>
            <button id="config-btn" class="btn-config" onclick="showConfig()">Config</button>
        </div>

        <div class="logs">
            <h3>Logs</h3>
            <div id="log-container" class="log-container"></div>
        </div>
    </div>

    <script>
        let isRunning = false;

        function updateStatus() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    isRunning = data.isRunning;

                    const statusText = document.getElementById('status-text');
                    const spinner = document.getElementById('spinner');
                    const startBtn = document.getElementById('start-btn');
                    const stopBtn = document.getElementById('stop-btn');

                    statusText.textContent = data.status;

                    if (data.isRunning) {
                        statusText.className = 'status-text status-running';
                        spinner.style.display = 'block';
                        startBtn.disabled = true;
                        startBtn.className = 'btn-disabled';
                        stopBtn.disabled = false;
                        stopBtn.className = 'btn-stop';
                    } else {
                        spinner.style.display = 'none';
                        startBtn.disabled = false;
                        startBtn.className = 'btn-start';
                        stopBtn.disabled = true;
                        stopBtn.className = 'btn-stop btn-disabled';

                        if (data.status === 'Completed') {
                            statusText.className = 'status-text status-completed';
                        } else if (data.status.includes('Error') || data.status === 'Failed') {
                            statusText.className = 'status-text status-error';
                        } else {
                            statusText.className = 'status-text status-ready';
                        }
                    }

                    // Update logs
                    const logContainer = document.getElementById('log-container');
                    logContainer.innerHTML = data.logs.join('<br>');
                    logContainer.scrollTop = logContainer.scrollHeight;
                });
        }

        function startSync() {
            if (isRunning) return;

            fetch('/api/start', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        updateStatus();
                    } else {
                        alert('Failed to start sync: ' + data.error);
                    }
                });
        }

        function stopSync() {
            if (!isRunning) return;

            fetch('/api/stop', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        updateStatus();
                    } else {
                        alert('Failed to stop sync: ' + data.error);
                    }
                });
        }

        function showConfig() {
            window.open('/config', '_blank');
        }

        // Update status every 2 seconds
        setInterval(updateStatus, 2000);

        // Initial status update
        updateStatus();
    </script>
</body>
</html>
`
	tmpl, _ := template.New("index").Parse(htmlTemplate)
	tmpl.Execute(rw, nil)
}

func (w *WebGUI) statusHandler(rw http.ResponseWriter, r *http.Request) {
	rw.Header().Set("Content-Type", "application/json")
	status := w.GetStatus()
	json.NewEncoder(rw).Encode(status)
}

func (w *WebGUI) startHandler(rw http.ResponseWriter, r *http.Request) {
	rw.Header().Set("Content-Type", "application/json")

	w.mutex.Lock()
	defer w.mutex.Unlock()

	if w.isRunning {
		json.NewEncoder(rw).Encode(map[string]interface{}{
			"success": false,
			"error":   "Sync is already running",
		})
		return
	}

	w.isRunning = true
	w.cancelled = false
	w.ctx, w.cancel = context.WithCancel(context.Background())
	w.status = "Starting..."

	go w.runSync()

	json.NewEncoder(rw).Encode(map[string]interface{}{
		"success": true,
	})
}

func (w *WebGUI) stopHandler(rw http.ResponseWriter, r *http.Request) {
	rw.Header().Set("Content-Type", "application/json")

	w.mutex.Lock()
	defer w.mutex.Unlock()

	if !w.isRunning {
		json.NewEncoder(rw).Encode(map[string]interface{}{
			"success": false,
			"error":   "Sync is not running",
		})
		return
	}

	w.status = "Stopping..."
	w.cancelled = true

	// Cancel the main context
	if w.cancel != nil {
		w.cancel()
	}

	// Also cancel the sync process directly
	if w.syncProcess != nil && w.syncProcess.cancel != nil {
		w.syncProcess.cancel()
		w.syncProcess.cancelled = true
	}

	json.NewEncoder(rw).Encode(map[string]interface{}{
		"success": true,
	})
}

func (w *WebGUI) configHandler(rw http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		// Show config editor
		configHTML := `
<!DOCTYPE html>
<html>
<head>
    <title>Configuration Editor</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        textarea { width: 100%; height: 400px; font-family: monospace; font-size: 14px; }
        button { padding: 10px 20px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; }
        .btn-save { background-color: #28a745; color: white; }
        .btn-cancel { background-color: #6c757d; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Configuration Editor</h1>
        <form id="config-form">
            <textarea id="config-text" placeholder="Loading configuration..."></textarea>
            <br>
            <button type="button" class="btn-save" onclick="saveConfig()">Save</button>
            <button type="button" class="btn-cancel" onclick="window.close()">Cancel</button>
        </form>
    </div>

    <script>
        // Load current config
        fetch('/api/config')
            .then(response => response.text())
            .then(data => {
                document.getElementById('config-text').value = data;
            });

        function saveConfig() {
            const configText = document.getElementById('config-text').value;

            fetch('/api/config', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ config: configText })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('Configuration saved successfully!');
                } else {
                    alert('Failed to save configuration: ' + data.error);
                }
            });
        }
    </script>
</body>
</html>
`
		rw.Header().Set("Content-Type", "text/html")
		rw.Write([]byte(configHTML))
	}
}

func (w *WebGUI) configAPIHandler(rw http.ResponseWriter, r *http.Request) {
	configPath := "config.json"

	if r.Method == "GET" {
		// Read config file
		content, err := os.ReadFile(configPath)
		if err != nil {
			http.Error(rw, "Failed to read config file", http.StatusInternalServerError)
			return
		}
		rw.Header().Set("Content-Type", "text/plain")
		rw.Write(content)
	} else if r.Method == "POST" {
		// Save config file
		var req struct {
			Config string `json:"config"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(rw, "Invalid request", http.StatusBadRequest)
			return
		}

		if err := os.WriteFile(configPath, []byte(req.Config), 0644); err != nil {
			json.NewEncoder(rw).Encode(map[string]interface{}{
				"success": false,
				"error":   err.Error(),
			})
			return
		}

		json.NewEncoder(rw).Encode(map[string]interface{}{
			"success": true,
		})
	}
}

func (w *WebGUI) runSync() {
	// Ensure cleanup happens no matter what
	defer func() {
		w.mutex.Lock()
		w.isRunning = false
		// Clean up sync process
		if w.syncProcess != nil {
			w.cleanupSyncProcess()
		}
		w.mutex.Unlock()
	}()

	w.SetStatus("Running...")
	w.AddLog("Starting SFTP Sync...")

	// Setup log redirection
	originalOut := log.Writer()

	// Create custom log writer that filters cancelled connection errors
	logWriter := &LogWriter{webGui: w}

	// Create sync process structure
	syncCtx, syncCancel := context.WithCancel(context.Background())
	w.syncProcess = &SyncProcess{
		cancel:    syncCancel,
		cancelled: false,
		logRestore: func() {
			log.SetOutput(originalOut)
		},
	}

	// Redirect log output
	log.SetOutput(logWriter)

	// No need for log reader goroutine since we're using custom writer
	logDone := make(chan struct{})
	close(logDone)

	// Load configuration
	configPath := "config.json"
	config, err := LoadConfig(configPath)
	if err != nil {
		w.AddLog(fmt.Sprintf("Failed to load configuration: %v", err))
		w.SetStatus("Error - Check config")
		return
	}

	// Convert configs
	sourceConfig := ConvertToSFTPConfig(config.Source)
	destConfig := ConvertToSFTPConfig(config.Destination)
	syncConfig := ConvertToSyncConfig(config.Sync)

	// Validate configuration
	if sourceConfig.Host == "" || sourceConfig.Username == "" {
		w.AddLog("Source SFTP configuration is incomplete")
		w.SetStatus("Error - Source config incomplete")
		return
	}
	if destConfig.Host == "" || destConfig.Username == "" {
		w.AddLog("Destination SFTP configuration is incomplete")
		w.SetStatus("Error - Dest config incomplete")
		return
	}

	w.AddLog(fmt.Sprintf("Source: %s@%s:%d", sourceConfig.Username, sourceConfig.Host, sourceConfig.Port))
	w.AddLog(fmt.Sprintf("Destination: %s@%s:%d", destConfig.Username, destConfig.Host, destConfig.Port))

	// Create syncer
	syncer := NewSFTPSync(sourceConfig, destConfig, syncConfig)
	w.syncProcess.syncer = syncer

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
				w.AddLog("Sync cancelled by user")
				w.SetStatus("Cancelled")
			} else {
				w.AddLog(fmt.Sprintf("Sync failed: %v", err))
				w.SetStatus("Failed")
			}
		} else {
			w.AddLog("Sync completed successfully!")
			w.SetStatus("Completed")
		}
	case <-w.ctx.Done():
		w.AddLog("Sync cancelled by user")
		w.SetStatus("Cancelled")
		// Cancel the sync context
		syncCancel()

		// Wait a bit for graceful shutdown
		select {
		case <-done:
			// Sync completed/failed
		case <-time.After(5 * time.Second):
			w.AddLog("Sync force-stopped after timeout")
		}
	case <-syncCtx.Done():
		w.AddLog("Sync cancelled")
		w.SetStatus("Cancelled")
	}

	// Clean up log redirection
	// Wait for log reader to finish
	select {
	case <-logDone:
		// Log cleanup finished normally
	case <-time.After(1 * time.Second):
		// Log cleanup timed out
	}
}

func (w *WebGUI) cleanupSyncProcess() {
	if w.syncProcess == nil {
		return
	}

	// Cancel the sync context
	if w.syncProcess.cancel != nil {
		w.syncProcess.cancel()
	}

	// Restore log output
	if w.syncProcess.logRestore != nil {
		w.syncProcess.logRestore()
	}

	w.syncProcess = nil
}

func (w *WebGUI) Start() {
	http.HandleFunc("/", w.indexHandler)
	http.HandleFunc("/api/status", w.statusHandler)
	http.HandleFunc("/api/start", w.startHandler)
	http.HandleFunc("/api/stop", w.stopHandler)
	http.HandleFunc("/config", w.configHandler)
	http.HandleFunc("/api/config", w.configAPIHandler)

	fmt.Printf("Starting Web GUI on http://localhost:%s\n", w.port)
	fmt.Println("Press Ctrl+C to stop the server")

	if err := http.ListenAndServe(":"+w.port, nil); err != nil {
		log.Fatal("Failed to start web server:", err)
	}
}

func mainWebGUI() {
	gui := NewWebGUI()
	gui.Start()
}
