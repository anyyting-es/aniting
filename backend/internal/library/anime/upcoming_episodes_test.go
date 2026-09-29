package anime_test

import (
	"seanime/internal/api/anilist"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestNewUpcomingEpisodesSortsAndHydratesMetadata(t *testing.T) {
	// upcoming episodes should be ordered by time until airing,
	// and each item should carry metadata for the exact next episode when we have it.
	h := newAnimeTestWrapper(t)
	h.clearAllNextAiringEpisodes()

	patchAnimeCollectionEntry(t, h.animeCollection, 154587, anilist.AnimeCollectionEntryPatch{
		Status:            new(anilist.MediaListStatusCurrent),
		NextAiringEpisode: &anilist.BaseAnime_NextAiringEpisode{Episode: 8, AiringAt: 1_700_000_200, TimeUntilAiring: 200},
	})
	frierenMetadata := h.setEpisodeMetadata(t, 154587, []int{1, 2, 3, 4, 5, 6, 7, 8}, nil)
	frierenMetadata.Episodes["8"].Title = "frieren next"

	patchAnimeCollectionEntry(t, h.animeCollection, 146065, anilist.AnimeCollectionEntryPatch{
		Status:            new(anilist.MediaListStatusCurrent),
		NextAiringEpisode: &anilist.BaseAnime_NextAiringEpisode{Episode: 3, AiringAt: 1_700_000_050, TimeUntilAiring: 50},
	})
	mushokuMetadata := h.setEpisodeMetadata(t, 146065, []int{1, 2, 3}, nil)
	mushokuMetadata.Episodes["3"].Title = "mushoku next"

	// dropped entries still have next-airing data in fixtures sometimes, but they should be filtered out.
	patchAnimeCollectionEntry(t, h.animeCollection, 21, anilist.AnimeCollectionEntryPatch{
		Status:            new(anilist.MediaListStatusDropped),
		NextAiringEpisode: &anilist.BaseAnime_NextAiringEpisode{Episode: 1100, AiringAt: 1_700_000_010, TimeUntilAiring: 10},
	})

	upcoming := h.newUpcomingEpisodes(t)

	require.Len(t, upcoming.Episodes, 2)
	require.Equal(t, 146065, upcoming.Episodes[0].MediaId)
	require.Equal(t, 3, upcoming.Episodes[0].EpisodeNumber)
	require.Equal(t, 50, upcoming.Episodes[0].TimeUntilAiring)
	require.NotNil(t, upcoming.Episodes[0].EpisodeMetadata)
	require.Equal(t, "mushoku next", upcoming.Episodes[0].EpisodeMetadata.Title)

	require.Equal(t, 154587, upcoming.Episodes[1].MediaId)
	require.Equal(t, 8, upcoming.Episodes[1].EpisodeNumber)
	require.Equal(t, 200, upcoming.Episodes[1].TimeUntilAiring)
	require.NotNil(t, upcoming.Episodes[1].EpisodeMetadata)
	require.Equal(t, "frieren next", upcoming.Episodes[1].EpisodeMetadata.Title)
}
