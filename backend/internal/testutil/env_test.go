package testutil

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewTestEnv_CreatesIsolatedPaths(t *testing.T) {
	first := NewTestEnv(t)
	second := NewTestEnv(t)

	assert.NotEqual(t, first.RootDir, second.RootDir)
	assert.DirExists(t, first.RootDir)
	assert.DirExists(t, first.DataDir)
	assert.DirExists(t, first.CacheDir)
	assert.Equal(t, filepath.Join(first.RootDir, "data"), first.DataDir)
	assert.Equal(t, filepath.Join(first.RootDir, "data", "cache"), first.CacheDir)

	offlineDir := first.EnsureDataDir("offline", "assets")
	assert.Equal(t, filepath.Join(first.DataDir, "offline", "assets"), offlineDir)
	assert.DirExists(t, offlineDir)

	cacheDir := first.EnsureCacheDir("metadata-provider")
	assert.Equal(t, filepath.Join(first.CacheDir, "metadata-provider"), cacheDir)
	assert.DirExists(t, cacheDir)
	assert.NotNil(t, first.Logger())
	assert.NotNil(t, first.Config())
	assert.Contains(t, first.Config().Database.Name, "seanime-test-")
}

func TestNewTestEnv_CreatesDatabaseAndCache(t *testing.T) {
	env := NewTestEnv(t)

	database := env.NewDatabase("")
	require.NotNil(t, database)
	require.NotNil(t, database.Gorm())

	cacher := env.NewCacher("continuity")
	require.NotNil(t, cacher)
	assert.DirExists(t, env.CachePath("continuity"))
}

func TestNewTestEnv_UsesDefaultsWithoutConfig(t *testing.T) {
	t.Setenv("TEST_CONFIG_PATH", t.TempDir())

	env := NewTestEnv(t)
	cfg := env.Config()

	assert.Equal(t, env.DataDir, cfg.Path.DataDir)
	assert.Contains(t, cfg.Database.Name, defaultTestDatabaseName)
	assert.DirExists(t, env.DataDir)
}

func TestFixtureRelPath(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "unix absolute path",
			input:    "/Users/rahim/Downloads/file.mkv",
			expected: filepath.Join("Users", "rahim", "Downloads", "file.mkv"),
		},
		{
			name:     "windows drive path",
			input:    `E:\Anime\Series\Ep1.mkv`,
			expected: filepath.Join("Anime", "Series", "Ep1.mkv"),
		},
		{
			name:     "relative path",
			input:    "fixture/file.txt",
			expected: filepath.Join("fixture", "file.txt"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, FixtureRelPath(tt.input))
		})
	}
}

func TestEnvMustWriteFixtureFile_RootsUnderTempDir(t *testing.T) {
	env := NewTestEnv(t)
	target := env.MustWriteFixtureFile("/Users/rahim/Downloads/media.mkv", []byte("fixture"))

	require.FileExists(t, target)
	assert.Equal(t, env.FixturePath("/Users/rahim/Downloads/media.mkv"), target)
	assert.True(t, strings.HasPrefix(target, env.RootDir))
}

func TestRequireSampleVideoPath_UsesEnvOverride(t *testing.T) {
	t.Setenv(SampleVideoPathEnv, "/tmp/sample.mkv")

	assert.Equal(t, "/tmp/sample.mkv", RequireSampleVideoPath(t))
}

func TestShouldRecordAnilistFixtures(t *testing.T) {
	t.Setenv(RecordAnilistFixturesEnvName, "true")
	assert.True(t, ShouldRecordAnilistFixtures())

	t.Setenv(RecordAnilistFixturesEnvName, "false")
	assert.False(t, ShouldRecordAnilistFixtures())

	t.Setenv(RecordAnilistFixturesEnvName, "not-a-bool")
	assert.False(t, ShouldRecordAnilistFixtures())
}
