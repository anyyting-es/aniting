package anime_test

import (
	"seanime/internal/api/anilist"
	"seanime/internal/library/anime"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestNewLibraryCollectionContinueWatchingList(t *testing.T) {
	h := newAnimeTestWrapper(t)

	localFiles := make([]*anime.LocalFile, 0)
	localFiles = append(localFiles, anime.NewTestLocalFiles(
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Sousou no Frieren/[SubsPlease] Sousou no Frieren - %ep.mkv",
			MediaID:          154587,
			Episodes: []anime.TestLocalFileEpisode{
				{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
				{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
				{Episode: 3, AniDBEpisode: "3", Type: anime.LocalFileTypeMain},
				{Episode: 4, AniDBEpisode: "4", Type: anime.LocalFileTypeMain},
				{Episode: 5, AniDBEpisode: "5", Type: anime.LocalFileTypeMain},
				{Episode: 6, AniDBEpisode: "6", Type: anime.LocalFileTypeMain},
				{Episode: 7, AniDBEpisode: "7", Type: anime.LocalFileTypeMain},
			},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Mushoku Tensei/[SubsPlease] Mushoku Tensei S2 - %ep.mkv",
			MediaID:          146065,
			Episodes: []anime.TestLocalFileEpisode{
				{Episode: 0, AniDBEpisode: "S1", Type: anime.LocalFileTypeMain},
				{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
				{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
				{Episode: 3, AniDBEpisode: "3", Type: anime.LocalFileTypeMain},
				{Episode: 4, AniDBEpisode: "4", Type: anime.LocalFileTypeMain},
				{Episode: 5, AniDBEpisode: "5", Type: anime.LocalFileTypeMain},
			},
		},
	)...)

	patchAnimeCollectionEntry(t, h.animeCollection, 154587, anilist.AnimeCollectionEntryPatch{
		Status:   new(anilist.MediaListStatusCurrent),
		Progress: new(4),
	})
	patchCollectionEntryEpisodeCount(t, h.animeCollection, 154587, 7)
	h.setEpisodeMetadata(t, 154587, []int{1, 2, 3, 4, 5, 6, 7}, nil)

	patchAnimeCollectionEntry(t, h.animeCollection, 146065, anilist.AnimeCollectionEntryPatch{
		Status:   new(anilist.MediaListStatusCurrent),
		Progress: new(1),
	})
	patchCollectionEntryEpisodeCount(t, h.animeCollection, 146065, 6)
	h.setEpisodeMetadata(t, 146065, []int{1, 2, 3, 4, 5}, map[string]int{"S1": 1})

	libraryCollection := h.newLibraryCollection(t, localFiles)

	require.Len(t, libraryCollection.ContinueWatchingList, 2)
	require.Equal(t, 154587, libraryCollection.ContinueWatchingList[0].BaseAnime.ID)
	require.Equal(t, 5, libraryCollection.ContinueWatchingList[0].EpisodeNumber)
	require.Equal(t, 146065, libraryCollection.ContinueWatchingList[1].BaseAnime.ID)
	require.Equal(t, 1, libraryCollection.ContinueWatchingList[1].EpisodeNumber)
	require.Empty(t, libraryCollection.UnmatchedLocalFiles)
	require.Empty(t, libraryCollection.UnknownGroups)
}

func TestNewLibraryCollectionMergesRepeatingAndHydratesStats(t *testing.T) {
	h := newAnimeTestWrapper(t)

	localFiles := anime.NewTestLocalFiles(
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Sousou no Frieren/%ep.mkv",
			MediaID:          154587,
			Episodes:         []anime.TestLocalFileEpisode{{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain}},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/One Piece/%ep.mkv",
			MediaID:          21,
			Episodes:         []anime.TestLocalFileEpisode{{Episode: 1070, AniDBEpisode: "1070", Type: anime.LocalFileTypeMain}},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Mushoku/%ep.mkv",
			MediaID:          146065,
			Episodes:         []anime.TestLocalFileEpisode{{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain}},
		},
	)

	patchAnimeCollectionEntry(t, h.animeCollection, 154587, anilist.AnimeCollectionEntryPatch{
		Status:   new(anilist.MediaListStatusCurrent),
		Progress: new(0),
	})
	onePieceEntry := patchAnimeCollectionEntry(t, h.animeCollection, 21, anilist.AnimeCollectionEntryPatch{
		Status:   new(anilist.MediaListStatusRepeating),
		Progress: new(1060),
	})
	mushokuEntry := patchAnimeCollectionEntry(t, h.animeCollection, 146065, anilist.AnimeCollectionEntryPatch{
		Status:   new(anilist.MediaListStatusCompleted),
		Progress: new(12),
	})

	movieFormat := anilist.MediaFormatMovie
	showFormat := anilist.MediaFormatTv
	ovaFormat := anilist.MediaFormatOva
	patchCollectionEntryFormat(t, h.animeCollection, 154587, showFormat)
	onePieceEntry.Media.Format = &movieFormat
	mushokuEntry.Media.Format = &ovaFormat

	libraryCollection := h.newLibraryCollection(t, localFiles)

	currentList := findCollectionListByStatus(t, libraryCollection, anilist.MediaListStatusCurrent)
	require.Len(t, currentList.Entries, 2)
	require.ElementsMatch(t, []int{154587, 21}, []int{currentList.Entries[0].MediaId, currentList.Entries[1].MediaId})
	require.Nil(t, findOptionalCollectionListByStatus(libraryCollection, anilist.MediaListStatusRepeating))

	var repeatingEntry *anime.LibraryCollectionEntry
	for _, entry := range currentList.Entries {
		if entry.MediaId == 21 {
			repeatingEntry = entry
			break
		}
	}
	require.NotNil(t, repeatingEntry)
	require.NotNil(t, repeatingEntry.EntryListData.Status)
	require.Equal(t, anilist.MediaListStatusRepeating, *repeatingEntry.EntryListData.Status)

	require.NotNil(t, libraryCollection.Stats)
	require.Equal(t, 3, libraryCollection.Stats.TotalEntries)
	require.Equal(t, len(localFiles), libraryCollection.Stats.TotalFiles)
	require.Equal(t, 1, libraryCollection.Stats.TotalShows)
	require.Equal(t, 1, libraryCollection.Stats.TotalMovies)
	require.Equal(t, 1, libraryCollection.Stats.TotalSpecials)
}

func TestNewLibraryCollectionGroupsUnknownIgnoredAndUnmatchedFiles(t *testing.T) {
	h := newAnimeTestWrapper(t)

	localFiles := anime.NewTestLocalFiles(
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Unknown Show/%ep.mkv",
			MediaID:          999999,
			Episodes: []anime.TestLocalFileEpisode{
				{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
				{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
			},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Resolve/A/%ep.mkv",
			MediaID:          0,
			Episodes: []anime.TestLocalFileEpisode{
				{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain},
				{Episode: 2, AniDBEpisode: "2", Type: anime.LocalFileTypeMain},
			},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Resolve/B/%ep.mkv",
			MediaID:          0,
			Episodes:         []anime.TestLocalFileEpisode{{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain}},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Ignored/Z/%ep.mkv",
			MediaID:          0,
			Episodes:         []anime.TestLocalFileEpisode{{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain}},
		},
		anime.TestLocalFileGroup{
			LibraryPath:      "/Anime",
			FilePathTemplate: "/Anime/Ignored/A/%ep.mkv",
			MediaID:          0,
			Episodes:         []anime.TestLocalFileEpisode{{Episode: 1, AniDBEpisode: "1", Type: anime.LocalFileTypeMain}},
		},
	)

	localFiles[5].Ignored = true
	localFiles[6].Ignored = true

	libraryCollection := h.newLibraryCollection(t, localFiles)

	require.Empty(t, libraryCollection.ContinueWatchingList)
	require.Len(t, libraryCollection.UnknownGroups, 1)
	require.Equal(t, 999999, libraryCollection.UnknownGroups[0].MediaId)
	require.Len(t, libraryCollection.UnknownGroups[0].LocalFiles, 2)

	require.Len(t, libraryCollection.UnmatchedLocalFiles, 3)
	require.Len(t, libraryCollection.UnmatchedGroups, 2)
	require.Equal(t, "/Anime/Resolve/A", libraryCollection.UnmatchedGroups[0].Dir)
	require.Len(t, libraryCollection.UnmatchedGroups[0].LocalFiles, 2)
	require.Equal(t, "/Anime/Resolve/B", libraryCollection.UnmatchedGroups[1].Dir)
	require.Len(t, libraryCollection.UnmatchedGroups[1].LocalFiles, 1)

	require.Len(t, libraryCollection.IgnoredLocalFiles, 2)
	require.Equal(t, "/Anime/Ignored/A/1.mkv", libraryCollection.IgnoredLocalFiles[0].GetPath())
	require.Equal(t, "/Anime/Ignored/Z/1.mkv", libraryCollection.IgnoredLocalFiles[1].GetPath())
}

func findCollectionListByStatus(t *testing.T, libraryCollection *anime.LibraryCollection, status anilist.MediaListStatus) *anime.LibraryCollectionList {
	t.Helper()
	list := findOptionalCollectionListByStatus(libraryCollection, status)
	require.NotNil(t, list)
	return list
}

func findOptionalCollectionListByStatus(libraryCollection *anime.LibraryCollection, status anilist.MediaListStatus) *anime.LibraryCollectionList {
	for _, list := range libraryCollection.Lists {
		if list.Status == status {
			return list
		}
	}
	return nil
}
