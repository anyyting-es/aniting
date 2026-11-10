//go:build windows

package systeminfo

import (
	"os"
	"strings"

	"golang.org/x/sys/windows/registry"
)

// displayClassKey is the device class key for display adapters. Every adapter
// gets a numbered subkey with `DriverDesc`, which is far cheaper than shelling
// out to WMI/PowerShell (and works on Windows 11 builds where `wmic` is gone).
const displayClassKey = `SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}`

const gpuPreferenceKey = `Software\Microsoft\DirectX\UserGpuPreferences`

// listGPUs enumerates display adapters from the registry.
func listGPUs() []GPU {
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, displayClassKey, registry.ENUMERATE_SUB_KEYS)
	if err != nil {
		return nil
	}
	defer key.Close()

	names, err := key.ReadSubKeyNames(-1)
	if err != nil {
		return nil
	}

	gpus := make([]GPU, 0, len(names))
	seen := make(map[string]struct{}, len(names))
	for _, name := range names {
		sub, err := registry.OpenKey(key, name, registry.QUERY_VALUE)
		if err != nil {
			continue
		}

		desc, _, _ := sub.GetStringValue("DriverDesc")
		provider, _, _ := sub.GetStringValue("ProviderName")
		sub.Close()

		desc = strings.TrimSpace(desc)
		if desc == "" {
			continue
		}
		// Microsoft Basic Display / remote adapters are noise.
		if strings.Contains(desc, "Basic Display") || strings.Contains(desc, "Remote") {
			continue
		}
		if _, dup := seen[desc]; dup {
			continue
		}
		seen[desc] = struct{}{}

		vendor := strings.TrimSpace(provider)
		if vendor == "" {
			vendor = guessVendor(desc)
		}

		gpus = append(gpus, GPU{
			Name:      desc,
			Vendor:    vendor,
			Dedicated: isDedicatedVendor(desc + " " + vendor),
		})
	}

	return gpus
}

func guessVendor(name string) string {
	lower := strings.ToLower(name)
	switch {
	case strings.Contains(lower, "nvidia"), strings.Contains(lower, "geforce"), strings.Contains(lower, "quadro"):
		return "NVIDIA"
	case strings.Contains(lower, "intel"), strings.Contains(lower, "arc"), strings.Contains(lower, "iris"):
		return "Intel"
	case strings.Contains(lower, "amd"), strings.Contains(lower, "radeon"):
		return "AMD"
	default:
		return ""
	}
}

func isDedicatedVendor(label string) bool {
	lower := strings.ToLower(label)
	if strings.Contains(lower, "intel") {
		return false
	}
	return strings.Contains(lower, "nvidia") ||
		strings.Contains(lower, "geforce") ||
		strings.Contains(lower, "quadro") ||
		strings.Contains(lower, "radeon") ||
		strings.Contains(lower, "amd") ||
		strings.Contains(lower, "arc")
}

// currentExecutable returns the path Windows keys the preference by.
func currentExecutable() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	return exe
}

// readPreference returns the stored per-app preference for this executable.
func readPreference() string {
	exe := currentExecutable()
	if exe == "" {
		return GPUModeAuto
	}

	key, err := registry.OpenKey(registry.CURRENT_USER, gpuPreferenceKey, registry.QUERY_VALUE)
	if err != nil {
		return GPUModeAuto
	}
	defer key.Close()

	value, _, err := key.GetStringValue(exe)
	if err != nil {
		return GPUModeAuto
	}

	// Windows stores it as "GpuPreference=2;".
	value = strings.ToLower(value)
	switch {
	case strings.Contains(value, "gpupreference=2"):
		return GPUModeHigh
	case strings.Contains(value, "gpupreference=1"):
		return GPUModePower
	default:
		return GPUModeAuto
	}
}

// writePreference stores the per-app preference. "auto" removes the entry so
// Windows falls back to its own decision.
func writePreference(mode string) error {
	exe := currentExecutable()
	if exe == "" {
		return os.ErrNotExist
	}

	key, _, err := registry.CreateKey(registry.CURRENT_USER, gpuPreferenceKey, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer key.Close()

	switch mode {
	case GPUModeHigh:
		return key.SetStringValue(exe, "GpuPreference=2;")
	case GPUModePower:
		return key.SetStringValue(exe, "GpuPreference=1;")
	case GPUModeAuto:
		if err := key.DeleteValue(exe); err != nil && err != registry.ErrNotExist {
			return err
		}
		return nil
	default:
		return os.ErrInvalid
	}
}

func platformGPUSettings() GPUSettings {
	return GPUSettings{
		Preference:       readPreference(),
		CanSetPreference: true,
		ExecutablePath:   currentExecutable(),
		Note:             "Windows applies the change the next time the app starts.",
	}
}
