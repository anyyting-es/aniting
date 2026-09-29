package testmocks

import (
	"seanime/internal/api/anilist"
	"seanime/internal/api/metadata"
	"seanime/internal/api/metadata_provider"
	"seanime/internal/util/result"
)

type FakeMetadataProviderBuilder struct {
	provider *FakeMetadataProvider
}

type FakeMetadataProvider struct {
	metadataByID map[int]*metadata.AnimeMetadata
	wrappersByID map[int]metadata_provider.AnimeMetadataWrapper
	calls        map[int]int
	cache        *result.BoundedCache[string, *metadata.AnimeMetadata]
}

type FakeAnimeMetadataWrapper struct {
	episodes map[string]metadata.EpisodeMetadata
}

func NewFakeMetadataProviderBuilder() *FakeMetadataProviderBuilder {
	return &FakeMetadataProviderBuilder{
		provider: &FakeMetadataProvider{
			metadataByID: make(map[int]*metadata.AnimeMetadata),
			wrappersByID: make(map[int]metadata_provider.AnimeMetadataWrapper),
			calls:        make(map[int]int),
			cache:        result.NewBoundedCache[string, *metadata.AnimeMetadata](10),
		},
	}
}

func (b *FakeMetadataProviderBuilder) WithAnimeMetadata(mediaID int, animeMetadata *metadata.AnimeMetadata) *FakeMetadataProviderBuilder {
	if animeMetadata != nil {
		b.provider.metadataByID[mediaID] = animeMetadata
	}
	return b
}

func (b *FakeMetadataProviderBuilder) WithWrapper(mediaID int, wrapper metadata_provider.AnimeMetadataWrapper) *FakeMetadataProviderBuilder {
	if wrapper != nil {
		b.provider.wrappersByID[mediaID] = wrapper
	}
	return b
}

func (b *FakeMetadataProviderBuilder) WithWrapperEpisodes(mediaID int, episodes map[string]metadata.EpisodeMetadata) *FakeMetadataProviderBuilder {
	if episodes == nil {
		return b
	}

	copyEpisodes := make(map[string]metadata.EpisodeMetadata, len(episodes))
	for key, episode := range episodes {
		copyEpisodes[key] = episode
	}

	b.provider.wrappersByID[mediaID] = FakeAnimeMetadataWrapper{episodes: copyEpisodes}
	return b
}

func (b *FakeMetadataProviderBuilder) Build() *FakeMetadataProvider {
	return b.provider
}

func (f *FakeMetadataProvider) MetadataCalls(mediaID int) int {
	return f.calls[mediaID]
}

func (f *FakeMetadataProvider) GetAnimeMetadata(_ metadata.Platform, mediaID int) (*metadata.AnimeMetadata, error) {
	f.calls[mediaID]++
	if animeMetadata, ok := f.metadataByID[mediaID]; ok {
		return animeMetadata, nil
	}
	return nil, nil
}

func (f *FakeMetadataProvider) GetAnimeMetadataWrapper(anime *anilist.BaseAnime, _ *metadata.AnimeMetadata) metadata_provider.AnimeMetadataWrapper {
	if anime != nil {
		if wrapper, ok := f.wrappersByID[anime.ID]; ok {
			return wrapper
		}
	}
	return FakeAnimeMetadataWrapper{episodes: map[string]metadata.EpisodeMetadata{}}
}

func (f *FakeMetadataProvider) GetCache() *result.BoundedCache[string, *metadata.AnimeMetadata] {
	return f.cache
}

func (f *FakeMetadataProvider) SetUseFallbackProvider(bool) {}

func (f *FakeMetadataProvider) ClearCache() {
	f.cache.Clear()
}

func (f *FakeMetadataProvider) Close() {}

func (f FakeAnimeMetadataWrapper) GetEpisodeMetadata(episode string) metadata.EpisodeMetadata {
	if f.episodes == nil {
		return metadata.EpisodeMetadata{}
	}
	if episodeMetadata, ok := f.episodes[episode]; ok {
		return episodeMetadata
	}
	return metadata.EpisodeMetadata{}
}
