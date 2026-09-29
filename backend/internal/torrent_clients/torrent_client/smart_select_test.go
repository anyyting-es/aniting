package torrent_client_test

import (
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/extension"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"seanime/internal/platforms/platform"
	"seanime/internal/testmocks"
	"seanime/internal/torrent_clients/torrent_client"
	"seanime/internal/torrents/torrent"
	"seanime/internal/util"
	"testing"

	"github.com/rs/zerolog"
	"github.com/stretchr/testify/require"
)

func testLogger() *zerolog.Logger {
	logger := zerolog.Nop()
	return &logger
}

func newTorrentRepository(bank *extension.UnifiedBank) *torrent.Repository {
	return torrent.NewRepository(&torrent.NewRepositoryOptions{
		Logger:              testLogger(),
		MetadataProviderRef: util.NewRef[metadata_provider.Provider](nil),
		ExtensionBankRef:    util.NewRef(bank),
	})
}

func newClientRepository(torrentRepo *torrent.Repository) *torrent_client.Repository {
	return torrent_client.NewRepository(&torrent_client.NewRepositoryOptions{
		Logger:            testLogger(),
		Provider:          torrent_client.NoneClient,
		TorrentRepository: torrentRepo,
	})
}

func newEmptyClientRepository() *torrent_client.Repository {
	return newClientRepository(newTorrentRepository(extension.NewUnifiedBank()))
}

func newClientRepositoryWithProvider(providerID string) *torrent_client.Repository {
	bank := extension.NewUnifiedBank()
	bank.Set(providerID, extension.NewAnimeTorrentProviderExtension(&extension.Extension{
		ID:          providerID,
		Name:        "Test Provider",
		Version:     "1.0.0",
		ManifestURI: "builtin",
		Language:    extension.LanguageGo,
		Type:        extension.TypeAnimeTorrentProvider,
	}, stubAnimeProvider{}))

	return newClientRepository(newTorrentRepository(bank))
}

func presentPlatformRef() *util.Ref[platform.Platform] {
	return util.NewRef[platform.Platform](testmocks.NewFakePlatformBuilder().Build())
}

func testTorrent(providerID string) *hibiketorrent.AnimeTorrent {
	return &hibiketorrent.AnimeTorrent{
		Provider: providerID,
		InfoHash: "hash",
	}
}

func mediaWithEpisodes(count int) *anilist.CompleteAnime {
	return &anilist.CompleteAnime{Episodes: &count}
}

type stubAnimeProvider struct{}

func (stubAnimeProvider) Search(hibiketorrent.AnimeSearchOptions) ([]*hibiketorrent.AnimeTorrent, error) {
	return nil, nil
}

func (stubAnimeProvider) SmartSearch(hibiketorrent.AnimeSmartSearchOptions) ([]*hibiketorrent.AnimeTorrent, error) {
	return nil, nil
}

func (stubAnimeProvider) GetTorrentInfoHash(*hibiketorrent.AnimeTorrent) (string, error) {
	return "hash", nil
}

func (stubAnimeProvider) GetTorrentMagnetLink(*hibiketorrent.AnimeTorrent) (string, error) {
	return "magnet:?xt=urn:btih:hash", nil
}

func (stubAnimeProvider) GetLatest() ([]*hibiketorrent.AnimeTorrent, error) {
	return nil, nil
}

func (stubAnimeProvider) GetSettings() hibiketorrent.AnimeProviderSettings {
	return hibiketorrent.AnimeProviderSettings{}
}

func TestDeselectAndDownloadValidation(t *testing.T) {
	t.Run("nil params", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.DeselectAndDownload(nil)

		require.EqualError(t, err, "torrent is nil")
	})

	t.Run("nil torrent", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.DeselectAndDownload(&torrent_client.DeselectAndDownloadParams{
			FileIndices: []int{0},
		})

		require.EqualError(t, err, "torrent is nil")
	})

	t.Run("nil repository", func(t *testing.T) {
		repo := newClientRepository(nil)

		err := repo.DeselectAndDownload(&torrent_client.DeselectAndDownloadParams{
			Torrent:     testTorrent("provider"),
			FileIndices: []int{0},
		})

		require.EqualError(t, err, "torrent is nil")
	})

	t.Run("empty file indices", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.DeselectAndDownload(&torrent_client.DeselectAndDownloadParams{
			Torrent: testTorrent("provider"),
		})

		require.EqualError(t, err, "no file indices provided")
	})

	t.Run("provider not found", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.DeselectAndDownload(&torrent_client.DeselectAndDownloadParams{
			Torrent:     testTorrent("missing-provider"),
			FileIndices: []int{0},
		})

		require.EqualError(t, err, "provider extension not found")
	})
}

func TestSmartSelectValidation(t *testing.T) {
	t.Run("nil params", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.SmartSelect(nil)

		require.EqualError(t, err, "torrent is nil")
	})

	t.Run("nil torrent", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Media:          mediaWithEpisodes(12),
			PlatformRef:    presentPlatformRef(),
			EpisodeNumbers: []int{1},
		})

		require.EqualError(t, err, "torrent is nil")
	})

	t.Run("nil repository", func(t *testing.T) {
		repo := newClientRepository(nil)

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Torrent:        testTorrent("provider"),
			Media:          mediaWithEpisodes(12),
			PlatformRef:    presentPlatformRef(),
			EpisodeNumbers: []int{1},
		})

		require.EqualError(t, err, "media or anilist client wrapper is nil")
	})

	t.Run("nil media", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Torrent:        testTorrent("provider"),
			PlatformRef:    presentPlatformRef(),
			EpisodeNumbers: []int{1},
		})

		require.EqualError(t, err, "media or anilist client wrapper is nil")
	})

	t.Run("absent platform ref", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Torrent:        testTorrent("provider"),
			Media:          mediaWithEpisodes(12),
			EpisodeNumbers: []int{1},
		})

		require.EqualError(t, err, "media or anilist client wrapper is nil")
	})

	t.Run("provider not found", func(t *testing.T) {
		repo := newEmptyClientRepository()

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Torrent:        testTorrent("missing-provider"),
			Media:          mediaWithEpisodes(12),
			PlatformRef:    presentPlatformRef(),
			EpisodeNumbers: []int{1},
		})

		require.EqualError(t, err, "provider extension not found")
	})

	t.Run("movie or single episode", func(t *testing.T) {
		repo := newClientRepositoryWithProvider("provider")

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Torrent:        testTorrent("provider"),
			Media:          mediaWithEpisodes(1),
			PlatformRef:    presentPlatformRef(),
			EpisodeNumbers: []int{1},
		})

		require.EqualError(t, err, "smart select is not supported for movies or single-episode series")
	})

	t.Run("empty episode numbers", func(t *testing.T) {
		repo := newClientRepositoryWithProvider("provider")

		err := repo.SmartSelect(&torrent_client.SmartSelectParams{
			Torrent:     testTorrent("provider"),
			Media:       mediaWithEpisodes(12),
			PlatformRef: presentPlatformRef(),
		})

		require.EqualError(t, err, "no episode numbers provided")
	})
}
