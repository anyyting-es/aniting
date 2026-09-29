package extension_repo

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"seanime/internal/util/filecache"
)

const (
	ExtensionSettingsKey    = "1"
	ExtensionSettingsBucket = "extension-settings"
)

type StoredExtensionSettingsData struct {
	DisabledExtensionIds map[string]bool `json:"disabledExtensionIds"`
	mu                   sync.Mutex      `json:"-"`
}

func defaultExtensionSettings() *StoredExtensionSettingsData {
	return &StoredExtensionSettingsData{
		DisabledExtensionIds: map[string]bool{},
	}
}

func (r *Repository) GetExtensionSettings() *StoredExtensionSettingsData {
	bucket := filecache.NewPermanentBucket(ExtensionSettingsBucket)

	var settings StoredExtensionSettingsData
	found, _ := r.fileCacher.GetPerm(bucket, ExtensionSettingsKey, &settings)
	if !found {
		settings := defaultExtensionSettings()
		r.fileCacher.SetPerm(bucket, ExtensionSettingsKey, settings)
		return settings
	}

	if settings.DisabledExtensionIds == nil {
		settings.DisabledExtensionIds = map[string]bool{}
	}

	return &settings
}

func (r *Repository) SetExternalExtensionDisabled(id string, disabled bool) error {
	if id == "" {
		return fmt.Errorf("id is empty")
	}
	if err := isValidExtensionID(id); err != nil {
		return err
	}

	if _, err := os.Stat(r.externalExtensionFilepath(id)); err != nil {
		return fmt.Errorf("extension not found")
	}

	bucket := filecache.NewPermanentBucket(ExtensionSettingsBucket)
	settings := r.GetExtensionSettings()
	if disabled {
		settings.mu.Lock()
		defer settings.mu.Unlock()
		settings.DisabledExtensionIds[id] = true
	} else {
		settings.mu.Lock()
		defer settings.mu.Unlock()
		delete(settings.DisabledExtensionIds, id)
	}

	if err := r.fileCacher.SetPerm(bucket, ExtensionSettingsKey, settings); err != nil {
		return err
	}

	r.reloadExtension(id)
	return nil
}

func (r *Repository) isExtensionDisabled(id string) bool {
	settings := r.GetExtensionSettings()
	settings.mu.Lock()
	defer settings.mu.Unlock()
	return settings.DisabledExtensionIds[id]
}

func (r *Repository) removeExtensionFromStoredSettings(id string) {
	bucket := filecache.NewPermanentBucket(ExtensionSettingsBucket)
	settings := r.GetExtensionSettings()
	settings.mu.Lock()
	defer settings.mu.Unlock()
	delete(settings.DisabledExtensionIds, id)
	r.fileCacher.SetPerm(bucket, ExtensionSettingsKey, settings)
}

func (r *Repository) externalExtensionFilepath(id string) string {
	return filepath.Join(r.extensionDir, id+".json")
}
