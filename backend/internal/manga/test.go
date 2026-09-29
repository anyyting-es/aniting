package manga

import (
	"seanime/internal/database/db"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"
)

func NewTestRepository(t *testing.T, db *db.Database) *Repository {
	t.Helper()

	return NewTestRepositoryWithEnv(testutil.NewTestEnv(t), db)
}

func NewTestRepositoryWithEnv(env *testutil.TestEnv, db *db.Database) *Repository {
	logger := env.Logger()
	cacheDir := env.EnsureCacheDir()
	fileCacher := env.NewCacher()

	repository := NewRepository(&NewRepositoryOptions{
		Logger:           logger,
		FileCacher:       fileCacher,
		CacheDir:         cacheDir,
		ServerURI:        "",
		WsEventManager:   events.NewMockWSEventManager(logger),
		DownloadDir:      env.MustMkdirData("manga"),
		Database:         db,
		ExtensionBankRef: util.NewRef(extension.NewUnifiedBank()),
	})

	return repository
}
