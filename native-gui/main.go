package main

import (
	"context"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"hash"
	"io"
	"log"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

// SFTPConfig holds SFTP connection configuration
type SFTPConfig struct {
	Host      string
	Port      int
	Username  string
	Password  string
	KeyFile   string
	Timeout   time.Duration
	KeepAlive time.Duration
}

// FileInfo represents file metadata with hash
type FileInfo struct {
	Path         string
	Size         int64
	ModTime      time.Time
	Hash         string
	IsDirectory  bool
	RelativePath string
}

// DirectoryGraph represents a directory structure with file hashes
type DirectoryGraph struct {
	RootPath string
	Files    map[string]*FileInfo
	Dirs     map[string]bool
	mutex    sync.RWMutex
}

// SyncConfig holds synchronization configuration
type SyncConfig struct {
	SourcePath             string
	DestinationPath        string
	ExcludePatterns        []string
	MaxConcurrentTransfers int
	ChunkSize              int
	RetryAttempts          int
	RetryDelay             time.Duration
	VerifyTransfers        bool
	DaysToSync             int
}

// SyncStats holds synchronization statistics
type SyncStats struct {
	TotalFiles       int
	TransferredFiles int
	SkippedFiles     int
	FailedFiles      int
	TotalBytes       int64
	StartTime        time.Time
	Duration         time.Duration
	mutex            sync.RWMutex
}

// Config represents the complete configuration structure
type Config struct {
	Source      SFTPConfigJSON `json:"source"`
	Destination SFTPConfigJSON `json:"destination"`
	Sync        SyncConfigJSON `json:"sync"`
}

// SFTPConfigJSON represents SFTP configuration in JSON format
type SFTPConfigJSON struct {
	Host      string `json:"host"`
	Port      int    `json:"port"`
	Username  string `json:"username"`
	Password  string `json:"password"`
	KeyFile   string `json:"keyfile"`
	Timeout   int    `json:"timeout"`
	KeepAlive int    `json:"keepalive"`
}

// SyncConfigJSON represents sync configuration in JSON format
type SyncConfigJSON struct {
	SourcePath             string   `json:"source_path"`
	DestinationPath        string   `json:"destination_path"`
	ExcludePatterns        []string `json:"exclude_patterns"`
	MaxConcurrentTransfers int      `json:"max_concurrent_transfers"`
	ChunkSize              int      `json:"chunk_size"`
	RetryAttempts          int      `json:"retry_attempts"`
	RetryDelay             int      `json:"retry_delay"`
	VerifyTransfers        bool     `json:"verify_transfers"`
	DaysToSync             int      `json:"days_to_sync"`
}

// SFTPSync manages SFTP synchronization
type SFTPSync struct {
	SourceConfig      SFTPConfig
	DestinationConfig SFTPConfig
	SyncConfig        SyncConfig
	Stats             *SyncStats
	sourceClient      *sftp.Client
	destClient        *sftp.Client
	sourceSSH         *ssh.Client
	destSSH           *ssh.Client
}

// NewSFTPSync creates a new SFTP synchronization instance
func NewSFTPSync(sourceConfig, destConfig SFTPConfig, syncConfig SyncConfig) *SFTPSync {
	return &SFTPSync{
		SourceConfig:      sourceConfig,
		DestinationConfig: destConfig,
		SyncConfig:        syncConfig,
		Stats: &SyncStats{
			StartTime: time.Now(),
		},
	}
}

// Connect establishes connections to both SFTP servers
func (s *SFTPSync) Connect() error {
	var err error

	// Connect to source SFTP
	s.sourceSSH, s.sourceClient, err = s.connectSFTP(s.SourceConfig)
	if err != nil {
		return fmt.Errorf("failed to connect to source SFTP: %v", err)
	}
	log.Println("Connected to source SFTP server")

	// Connect to destination SFTP
	s.destSSH, s.destClient, err = s.connectSFTP(s.DestinationConfig)
	if err != nil {
		s.sourceClient.Close()
		s.sourceSSH.Close()
		return fmt.Errorf("failed to connect to destination SFTP: %v", err)
	}
	log.Println("Connected to destination SFTP server")

	return nil
}

// connectSFTP establishes a single SFTP connection
func (s *SFTPSync) connectSFTP(config SFTPConfig) (*ssh.Client, *sftp.Client, error) {
	var auth []ssh.AuthMethod

	if config.KeyFile != "" {
		key, err := os.ReadFile(config.KeyFile)
		if err != nil {
			return nil, nil, fmt.Errorf("unable to read private key: %v", err)
		}

		signer, err := ssh.ParsePrivateKey(key)
		if err != nil {
			return nil, nil, fmt.Errorf("unable to parse private key: %v", err)
		}
		auth = append(auth, ssh.PublicKeys(signer))
	}

	if config.Password != "" {
		auth = append(auth, ssh.Password(config.Password))
	}

	sshConfig := &ssh.ClientConfig{
		User:            config.Username,
		Auth:            auth,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         config.Timeout,
	}

	addr := fmt.Sprintf("%s:%d", config.Host, config.Port)
	sshClient, err := ssh.Dial("tcp", addr, sshConfig)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to dial SSH: %v", err)
	}

	// Setup keep-alive
	if config.KeepAlive > 0 {
		go func() {
			ticker := time.NewTicker(config.KeepAlive)
			defer ticker.Stop()
			for {
				select {
				case <-ticker.C:
					if sshClient != nil {
						sshClient.SendRequest("keepalive@openssh.com", true, nil)
					}
				}
			}
		}()
	}

	sftpClient, err := sftp.NewClient(sshClient)
	if err != nil {
		sshClient.Close()
		return nil, nil, fmt.Errorf("failed to create SFTP client: %v", err)
	}

	return sshClient, sftpClient, nil
}

// Close closes all SFTP connections
func (s *SFTPSync) Close() {
	if s.sourceClient != nil {
		s.sourceClient.Close()
	}
	if s.sourceSSH != nil {
		s.sourceSSH.Close()
	}
	if s.destClient != nil {
		s.destClient.Close()
	}
	if s.destSSH != nil {
		s.destSSH.Close()
	}
}

// generateDateDirectories generates directory names for the last N days
func (s *SFTPSync) generateDateDirectories(days int) []string {
	var dirs []string
	now := time.Now()

	for i := 0; i < days; i++ {
		date := now.AddDate(0, 0, -i)
		dirName := date.Format("02012006") // ddmmyyyy format
		dirs = append(dirs, dirName)
	}

	return dirs
}

// NewDirectoryGraph creates a new directory graph
func NewDirectoryGraph(rootPath string) *DirectoryGraph {
	return &DirectoryGraph{
		RootPath: rootPath,
		Files:    make(map[string]*FileInfo),
		Dirs:     make(map[string]bool),
	}
}

// AddFile adds a file to the directory graph
func (dg *DirectoryGraph) AddFile(fileInfo *FileInfo) {
	dg.mutex.Lock()
	defer dg.mutex.Unlock()
	dg.Files[fileInfo.Path] = fileInfo
}

// AddDir adds a directory to the directory graph
func (dg *DirectoryGraph) AddDir(dirPath string) {
	dg.mutex.Lock()
	defer dg.mutex.Unlock()
	dg.Dirs[dirPath] = true
}

// GetFile retrieves file info from the directory graph
func (dg *DirectoryGraph) GetFile(filePath string) (*FileInfo, bool) {
	dg.mutex.RLock()
	defer dg.mutex.RUnlock()
	file, exists := dg.Files[filePath]
	return file, exists
}

// GetFileCount returns the number of files in the graph
func (dg *DirectoryGraph) GetFileCount() int {
	dg.mutex.RLock()
	defer dg.mutex.RUnlock()
	return len(dg.Files)
}

// buildDirectoryGraph builds a directory graph for specified date directories
func (s *SFTPSync) buildDirectoryGraph(client *sftp.Client, rootPath string, dateDirs []string) (*DirectoryGraph, error) {
	return s.buildDirectoryGraphWithContext(context.Background(), client, rootPath, dateDirs)
}

func (s *SFTPSync) buildDirectoryGraphWithContextInternal(ctx context.Context, client *sftp.Client, rootPath string, dateDirs []string) (*DirectoryGraph, error) {
	graph := NewDirectoryGraph(rootPath)

	log.Printf("Building directory graph for %d date directories...", len(dateDirs))

	// Progress tracking
	var completed int32
	var totalFiles int32
	var totalDirs int32

	// Start progress reporter
	progressDone := make(chan struct{})
	startTime := time.Now()
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		lastFiles := int32(0)
		lastDirs := int32(0)

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				currentCompleted := atomic.LoadInt32(&completed)
				currentFiles := atomic.LoadInt32(&totalFiles)
				currentDirs := atomic.LoadInt32(&totalDirs)

				filesPerSec := float64(currentFiles-lastFiles) / 2.0
				dirsPerSec := float64(currentDirs-lastDirs) / 2.0

				// Calculate progress percentage and ETA
				progress := float64(currentCompleted) / float64(len(dateDirs)) * 100
				elapsed := time.Since(startTime)
				var eta string
				if currentCompleted > 0 {
					remainingTime := time.Duration(float64(elapsed) * (float64(len(dateDirs)) - float64(currentCompleted)) / float64(currentCompleted))
					eta = fmt.Sprintf("ETA: %s", remainingTime.Round(time.Second))
				} else {
					eta = "ETA: calculating..."
				}

				log.Printf("📊 Building Graph [%.1f%%] %d/%d dirs | Files: %d (%.1f/s) | Dirs: %d (%.1f/s) | %s",
					progress, currentCompleted, len(dateDirs), currentFiles, filesPerSec, currentDirs, dirsPerSec, eta)

				lastFiles = currentFiles
				lastDirs = currentDirs
			case <-progressDone:
				return
			}
		}
	}()

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, s.SyncConfig.MaxConcurrentTransfers)
	cancelled := make(chan struct{})

	// Monitor context cancellation
	go func() {
		<-ctx.Done()
		close(cancelled)
	}()

	for _, dateDir := range dateDirs {
		wg.Add(1)
		go func(dir string) {
			defer wg.Done()
			defer atomic.AddInt32(&completed, 1)

			select {
			case <-cancelled:
				return
			case semaphore <- struct{}{}:
				defer func() { <-semaphore }()

				fullPath := path.Join(rootPath, dir)
				if err := s.scanDirectory(client, fullPath, rootPath, graph, &totalFiles, &totalDirs); err != nil {
					log.Printf("Error scanning directory %s: %v", fullPath, err)
				}
			}
		}(dateDir)
	}

	// Wait for completion or cancellation
	waitDone := make(chan struct{})
	go func() {
		wg.Wait()
		close(waitDone)
	}()

	select {
	case <-waitDone:
		// Normal completion
	case <-ctx.Done():
		// Context cancelled, return early
		close(progressDone)
		return nil, ctx.Err()
	}

	close(progressDone)

	finalFiles := atomic.LoadInt32(&totalFiles)
	finalDirs := atomic.LoadInt32(&totalDirs)
	elapsed := time.Since(startTime)
	log.Printf("✅ Directory graph completed in %s: %d files, %d directories", elapsed.Round(time.Second), finalFiles, finalDirs)
	return graph, nil
}

// scanDirectory recursively scans a directory and builds the graph
func (s *SFTPSync) scanDirectory(client *sftp.Client, dirPath, rootPath string, graph *DirectoryGraph, totalFiles, totalDirs *int32) error {
	entries, err := client.ReadDir(dirPath)
	if err != nil {
		return fmt.Errorf("failed to read directory %s: %v", dirPath, err)
	}

	graph.AddDir(dirPath)
	atomic.AddInt32(totalDirs, 1)

	for _, entry := range entries {
		fullPath := path.Join(dirPath, entry.Name())

		if s.shouldExcludeFile(fullPath) {
			continue
		}

		if entry.IsDir() {
			if err := s.scanDirectory(client, fullPath, rootPath, graph, totalFiles, totalDirs); err != nil {
				log.Printf("Error scanning subdirectory %s: %v", fullPath, err)
			}
		} else {
			relativePath, _ := filepath.Rel(rootPath, fullPath)

			fileInfo := &FileInfo{
				Path:         fullPath,
				Size:         entry.Size(),
				ModTime:      entry.ModTime(),
				IsDirectory:  false,
				RelativePath: relativePath,
			}

			// Calculate hash for existing files (destination only)
			if client == s.destClient {
				hash, err := s.calculateRemoteFileHash(client, fullPath)
				if err != nil {
					log.Printf("Warning: Failed to calculate hash for %s: %v", fullPath, err)
				} else {
					fileInfo.Hash = hash
				}
			}

			graph.AddFile(fileInfo)
			atomic.AddInt32(totalFiles, 1)
		}
	}

	return nil
}

// shouldExcludeFile checks if a file should be excluded based on patterns
func (s *SFTPSync) shouldExcludeFile(filePath string) bool {
	baseName := filepath.Base(filePath)

	for _, pattern := range s.SyncConfig.ExcludePatterns {
		if strings.Contains(filePath, pattern) || strings.HasPrefix(baseName, pattern) {
			return true
		}
	}

	return false
}

// calculateRemoteFileHash calculates MD5 hash of a remote file
func (s *SFTPSync) calculateRemoteFileHash(client *sftp.Client, filePath string) (string, error) {
	file, err := client.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hasher := md5.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}

	return fmt.Sprintf("%x", hasher.Sum(nil)), nil
}

// compareGraphs compares source and destination graphs and returns files to sync
func (s *SFTPSync) compareGraphs(sourceGraph, destGraph *DirectoryGraph) []*FileInfo {
	var filesToSync []*FileInfo

	sourceGraph.mutex.RLock()
	destGraph.mutex.RLock()
	defer sourceGraph.mutex.RUnlock()
	defer destGraph.mutex.RUnlock()

	for _, sourceFile := range sourceGraph.Files {
		destPath := path.Join(s.SyncConfig.DestinationPath, sourceFile.RelativePath)

		if destFile, exists := destGraph.Files[destPath]; exists {
			// File exists in destination, check if it needs updating
			if sourceFile.Size != destFile.Size || sourceFile.ModTime.After(destFile.ModTime) {
				filesToSync = append(filesToSync, sourceFile)
			} else {
				s.Stats.mutex.Lock()
				s.Stats.SkippedFiles++
				s.Stats.mutex.Unlock()
			}
		} else {
			// File doesn't exist in destination
			filesToSync = append(filesToSync, sourceFile)
		}
	}

	// Sort files by size (smaller files first for better parallelism)
	sort.Slice(filesToSync, func(i, j int) bool {
		return filesToSync[i].Size < filesToSync[j].Size
	})

	return filesToSync
}

// syncFiles transfers files from source to destination
func (s *SFTPSync) syncFiles(filesToSync []*FileInfo) error {
	s.Stats.mutex.Lock()
	s.Stats.TotalFiles = len(filesToSync)
	s.Stats.mutex.Unlock()

	if len(filesToSync) == 0 {
		log.Println("No files to sync")
		return nil
	}

	log.Printf("Starting to sync %d files...", len(filesToSync))

	// Progress tracking for file sync
	var syncCompleted int32
	var syncBytes int64
	syncStartTime := time.Now()

	// Start sync progress reporter
	syncProgressDone := make(chan struct{})
	go func() {
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()
		lastCompleted := int32(0)
		lastBytes := int64(0)

		for {
			select {
			case <-ticker.C:
				currentCompleted := atomic.LoadInt32(&syncCompleted)
				currentBytes := atomic.LoadInt64(&syncBytes)

				filesPerSec := float64(currentCompleted-lastCompleted) / 3.0
				bytesPerSec := float64(currentBytes-lastBytes) / 3.0

				// Calculate progress percentage and ETA
				progress := float64(currentCompleted) / float64(len(filesToSync)) * 100
				elapsed := time.Since(syncStartTime)
				var eta string
				if currentCompleted > 0 {
					remainingTime := time.Duration(float64(elapsed) * (float64(len(filesToSync)) - float64(currentCompleted)) / float64(currentCompleted))
					eta = fmt.Sprintf("ETA: %s", remainingTime.Round(time.Second))
				} else {
					eta = "ETA: calculating..."
				}

				// Format bytes
				var bytesStr string
				if currentBytes > 1024*1024*1024 {
					bytesStr = fmt.Sprintf("%.2f GB", float64(currentBytes)/(1024*1024*1024))
				} else if currentBytes > 1024*1024 {
					bytesStr = fmt.Sprintf("%.2f MB", float64(currentBytes)/(1024*1024))
				} else if currentBytes > 1024 {
					bytesStr = fmt.Sprintf("%.2f KB", float64(currentBytes)/1024)
				} else {
					bytesStr = fmt.Sprintf("%d bytes", currentBytes)
				}

				var speedStr string
				if bytesPerSec > 1024*1024 {
					speedStr = fmt.Sprintf("%.2f MB/s", bytesPerSec/(1024*1024))
				} else if bytesPerSec > 1024 {
					speedStr = fmt.Sprintf("%.2f KB/s", bytesPerSec/1024)
				} else {
					speedStr = fmt.Sprintf("%.0f B/s", bytesPerSec)
				}

				log.Printf("🚀 Syncing Files [%.1f%%] %d/%d files | %s transferred | %.1f files/s | %s | %s",
					progress, currentCompleted, len(filesToSync), bytesStr, filesPerSec, speedStr, eta)

				lastCompleted = currentCompleted
				lastBytes = currentBytes
			case <-syncProgressDone:
				return
			}
		}
	}()

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, s.SyncConfig.MaxConcurrentTransfers)

	for _, file := range filesToSync {
		wg.Add(1)
		go func(f *FileInfo) {
			defer wg.Done()
			defer atomic.AddInt32(&syncCompleted, 1)

			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			if err := s.transferFile(f); err != nil {
				log.Printf("Failed to transfer %s: %v", f.Path, err)
				s.Stats.mutex.Lock()
				s.Stats.FailedFiles++
				s.Stats.mutex.Unlock()
			} else {
				s.Stats.mutex.Lock()
				s.Stats.TransferredFiles++
				s.Stats.TotalBytes += f.Size
				s.Stats.mutex.Unlock()
				atomic.AddInt64(&syncBytes, f.Size)
			}
		}(file)
	}

	wg.Wait()
	close(syncProgressDone)

	// Final sync summary
	finalCompleted := atomic.LoadInt32(&syncCompleted)
	finalBytes := atomic.LoadInt64(&syncBytes)
	syncElapsed := time.Since(syncStartTime)

	var finalBytesStr string
	if finalBytes > 1024*1024*1024 {
		finalBytesStr = fmt.Sprintf("%.2f GB", float64(finalBytes)/(1024*1024*1024))
	} else if finalBytes > 1024*1024 {
		finalBytesStr = fmt.Sprintf("%.2f MB", float64(finalBytes)/(1024*1024))
	} else if finalBytes > 1024 {
		finalBytesStr = fmt.Sprintf("%.2f KB", float64(finalBytes)/1024)
	} else {
		finalBytesStr = fmt.Sprintf("%d bytes", finalBytes)
	}

	log.Printf("✅ File sync completed in %s: %d files, %s transferred",
		syncElapsed.Round(time.Second), finalCompleted, finalBytesStr)
	return nil
}

// transferFile transfers a single file with verification
func (s *SFTPSync) transferFile(file *FileInfo) error {
	destPath := path.Join(s.SyncConfig.DestinationPath, file.RelativePath)
	tempPath := destPath + ".tmp"

	// Create destination directory if it doesn't exist
	destDir := path.Dir(destPath)
	if err := s.destClient.MkdirAll(destDir); err != nil {
		return fmt.Errorf("failed to create destination directory %s: %v", destDir, err)
	}

	// Retry logic
	var lastErr error
	for attempt := 0; attempt < s.SyncConfig.RetryAttempts; attempt++ {
		if attempt > 0 {
			log.Printf("Retrying transfer of %s (attempt %d/%d)", file.Path, attempt+1, s.SyncConfig.RetryAttempts)
			time.Sleep(s.SyncConfig.RetryDelay)
		}

		// Open source file
		srcFile, err := s.sourceClient.Open(file.Path)
		if err != nil {
			lastErr = fmt.Errorf("failed to open source file: %v", err)
			continue
		}

		// Create destination file
		destFile, err := s.destClient.Create(tempPath)
		if err != nil {
			srcFile.Close()
			lastErr = fmt.Errorf("failed to create destination file: %v", err)
			continue
		}

		// Copy with progress tracking
		var srcHasher, destHasher hash.Hash
		if s.SyncConfig.VerifyTransfers {
			srcHasher = md5.New()
			destHasher = md5.New()
		}

		var written int64
		buffer := make([]byte, s.SyncConfig.ChunkSize)

		for {
			n, readErr := srcFile.Read(buffer)
			if n > 0 {
				// Write to destination
				if _, writeErr := destFile.Write(buffer[:n]); writeErr != nil {
					srcFile.Close()
					destFile.Close()
					s.destClient.Remove(tempPath)
					lastErr = fmt.Errorf("failed to write to destination: %v", writeErr)
					break
				}

				// Update hashes if verification is enabled
				if s.SyncConfig.VerifyTransfers {
					srcHasher.Write(buffer[:n])
					destHasher.Write(buffer[:n])
				}

				written += int64(n)
			}

			if readErr != nil {
				if readErr == io.EOF {
					break
				}
				srcFile.Close()
				destFile.Close()
				s.destClient.Remove(tempPath)
				lastErr = fmt.Errorf("failed to read from source: %v", readErr)
				break
			}
		}

		srcFile.Close()
		destFile.Close()

		if lastErr != nil {
			continue
		}

		// Verify file integrity if enabled
		if s.SyncConfig.VerifyTransfers {
			srcHash := fmt.Sprintf("%x", srcHasher.Sum(nil))
			destHash := fmt.Sprintf("%x", destHasher.Sum(nil))

			if srcHash != destHash {
				s.destClient.Remove(tempPath)
				lastErr = fmt.Errorf("hash verification failed: src=%s, dest=%s", srcHash, destHash)
				continue
			}
		}

		// Atomic rename to final destination
		if err := s.destClient.Rename(tempPath, destPath); err != nil {
			s.destClient.Remove(tempPath)
			lastErr = fmt.Errorf("failed to rename temporary file: %v", err)
			continue
		}

		// Set file times to match source
		if err := s.destClient.Chtimes(destPath, file.ModTime, file.ModTime); err != nil {
			log.Printf("Warning: Failed to set modification time for %s: %v", destPath, err)
		}

		log.Printf("Successfully transferred: %s (%d bytes)", file.RelativePath, written)
		return nil
	}

	return fmt.Errorf("transfer failed after %d attempts: %v", s.SyncConfig.RetryAttempts, lastErr)
}

// Sync performs the complete synchronization process
func (s *SFTPSync) Sync() error {
	return s.SyncWithContext(context.Background())
}

func (s *SFTPSync) SyncWithContext(ctx context.Context) error {
	if err := s.Connect(); err != nil {
		return err
	}
	defer s.Close()

	// Check for cancellation
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// Generate date directories for the last N days
	dateDirs := s.generateDateDirectories(s.SyncConfig.DaysToSync)
	log.Printf("Syncing directories for last %d days: %v", s.SyncConfig.DaysToSync, dateDirs)

	// Build destination directory graph first (for comparison)
	log.Println("Building destination directory graph...")
	destGraph, err := s.buildDirectoryGraphWithContext(ctx, s.destClient, s.SyncConfig.DestinationPath, dateDirs)
	if err != nil {
		return fmt.Errorf("failed to build destination graph: %v", err)
	}

	// Check for cancellation
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// Build source directory graph
	log.Println("Building source directory graph...")
	sourceGraph, err := s.buildDirectoryGraphWithContext(ctx, s.sourceClient, s.SyncConfig.SourcePath, dateDirs)
	if err != nil {
		return fmt.Errorf("failed to build source graph: %v", err)
	}

	// Check for cancellation
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// Compare graphs and get files to sync
	log.Println("🔍 Comparing directory graphs...")
	filesToSync := s.compareGraphs(sourceGraph, destGraph)

	if len(filesToSync) == 0 {
		log.Println("✅ No files need synchronization - everything is up to date!")
	} else {
		log.Printf("📋 Found %d files to synchronize", len(filesToSync))
	}

	// Sync files
	if err := s.syncFilesWithContext(ctx, filesToSync); err != nil {
		return fmt.Errorf("failed to sync files: %v", err)
	}

	// Calculate final statistics
	s.Stats.mutex.Lock()
	s.Stats.Duration = time.Since(s.Stats.StartTime)
	s.Stats.mutex.Unlock()

	s.printStats()
	return nil
}

func (s *SFTPSync) buildDirectoryGraphWithContext(ctx context.Context, client *sftp.Client, basePath string, dateDirs []string) (*DirectoryGraph, error) {
	// Check for cancellation
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}

	// Use context-aware implementation
	return s.buildDirectoryGraphWithContextInternal(ctx, client, basePath, dateDirs)
}

func (s *SFTPSync) syncFilesWithContext(ctx context.Context, filesToSync []*FileInfo) error {
	// Check for cancellation
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	if len(filesToSync) == 0 {
		return nil
	}

	s.Stats.mutex.Lock()
	s.Stats.StartTime = time.Now()
	s.Stats.TotalFiles = len(filesToSync)
	s.Stats.mutex.Unlock()

	// Create a buffered channel for file transfer tasks
	tasks := make(chan *FileInfo, len(filesToSync))
	for _, file := range filesToSync {
		tasks <- file
	}
	close(tasks)

	// Create worker goroutines for concurrent transfers
	var wg sync.WaitGroup
	workers := s.SyncConfig.MaxConcurrentTransfers
	if workers <= 0 {
		workers = 1
	}

	// Use a separate context for workers that can be cancelled
	workerCtx, workerCancel := context.WithCancel(ctx)
	defer workerCancel()

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-workerCtx.Done():
					return
				case file, ok := <-tasks:
					if !ok {
						return // Channel closed, no more tasks
					}

					// Check for cancellation before each file
					select {
					case <-workerCtx.Done():
						return
					default:
					}

					if err := s.transferFile(file); err != nil {
						log.Printf("❌ Failed to transfer %s: %v", file.RelativePath, err)
						s.Stats.mutex.Lock()
						s.Stats.FailedFiles++
						s.Stats.mutex.Unlock()
					} else {
						s.Stats.mutex.Lock()
						s.Stats.TransferredFiles++
						s.Stats.TotalBytes += file.Size
						s.Stats.mutex.Unlock()
					}
				}
			}
		}()
	}

	// Wait for all workers to complete or context cancellation
	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		// All workers completed
		return nil
	case <-ctx.Done():
		// Context cancelled, signal workers to stop
		workerCancel()
		// Wait for workers to finish with timeout
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			log.Println("⚠️  Workers did not finish within timeout")
		}
		return ctx.Err()
	}
}

// printStats prints synchronization statistics
func (s *SFTPSync) printStats() {
	s.Stats.mutex.RLock()
	defer s.Stats.mutex.RUnlock()

	log.Println(strings.Repeat("=", 60))
	log.Println("🎉 SYNCHRONIZATION COMPLETED!")
	log.Println(strings.Repeat("=", 60))

	// Format total bytes
	var totalBytesStr string
	if s.Stats.TotalBytes > 1024*1024*1024 {
		totalBytesStr = fmt.Sprintf("%.2f GB", float64(s.Stats.TotalBytes)/(1024*1024*1024))
	} else if s.Stats.TotalBytes > 1024*1024 {
		totalBytesStr = fmt.Sprintf("%.2f MB", float64(s.Stats.TotalBytes)/(1024*1024))
	} else if s.Stats.TotalBytes > 1024 {
		totalBytesStr = fmt.Sprintf("%.2f KB", float64(s.Stats.TotalBytes)/1024)
	} else {
		totalBytesStr = fmt.Sprintf("%d bytes", s.Stats.TotalBytes)
	}

	log.Printf("📊 STATISTICS:")
	log.Printf("   📁 Total files processed: %d", s.Stats.TotalFiles)
	log.Printf("   ✅ Successfully transferred: %d", s.Stats.TransferredFiles)
	log.Printf("   ⏭️  Skipped (up-to-date): %d", s.Stats.SkippedFiles)
	log.Printf("   ❌ Failed transfers: %d", s.Stats.FailedFiles)
	log.Printf("   📦 Total data transferred: %s", totalBytesStr)
	log.Printf("   ⏱️  Total duration: %v", s.Stats.Duration.Round(time.Second))

	if s.Stats.Duration > 0 && s.Stats.TotalBytes > 0 {
		throughput := float64(s.Stats.TotalBytes) / s.Stats.Duration.Seconds()
		var throughputStr string
		if throughput > 1024*1024 {
			throughputStr = fmt.Sprintf("%.2f MB/s", throughput/(1024*1024))
		} else if throughput > 1024 {
			throughputStr = fmt.Sprintf("%.2f KB/s", throughput/1024)
		} else {
			throughputStr = fmt.Sprintf("%.0f B/s", throughput)
		}
		log.Printf("   🚀 Average throughput: %s", throughputStr)
	}

	// Success rate
	if s.Stats.TotalFiles > 0 {
		successRate := float64(s.Stats.TransferredFiles) / float64(s.Stats.TotalFiles) * 100
		log.Printf("   📈 Success rate: %.1f%%", successRate)
	}

	log.Println(strings.Repeat("=", 60))
}

// Configuration example
func main() {
	// Check if GUI mode is requested
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--gui":
			mainWebGUI()
			return
		case "--native":
			mainNativeGUI()
			return
		case "--native-gui":
			mainNativeGUI()
			return
		}
	}

	// Run CLI mode
	mainCLI()
}

func mainCLI() {
	log.Println("Starting SFTP Sync Tool")

	// Load configuration from config.json or environment variables
	configPath := "config.json"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}

	config, err := LoadConfig(configPath)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Convert JSON config to internal config structures
	sourceConfig := ConvertToSFTPConfig(config.Source)
	destConfig := ConvertToSFTPConfig(config.Destination)
	syncConfig := ConvertToSyncConfig(config.Sync)

	// Validate required configuration
	if sourceConfig.Host == "" || sourceConfig.Username == "" {
		log.Fatal("Source SFTP configuration is incomplete (host and username are required)")
	}
	if destConfig.Host == "" || destConfig.Username == "" {
		log.Fatal("Destination SFTP configuration is incomplete (host and username are required)")
	}
	if sourceConfig.Password == "" && sourceConfig.KeyFile == "" {
		log.Fatal("Source SFTP requires either password or key file")
	}
	if destConfig.Password == "" && destConfig.KeyFile == "" {
		log.Fatal("Destination SFTP requires either password or key file")
	}

	log.Printf("Source: %s@%s:%d -> %s", sourceConfig.Username, sourceConfig.Host, sourceConfig.Port, syncConfig.SourcePath)
	log.Printf("Destination: %s@%s:%d -> %s", destConfig.Username, destConfig.Host, destConfig.Port, syncConfig.DestinationPath)
	log.Printf("Sync configuration: %d days, %d concurrent transfers, verify: %v", syncConfig.DaysToSync, syncConfig.MaxConcurrentTransfers, syncConfig.VerifyTransfers)

	syncer := NewSFTPSync(sourceConfig, destConfig, syncConfig)
	if err := syncer.Sync(); err != nil {
		log.Fatalf("Sync failed: %v", err)
	}
}

// LoadConfig loads configuration from JSON file with environment variable fallback
func LoadConfig(configPath string) (*Config, error) {
	config := &Config{}

	// First try to load from JSON file
	if _, err := os.Stat(configPath); err == nil {
		log.Printf("Loading configuration from %s", configPath)
		data, err := os.ReadFile(configPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}

		if err := json.Unmarshal(data, config); err != nil {
			return nil, fmt.Errorf("failed to parse config file: %w", err)
		}

		log.Println("Configuration loaded from JSON file")
	} else {
		log.Printf("Config file %s not found, using environment variables", configPath)
	}

	// Override with environment variables if they exist
	loadFromEnv(config)

	return config, nil
}

// loadFromEnv loads configuration from environment variables
func loadFromEnv(config *Config) {
	// Source SFTP configuration
	if host := os.Getenv("SOURCE_HOST"); host != "" {
		config.Source.Host = host
	}
	if port := os.Getenv("SOURCE_PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			config.Source.Port = p
		}
	}
	if username := os.Getenv("SOURCE_USERNAME"); username != "" {
		config.Source.Username = username
	}
	if password := os.Getenv("SOURCE_PASSWORD"); password != "" {
		config.Source.Password = password
	}
	if keyfile := os.Getenv("SOURCE_KEYFILE"); keyfile != "" {
		config.Source.KeyFile = keyfile
	}
	if timeout := os.Getenv("SOURCE_TIMEOUT"); timeout != "" {
		if t, err := strconv.Atoi(timeout); err == nil {
			config.Source.Timeout = t
		}
	}
	if keepalive := os.Getenv("SOURCE_KEEPALIVE"); keepalive != "" {
		if k, err := strconv.Atoi(keepalive); err == nil {
			config.Source.KeepAlive = k
		}
	}

	// Destination SFTP configuration
	if host := os.Getenv("DEST_HOST"); host != "" {
		config.Destination.Host = host
	}
	if port := os.Getenv("DEST_PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			config.Destination.Port = p
		}
	}
	if username := os.Getenv("DEST_USERNAME"); username != "" {
		config.Destination.Username = username
	}
	if password := os.Getenv("DEST_PASSWORD"); password != "" {
		config.Destination.Password = password
	}
	if keyfile := os.Getenv("DEST_KEYFILE"); keyfile != "" {
		config.Destination.KeyFile = keyfile
	}
	if timeout := os.Getenv("DEST_TIMEOUT"); timeout != "" {
		if t, err := strconv.Atoi(timeout); err == nil {
			config.Destination.Timeout = t
		}
	}
	if keepalive := os.Getenv("DEST_KEEPALIVE"); keepalive != "" {
		if k, err := strconv.Atoi(keepalive); err == nil {
			config.Destination.KeepAlive = k
		}
	}

	// Sync configuration
	if sourcePath := os.Getenv("SOURCE_PATH"); sourcePath != "" {
		config.Sync.SourcePath = sourcePath
	}
	if destPath := os.Getenv("DEST_PATH"); destPath != "" {
		config.Sync.DestinationPath = destPath
	}
	if excludePatterns := os.Getenv("EXCLUDE_PATTERNS"); excludePatterns != "" {
		config.Sync.ExcludePatterns = strings.Split(excludePatterns, ",")
	}
	if maxConcurrent := os.Getenv("MAX_CONCURRENT_TRANSFERS"); maxConcurrent != "" {
		if m, err := strconv.Atoi(maxConcurrent); err == nil {
			config.Sync.MaxConcurrentTransfers = m
		}
	}
	if chunkSize := os.Getenv("CHUNK_SIZE"); chunkSize != "" {
		if c, err := strconv.Atoi(chunkSize); err == nil {
			config.Sync.ChunkSize = c
		}
	}
	if retryAttempts := os.Getenv("RETRY_ATTEMPTS"); retryAttempts != "" {
		if r, err := strconv.Atoi(retryAttempts); err == nil {
			config.Sync.RetryAttempts = r
		}
	}
	if retryDelay := os.Getenv("RETRY_DELAY"); retryDelay != "" {
		if r, err := strconv.Atoi(retryDelay); err == nil {
			config.Sync.RetryDelay = r
		}
	}
	if verifyTransfers := os.Getenv("VERIFY_TRANSFERS"); verifyTransfers != "" {
		if v, err := strconv.ParseBool(verifyTransfers); err == nil {
			config.Sync.VerifyTransfers = v
		}
	}
	if daysToSync := os.Getenv("DAYS_TO_SYNC"); daysToSync != "" {
		if d, err := strconv.Atoi(daysToSync); err == nil {
			config.Sync.DaysToSync = d
		}
	}

	log.Println("Configuration loaded from environment variables")
}

// ConvertToSFTPConfig converts JSON config to internal SFTP config
func ConvertToSFTPConfig(jsonConfig SFTPConfigJSON) SFTPConfig {
	return SFTPConfig{
		Host:      jsonConfig.Host,
		Port:      jsonConfig.Port,
		Username:  jsonConfig.Username,
		Password:  jsonConfig.Password,
		KeyFile:   jsonConfig.KeyFile,
		Timeout:   time.Duration(jsonConfig.Timeout) * time.Second,
		KeepAlive: time.Duration(jsonConfig.KeepAlive) * time.Second,
	}
}

// ConvertToSyncConfig converts JSON config to internal sync config
func ConvertToSyncConfig(jsonConfig SyncConfigJSON) SyncConfig {
	return SyncConfig{
		SourcePath:             jsonConfig.SourcePath,
		DestinationPath:        jsonConfig.DestinationPath,
		ExcludePatterns:        jsonConfig.ExcludePatterns,
		MaxConcurrentTransfers: jsonConfig.MaxConcurrentTransfers,
		ChunkSize:              jsonConfig.ChunkSize,
		RetryAttempts:          jsonConfig.RetryAttempts,
		RetryDelay:             time.Duration(jsonConfig.RetryDelay) * time.Second,
		VerifyTransfers:        jsonConfig.VerifyTransfers,
		DaysToSync:             jsonConfig.DaysToSync,
	}
}
