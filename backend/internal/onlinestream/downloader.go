package onlinestream

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"seanime/internal/database/db"
	"seanime/internal/database/db_bridge"
	"seanime/internal/events"
	"seanime/internal/notifier"
	"seanime/internal/util"

	"github.com/rs/zerolog"
)

var (
	ErrAlreadyDownloading = errors.New("episode is already downloading")
	ErrTaskNotFound       = errors.New("download task not found")
	ErrNoVideoURL         = errors.New("video URL is required")
	ErrNoLibraryPath      = errors.New("no library path configured on server")
	ErrFFmpegNotFound     = errors.New("ffmpeg is not installed on the server host")

	sanitizerRegex = regexp.MustCompile(`[\\/:*?"<>|\r\n\t]`)
)

type DownloadTaskStatus string

const (
	DownloadStatusQueued      DownloadTaskStatus = "queued"
	DownloadStatusDownloading DownloadTaskStatus = "downloading"
	DownloadStatusCompleted   DownloadTaskStatus = "completed"
	DownloadStatusFailed      DownloadTaskStatus = "failed"
	DownloadStatusCancelled   DownloadTaskStatus = "cancelled"
)

type DownloadTask struct {
	ID              string             `json:"id"`
	MediaID         int                `json:"mediaId"`
	EpisodeNumber   int                `json:"episodeNumber"`
	AnimeTitle      string             `json:"animeTitle"`
	EpisodeTitle    string             `json:"episodeTitle"`
	Thumbnail       string             `json:"thumbnail,omitempty"`
	ProviderID      string             `json:"providerId"`
	ProviderName    string             `json:"providerName"`
	Server          string             `json:"server"`
	Quality         string             `json:"quality"`
	VideoURL        string             `json:"videoUrl"`
	Headers         map[string]string  `json:"headers,omitempty"`
	IsHLS           bool               `json:"isHls"`
	SavePath        string             `json:"savePath"`
	Destination     string             `json:"destination"`
	Subtitles       []*Subtitle        `json:"subtitles,omitempty"`
	Status          DownloadTaskStatus `json:"status"`
	Progress        float64            `json:"progress"`
	DownloadedBytes int64              `json:"downloadedBytes"`
	Speed           string             `json:"speed"`
	ETA             string             `json:"eta"`
	Error           string             `json:"error,omitempty"`
	CreatedAt       time.Time          `json:"createdAt"`
	CompletedAt     *time.Time         `json:"completedAt,omitempty"`
}

type StartDownloadOptions struct {
	MediaID       int               `json:"mediaId"`
	EpisodeNumber int               `json:"episodeNumber"`
	AnimeTitle    string            `json:"animeTitle"`
	EpisodeTitle  string            `json:"episodeTitle"`
	Thumbnail     string            `json:"thumbnail,omitempty"`
	ProviderID    string            `json:"providerId"`
	ProviderName  string            `json:"providerName"`
	Server        string            `json:"server"`
	Quality       string            `json:"quality"`
	VideoURL      string            `json:"videoUrl"`
	Headers       map[string]string `json:"headers,omitempty"`
	IsHLS         bool              `json:"isHls"`
	Destination   string            `json:"destination,omitempty"`
	Subtitles     []*Subtitle       `json:"subtitles,omitempty"`
}

type NewDownloaderOptions struct {
	Logger         *zerolog.Logger
	WSEventManager *events.WSEventManager
	Database       *db.Database
	GetLibraryPath func() string
	OnCompleted    func(task *DownloadTask)
}

type Downloader struct {
	opts       *NewDownloaderOptions
	logger     *zerolog.Logger
	mu         sync.RWMutex
	tasks      map[string]*DownloadTask
	cancels    map[string]context.CancelFunc
	ffmpegPath string
}

func NewDownloader(opts *NewDownloaderOptions) *Downloader {
	ffmpegPath, _ := exec.LookPath("ffmpeg")
	if ffmpegPath == "" {
		ffmpegPath = "ffmpeg"
	}

	return &Downloader{
		opts:       opts,
		logger:     opts.Logger,
		tasks:      make(map[string]*DownloadTask),
		cancels:    make(map[string]context.CancelFunc),
		ffmpegPath: ffmpegPath,
	}
}

// StartDownload queues and executes an online stream download on the server.
func (d *Downloader) StartDownload(opts StartDownloadOptions) (*DownloadTask, error) {
	if opts.VideoURL == "" {
		return nil, ErrNoVideoURL
	}

	taskId := fmt.Sprintf("%d_%d", opts.MediaID, opts.EpisodeNumber)

	d.mu.Lock()
	if existing, ok := d.tasks[taskId]; ok && existing.Status == DownloadStatusDownloading {
		d.mu.Unlock()
		return nil, ErrAlreadyDownloading
	}

	cleanTitle := sanitizeName(opts.AnimeTitle)
	if cleanTitle == "" {
		cleanTitle = fmt.Sprintf("Anime_%d", opts.MediaID)
	}

	// 1. Resolve destination directory
	destDir := opts.Destination
	if destDir == "" || !filepath.IsAbs(destDir) {
		destDir = d.resolveDestination(opts.MediaID, cleanTitle)
	}

	if destDir == "" {
		d.mu.Unlock()
		return nil, ErrNoLibraryPath
	}

	// Ensure destination directory exists on host
	if err := os.MkdirAll(destDir, 0755); err != nil {
		d.mu.Unlock()
		return nil, fmt.Errorf("failed to create destination directory: %w", err)
	}

	fileName := fmt.Sprintf("%s - %02d.mp4", cleanTitle, opts.EpisodeNumber)
	savePath := filepath.Join(destDir, fileName)

	task := &DownloadTask{
		ID:            taskId,
		MediaID:       opts.MediaID,
		EpisodeNumber: opts.EpisodeNumber,
		AnimeTitle:    opts.AnimeTitle,
		EpisodeTitle:  opts.EpisodeTitle,
		Thumbnail:     opts.Thumbnail,
		ProviderID:    opts.ProviderID,
		ProviderName:  opts.ProviderName,
		Server:        opts.Server,
		Quality:       opts.Quality,
		VideoURL:      opts.VideoURL,
		Headers:       opts.Headers,
		IsHLS:         opts.IsHLS,
		SavePath:      savePath,
		Destination:   destDir,
		Subtitles:     opts.Subtitles,
		Status:        DownloadStatusDownloading,
		CreatedAt:     time.Now(),
	}

	ctx, cancel := context.WithCancel(context.Background())
	d.tasks[taskId] = task
	d.cancels[taskId] = cancel
	d.mu.Unlock()

	d.broadcastQueue()

	go d.runDownload(ctx, task, cleanTitle)

	return task, nil
}

func (d *Downloader) resolveDestination(mediaID int, cleanTitle string) string {
	// Look up existing anime path from database local files
	if mediaID > 0 && d.opts.Database != nil {
		if localFiles, _, err := db_bridge.GetLocalFiles(d.opts.Database); err == nil {
			for _, lf := range localFiles {
				if lf.MediaId == mediaID && lf.Path != "" {
					dir := filepath.Dir(lf.Path)
					if dir != "" && dir != "." {
						return dir
					}
				}
			}
		}
	}

	// Fallback to configured LibraryPath
	if d.opts.GetLibraryPath != nil {
		libPath := d.opts.GetLibraryPath()
		if libPath != "" {
			return filepath.Join(libPath, cleanTitle)
		}
	}

	return ""
}

func (d *Downloader) runDownload(ctx context.Context, task *DownloadTask, cleanTitle string) {
	defer util.HandlePanicInModuleThen("onlinestream/runDownload", func() {
		d.failTask(task.ID, "internal error during download")
	})

	tempPath := task.SavePath + ".part"
	_ = os.Remove(tempPath)

	err := d.executeFfmpeg(ctx, task, tempPath, true)
	// If failed on HLS with aac_adtstoasc bitstream filter, try once without it
	if err != nil && ctx.Err() == nil && task.IsHLS {
		d.logger.Warn().Err(err).Msg("onlinestream: ffmpeg failed with bitstream filter, retrying without filter")
		_ = os.Remove(tempPath)
		err = d.executeFfmpeg(ctx, task, tempPath, false)
	}

	if ctx.Err() != nil {
		_ = os.Remove(tempPath)
		d.mu.Lock()
		task.Status = DownloadStatusCancelled
		delete(d.cancels, task.ID)
		d.mu.Unlock()
		d.broadcastQueue()
		return
	}

	if err != nil {
		_ = os.Remove(tempPath)
		d.failTask(task.ID, err.Error())
		return
	}

	// Validate output file
	fi, statErr := os.Stat(tempPath)
	if statErr != nil || fi.Size() < 1000 {
		_ = os.Remove(tempPath)
		d.failTask(task.ID, "downloaded file is empty or corrupted")
		return
	}

	// Rename temp file to final save path
	if err := os.Rename(tempPath, task.SavePath); err != nil {
		_ = os.Remove(tempPath)
		d.failTask(task.ID, fmt.Sprintf("failed to save final file: %v", err))
		return
	}

	// Download any subtitles alongside video
	baseFileName := strings.TrimSuffix(filepath.Base(task.SavePath), filepath.Ext(task.SavePath))
	d.downloadSubtitles(task, task.Destination, baseFileName)

	now := time.Now()
	d.mu.Lock()
	task.Status = DownloadStatusCompleted
	task.Progress = 1.0
	task.Speed = ""
	task.ETA = ""
	task.CompletedAt = &now
	delete(d.cancels, task.ID)
	d.mu.Unlock()

	d.logger.Info().Str("path", task.SavePath).Msg("onlinestream: Download completed")
	d.broadcastQueue()

	if d.opts.WSEventManager != nil {
		msg := fmt.Sprintf("Downloaded %s Ep. %d", task.AnimeTitle, task.EpisodeNumber)
		d.opts.WSEventManager.SendEvent(events.SuccessToast, msg)
	}
	notifier.GlobalNotifier.Notify(notifier.AutoScanner, fmt.Sprintf("Downloaded %s Ep. %d", task.AnimeTitle, task.EpisodeNumber))

	if d.opts.OnCompleted != nil {
		d.opts.OnCompleted(task)
	}
}

func (d *Downloader) executeFfmpeg(ctx context.Context, task *DownloadTask, tempPath string, useAacFilter bool) error {
	args := []string{
		"-y",
		"-loglevel", "error",
	}

	if len(task.Headers) > 0 {
		var headersList []string
		for k, v := range task.Headers {
			headersList = append(headersList, fmt.Sprintf("%s: %s", k, v))
		}
		args = append(args, "-headers", strings.Join(headersList, "\r\n")+"\r\n")
	}

	args = append(args, "-i", task.VideoURL, "-c", "copy")

	if task.IsHLS && useAacFilter {
		args = append(args, "-bsf:a", "aac_adtstoasc")
	}

	args = append(args, "-progress", "pipe:1", tempPath)

	cmd := util.NewCmdCtx(ctx, d.ffmpegPath, args...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to open stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start ffmpeg: %w", err)
	}

	scanner := bufio.NewScanner(stdout)
	lastUpdate := time.Now()
	startTime := time.Now()

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		d.mu.Lock()
		t, ok := d.tasks[task.ID]
		if !ok || t.Status != DownloadStatusDownloading {
			d.mu.Unlock()
			break
		}

		if strings.HasPrefix(line, "total_size=") {
			val := strings.TrimPrefix(line, "total_size=")
			if sz, err := strconv.ParseInt(val, 10, 64); err == nil && sz > 0 {
				t.DownloadedBytes = sz
			}
		} else if strings.HasPrefix(line, "speed=") {
			spd := strings.TrimSpace(strings.TrimPrefix(line, "speed="))
			if spd != "" {
				t.Speed = spd
			}
		} else if strings.HasPrefix(line, "out_time_ms=") {
			val := strings.TrimPrefix(line, "out_time_ms=")
			if ms, err := strconv.ParseInt(val, 10, 64); err == nil && ms > 0 {
				const defaultEpDurationMs = 1440000.0 // ~24 minutes
				progress := float64(ms) / defaultEpDurationMs
				if progress > 0.99 {
					progress = 0.99
				}
				t.Progress = progress

				// Calculate ETA
				elapsed := time.Since(startTime).Seconds()
				if progress > 0.05 && elapsed > 2 {
					totalEstimated := elapsed / progress
					remain := totalEstimated - elapsed
					if remain > 0 {
						t.ETA = formatETA(time.Duration(remain) * time.Second)
					}
				}
			}
		} else if strings.HasPrefix(line, "progress=end") {
			t.Progress = 1.0
		}
		d.mu.Unlock()

		if time.Since(lastUpdate) >= 800*time.Millisecond {
			lastUpdate = time.Now()
			d.broadcastQueue()
		}
	}

	if err := cmd.Wait(); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("ffmpeg error: %w", err)
	}

	return nil
}

func (d *Downloader) downloadSubtitles(task *DownloadTask, destDir string, baseFileName string) {
	if len(task.Subtitles) == 0 {
		return
	}

	client := &http.Client{Timeout: 30 * time.Second}
	for _, sub := range task.Subtitles {
		if sub.URL == "" {
			continue
		}

		lang := strings.ToLower(regexp.MustCompile(`[^a-zA-Z0-9]`).ReplaceAllString(sub.Language, "_"))
		if lang == "" {
			lang = "sub"
		}
		ext := "vtt"
		if strings.HasSuffix(sub.URL, ".srt") {
			ext = "srt"
		} else if strings.HasSuffix(sub.URL, ".ass") {
			ext = "ass"
		}

		subPath := filepath.Join(destDir, fmt.Sprintf("%s.%s.%s", baseFileName, lang, ext))
		if _, err := os.Stat(subPath); err == nil {
			continue
		}

		req, err := http.NewRequest(http.MethodGet, sub.URL, nil)
		if err != nil {
			continue
		}
		for k, v := range task.Headers {
			req.Header.Set(k, v)
		}

		resp, err := client.Do(req)
		if err != nil {
			continue
		}

		if resp.StatusCode == http.StatusOK {
			f, err := os.Create(subPath)
			if err == nil {
				_, _ = io.Copy(f, resp.Body)
				_ = f.Close()
			}
		}
		_ = resp.Body.Close()
	}
}

func (d *Downloader) failTask(taskID string, reason string) {
	d.mu.Lock()
	if task, ok := d.tasks[taskID]; ok {
		task.Status = DownloadStatusFailed
		task.Error = reason
		task.Speed = ""
		task.ETA = ""
	}
	delete(d.cancels, taskID)
	d.mu.Unlock()

	d.logger.Error().Str("taskId", taskID).Str("error", reason).Msg("onlinestream: Download failed")
	d.broadcastQueue()
}

// GetQueue returns all tasks sorted by creation date descending.
func (d *Downloader) GetQueue() []*DownloadTask {
	d.mu.RLock()
	defer d.mu.RUnlock()

	result := make([]*DownloadTask, 0, len(d.tasks))
	for _, t := range d.tasks {
		taskCopy := *t
		result = append(result, &taskCopy)
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].CreatedAt.After(result[j].CreatedAt)
	})

	return result
}

// CancelDownload cancels a currently downloading task and deletes its temporary file.
func (d *Downloader) CancelDownload(taskID string) error {
	d.mu.Lock()
	cancel, hasCancel := d.cancels[taskID]
	task, hasTask := d.tasks[taskID]
	if !hasTask {
		d.mu.Unlock()
		return ErrTaskNotFound
	}

	if hasCancel {
		cancel()
		delete(d.cancels, taskID)
	}
	task.Status = DownloadStatusCancelled
	task.Speed = ""
	task.ETA = ""
	partFile := task.SavePath + ".part"
	d.mu.Unlock()

	_ = os.Remove(partFile)
	d.broadcastQueue()
	return nil
}

// ClearCompleted removes completed, cancelled, and failed tasks from the in-memory list.
func (d *Downloader) ClearCompleted() {
	d.mu.Lock()
	for id, t := range d.tasks {
		if t.Status == DownloadStatusCompleted || t.Status == DownloadStatusCancelled || t.Status == DownloadStatusFailed {
			delete(d.tasks, id)
			delete(d.cancels, id)
		}
	}
	d.mu.Unlock()
	d.broadcastQueue()
}

// Close cancels all active tasks on shutdown.
func (d *Downloader) Close() {
	d.mu.Lock()
	for id, cancel := range d.cancels {
		cancel()
		delete(d.cancels, id)
	}
	d.mu.Unlock()
}

func (d *Downloader) broadcastQueue() {
	if d.opts.WSEventManager != nil {
		d.opts.WSEventManager.SendEvent(events.OnlinestreamDownloadQueueUpdated, d.GetQueue())
	}
}

func sanitizeName(name string) string {
	clean := sanitizerRegex.ReplaceAllString(name, "_")
	return strings.Trim(clean, " _")
}

func formatETA(d time.Duration) string {
	s := int(d.Seconds())
	if s < 60 {
		return fmt.Sprintf("%ds", s)
	}
	m := s / 60
	s = s % 60
	if m < 60 {
		return fmt.Sprintf("%dm %ds", m, s)
	}
	h := m / 60
	m = m % 60
	return fmt.Sprintf("%dh %dm", h, m)
}
