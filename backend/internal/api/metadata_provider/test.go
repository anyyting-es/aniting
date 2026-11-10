package metadata_provider

import (
	"aniting/internal/database/db"
	"aniting/internal/extension"
	"aniting/internal/testutil"
	"aniting/internal/util"
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
