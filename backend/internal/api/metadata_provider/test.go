package metadata_provider

import (
	"seanime/internal/database/db"
	"seanime/internal/extension"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"
)

func NewTestProvider(t *testing.T, db *db.Database) Provider {
	t.Helper()

	return NewTestProviderWithEnv(testutil.NewTestEnv(t), db)
}

func NewTestProviderWithEnv(env *testutil.TestEnv, db *db.Database) Provider {
	return NewProvider(&NewProviderImplOptions{
		Logger:           env.Logger(),
		FileCacher:       env.NewCacher("metadata-provider"),
		Database:         db,
		ExtensionBankRef: util.NewRef(extension.NewUnifiedBank()),
	})
}
