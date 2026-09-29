package testutil

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetConfig(t *testing.T) {
	cfg := InitTestProvider(t)
	assert.NotEqual(t, Config{}, *cfg)
}

func TestLoadConfig_IsolatedInstances(t *testing.T) {
	first := LoadConfig(t)
	second := LoadConfig(t)

	assert.NotSame(t, first, second)
	assert.Equal(t, *first, *second)

	first.Path.DataDir = t.TempDir()
	assert.NotEqual(t, first.Path.DataDir, second.Path.DataDir)
}

func TestInitTestProvider_DefaultsWithoutConfig(t *testing.T) {
	t.Setenv("TEST_CONFIG_PATH", t.TempDir())

	cfg := InitTestProvider(t)

	assert.NotNil(t, cfg)
	assert.Equal(t, defaultTestDatabaseName, cfg.Database.Name)
	assert.Empty(t, cfg.Path.DataDir)
	assert.False(t, cfg.Flags.EnableAnilistTests)
}
