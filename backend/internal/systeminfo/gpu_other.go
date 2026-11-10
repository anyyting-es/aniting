//go:build !windows && !linux

package systeminfo

import "errors"

// listGPUs is unsupported on this platform.
func listGPUs() []GPU { return nil }

// platformGPUSettings has no per-app GPU preference on this platform.
func platformGPUSettings() GPUSettings {
	return GPUSettings{Preference: GPUModeAuto}
}

func writePreference(string) error {
	return errors.New("per-app GPU preference is not supported on this platform")
}
