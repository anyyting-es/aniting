//go:build linux

package systeminfo

import (
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// listGPUs reads the DRM cards exposed by the kernel.
func listGPUs() []GPU {
	entries, err := filepath.Glob("/sys/class/drm/card[0-9]*/device/vendor")
	if err != nil {
		return nil
	}

	gpus := make([]GPU, 0, len(entries))
	for _, vendorPath := range entries {
		raw, err := os.ReadFile(vendorPath)
		if err != nil {
			continue
		}
		vendor := strings.TrimSpace(string(raw))
		name := vendorName(vendor)
		if name == "" {
			continue
		}

		card := filepath.Base(filepath.Dir(filepath.Dir(vendorPath)))
		gpus = append(gpus, GPU{
			Name:      name + " (" + card + ")",
			Vendor:    name,
			Dedicated: name == "NVIDIA" || name == "AMD",
		})
	}
	return gpus
}

func vendorName(pciID string) string {
	switch strings.ToLower(pciID) {
	case "0x10de":
		return "NVIDIA"
	case "0x1002":
		return "AMD"
	case "0x8086":
		return "Intel"
	case "0x13b5":
		return "ARM"
	case "0x5143":
		return "Qualcomm"
	default:
		if id, err := strconv.ParseUint(strings.TrimPrefix(pciID, "0x"), 16, 32); err == nil && id > 0 {
			return "PCI " + pciID
		}
		return ""
	}
}

// platformGPUSettings reports that Linux has no per-app preference: hybrid
// setups use the Mesa offload environment variable at launch time.
func platformGPUSettings() GPUSettings {
	return GPUSettings{
		Preference:       GPUModeAuto,
		CanSetPreference: false,
		Note:             "Launch the app with DRI_PRIME=1 to use the discrete GPU.",
	}
}

func writePreference(string) error {
	return errors.New("per-app GPU preference is not supported on Linux")
}
