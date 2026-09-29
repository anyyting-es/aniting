package extension_repo

import (
	"os"
	"path/filepath"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/hook"
	"seanime/internal/util"
	"seanime/internal/util/filecache"
	"testing"

	"github.com/goccy/go-json"
	"github.com/samber/lo"
	"github.com/stretchr/testify/require"
)

func TestDisabledExternalExtensionIsListedWithoutLoading(t *testing.T) {
	repo, extensionDir := newExternalExtensionTestRepository(t)
	ext := testExternalExtension()
	writeTestExternalExtension(t, extensionDir, ext)

	// disabling should unload/skip runtime work while keeping the install manageable
	require.NoError(t, repo.SetExternalExtensionDisabled(ext.ID, true))

	_, found := repo.GetLoadedExtension(ext.ID)
	require.False(t, found)

	allExtensions := repo.GetAllExtensions(false)
	require.Empty(t, allExtensions.Extensions)
	require.Empty(t, allExtensions.InvalidExtensions)
	require.Len(t, allExtensions.DisabledExtensions, 1)
	require.Equal(t, ext.ID, allExtensions.DisabledExtensions[0].ID)
	require.Empty(t, allExtensions.DisabledExtensions[0].Payload)
	require.Equal(t, ext.Payload, repo.GetExtensionPayload(ext.ID))
	require.True(t, repo.GetExtensionSettings().DisabledExtensionIds[ext.ID])
}

func TestUninstallExternalExtensionClearsDisabledState(t *testing.T) {
	repo, extensionDir := newExternalExtensionTestRepository(t)
	ext := testExternalExtension()
	writeTestExternalExtension(t, extensionDir, ext)

	// uninstall should remove both the manifest and the stored disabled bit
	require.NoError(t, repo.SetExternalExtensionDisabled(ext.ID, true))
	require.NoError(t, repo.UninstallExternalExtension(ext.ID))

	require.False(t, repo.GetExtensionSettings().DisabledExtensionIds[ext.ID])
	require.Empty(t, repo.GetAllExtensions(false).DisabledExtensions)
	_, err := os.Stat(filepath.Join(extensionDir, ext.ID+".json"))
	require.ErrorIs(t, err, os.ErrNotExist)
}

func newExternalExtensionTestRepository(t *testing.T) (*Repository, string) {
	t.Helper()

	logger := util.NewLogger()
	extensionDir := t.TempDir()
	return NewRepository(&NewRepositoryOptions{
		Logger:           logger,
		ExtensionDir:     extensionDir,
		WSEventManager:   events.NewMockWSEventManager(logger),
		FileCacher:       lo.Must(filecache.NewCacher(t.TempDir())),
		HookManager:      hook.NewHookManager(hook.NewHookManagerOptions{Logger: logger}),
		ExtensionBankRef: util.NewRef(extension.NewUnifiedBank()),
	}), extensionDir
}

func testExternalExtension() extension.Extension {
	return extension.Extension{
		ID:          "dummy-provider",
		Name:        "Dummy",
		Version:     "1.0.0",
		ManifestURI: "https://example.com/dummy.json",
		Language:    extension.LanguageJavascript,
		Type:        extension.TypeMangaProvider,
		Description: "Test provider",
		Author:      "Test",
		Lang:        "en",
		Payload:     "throw new Error('should not load')",
	}
}

func writeTestExternalExtension(t *testing.T, extensionDir string, ext extension.Extension) {
	t.Helper()

	raw, err := json.Marshal(ext)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(extensionDir, ext.ID+".json"), raw, 0600))
}
