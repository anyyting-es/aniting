package extension_repo

import (
	"context"
	"seanime/internal/events"
	"seanime/internal/extension"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"seanime/internal/goja/goja_runtime"
	"seanime/internal/util"
	"testing"

	"github.com/dop251/goja"
	"github.com/stretchr/testify/require"
)

const asyncAnimeTorrentProviderPayload = `
class Provider {
  async search() {
    await Promise.resolve("ready")

    return [{
      name: "[SubsPlease] Frieren - 01 (1080p)",
      date: "2024-01-01T00:00:00Z",
      size: 1,
      seeders: 10,
      leechers: 1,
      downloadCount: 20,
      link: "https://example.com/search",
      downloadUrl: "",
      infoHash: "async-search-hash",
      resolution: "1080p",
      episodeNumber: 1
    }]
  }

  async smartSearch() {
    await Promise.resolve("ready")
    return []
  }

  async getTorrentInfoHash(torrent) {
    return torrent.infoHash || ""
  }

  async getTorrentMagnetLink() {
    await Promise.resolve("ready")
    return "magnet:?xt=urn:btih:async-search-hash"
  }

  async getLatest() {
    await Promise.resolve("ready")

    return [{
      name: "[SubsPlease] Frieren - 02 (1080p)",
      date: "2026-01-02T00:00:00Z",
      size: 2,
      seeders: 11,
      leechers: 1,
      downloadCount: 22,
      link: "https://example.com/latest",
      downloadUrl: "",
      infoHash: "async-latest-hash",
      resolution: "1080p",
      episodeNumber: 2
    }]
  }

  getSettings() {
    return {
      canSmartSearch: true,
      smartSearchFilters: [],
      supportsAdult: false,
      type: "main"
    }
  }
}
`

func newTestGojaAnimeTorrentProvider(t testing.TB) *GojaAnimeTorrentProvider {
	t.Helper()

	logger := util.NewLogger()
	runtimeManager := goja_runtime.NewManager(logger)
	wsEventManager := events.NewMockWSEventManager(logger)
	ext := &extension.Extension{
		ID:       "test-async-provider",
		Name:     "test async provider",
		Version:  "0.1.0",
		Language: extension.LanguageJavascript,
		Type:     extension.TypeAnimeTorrentProvider,
		Payload:  asyncAnimeTorrentProviderPayload,
	}

	_, provider, err := NewGojaAnimeTorrentProvider(ext, ext.Language, logger, runtimeManager, wsEventManager)
	require.NoError(t, err)

	return provider
}

func TestGojaAnimeTorrentProviderCallClassMethod(t *testing.T) {
	provider := newTestGojaAnimeTorrentProvider(t)

	raw, err := provider.callClassMethod(context.Background(), "search", structToMap(hibiketorrent.AnimeSearchOptions{Query: "Frieren"}))
	require.NoError(t, err)

	_, isGojaValue := raw.(goja.Value)
	require.False(t, isGojaValue)

	_, isPromise := raw.(*goja.Promise)
	require.False(t, isPromise)

	items, ok := raw.([]interface{})
	require.True(t, ok)
	require.Len(t, items, 1)

	item, ok := items[0].(map[string]interface{})
	require.True(t, ok)
	require.Equal(t, "async-search-hash", item["infoHash"])
}

func TestGojaAnimeTorrentProviderAsyncMethods(t *testing.T) {
	provider := newTestGojaAnimeTorrentProvider(t)

	for i := range 20 {
		results, err := provider.Search(hibiketorrent.AnimeSearchOptions{Query: "Frieren"})
		require.NoErrorf(t, err, "iteration %d", i)
		require.Len(t, results, 1)
		require.Equal(t, "test-async-provider", results[0].Provider)
		require.Equal(t, "async-search-hash", results[0].InfoHash)
	}

	latest, err := provider.GetLatest()
	require.NoError(t, err)
	require.Len(t, latest, 1)
	require.Equal(t, "async-latest-hash", latest[0].InfoHash)

	infoHash, err := provider.GetTorrentInfoHash(&hibiketorrent.AnimeTorrent{InfoHash: "async-search-hash"})
	require.NoError(t, err)
	require.Equal(t, "async-search-hash", infoHash)

}
