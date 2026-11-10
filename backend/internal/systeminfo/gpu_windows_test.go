//go:build windows

package systeminfo

import "testing"

// TestPreferenceRoundTrip writes the real per-app preference for this test
// binary and removes it afterwards.
func TestPreferenceRoundTrip(t *testing.T) {
	if currentExecutable() == "" {
		t.Skip("executable path unavailable")
	}
	t.Cleanup(func() { _ = writePreference(GPUModeAuto) })

	if got := readPreference(); got != GPUModeAuto {
		t.Fatalf("expected a clean start, got %q", got)
	}

	if err := writePreference(GPUModeHigh); err != nil {
		t.Fatalf("write high: %v", err)
	}
	if got := readPreference(); got != GPUModeHigh {
		t.Fatalf("expected high, got %q", got)
	}

	if err := writePreference(GPUModePower); err != nil {
		t.Fatalf("write power: %v", err)
	}
	if got := readPreference(); got != GPUModePower {
		t.Fatalf("expected power, got %q", got)
	}

	if err := writePreference(GPUModeAuto); err != nil {
		t.Fatalf("clear: %v", err)
	}
	if got := readPreference(); got != GPUModeAuto {
		t.Fatalf("expected auto after clearing, got %q", got)
	}
}
