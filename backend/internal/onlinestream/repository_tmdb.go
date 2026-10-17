package onlinestream

import (
	"context"
	"fmt"
	"strings"

	"seanime/internal/extension"
	hibikeonlinestream "seanime/internal/extension/hibike/onlinestream"
	"seanime/internal/util/filecache"

	"github.com/samber/lo"
)

// GetTmdbEpisodeSources resolves the video sources of a TMDB movie/series episode
// using an online streaming provider that declares Settings.SupportsTmdb.
//
// This reuses the onlinestream provider interface (Search / FindEpisodes / FindEpisodeServer).
// The only difference with the AniList flow is that the media descriptor is built from
// TMDB data (tmdbId, mediaType, titles, year, season) instead of an AniList ID.
func (r *Repository) GetTmdbEpisodeSources(_ context.Context, provider string, media *hibikeonlinestream.Media, number int, dubbed bool, refresh bool) (*EpisodeSource, error) {
	if provider == "" {
		return nil, ErrNoVideoSourceFound
	}
	if media == nil || media.TmdbId == 0 {
		return nil, fmt.Errorf("onlinestream: missing TMDB media")
	}

	providerExtension, ok := extension.GetExtension[extension.OnlinestreamProviderExtension](r.extensionBankRef.Get(), provider)
	if !ok {
		return nil, fmt.Errorf("provider extension '%s' not found", provider)
	}

	if !providerExtension.GetProvider().GetSettings().SupportsTmdb {
		return nil, fmt.Errorf("provider '%s' does not support TMDB media", provider)
	}

	// Cache buckets are namespaced with "tmdb" to avoid colliding with AniList-keyed entries.
	cacheId := fmt.Sprintf("%s_%d_%s_%d", provider, media.TmdbId, media.MediaType, media.Season)
	fcEpisodeListBucket := filecache.NewBucket("onlinestream_tmdb_episode-list_"+cacheId, episodeListCacheTTL)
	fcEpisodeDataBucket := filecache.NewBucket("onlinestream_tmdb_episode-data_"+cacheId, episodeSourceCacheTTL)

	// +---------------------+
	// |    Episode list     |
	// +---------------------+

	var providerEpisodeList []*hibikeonlinestream.EpisodeDetails
	episodeListKey := fmt.Sprintf("%d$%s$%v", media.TmdbId, provider, dubbed)
	if found, _ := r.fileCacher.Get(fcEpisodeListBucket, episodeListKey, &providerEpisodeList); !found {
		var err error
		providerEpisodeList, err = r.getTmdbProviderEpisodeList(providerExtension, media, dubbed)
		if err != nil {
			r.logger.Error().Err(err).Msg("onlinestream: Failed to get TMDB provider episodes")
			return nil, err
		}
		_ = r.fileCacher.Set(fcEpisodeListBucket, episodeListKey, providerEpisodeList)
	}

	// +---------------------+
	// |   Episode servers   |
	// +---------------------+

	var episodeDetails *hibikeonlinestream.EpisodeDetails
	for _, e := range providerEpisodeList {
		if e.Number == number {
			episodeDetails = e
			break
		}
	}
	if episodeDetails == nil {
		return nil, errNoEpisodeSourceFound
	}

	episodeKey := fmt.Sprintf("%d$%s$%d$%v", media.TmdbId, provider, number, dubbed)
	var cachedEpisode *episodeData
	if found, _ := r.fileCacher.Get(fcEpisodeDataBucket, episodeKey, &cachedEpisode); found && !refresh && cachedEpisode != nil {
		return episodeDataToSource(cachedEpisode), nil
	}

	servers, err := r.getProviderEpisodeServers(provider, episodeDetails)
	if err != nil {
		return nil, err
	}

	episode := &episodeData{
		ID:      episodeDetails.ID,
		Number:  episodeDetails.Number,
		Title:   episodeDetails.Title,
		Servers: servers,
	}
	_ = r.fileCacher.Set(fcEpisodeDataBucket, episodeKey, episode)

	return episodeDataToSource(episode), nil
}

// getTmdbProviderEpisodeList resolves the provider's media id by searching with the TMDB titles,
// then fetches the episode list.
func (r *Repository) getTmdbProviderEpisodeList(providerExtension extension.OnlinestreamProviderExtension, media *hibikeonlinestream.Media, dubbed bool) ([]*hibikeonlinestream.EpisodeDetails, error) {
	queries := tmdbSearchQueries(media)
	if len(queries) == 0 {
		return nil, ErrNoAnimeFound
	}

	year := 0
	if media.StartDate != nil {
		year = media.StartDate.Year
	}

	searchResults := make([]*hibikeonlinestream.SearchResult, 0)
	added := make(map[string]struct{})

	for _, query := range queries {
		res, err := providerExtension.GetProvider().Search(hibikeonlinestream.SearchOptions{
			Media: *media,
			Query: query,
			Dub:   dubbed,
			Year:  year,
		})
		if err != nil {
			r.logger.Error().Err(err).Str("query", query).Msg("onlinestream: Failed to search TMDB media")
			continue
		}
		for _, sr := range res {
			if _, ok := added[sr.ID]; ok {
				continue
			}
			added[sr.ID] = struct{}{}
			searchResults = append(searchResults, sr)
		}
	}

	if len(searchResults) == 0 {
		return nil, fmt.Errorf("automatic matching returned no results")
	}

	bestResult, found := GetBestSearchResult(searchResults, tmdbSearchQueriesPtr(media))
	if !found {
		return nil, ErrNoAnimeFound
	}

	eps, err := providerExtension.GetProvider().FindEpisodes(bestResult.ID)
	if err != nil {
		return nil, fmt.Errorf("provider returned an error: %w", err)
	}
	if len(eps) == 0 {
		return nil, fmt.Errorf("provider returned no episodes")
	}

	return eps, nil
}

// episodeDataToSource converts an episodeData into the public EpisodeSource shape.
func episodeDataToSource(episode *episodeData) *EpisodeSource {
	s := &EpisodeSource{
		Number:       episode.Number,
		VideoSources: make([]*VideoSource, 0),
	}
	for _, es := range episode.Servers {
		for _, vs := range es.VideoSources {
			s.VideoSources = append(s.VideoSources, &VideoSource{
				Server:  es.Server,
				Headers: es.Headers,
				URL:     vs.URL,
				Label:   vs.Label,
				Quality: vs.Quality,
				Type:    vs.Type,
				Subtitles: lo.Map(vs.Subtitles, func(sub *hibikeonlinestream.VideoSubtitle, _ int) *Subtitle {
					return subtitleFromProvider(sub)
				}),
			})
		}
	}
	return s
}

// tmdbSearchQueries returns the distinct non-empty titles to search with.
func tmdbSearchQueries(media *hibikeonlinestream.Media) []string {
	queries := make([]string, 0, 3)
	seen := make(map[string]struct{})
	add := func(s string) {
		s = strings.TrimSpace(s)
		if s == "" {
			return
		}
		if _, ok := seen[s]; ok {
			return
		}
		seen[s] = struct{}{}
		queries = append(queries, s)
	}
	if media.EnglishTitle != nil {
		add(*media.EnglishTitle)
	}
	add(media.RomajiTitle)
	for _, s := range media.Synonyms {
		add(s)
	}
	return queries
}

func tmdbSearchQueriesPtr(media *hibikeonlinestream.Media) []*string {
	queries := tmdbSearchQueries(media)
	titles := make([]*string, 0, len(queries))
	for _, q := range queries {
		q := q
		titles = append(titles, &q)
	}
	return titles
}
