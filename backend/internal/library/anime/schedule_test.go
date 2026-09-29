package anime_test

import (
	"seanime/internal/api/anilist"
	"seanime/internal/customsource"
	"seanime/internal/library/anime"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestGetScheduleItemsFormatsDeduplicates(t *testing.T) {
	// schedule items are merged from all schedule buckets,
	// deduped by media/episode/time
	h := newAnimeTestWrapper(t)

	patchAnimeCollectionEntry(t, h.animeCollection, 154587, anilist.AnimeCollectionEntryPatch{
		Status:        new(anilist.MediaListStatusCurrent),
		AiredEpisodes: new(12),
	})
	patchCollectionEntryEpisodeCount(t, h.animeCollection, 154587, 12)

	patchAnimeCollectionEntry(t, h.animeCollection, 146065, anilist.AnimeCollectionEntryPatch{
		Status:        new(anilist.MediaListStatusCurrent),
		AiredEpisodes: new(1),
	})
	patchCollectionEntryEpisodeCount(t, h.animeCollection, 146065, 1)
	movieFormat := anilist.MediaFormatMovie
	patchCollectionEntryFormat(t, h.animeCollection, 146065, movieFormat)
	movieEntry := findCollectionEntryByMediaID(t, h.animeCollection, 146065)
	fallbackTitle := "movie fallback"
	movieEntry.Media.Title.UserPreferred = nil
	movieEntry.Media.Title.English = &fallbackTitle

	// extension-backed ids should not leak into the schedule list.
	extensionEntry := findCollectionEntryByMediaID(t, h.animeCollection, 21)
	extensionID := customsource.GenerateMediaId(1, 99)
	extensionEntry.Media.ID = extensionID
	extensionEntry.Status = new(anilist.MediaListStatusCurrent)

	animeSchedule := &anilist.AnimeAiringSchedule{
		Ongoing: &anilist.AnimeAiringSchedule_Ongoing{Media: []*anilist.AnimeSchedule{
			newAnimeSchedule(154587,
				[]*anilist.AnimeSchedule_Previous_Nodes{newPreviousScheduleNode(1_700_000_100, 11, -100)},
				[]*anilist.AnimeSchedule_Upcoming_Nodes{newUpcomingScheduleNode(1_700_000_200, 12, 200)},
			),
			newAnimeSchedule(extensionID, nil, []*anilist.AnimeSchedule_Upcoming_Nodes{newUpcomingScheduleNode(1_700_000_050, 1, 50)}),
		}},
		OngoingNext: &anilist.AnimeAiringSchedule_OngoingNext{Media: []*anilist.AnimeSchedule{
			newAnimeSchedule(154587, nil, []*anilist.AnimeSchedule_Upcoming_Nodes{newUpcomingScheduleNode(1_700_000_200, 12, 200)}),
		}},
		Upcoming: &anilist.AnimeAiringSchedule_Upcoming{Media: []*anilist.AnimeSchedule{
			newAnimeSchedule(146065, nil, []*anilist.AnimeSchedule_Upcoming_Nodes{newUpcomingScheduleNode(1_700_000_300, 1, 300)}),
		}},
	}

	items := anime.GetScheduleItems(animeSchedule, h.animeCollection)

	require.Len(t, items, 3)
	require.Len(t, findScheduleItems(items, 154587, 12), 1)
	require.Empty(t, findScheduleItems(items, extensionID, 1))

	previousItem := findScheduleItem(t, items, 154587, 11)
	require.Equal(t, time.Unix(1_700_000_100, 0).UTC(), previousItem.DateTime)
	require.Equal(t, previousItem.DateTime.Format("15:04"), previousItem.Time)
	require.False(t, previousItem.IsSeasonFinale)
	require.False(t, previousItem.IsMovie)

	finaleItem := findScheduleItem(t, items, 154587, 12)
	require.True(t, finaleItem.IsSeasonFinale)

	movieItem := findScheduleItem(t, items, 146065, 1)
	require.Equal(t, fallbackTitle, movieItem.Title)
	require.True(t, movieItem.IsMovie)
	require.True(t, movieItem.IsSeasonFinale)
}

func TestGetScheduleItemsHandlesNilInputs(t *testing.T) {
	// nil inputs should just give the caller an empty slice instead of exploding.
	require.Empty(t, anime.GetScheduleItems(nil, nil))
}

func newAnimeSchedule(mediaID int, previous []*anilist.AnimeSchedule_Previous_Nodes, upcoming []*anilist.AnimeSchedule_Upcoming_Nodes) *anilist.AnimeSchedule {
	ret := &anilist.AnimeSchedule{ID: mediaID}
	if previous != nil {
		ret.Previous = &anilist.AnimeSchedule_Previous{Nodes: previous}
	}
	if upcoming != nil {
		ret.Upcoming = &anilist.AnimeSchedule_Upcoming{Nodes: upcoming}
	}
	return ret
}

func newPreviousScheduleNode(airingAt int, episode int, timeUntilAiring int) *anilist.AnimeSchedule_Previous_Nodes {
	return &anilist.AnimeSchedule_Previous_Nodes{
		AiringAt:        airingAt,
		Episode:         episode,
		TimeUntilAiring: timeUntilAiring,
	}
}

func newUpcomingScheduleNode(airingAt int, episode int, timeUntilAiring int) *anilist.AnimeSchedule_Upcoming_Nodes {
	return &anilist.AnimeSchedule_Upcoming_Nodes{
		AiringAt:        airingAt,
		Episode:         episode,
		TimeUntilAiring: timeUntilAiring,
	}
}

func findScheduleItem(t *testing.T, items []*anime.ScheduleItem, mediaID int, episodeNumber int) *anime.ScheduleItem {
	t.Helper()
	matching := findScheduleItems(items, mediaID, episodeNumber)
	require.Len(t, matching, 1)
	return matching[0]
}

func findScheduleItems(items []*anime.ScheduleItem, mediaID int, episodeNumber int) []*anime.ScheduleItem {
	ret := make([]*anime.ScheduleItem, 0)
	for _, item := range items {
		if item.MediaId == mediaID && item.EpisodeNumber == episodeNumber {
			ret = append(ret, item)
		}
	}
	return ret
}
