package systeminfo

import (
	"encoding/json"
	"testing"
)

func TestSettingsIsJSONSerializable(t *testing.T) {
	settings := Settings()

	if settings.Preference == "" {
		t.Fatal("preference must never be empty")
	}
	if settings.GPUs == nil {
		t.Fatal("gpus must be an empty slice, not nil, so JSON emits []")
	}

	if _, err := json.Marshal(settings); err != nil {
		t.Fatalf("settings must marshal: %v", err)
	}
}

func TestListGPUsIsStable(t *testing.T) {
	first := ListGPUs()
	second := ListGPUs()

	// The second call must be served from the cache (same slice values).
	if len(first) != len(second) {
		t.Fatalf("unstable enumeration: %d vs %d", len(first), len(second))
	}
	for i := range first {
		if first[i].Name != second[i].Name {
			t.Fatalf("unstable entry %d: %q vs %q", i, first[i].Name, second[i].Name)
		}
	}
}

func TestSetPreferenceRejectsUnknownMode(t *testing.T) {
	if err := SetPreference("turbo"); err == nil {
		t.Fatal("expected an error for an unknown mode")
	}
}
