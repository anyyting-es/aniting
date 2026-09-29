package scanner

import (
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/database/db"
	"seanime/internal/events"
	"seanime/internal/extension"
	"seanime/internal/library/anime"
	"seanime/internal/platforms/anilist_platform"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"seanime/internal/util/limiter"
	"testing"

	"github.com/rs/zerolog"
)

const scannerTestLibraryDir = "E:/Anime"

type scannerTestWrapper struct {
	Env                *testutil.TestEnv
	Config             *testutil.Config
	Logger             *zerolog.Logger
	Database           *db.Database
	AnilistClient      anilist.AnilistClient
	Platform           *anilist_platform.AnilistPlatform
	MetadataProvider   metadata_provider.Provider
	CompleteAnimeCache *anilist.CompleteAnimeCache
	AnilistRateLimiter *limiter.Limiter
	WSEventManager     events.WSEventManagerInterface
	LibraryDir         string
}

func newScannerFixtureWrapper(t testing.TB) *scannerTestWrapper {
	t.Helper()

	env := testutil.NewTestEnv(t)
	return newScannerWrapper(t, env, anilist.NewTestAnilistClient(), "")
}

func newScannerLiveWrapper(t testing.TB) *scannerTestWrapper {
	t.Helper()

	env := testutil.NewTestEnv(t, testutil.Anilist())
	cfg := env.Config()

	return newScannerWrapper(t, env, anilist.NewAnilistClient(cfg.Provider.AnilistJwt, ""), cfg.Provider.AnilistUsername)
}

func newScannerWrapper(t testing.TB, env *testutil.TestEnv, client anilist.AnilistClient, username string) *scannerTestWrapper {
	t.Helper()

	logger := env.Logger()
	database := env.MustNewDatabase(logger)
	anilistClientRef := util.NewRef(client)
	extensionBankRef := util.NewRef(extension.NewUnifiedBank())
	platform := anilist_platform.NewAnilistPlatform(anilistClientRef, extensionBankRef, logger, database).(*anilist_platform.AnilistPlatform)
	if username != "" {
		platform.SetUsername(username)
	}

	return &scannerTestWrapper{
		Env:                env,
		Config:             env.Config(),
		Logger:             logger,
		Database:           database,
		AnilistClient:      client,
		Platform:           platform,
		MetadataProvider:   metadata_provider.NewTestProviderWithEnv(env, database),
		CompleteAnimeCache: anilist.NewCompleteAnimeCache(),
		AnilistRateLimiter: limiter.NewAnilistLimiter(),
		WSEventManager:     events.NewMockWSEventManager(logger),
		LibraryDir:         scannerTestLibraryDir,
	}
}

func (h *scannerTestWrapper) LocalFiles(paths ...string) []*anime.LocalFile {
	localFiles := make([]*anime.LocalFile, 0, len(paths))
	for _, path := range paths {
		localFiles = append(localFiles, anime.NewLocalFile(path, h.LibraryDir))
	}

	return localFiles
}
