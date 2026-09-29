package cassette

import (
	"context"
	"runtime"
	"sync"
	"sync/atomic"
	"time"

	"github.com/rs/zerolog"
)

// Governor throttles concurrent ffmpeg processes
type Governor struct {
	sem     chan struct{}
	active  atomic.Int32
	maxSlot int
	logger  *zerolog.Logger

	mu    sync.Mutex
	stats GovernorStats
}

// GovernorStats contains runtime metrics
type GovernorStats struct {
	ActiveProcesses int32         `json:"activeProcesses"`
	MaxConcurrency  int           `json:"maxConcurrency"`
	TotalLaunched   int64         `json:"totalLaunched"`
	TotalCompleted  int64         `json:"totalCompleted"`
	TotalWaitTime   time.Duration `json:"totalWaitTime"`
}

// NewGovernor creates a governor with max concurrency
func NewGovernor(maxConcurrency int, hwAccelEnabled bool, logger *zerolog.Logger) *Governor {
	if maxConcurrency <= 0 {
		if hwAccelEnabled {
			maxConcurrency = max(runtime.NumCPU()*2, 10) // give hardware accel a higher threshold
		} else {
			maxConcurrency = max(runtime.NumCPU(), 1)
		}
	}
	return &Governor{
		sem:     make(chan struct{}, maxConcurrency),
		maxSlot: maxConcurrency,
		logger:  logger,
	}
}

// Acquire blocks until a slot is available
func (g *Governor) Acquire(ctx context.Context) (release func(), err error) {
	start := time.Now()

	select {
	case g.sem <- struct{}{}:
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	waited := time.Since(start)
	n := g.active.Add(1)

	g.mu.Lock()
	g.stats.TotalLaunched++
	g.stats.TotalWaitTime += waited
	g.stats.ActiveProcesses = n
	g.stats.MaxConcurrency = g.maxSlot
	g.mu.Unlock()

	if waited > 50*time.Millisecond {
		g.logger.Debug().
			Dur("waited", waited).
			Int32("active", n).
			Msg("cassette/governor: slot acquired after wait")
	}

	return func() {
		remaining := g.active.Add(-1)
		g.mu.Lock()
		g.stats.TotalCompleted++
		g.stats.ActiveProcesses = remaining
		g.mu.Unlock()
		<-g.sem
	}, nil
}

// Stats returns the governor metrics
func (g *Governor) Stats() GovernorStats {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.stats
}
