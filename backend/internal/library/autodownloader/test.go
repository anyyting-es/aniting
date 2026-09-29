package autodownloader

import (
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/database/db"
	"seanime/internal/database/models"
	"seanime/internal/events"
	"seanime/internal/extension"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"seanime/internal/testutil"
	"seanime/internal/torrents/torrent"
	"seanime/internal/util"
	"testing"
)

type TestWrapper struct {
	SearchResults    []*hibiketorrent.AnimeTorrent
	GetLatestResults []*hibiketorrent.AnimeTorrent
	Database         *db.Database
	Providers        map[string]hibiketorrent.AnimeProvider
	DefaultProvider  string
}

type TestTorrentProvider struct {
	wrapper *TestWrapper
}

func (f TestTorrentProvider) Search(opts hibiketorrent.AnimeSearchOptions) ([]*hibiketorrent.AnimeTorrent, error) {
	return f.wrapper.SearchResults, nil
}

func (f TestTorrentProvider) SmartSearch(opts hibiketorrent.AnimeSmartSearchOptions) ([]*hibiketorrent.AnimeTorrent, error) {
	return f.wrapper.SearchResults, nil
}

func (f TestTorrentProvider) GetTorrentInfoHash(torrent *hibiketorrent.AnimeTorrent) (string, error) {
	return torrent.InfoHash, nil
}

func (f TestTorrentProvider) GetTorrentMagnetLink(torrent *hibiketorrent.AnimeTorrent) (string, error) {
	return torrent.MagnetLink, nil
}

func (f TestTorrentProvider) GetLatest() ([]*hibiketorrent.AnimeTorrent, error) {
	return f.wrapper.GetLatestResults, nil
}

func (f TestTorrentProvider) GetSettings() hibiketorrent.AnimeProviderSettings {
	return hibiketorrent.AnimeProviderSettings{
		CanSmartSearch:     false,
		SmartSearchFilters: nil,
		SupportsAdult:      false,
		Type:               "main",
	}
}

var _ hibiketorrent.AnimeProvider = (*TestTorrentProvider)(nil)

func (f *TestWrapper) New(t *testing.T) *AutoDownloader {
	t.Helper()
	env := testutil.NewTestEnv(t)

	logger := env.Logger()
	database := env.NewDatabase("")

	f.Database = database

	filecacher := env.NewCacher("autodownloader")

	extensionBankRef := util.NewRef(extension.NewUnifiedBank())

	providers := f.Providers
	if len(providers) == 0 {
		providers = map[string]hibiketorrent.AnimeProvider{
			"fake": TestTorrentProvider{wrapper: f},
		}
	}

	for id, provider := range providers {
		ext := extension.NewAnimeTorrentProviderExtension(&extension.Extension{
			ID:   id,
			Type: extension.TypeAnimeTorrentProvider,
			Name: id,
		}, provider)

		extensionBankRef.Get().Set(id, ext)
	}

	metadataProvider := metadata_provider.NewProvider(&metadata_provider.NewProviderImplOptions{
		Logger:           logger,
		FileCacher:       filecacher,
		Database:         database,
		ExtensionBankRef: extensionBankRef,
	})

	torrentRepository := torrent.NewRepository(&torrent.NewRepositoryOptions{
		Logger:              logger,
		MetadataProviderRef: util.NewRef(metadataProvider),
		ExtensionBankRef:    extensionBankRef,
	})

	metadataProviderRef := util.NewRef[metadata_provider.Provider](metadataProvider)
	defaultProvider := f.DefaultProvider
	if defaultProvider == "" {
		defaultProvider = "fake"
		for id := range providers {
			defaultProvider = id
			break
		}
	}
	//torrentClientRepository := torrent_client.NewRepository(&torrent_client.NewRepositoryOptions{
	//	Logger:              logger,
	//	QbittorrentClient:   &qbittorrent.Client{},
	//	Transmission:        &transmission.Transmission{},
	//	TorrentRepository:   torrentRepository,
	//	Provider:            "",
	//	MetadataProviderRef: nil,
	//})
	ad := New(&NewAutoDownloaderOptions{
		Logger:                  logger,
		TorrentClientRepository: nil,
		TorrentRepository:       torrentRepository,
		WSEventManager:          events.NewMockWSEventManager(logger),
		Database:                database,
		MetadataProviderRef:     metadataProviderRef,
		DebridClientRepository:  nil,
		IsOfflineRef:            util.NewRef(false),
	})

	ad.SetSettings(&models.AutoDownloaderSettings{
		Provider:              defaultProvider,
		Interval:              15,
		Enabled:               true,
		DownloadAutomatically: false,
		EnableEnhancedQueries: false,
		EnableSeasonCheck:     false,
		UseDebrid:             false,
	})
	ad.SetAnimeCollection(&anilist.AnimeCollection{})

	return ad
}
