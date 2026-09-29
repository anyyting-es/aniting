package local

import (
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/database/db"
	"seanime/internal/database/db_bridge"
	"seanime/internal/database/models"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/library/anime"
	"seanime/internal/manga"
	"seanime/internal/platforms/anilist_platform"
	"seanime/internal/platforms/platform"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"

	"github.com/stretchr/testify/require"
)

func NewTestManager(t *testing.T, db *db.Database) Manager {
	env := testutil.NewTestEnv(t)

	logger := env.Logger()
	metadataProvider := metadata_provider.NewTestProviderWithEnv(env, db)
	metadataProviderRef := util.NewRef(metadataProvider)
	mangaRepository := manga.NewTestRepositoryWithEnv(env, db)

	wsEventManager := events.NewMockWSEventManager(logger)
	anilistClient := anilist.NewFixtureAnilistClient()
	anilistClientRef := util.NewRef[anilist.AnilistClient](anilistClient)
	extensionBankRef := util.NewRef(extension.NewUnifiedBank())
	anilistPlatform := anilist_platform.NewAnilistPlatform(anilistClientRef, extensionBankRef, logger, db)
	anilistPlatformRef := util.NewRef[platform.Platform](anilistPlatform)

	localDir := env.MustMkdirData("offline")
	assetsDir := env.MustMkdirData("offline", "assets")

	var localFilesCount int64
	err := db.Gorm().Model(&models.LocalFiles{}).Count(&localFilesCount).Error
	require.NoError(t, err)
	if localFilesCount == 0 {
		_, err = db_bridge.InsertLocalFiles(db, make([]*anime.LocalFile, 0))
		require.NoError(t, err)
	}

	m, err := NewManager(&NewManagerOptions{
		LocalDir:            localDir,
		AssetDir:            assetsDir,
		Logger:              logger,
		MetadataProviderRef: metadataProviderRef,
		MangaRepository:     mangaRepository,
		Database:            db,
		WSEventManager:      wsEventManager,
		AnilistPlatformRef:  anilistPlatformRef,
		IsOffline:           false,
	})
	require.NoError(t, err)

	return m
}
