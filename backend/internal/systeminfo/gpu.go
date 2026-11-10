// Package systeminfo exposes host hardware details the client cannot read
// through Flutter plugins, starting with the GPUs and the Windows per-app GPU
// preference.
package systeminfo

import (
	"sync"
	"time"
)

// GPU is a display adapter reported by the operating system.
type GPU struct {
	Name string `json:"name"`

	// Vendor as reported by the driver ("NVIDIA", "Intel", "AMD"…).
	Vendor string `json:"vendor,omitempty"`

	// Dedicated reports whether the adapter is expected to be the discrete one.
	// It is a heuristic based on the vendor, not a guarantee.
	Dedicated bool `json:"dedicated"`
}

var (
	gpuCacheMu   sync.Mutex
	gpuCache     []GPU
	gpuCacheTime time.Time
)

// gpuCacheTTL keeps the enumeration cheap: it is only read when the settings
// panel is open, and hot-plugging a GPU mid-session is not a real scenario.
const gpuCacheTTL = 2 * time.Minute

// Settings returns the detected GPUs plus the per-app preference state.
func Settings() GPUSettings {
	settings := platformGPUSettings()
	settings.GPUs = ListGPUs()
	return settings
}

// ListGPUs returns the host display adapters, cached briefly.
func ListGPUs() []GPU {
	gpuCacheMu.Lock()
	defer gpuCacheMu.Unlock()

	if gpuCache != nil && time.Since(gpuCacheTime) < gpuCacheTTL {
		return gpuCache
	}

	detected := listGPUs()
	if detected == nil {
		detected = []GPU{}
	}
	gpuCache = detected
	gpuCacheTime = time.Now()
	return detected
}

// SetPreference stores the per-app GPU preference.
func SetPreference(mode string) error {
	if err := writePreference(mode); err != nil {
		return err
	}

	// The preference is part of Settings, so drop the cached enumeration to let
	// the next read reflect the new state.
	gpuCacheMu.Lock()
	gpuCacheTime = time.Time{}
	gpuCacheMu.Unlock()
	return nil
}

// GPU preference modes understood by the Windows per-app setting.
const (
	GPUModeAuto  = "auto"
	GPUModeHigh  = "high"
	GPUModePower = "power"
)

// GPUSettings is what the client needs to render the GPU panel.
type GPUSettings struct {
	GPUs []GPU `json:"gpus"`

	// Preference is the current per-app preference (auto/high/power).
	Preference string `json:"preference"`

	// CanSetPreference is false on platforms without a per-app preference.
	CanSetPreference bool `json:"canSetPreference"`

	// ExecutablePath is the binary the preference applies to.
	ExecutablePath string `json:"executablePath,omitempty"`

	// Note carries a platform hint (e.g. the DRI_PRIME command on Linux).
	Note string `json:"note,omitempty"`
}
