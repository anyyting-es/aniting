package continuity

import (
	"path/filepath"
	"seanime/internal/database/db"
	"seanime/internal/util"
	"seanime/internal/util/filecache"
	"testing"

	"github.com/stretchr/testify/require"
)

func NewTestManager(t *testing.T, db *db.Database) *Manager {
	logger := util.NewLogger()
	cacher, err := filecache.NewCacher(filepath.Join(t.TempDir(), "cache"))
	require.NoError(t, err)

	manager := NewManager(&NewManagerOptions{
		FileCacher: cacher,
		Logger:     logger,
		Database:   db,
	})

	return manager
}
