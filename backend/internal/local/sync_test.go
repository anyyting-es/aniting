package local

import (
	"errors"
	"fmt"
	"seanime/internal/api/anilist"
	"seanime/internal/extension"
	"seanime/internal/platforms/anilist_platform"
	"seanime/internal/platforms/platform"
	"seanime/internal/testmocks"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func testSetupManager(t *testing.T) (Manager, *anilist.AnimeCollection, *anilist.MangaCollection) {
	env := testutil.NewTestEnv(t)
	logger := env.Logger()

	database := env.MustNewDatabase(logger)
	anilistClient := anilist.NewTestAnilistClient()
	extensionBankRef := util.NewRef(extension.NewUnifiedBank())
	anilistPlatform := anilist_platform.NewAnilistPlatform(util.NewRef[anilist.AnilistClient](anilistClient), extensionBankRef, logger, database)
	animeCollection, err := anilistPlatform.GetAnimeCollection(t.Context(), true)
	require.NoError(t, err)
	mangaCollection, err := anilistPlatform.GetMangaCollection(t.Context(), true)
	require.NoError(t, err)

	manager := NewTestManager(t, database)

	manager.SetAnimeCollection(animeCollection)
	manager.SetMangaCollection(mangaCollection)

	return manager, animeCollection, mangaCollection
}

func TestSync2(t *testing.T) {
	manager, animeCollection, _ := testSetupManager(t)

	err := manager.TrackAnime(130003) // Bocchi the rock
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}
	err = manager.TrackAnime(10800) // Chihayafuru
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}
	err = manager.TrackAnime(171457) // Make Heroine ga Oosugiru!
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}
	err = manager.TrackManga(101517) // JJK
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}

	err = manager.SynchronizeLocal()
	require.NoError(t, err)

	select {
	case <-manager.GetSyncer().doneUpdatingLocalCollections:
		util.Spew(manager.GetLocalAnimeCollection().MustGet())
		util.Spew(manager.GetLocalMangaCollection().MustGet())
		break
	case <-time.After(10 * time.Second):
		t.Log("Timeout")
		break
	}

	anilist.PatchAnimeCollectionEntry(animeCollection, 130003, anilist.AnimeCollectionEntryPatch{
		Status:   new(anilist.MediaListStatusCompleted),
		Progress: new(12), // Mock progress
	})

	fmt.Println("================================================================================================")
	fmt.Println("================================================================================================")

	err = manager.SynchronizeLocal()
	require.NoError(t, err)

	select {
	case <-manager.GetSyncer().doneUpdatingLocalCollections:
		util.Spew(manager.GetLocalAnimeCollection().MustGet())
		util.Spew(manager.GetLocalMangaCollection().MustGet())
		break
	case <-time.After(10 * time.Second):
		t.Log("Timeout")
		break
	}

}

func TestSync(t *testing.T) {
	manager, _, _ := testSetupManager(t)

	err := manager.TrackAnime(130003) // Bocchi the rock
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}
	err = manager.TrackAnime(10800) // Chihayafuru
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}
	err = manager.TrackAnime(171457) // Make Heroine ga Oosugiru!
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}
	err = manager.TrackManga(101517) // JJK
	if err != nil && !errors.Is(err, ErrAlreadyTracked) {
		require.NoError(t, err)
	}

	err = manager.SynchronizeLocal()
	require.NoError(t, err)

	select {
	case <-manager.GetSyncer().doneUpdatingLocalCollections:
		util.Spew(manager.GetLocalAnimeCollection().MustGet())
		util.Spew(manager.GetLocalMangaCollection().MustGet())
		break
	case <-time.After(10 * time.Second):
		t.Log("Timeout")
		break
	}

}

func TestSynchronizeAnilistDoesNotPanicWithoutLocalCollections(t *testing.T) {
	manager, _, _ := testSetupManager(t)

	require.NotPanics(t, func() {
		require.NoError(t, manager.SynchronizeAnilist())
	})
}

func TestSynchronizeSimulatedCollectionToAnilistCreatesMissingEntries(t *testing.T) {
	manager, animeCollection, mangaCollection := testSetupManager(t)
	managerImpl := manager.(*ManagerImpl)

	animeEntry, found := animeCollection.GetListEntryFromAnimeId(130003)
	require.True(t, found)
	mangaEntry, found := mangaCollection.GetListEntryFromMangaId(101517)
	require.True(t, found)

	manager.SaveSimulatedAnimeCollection(newSingleAnimeCollection(animeEntry))
	manager.SaveSimulatedMangaCollection(newSingleMangaCollection(mangaEntry))

	manager.SetAnimeCollection(newEmptyAnimeCollection())
	manager.SetMangaCollection(newEmptyMangaCollection())

	fakePlatform := testmocks.NewFakePlatformBuilder().Build()
	managerImpl.anilistPlatformRef = util.NewRef[platform.Platform](fakePlatform)

	require.NoError(t, manager.SynchronizeSimulatedCollectionToAnilist())

	updateCalls := fakePlatform.UpdateEntryCalls()
	require.Len(t, updateCalls, 2)
	require.Contains(t, []int{updateCalls[0].MediaID, updateCalls[1].MediaID}, 130003)
	require.Contains(t, []int{updateCalls[0].MediaID, updateCalls[1].MediaID}, 101517)

	for _, call := range updateCalls {
		switch call.MediaID {
		case 130003:
			require.NotNil(t, call.Status)
			require.Equal(t, animeEntry.GetStatus(), call.Status)
		case 101517:
			require.NotNil(t, call.Status)
			require.Equal(t, mangaEntry.GetStatus(), call.Status)
		}
	}
}

func newEmptyAnimeCollection() *anilist.AnimeCollection {
	return &anilist.AnimeCollection{
		MediaListCollection: &anilist.AnimeCollection_MediaListCollection{
			Lists: []*anilist.AnimeCollection_MediaListCollection_Lists{},
		},
	}
}

func newEmptyMangaCollection() *anilist.MangaCollection {
	return &anilist.MangaCollection{
		MediaListCollection: &anilist.MangaCollection_MediaListCollection{
			Lists: []*anilist.MangaCollection_MediaListCollection_Lists{},
		},
	}
}

func newSingleAnimeCollection(entry *anilist.AnimeListEntry) *anilist.AnimeCollection {
	return &anilist.AnimeCollection{
		MediaListCollection: &anilist.AnimeCollection_MediaListCollection{
			Lists: []*anilist.AnimeCollection_MediaListCollection_Lists{
				{
					Status:  entry.Status,
					Entries: []*anilist.AnimeCollection_MediaListCollection_Lists_Entries{entry},
				},
			},
		},
	}
}

func newSingleMangaCollection(entry *anilist.MangaListEntry) *anilist.MangaCollection {
	return &anilist.MangaCollection{
		MediaListCollection: &anilist.MangaCollection_MediaListCollection{
			Lists: []*anilist.MangaCollection_MediaListCollection_Lists{
				{
					Status:  entry.Status,
					Entries: []*anilist.MangaCollection_MediaListCollection_Lists_Entries{entry},
				},
			},
		},
	}
}
