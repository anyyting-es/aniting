package extension_playground

import (
	"encoding/json"
	"fmt"
	metadataapi "seanime/internal/api/metadata"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/extension"
	hibikemanga "seanime/internal/extension/hibike/manga"
	hibikeonlinestream "seanime/internal/extension/hibike/onlinestream"
	hibiketorrent "seanime/internal/extension/hibike/torrent"
	"seanime/internal/platforms/platform"
	"seanime/internal/testmocks"
	"seanime/internal/util"
	"testing"

	"github.com/stretchr/testify/require"
)

const (
	testAnimeID = 101
	testMangaID = 202
)

const torrentProviderScript = `
class Provider {
  getSettings() {
    console.log("getSettings")
    return {
      type: "main",
      canSmartSearch: true,
      supportsAdult: true,
      smartSearchFilters: ["query", "episodeNumber", "resolution", "batch", "bestReleases"],
    }
  }

  async search(options) {
    console.log("search:" + options.query)
    return [this.makeTorrent(options.query + ":" + options.media.romajiTitle, options.media.absoluteSeasonOffset, options.media.synonyms.length)]
  }

  async smartSearch(options) {
    console.log("smartSearch:" + options.query)
    return [this.makeTorrent("smart:" + [
      options.media.absoluteSeasonOffset,
      options.anidbAID,
      options.anidbEID,
      options.episodeNumber,
      options.resolution,
      options.bestReleases,
      options.batch,
    ].join(":"), options.episodeNumber, options.anidbEID)]
  }

  async getTorrentInfoHash(torrent) {
    return torrent.infoHash || "calculated-hash"
  }

  async getTorrentMagnetLink(torrent) {
    return torrent.magnetLink || ("magnet:?xt=urn:btih:" + (torrent.infoHash || "calculated-hash"))
  }

  async getLatest() {
    return [this.makeTorrent("latest", 0, 0)]
  }

  makeTorrent(name, episodeNumber, seeders) {
    return {
      name: name,
      date: "2024-01-02T03:04:05Z",
      size: 1234,
      formattedSize: "1.2 KB",
      seeders: seeders,
      leechers: 1,
      downloadCount: 2,
      link: "https://example.com/torrent",
      downloadUrl: "https://example.com/torrent/download",
      magnetLink: "magnet:?xt=urn:btih:abcdef1234567890",
      infoHash: "abcdef1234567890",
      resolution: "1080p",
      isBatch: episodeNumber === 0,
      episodeNumber: episodeNumber,
      releaseGroup: "subsplease",
      isBestRelease: true,
      confirmed: true,
    }
  }
}
`

const mangaProviderScript = `
class Provider {
  getSettings() {
    return {
      supportsMultiLanguage: true,
      supportsMultiScanlator: false,
    }
  }

  async search(options) {
    console.log("manga-search:" + options.query)
    return [
      {
        id: options.query === "Blue Lock" ? "exact" : "fallback",
        title: options.query,
        synonyms: [options.query + " Alt"],
        year: options.year,
        image: "https://example.com/manga.jpg",
      },
      {
        id: "mismatch",
        title: "Completely Different",
        synonyms: ["No Match"],
        year: 1999,
        image: "https://example.com/other.jpg",
      },
    ]
  }

  async findChapters(id) {
    return [
      {
        id: id + ":1",
        url: "https://example.com/chapters/1",
        title: "Chapter 1 - Start",
        chapter: "1",
        index: 0,
        language: "en",
      },
    ]
  }

  async findChapterPages(id) {
    return [
      {
        url: "https://example.com/pages/1.jpg",
        index: 0,
        headers: {
          Referer: "https://example.com/chapters/" + id,
        },
      },
    ]
  }
}
`

const onlinestreamProviderScript = `
class Provider {
  getSettings() {
    return {
      episodeServers: ["default", "mirror"],
      supportsDub: true,
    }
  }

  async search(options) {
    console.log("stream-search:" + options.query + ":" + options.dub)
    return [
      {
        id: "stream-" + options.query.toLowerCase().replace(/\s+/g, "-"),
        title: options.query,
        url: "https://example.com/anime/" + options.query.toLowerCase().replace(/\s+/g, "-"),
        subOrDub: options.dub ? "dub" : "sub",
      },
    ]
  }

  async findEpisodes(id) {
    return [
      {
        id: id + "-1",
        number: 1,
        url: "https://example.com/anime/" + id + "/1",
        title: "Episode 1",
      },
    ]
  }

  async findEpisodeServer(episode, server) {
    return {
      server: server,
      headers: {
        Referer: episode.url,
      },
      videoSources: [
        {
          url: "https://cdn.example.com/video.m3u8",
          type: "m3u8",
          quality: "1080p",
          subtitles: [
            {
              id: "en",
              url: "https://cdn.example.com/subtitles/en.vtt",
              language: "en",
              isDefault: true,
            },
          ],
        },
      ],
    }
  }
}
`

const noResultsOnlinestreamProviderScript = `
class Provider {
  getSettings() {
    return {
      episodeServers: ["default"],
      supportsDub: false,
    }
  }

  async search(_options) {
    return []
  }

  async findEpisodes(_id) {
    return []
  }

  async findEpisodeServer(_episode, _server) {
    return {
      server: "default",
      headers: {},
      videoSources: [],
    }
  }
}
`

func TestPlaygroundResponseFormatting(t *testing.T) {
	repo, _, _ := newTestPlaygroundRepository()

	t.Run("string value", func(t *testing.T) {
		playgroundLogger := repo.newPlaygroundDebugLogger()
		playgroundLogger.logger.Info().Msg("plain-value")

		resp := newPlaygroundResponse(playgroundLogger, "ok")
		require.Equal(t, "ok", resp.Value)
		require.Contains(t, resp.Logs, "plain-value")
	})

	t.Run("error value", func(t *testing.T) {
		playgroundLogger := repo.newPlaygroundDebugLogger()
		resp := newPlaygroundResponse(playgroundLogger, fmt.Errorf("boom"))
		require.Contains(t, resp.Value, "ERROR: boom")
	})

	t.Run("marshal failure", func(t *testing.T) {
		playgroundLogger := repo.newPlaygroundDebugLogger()
		resp := newPlaygroundResponse(playgroundLogger, make(chan int))
		require.Contains(t, resp.Value, "ERROR: Failed to marshal value to JSON")
	})
}

func TestPlaygroundRepositoryCachesFetchedMedia(t *testing.T) {
	repo, fakePlatform, fakeMetadataProvider := newTestPlaygroundRepository()

	anime, metadata, err := repo.getAnime(testAnimeID)
	require.NoError(t, err)
	require.NotNil(t, anime)
	require.NotNil(t, metadata)

	anime, metadata, err = repo.getAnime(testAnimeID)
	require.NoError(t, err)
	require.NotNil(t, anime)
	require.NotNil(t, metadata)
	require.Equal(t, 1, fakePlatform.AnimeCalls(testAnimeID))
	require.Equal(t, 2, fakeMetadataProvider.MetadataCalls(testAnimeID))

	manga, err := repo.getManga(testMangaID)
	require.NoError(t, err)
	require.NotNil(t, manga)

	manga, err = repo.getManga(testMangaID)
	require.NoError(t, err)
	require.NotNil(t, manga)
	require.Equal(t, 1, fakePlatform.MangaCalls(testMangaID))
}

func TestRunPlaygroundCodeValidation(t *testing.T) {
	repo, _, _ := newTestPlaygroundRepository()

	resp, err := repo.RunPlaygroundCode(nil)
	require.Nil(t, resp)
	require.EqualError(t, err, "no parameters provided")

	resp, err = repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
		Type:     extension.Type("not-a-provider"),
		Language: extension.LanguageJavascript,
		Code:     "class Provider {}",
		Inputs:   map[string]interface{}{},
	})
	require.Nil(t, resp)
	require.EqualError(t, err, "invalid extension type")
}

func TestRunPlaygroundCodeAnimeTorrentProvider(t *testing.T) {
	repo, _, _ := newTestPlaygroundRepository()

	t.Run("invalid media id", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs:   map[string]interface{}{"mediaId": 0.0},
			Function: "search",
		})
		require.Nil(t, resp)
		require.EqualError(t, err, "invalid mediaId")
	})

	t.Run("search typescript payload", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageTypescript,
			Code:     torrentProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"query":   "One Piece",
			},
			Function: "search",
		})
		require.NoError(t, err)
		require.Contains(t, resp.Logs, "search:One Piece")

		var torrents []hibiketorrent.AnimeTorrent
		decodeJSON(t, resp.Value, &torrents)
		require.Len(t, torrents, 1)
		require.Equal(t, "One Piece:Sample Anime", torrents[0].Name)
		require.Equal(t, "playground-extension", torrents[0].Provider)
		require.Equal(t, 1, torrents[0].Seeders)
	})

	t.Run("smart search includes metadata derived identifiers", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"options": map[string]interface{}{
					"query":         "custom-query",
					"batch":         true,
					"episodeNumber": 1,
					"resolution":    "720",
					"bestReleases":  true,
				},
			},
			Function: "smartSearch",
		})
		require.NoError(t, err)

		var torrents []hibiketorrent.AnimeTorrent
		decodeJSON(t, resp.Value, &torrents)
		require.Len(t, torrents, 1)
		require.Equal(t, "smart:12:9001:77:1:720:true:true", torrents[0].Name)
		require.Equal(t, 77, torrents[0].Seeders)
	})

	t.Run("direct info helpers and settings", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"torrent": `{"infoHash":"hash-123","magnetLink":"magnet:?xt=urn:btih:hash-123"}`,
			},
			Function: "getTorrentInfoHash",
		})
		require.NoError(t, err)
		require.Equal(t, "hash-123", resp.Value)

		resp, err = repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"torrent": `{"infoHash":"hash-123"}`,
			},
			Function: "getTorrentMagnetLink",
		})
		require.NoError(t, err)
		require.Equal(t, "magnet:?xt=urn:btih:hash-123", resp.Value)

		resp, err = repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs:   map[string]interface{}{"mediaId": float64(testAnimeID)},
			Function: "getLatest",
		})
		require.NoError(t, err)
		var latest []hibiketorrent.AnimeTorrent
		decodeJSON(t, resp.Value, &latest)
		require.Len(t, latest, 1)
		require.Equal(t, "latest", latest[0].Name)

		resp, err = repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs:   map[string]interface{}{"mediaId": float64(testAnimeID)},
			Function: "getSettings",
		})
		require.NoError(t, err)
		var settings hibiketorrent.AnimeProviderSettings
		decodeJSON(t, resp.Value, &settings)
		require.True(t, settings.CanSmartSearch)
		require.Equal(t, hibiketorrent.AnimeProviderTypeMain, settings.Type)
	})

	t.Run("unknown call", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeAnimeTorrentProvider,
			Language: extension.LanguageJavascript,
			Code:     torrentProviderScript,
			Inputs:   map[string]interface{}{"mediaId": float64(testAnimeID)},
			Function: "missing",
		})
		require.Nil(t, resp)
		require.EqualError(t, err, "unknown call")
	})
}

func TestRunPlaygroundCodeMangaProvider(t *testing.T) {
	repo, _, _ := newTestPlaygroundRepository()

	t.Run("invalid media id", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeMangaProvider,
			Language: extension.LanguageJavascript,
			Code:     mangaProviderScript,
			Inputs:   map[string]interface{}{"mediaId": -1.0},
			Function: "search",
		})
		require.Nil(t, resp)
		require.EqualError(t, err, "invalid mediaId")
	})

	t.Run("search selects the best result", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeMangaProvider,
			Language: extension.LanguageJavascript,
			Code:     mangaProviderScript,
			Inputs:   map[string]interface{}{"mediaId": float64(testMangaID)},
			Function: "search",
		})
		require.NoError(t, err)
		require.Contains(t, resp.Logs, "manga-search:Blue Lock")

		var result hibikemanga.SearchResult
		decodeJSON(t, resp.Value, &result)
		require.Equal(t, "exact", result.ID)
		require.Equal(t, "playground-extension", result.Provider)
		require.Equal(t, "Blue Lock", result.Title)
	})

	t.Run("chapters and chapter pages", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeMangaProvider,
			Language: extension.LanguageJavascript,
			Code:     mangaProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testMangaID),
				"id":      "series-1",
			},
			Function: "findChapters",
		})
		require.NoError(t, err)
		var chapters []hibikemanga.ChapterDetails
		decodeJSON(t, resp.Value, &chapters)
		require.Len(t, chapters, 1)
		require.Equal(t, "playground-extension", chapters[0].Provider)
		require.Equal(t, "series-1:1", chapters[0].ID)

		resp, err = repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeMangaProvider,
			Language: extension.LanguageJavascript,
			Code:     mangaProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testMangaID),
				"id":      "chapter-1",
			},
			Function: "findChapterPages",
		})
		require.NoError(t, err)
		var pages []hibikemanga.ChapterPage
		decodeJSON(t, resp.Value, &pages)
		require.Len(t, pages, 1)
		require.Equal(t, "playground-extension", pages[0].Provider)
		require.Equal(t, "https://example.com/pages/1.jpg", pages[0].URL)
	})

	t.Run("unknown call", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeMangaProvider,
			Language: extension.LanguageJavascript,
			Code:     mangaProviderScript,
			Inputs:   map[string]interface{}{"mediaId": float64(testMangaID)},
			Function: "missing",
		})
		require.Nil(t, resp)
		require.EqualError(t, err, "unknown call")
	})
}

func TestRunPlaygroundCodeOnlinestreamProvider(t *testing.T) {
	repo, _, _ := newTestPlaygroundRepository()

	t.Run("invalid media id", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeOnlinestreamProvider,
			Language: extension.LanguageJavascript,
			Code:     onlinestreamProviderScript,
			Inputs:   map[string]interface{}{"mediaId": 0.0},
			Function: "search",
		})
		require.Nil(t, resp)
		require.EqualError(t, err, "invalid mediaId")
	})

	t.Run("search returns the best match", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeOnlinestreamProvider,
			Language: extension.LanguageJavascript,
			Code:     onlinestreamProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"dub":     true,
			},
			Function: "search",
		})
		require.NoError(t, err)
		require.Contains(t, resp.Logs, "stream-search:Sample Anime:true")

		var result hibikeonlinestream.SearchResult
		decodeJSON(t, resp.Value, &result)
		require.Equal(t, "Sample Anime", result.Title)
		require.Equal(t, hibikeonlinestream.Dub, result.SubOrDub)
	})

	t.Run("no results are surfaced in the response", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeOnlinestreamProvider,
			Language: extension.LanguageJavascript,
			Code:     noResultsOnlinestreamProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"dub":     false,
			},
			Function: "search",
		})
		require.NoError(t, err)
		require.Contains(t, resp.Value, "ERROR:")
	})

	t.Run("episodes and episode server", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeOnlinestreamProvider,
			Language: extension.LanguageJavascript,
			Code:     onlinestreamProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"id":      "sample-anime",
			},
			Function: "findEpisodes",
		})
		require.NoError(t, err)
		var episodes []hibikeonlinestream.EpisodeDetails
		decodeJSON(t, resp.Value, &episodes)
		require.Len(t, episodes, 1)
		require.Equal(t, "playground-extension", episodes[0].Provider)

		episodeJSON, err := json.Marshal(episodes[0])
		require.NoError(t, err)

		resp, err = repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeOnlinestreamProvider,
			Language: extension.LanguageJavascript,
			Code:     onlinestreamProviderScript,
			Inputs: map[string]interface{}{
				"mediaId": float64(testAnimeID),
				"episode": string(episodeJSON),
				"server":  "mirror",
			},
			Function: "findEpisodeServer",
		})
		require.NoError(t, err)
		var server hibikeonlinestream.EpisodeServer
		decodeJSON(t, resp.Value, &server)
		require.Equal(t, "playground-extension", server.Provider)
		require.Equal(t, "mirror", server.Server)
		require.Len(t, server.VideoSources, 1)
	})

	t.Run("unknown call", func(t *testing.T) {
		resp, err := repo.RunPlaygroundCode(&RunPlaygroundCodeParams{
			Type:     extension.TypeOnlinestreamProvider,
			Language: extension.LanguageJavascript,
			Code:     onlinestreamProviderScript,
			Inputs:   map[string]interface{}{"mediaId": float64(testAnimeID)},
			Function: "missing",
		})
		require.Nil(t, resp)
		require.EqualError(t, err, "unknown call")
	})
}

func newTestPlaygroundRepository() (*PlaygroundRepository, *testmocks.FakePlatform, *testmocks.FakeMetadataProvider) {
	logger := util.NewLogger()
	fakePlatform := testmocks.NewFakePlatformBuilder().
		WithAnime(testmocks.NewBaseAnime(testAnimeID, "Sample Anime")).
		WithManga(testmocks.NewBaseManga(testMangaID, "Blue Lock")).
		Build()
	fakeMetadataProvider := testmocks.NewFakeMetadataProviderBuilder().
		WithAnimeMetadata(testAnimeID, &metadataapi.AnimeMetadata{
			Titles: map[string]string{
				"en": "Sample Anime",
			},
			Episodes: map[string]*metadataapi.EpisodeMetadata{
				"1": {
					Episode:               "1",
					EpisodeNumber:         1,
					AbsoluteEpisodeNumber: 13,
					AnidbEid:              77,
				},
			},
			Mappings: &metadataapi.AnimeMappings{AnidbId: 9001},
		}).
		Build()

	return NewPlaygroundRepository(
		logger,
		util.NewRef[platform.Platform](fakePlatform),
		util.NewRef[metadata_provider.Provider](fakeMetadataProvider),
	), fakePlatform, fakeMetadataProvider
}

func decodeJSON(t *testing.T, raw string, target interface{}) {
	t.Helper()
	require.NoError(t, json.Unmarshal([]byte(raw), target))
}
