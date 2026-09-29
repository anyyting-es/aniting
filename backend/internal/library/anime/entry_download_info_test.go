package anime_test

import (
	"seanime/internal/api/anilist"
	"seanime/internal/library/anime"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestNewEntryDownloadInfoEpisodeZeroDiscrepancy(t *testing.T) {
	// anilist counts episode 0 here, but the metadata maps it as S1.
	// the expected list should still expose that extra slot as episode 0.
	h := newAnimeTestWrapper(t)
	mediaID := 146065

	patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusReleasing)
	patchAnimeCollectionEntry(t, h.animeCollection, mediaID, anilist.AnimeCollectionEntryPatch{
		AiredEpisodes:     new(6),
		NextAiringEpisode: &anilist.BaseAnime_NextAiringEpisode{Episode: 7},
	})
	h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3, 4, 5}, map[string]int{"S1": 1})

	tests := []struct {
		name             string
		progress         int
		expectedEpisodes []downloadEpisodeExpectation
	}{
		{
			name:             "progress zero keeps episode zero",
			progress:         0,
			expectedEpisodes: []downloadEpisodeExpectation{{0, "S1"}, {1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {5, "5"}},
		},
		{
			name:             "progress one only removes episode zero",
			progress:         1,
			expectedEpisodes: []downloadEpisodeExpectation{{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {5, "5"}},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// we only care about the logical episode list here, not local download state.
			info := h.newEntryDownloadInfo(t, mediaID, nil, tt.progress, anilist.MediaListStatusCurrent)

			require.ElementsMatch(t, tt.expectedEpisodes, collectDownloadEpisodes(info))
			require.False(t, info.HasInaccurateSchedule)
			// generated download entries use placeholder local files internally, then clear them back out.
			for _, episode := range info.EpisodesToDownload {
				require.Nil(t, episode.Episode.LocalFile)
				require.Equal(t, episode.AniDBEpisode, episode.Episode.AniDBEpisode)
			}
		})
	}
}

func TestNewEntryDownloadInfoSpecialsDiscrepancyAndBatchFlags(t *testing.T) {
	// this covers the path where anilist's aired count includes specials.
	// we expect the main episodes plus two remapped specials, and finished media should allow batch mode.
	h := newAnimeTestWrapper(t)
	mediaID := 154587

	patchCollectionEntryEpisodeCount(t, h.animeCollection, mediaID, 6)
	patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusFinished)
	metadataOverride := h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3, 4}, map[string]int{"S1": 1, "S2": 2})
	metadataOverride.Episodes["1"].AbsoluteEpisodeNumber = 13

	info := h.newEntryDownloadInfo(t, mediaID, nil, 0, anilist.MediaListStatusCurrent)

	require.ElementsMatch(t, []downloadEpisodeExpectation{{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {6, "S1"}, {5, "S2"}}, collectDownloadEpisodes(info))
	require.True(t, info.CanBatch)
	require.True(t, info.BatchAll)
	require.False(t, info.Rewatch)
	require.Equal(t, 12, info.AbsoluteOffset)
}

func TestNewEntryDownloadInfoCompletedRewatchFiltersDownloadedEpisodes(t *testing.T) {
	// completed entries reset progress back to 0 for download planning.
	// the remaining list should just be "everything not already on disk" and mark this as a rewatch.
	h := newAnimeTestWrapper(t)
	mediaID := 154587

	patchCollectionEntryEpisodeCount(t, h.animeCollection, mediaID, 5)
	patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusFinished)
	h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3, 4, 5}, nil)

	localFiles := anime.NewTestLocalFiles(
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Frieren/%ep.mkv",
			MediaID:          mediaID,
			Episodes: []anime.TestLocalFileEpisode{
				{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
				{Episode: 3, AniDBEpisode: "3", Type: anime.LocalFileTypeMain},
			},
		},
	)

	info := h.newEntryDownloadInfo(t, mediaID, localFiles, 4, anilist.MediaListStatusCompleted)

	require.ElementsMatch(t, []downloadEpisodeExpectation{{2, "2"}, {4, "4"}, {5, "5"}}, collectDownloadEpisodes(info))
	require.True(t, info.CanBatch)
	require.False(t, info.BatchAll)
	require.True(t, info.Rewatch)
}

func TestNewEntryDownloadInfoScheduleFlags(t *testing.T) {
	t.Run("releasing without next airing is inaccurate", func(t *testing.T) {
		// releasing shows without next airing data keep the full aired list,
		// but they should be marked as having an inaccurate schedule.
		h := newAnimeTestWrapper(t)
		mediaID := 154587

		patchCollectionEntryEpisodeCount(t, h.animeCollection, mediaID, 5)
		patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusReleasing)
		h.clearNextAiringEpisode(t, mediaID)
		h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3, 4, 5}, nil)

		info := h.newEntryDownloadInfo(t, mediaID, nil, 0, anilist.MediaListStatusCurrent)

		require.ElementsMatch(t, []downloadEpisodeExpectation{{1, "1"}, {2, "2"}, {3, "3"}, {4, "4"}, {5, "5"}}, collectDownloadEpisodes(info))
		require.True(t, info.HasInaccurateSchedule)
	})

	t.Run("next airing trims future episodes", func(t *testing.T) {
		// once next airing is known, anything at or after that future episode should be filtered out.
		h := newAnimeTestWrapper(t)
		mediaID := 154587

		patchCollectionEntryEpisodeCount(t, h.animeCollection, mediaID, 12)
		patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusReleasing)
		patchAnimeCollectionEntry(t, h.animeCollection, mediaID, anilist.AnimeCollectionEntryPatch{
			NextAiringEpisode: &anilist.BaseAnime_NextAiringEpisode{Episode: 4},
		})
		h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3, 4, 5, 6}, nil)

		info := h.newEntryDownloadInfo(t, mediaID, nil, 0, anilist.MediaListStatusCurrent)

		require.ElementsMatch(t, []downloadEpisodeExpectation{{1, "1"}, {2, "2"}, {3, "3"}}, collectDownloadEpisodes(info))
		require.False(t, info.HasInaccurateSchedule)
	})
}

func TestNewEntryDownloadInfoFallsBackToMetadataCurrentEpisodeCount(t *testing.T) {
	// if media.Episodes is missing, the code falls back to aired episode dates in metadata.
	// only past-dated episodes should survive that fallback count.
	h := newAnimeTestWrapper(t)
	mediaID := 154587

	patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusFinished)
	h.clearEpisodeCount(t, mediaID)
	h.clearNextAiringEpisode(t, mediaID)
	h.setCustomMetadata(mediaID, h.newMetadataWithAirDates(t, mediaID, map[int]string{
		1: "2000-01-01",
		2: "2000-01-02",
		3: "2099-01-01",
	}))

	info := h.newEntryDownloadInfo(t, mediaID, nil, 0, anilist.MediaListStatusCurrent)

	require.ElementsMatch(t, []downloadEpisodeExpectation{{1, "1"}, {2, "2"}}, collectDownloadEpisodes(info))
}

func TestNewEntryDownloadInfoEarlyReturnsAndErrors(t *testing.T) {
	t.Run("not yet released returns empty result", func(t *testing.T) {
		// unreleased media short-circuits before any download planning starts.
		h := newAnimeTestWrapper(t)
		mediaID := 154587

		patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusNotYetReleased)
		h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3}, nil)

		info := h.newEntryDownloadInfo(t, mediaID, nil, 0, anilist.MediaListStatusCurrent)

		require.Empty(t, info.EpisodesToDownload)
		require.False(t, info.CanBatch)
		require.False(t, info.Rewatch)
	})

	t.Run("missing metadata returns an error", func(t *testing.T) {
		// metadata is required for the planner, so nil should fail fast.
		h := newAnimeTestWrapper(t)
		mediaID := 154587
		entry := h.findEntry(t, mediaID)

		_, err := anime.NewEntryDownloadInfo(&anime.NewEntryDownloadInfoOptions{
			LocalFiles:          nil,
			Progress:            new(0),
			Status:              new(anilist.MediaListStatusCurrent),
			Media:               entry.Media,
			MetadataProviderRef: h.metadataProviderRef,
			AnimeMetadata:       nil,
		})

		require.EqualError(t, err, "could not get anime metadata")
	})

	t.Run("missing current episode count returns empty result", func(t *testing.T) {
		// when both media and metadata resolve to zero aired episodes, we just get an empty plan.
		mediaID := 154587
		h := newAnimeTestWrapper(t)

		patchEntryMediaStatus(t, h.animeCollection, mediaID, anilist.MediaStatusFinished)
		h.clearEpisodeCount(t, mediaID)
		h.clearNextAiringEpisode(t, mediaID)
		h.setCustomMetadata(mediaID, h.setEpisodeMetadata(t, mediaID, []int{1, 2, 3}, nil))
		h.clearMetadataAirDates(mediaID)

		info := h.newEntryDownloadInfo(t, mediaID, nil, 0, anilist.MediaListStatusCurrent)

		require.Empty(t, info.EpisodesToDownload)
	})
}

type downloadEpisodeExpectation struct {
	episodeNumber int
	aniDBEpisode  string
}

func collectDownloadEpisodes(info *anime.EntryDownloadInfo) []downloadEpisodeExpectation {
	ret := make([]downloadEpisodeExpectation, 0, len(info.EpisodesToDownload))
	for _, episode := range info.EpisodesToDownload {
		ret = append(ret, downloadEpisodeExpectation{
			episodeNumber: episode.EpisodeNumber,
			aniDBEpisode:  episode.AniDBEpisode,
		})
	}
	return ret
}
