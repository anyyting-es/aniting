package cassette

import (
	"sync"
	"time"
)

// VelocityEstimator tracks playback speed to adjust prefetch
type VelocityEstimator struct {
	mu      sync.Mutex
	samples []velocitySample
	maxAge  time.Duration
}

type velocitySample struct {
	segment int32
	at      time.Time
}

// NewVelocityEstimator creates an estimator with a moving window
func NewVelocityEstimator(window time.Duration) *VelocityEstimator {
	return &VelocityEstimator{
		samples: make([]velocitySample, 0, 64),
		maxAge:  window,
	}
}

// Record adds a new segment request observation
func (ve *VelocityEstimator) Record(seg int32) {
	ve.mu.Lock()
	defer ve.mu.Unlock()

	now := time.Now()
	ve.samples = append(ve.samples, velocitySample{segment: seg, at: now})

	// Evict old samples.
	cutoff := now.Add(-ve.maxAge)
	i := 0
	for i < len(ve.samples) && ve.samples[i].at.Before(cutoff) {
		i++
	}
	if i > 0 {
		ve.samples = ve.samples[i:]
	}
}

// SegmentsPerSecond returns the consumption rate
func (ve *VelocityEstimator) SegmentsPerSecond() float64 {
	ve.mu.Lock()
	defer ve.mu.Unlock()

	if len(ve.samples) < 2 {
		return 0
	}
	first := ve.samples[0]
	last := ve.samples[len(ve.samples)-1]
	dt := last.at.Sub(first.at).Seconds()
	if dt < 0.01 {
		return 0
	}
	dSeg := float64(last.segment - first.segment)
	if dSeg < 0 {
		// seek backwards
		return 0
	}
	return dSeg / dt
}

// LookAhead returns suggested prefetch count based on velocity
func (ve *VelocityEstimator) LookAhead(base int32) int32 {
	v := ve.SegmentsPerSecond()
	if v <= 0 {
		return base
	}
	// At 1x playback, v ~= 0.25 seg/s.
	extra := int32(v * 20)     // scale up for faster network/playback
	return min(base+extra, 30) // cap at 30 segments
}

// DetectSeek returns true if the request looks like a seek
func (ve *VelocityEstimator) DetectSeek(threshold int32) bool {
	ve.mu.Lock()
	defer ve.mu.Unlock()

	n := len(ve.samples)
	if n < 2 {
		return false
	}
	delta := ve.samples[n-1].segment - ve.samples[n-2].segment
	return abs32(delta) > threshold
}

// Reset clears all samples
func (ve *VelocityEstimator) Reset() {
	ve.mu.Lock()
	defer ve.mu.Unlock()
	ve.samples = ve.samples[:0]
}
