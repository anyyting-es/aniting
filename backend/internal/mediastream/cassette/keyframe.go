package cassette

import (
	"bufio"
	"path/filepath"
	"seanime/internal/mediastream/videofile"
	"seanime/internal/util"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/rs/zerolog"
)

// KeyframeIndex holds extracted keyframe timestamps
type KeyframeIndex struct {
	Sha       string    `json:"sha"`
	Keyframes []float64 `json:"keyframes"`
	IsDone    bool      `json:"isDone"`

	mu        sync.RWMutex
	ready     sync.WaitGroup
	listeners []func(keyframes []float64)
}

// Get returns the keyframe timestamp
func (ki *KeyframeIndex) Get(idx int32) float64 {
	ki.mu.RLock()
	defer ki.mu.RUnlock()
	return ki.Keyframes[idx]
}

// Slice returns a copy of keyframe timestamps
func (ki *KeyframeIndex) Slice(start, end int32) []float64 {
	if end <= start {
		return nil
	}
	ki.mu.RLock()
	defer ki.mu.RUnlock()
	out := make([]float64, end-start)
	copy(out, ki.Keyframes[start:end])
	return out
}

// Length returns number of keyframes and status
func (ki *KeyframeIndex) Length() (int32, bool) {
	ki.mu.RLock()
	defer ki.mu.RUnlock()
	return int32(len(ki.Keyframes)), ki.IsDone
}

// AddListener registers a callback for new keyframes
func (ki *KeyframeIndex) AddListener(fn func([]float64)) {
	ki.mu.Lock()
	defer ki.mu.Unlock()
	ki.listeners = append(ki.listeners, fn)
}

func (ki *KeyframeIndex) append(values []float64) {
	ki.mu.Lock()
	defer ki.mu.Unlock()
	ki.Keyframes = append(ki.Keyframes, values...)
	for _, fn := range ki.listeners {
		fn(ki.Keyframes)
	}
}

// global keyframe cache

var (
	kfCache   sync.Map // map[string]*KeyframeIndex
	kfCacheMu sync.Mutex
)

// ClearKeyframeCache removes cached indexes
func ClearKeyframeCache() {
	kfCache.Range(func(key, _ any) bool {
		kfCache.Delete(key)
		return true
	})
}

// getOrExtractKeyframes returns a keyframe index
func getOrExtractKeyframes(
	path string,
	hash string,
	settings *Settings,
	logger *zerolog.Logger,
) *KeyframeIndex {
	if v, ok := kfCache.Load(hash); ok {
		ki := v.(*KeyframeIndex)
		ki.ready.Wait()
		return ki
	}

	kfCacheMu.Lock()
	if v, ok := kfCache.Load(hash); ok {
		kfCacheMu.Unlock()
		ki := v.(*KeyframeIndex)
		ki.ready.Wait()
		return ki
	}

	ki := &KeyframeIndex{Sha: hash}
	ki.ready.Add(1)
	kfCache.Store(hash, ki)
	kfCacheMu.Unlock()

	go func() {
		diskPath := filepath.Join(settings.StreamDir, hash, "keyframes.json")

		// Try disk cache first
		if err := getSavedInfo(diskPath, ki); err == nil {
			logger.Trace().Msg("cassette: keyframes disk cache HIT")
			ki.ready.Done()
			return
		}

		// Extract from the file
		if err := extractKeyframes(settings.FfprobePath, path, ki, hash, logger); err == nil {
			saveInfo(diskPath, ki)
		}
	}()

	ki.ready.Wait()
	return ki
}

// extractKeyframes probes the file for keyframes
func extractKeyframes(
	ffprobePath string,
	path string,
	ki *KeyframeIndex,
	hash string,
	logger *zerolog.Logger,
) error {
	defer printExecTime(logger, "ffprobe keyframe analysis for %s", path)()

	probeBin := ffprobePath
	if probeBin == "" {
		probeBin = "ffprobe"
	}

	cmd := util.NewCmd(
		probeBin,
		"-loglevel", "error",
		"-select_streams", "v:0",
		"-show_entries", "packet=pts_time,flags",
		"-of", "csv=print_section=0",
		path,
	)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}

	scanner := bufio.NewScanner(stdout)
	buf := make([]float64, 0, 1000)
	batchSize := 100
	flushed := int32(0)
	var readyDone atomic.Bool

	flush := func(final bool) {
		if len(buf) == 0 && !final {
			return
		}
		ki.append(buf)
		flushed += int32(len(buf))
		if !readyDone.Load() {
			readyDone.Store(true)
			ki.ready.Done()
		}
		buf = buf[:0]
		// After the first 500 keyframes increase batch size to reduce
		// listener overhead on long files
		if flushed >= 500 {
			batchSize = 500
		}
	}

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, ",", 2)
		if len(parts) < 2 {
			continue
		}
		pts, flags := parts[0], parts[1]
		if pts == "N/A" {
			break
		}
		if len(flags) == 0 || flags[0] != 'K' {
			continue
		}
		fpts, err := strconv.ParseFloat(pts, 64)
		if err != nil {
			return err
		}
		buf = append(buf, fpts)
		if len(buf) >= batchSize {
			flush(false)
		}
	}

	// Handle files with <=1 keyframe
	if flushed == 0 && len(buf) < 2 {
		dummy, err := makeDummyKeyframes(ffprobePath, path, hash)
		if err != nil {
			return err
		}
		buf = dummy
	}

	flush(true)
	ki.IsDone = true
	return nil
}

// makeDummyKeyframes at 2s intervals
func makeDummyKeyframes(ffprobePath, path, hash string) ([]float64, error) {
	const interval = 2.0
	info, err := videofile.FfprobeGetInfo(ffprobePath, path, hash)
	if err != nil {
		return nil, err
	}
	n := int(float64(info.Duration)/interval) + 1
	out := make([]float64, n)
	for i := range out {
		out[i] = float64(i) * interval
	}
	return out, nil
}
