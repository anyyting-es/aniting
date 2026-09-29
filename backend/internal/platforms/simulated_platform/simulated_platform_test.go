package simulated_platform

import (
	"context"
	"errors"
	"seanime/internal/api/anilist"
	"seanime/internal/extension"
	"seanime/internal/local"
	"seanime/internal/testmocks"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"

	"github.com/gqlgo/gqlgenc/clientv2"
	"github.com/stretchr/testify/require"
)

func TestRefreshAnimeCollectionRefreshesMutableEntries(t *testing.T) {
	sp, manager, client := newTestSimulatedPlatform(t, newRefreshingFixtureClient(
		map[int]*anilist.BaseAnime{
			101: testmocks.NewBaseAnimeBuilder(101, "anime current fresh").WithStatus(anilist.MediaStatusFinished).Build(),
			102: testmocks.NewBaseAnimeBuilder(102, "anime paused fresh").WithStatus(anilist.MediaStatusReleasing).Build(),
			103: testmocks.NewBaseAnimeBuilder(103, "anime planning fresh").WithStatus(anilist.MediaStatusFinished).Build(),
		},
		nil,
	))

	// keep a mix of mutable and settled entries so refresh only fetches the ones that can change
	manager.SaveSimulatedAnimeCollection(&anilist.AnimeCollection{
		MediaListCollection: &anilist.AnimeCollection_MediaListCollection{
			Lists: []*anilist.AnimeCollection_MediaListCollection_Lists{
				newAnimeCollectionList(anilist.MediaListStatusCurrent,
					newAnimeCollectionEntry(testmocks.NewBaseAnimeBuilder(101, "anime current stale").WithStatus(anilist.MediaStatusReleasing).Build(), anilist.MediaListStatusCurrent),
					newAnimeCollectionEntry(testmocks.NewBaseAnimeBuilder(105, "anime settled stale").WithStatus(anilist.MediaStatusFinished).Build(), anilist.MediaListStatusCurrent),
				),
				newAnimeCollectionList(anilist.MediaListStatusPaused,
					newAnimeCollectionEntry(testmocks.NewBaseAnimeBuilder(102, "anime paused stale").WithStatus(anilist.MediaStatusNotYetReleased).Build(), anilist.MediaListStatusPaused),
				),
				newAnimeCollectionList(anilist.MediaListStatusPlanning,
					newAnimeCollectionEntry(testmocks.NewBaseAnimeBuilder(103, "anime planning stale").WithStatus(anilist.MediaStatusReleasing).Build(), anilist.MediaListStatusPlanning),
				),
				newAnimeCollectionList(anilist.MediaListStatusCompleted,
					newAnimeCollectionEntry(testmocks.NewBaseAnimeBuilder(104, "anime completed stale").WithStatus(anilist.MediaStatusReleasing).Build(), anilist.MediaListStatusCompleted),
				),
			},
		},
	})

	_, err := sp.RefreshAnimeCollection(context.Background())
	require.NoError(t, err)

	require.ElementsMatch(t, []int{101, 102, 103}, client.animeCalls)

	collection := manager.GetSimulatedAnimeCollection().MustGet()
	currentEntry, found := collection.GetListEntryFromAnimeId(101)
	require.True(t, found)
	require.Equal(t, "anime current fresh", *currentEntry.GetMedia().GetTitle().GetEnglish())
	require.Equal(t, anilist.MediaStatusFinished, *currentEntry.GetMedia().GetStatus())

	pausedEntry, found := collection.GetListEntryFromAnimeId(102)
	require.True(t, found)
	require.Equal(t, "anime paused fresh", *pausedEntry.GetMedia().GetTitle().GetEnglish())

	planningEntry, found := collection.GetListEntryFromAnimeId(103)
	require.True(t, found)
	require.Equal(t, "anime planning fresh", *planningEntry.GetMedia().GetTitle().GetEnglish())

	completedEntry, found := collection.GetListEntryFromAnimeId(104)
	require.True(t, found)
	require.Equal(t, "anime completed stale", *completedEntry.GetMedia().GetTitle().GetEnglish())

	settledEntry, found := collection.GetListEntryFromAnimeId(105)
	require.True(t, found)
	require.Equal(t, "anime settled stale", *settledEntry.GetMedia().GetTitle().GetEnglish())
}

func TestRefreshMangaCollectionRefreshesMutableEntries(t *testing.T) {
	sp, manager, client := newTestSimulatedPlatform(t, newRefreshingFixtureClient(
		nil,
		map[int]*anilist.BaseManga{
			201: testmocks.NewBaseMangaBuilder(201, "manga current fresh").WithStatus(anilist.MediaStatusFinished).Build(),
			202: testmocks.NewBaseMangaBuilder(202, "manga paused fresh").WithStatus(anilist.MediaStatusReleasing).Build(),
			203: testmocks.NewBaseMangaBuilder(203, "manga planning fresh").WithStatus(anilist.MediaStatusFinished).Build(),
		},
	))

	// refresh should skip dropped or already settled manga entries.
	manager.SaveSimulatedMangaCollection(&anilist.MangaCollection{
		MediaListCollection: &anilist.MangaCollection_MediaListCollection{
			Lists: []*anilist.MangaCollection_MediaListCollection_Lists{
				newMangaCollectionList(anilist.MediaListStatusCurrent,
					newMangaCollectionEntry(testmocks.NewBaseMangaBuilder(201, "manga current stale").WithStatus(anilist.MediaStatusReleasing).Build(), anilist.MediaListStatusCurrent),
					newMangaCollectionEntry(testmocks.NewBaseMangaBuilder(205, "manga settled stale").WithStatus(anilist.MediaStatusFinished).Build(), anilist.MediaListStatusCurrent),
				),
				newMangaCollectionList(anilist.MediaListStatusPaused,
					newMangaCollectionEntry(testmocks.NewBaseMangaBuilder(202, "manga paused stale").WithStatus(anilist.MediaStatusNotYetReleased).Build(), anilist.MediaListStatusPaused),
				),
				newMangaCollectionList(anilist.MediaListStatusPlanning,
					newMangaCollectionEntry(testmocks.NewBaseMangaBuilder(203, "manga planning stale").WithStatus(anilist.MediaStatusReleasing).Build(), anilist.MediaListStatusPlanning),
				),
				newMangaCollectionList(anilist.MediaListStatusDropped,
					newMangaCollectionEntry(testmocks.NewBaseMangaBuilder(204, "manga dropped stale").WithStatus(anilist.MediaStatusReleasing).Build(), anilist.MediaListStatusDropped),
				),
			},
		},
	})

	_, err := sp.RefreshMangaCollection(context.Background())
	require.NoError(t, err)

	require.ElementsMatch(t, []int{201, 202, 203}, client.mangaCalls)

	collection := manager.GetSimulatedMangaCollection().MustGet()
	currentEntry, found := collection.GetListEntryFromMangaId(201)
	require.True(t, found)
	require.Equal(t, "manga current fresh", *currentEntry.GetMedia().GetTitle().GetEnglish())
	require.Equal(t, anilist.MediaStatusFinished, *currentEntry.GetMedia().GetStatus())

	pausedEntry, found := collection.GetListEntryFromMangaId(202)
	require.True(t, found)
	require.Equal(t, "manga paused fresh", *pausedEntry.GetMedia().GetTitle().GetEnglish())

	planningEntry, found := collection.GetListEntryFromMangaId(203)
	require.True(t, found)
	require.Equal(t, "manga planning fresh", *planningEntry.GetMedia().GetTitle().GetEnglish())

	droppedEntry, found := collection.GetListEntryFromMangaId(204)
	require.True(t, found)
	require.Equal(t, "manga dropped stale", *droppedEntry.GetMedia().GetTitle().GetEnglish())

	settledEntry, found := collection.GetListEntryFromMangaId(205)
	require.True(t, found)
	require.Equal(t, "manga settled stale", *settledEntry.GetMedia().GetTitle().GetEnglish())
}

func newTestSimulatedPlatform(t *testing.T, client *refreshingFixtureClient) (*SimulatedPlatform, local.Manager, *refreshingFixtureClient) {
	t.Helper()

	env := testutil.NewTestEnv(t)
	logger := env.Logger()
	database := env.MustNewDatabase(logger)
	manager := local.NewTestManager(t, database)

	platformInstance, err := NewSimulatedPlatform(
		manager,
		util.NewRef[anilist.AnilistClient](client),
		util.NewRef(extension.NewUnifiedBank()),
		logger,
		database,
	)
	require.NoError(t, err)

	sp, ok := platformInstance.(*SimulatedPlatform)
	require.True(t, ok)
	return sp, manager, client
}

type refreshingFixtureClient struct {
	anilist.AnilistClient
	animeByID  map[int]*anilist.BaseAnime
	mangaByID  map[int]*anilist.BaseManga
	animeCalls []int
	mangaCalls []int
}

func newRefreshingFixtureClient(animeByID map[int]*anilist.BaseAnime, mangaByID map[int]*anilist.BaseManga) *refreshingFixtureClient {
	return &refreshingFixtureClient{
		AnilistClient: anilist.NewTestAnilistClient(),
		animeByID:     animeByID,
		mangaByID:     mangaByID,
	}
}

func (c *refreshingFixtureClient) BaseAnimeByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*anilist.BaseAnimeByID, error) {
	if id != nil {
		c.animeCalls = append(c.animeCalls, *id)
		if media, ok := c.animeByID[*id]; ok {
			return &anilist.BaseAnimeByID{Media: media}, nil
		}
	}

	return nil, errors.New("unexpected anime refresh request")
}

func (c *refreshingFixtureClient) BaseMangaByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*anilist.BaseMangaByID, error) {
	if id != nil {
		c.mangaCalls = append(c.mangaCalls, *id)
		if media, ok := c.mangaByID[*id]; ok {
			return &anilist.BaseMangaByID{Media: media}, nil
		}
	}

	return nil, errors.New("unexpected manga refresh request")
}

func newAnimeCollectionList(status anilist.MediaListStatus, entries ...*anilist.AnimeCollection_MediaListCollection_Lists_Entries) *anilist.AnimeCollection_MediaListCollection_Lists {
	return &anilist.AnimeCollection_MediaListCollection_Lists{
		Status:       &status,
		Name:         new(string(status)),
		IsCustomList: new(false),
		Entries:      entries,
	}
}

func newAnimeCollectionEntry(media *anilist.BaseAnime, status anilist.MediaListStatus) *anilist.AnimeCollection_MediaListCollection_Lists_Entries {
	return &anilist.AnimeCollection_MediaListCollection_Lists_Entries{
		Media:    media,
		Progress: new(0),
		Score:    new(0.0),
		Repeat:   new(0),
		Status:   &status,
	}
}

func newMangaCollectionList(status anilist.MediaListStatus, entries ...*anilist.MangaCollection_MediaListCollection_Lists_Entries) *anilist.MangaCollection_MediaListCollection_Lists {
	return &anilist.MangaCollection_MediaListCollection_Lists{
		Status:       &status,
		Name:         new(string(status)),
		IsCustomList: new(false),
		Entries:      entries,
	}
}

func newMangaCollectionEntry(media *anilist.BaseManga, status anilist.MediaListStatus) *anilist.MangaCollection_MediaListCollection_Lists_Entries {
	return &anilist.MangaCollection_MediaListCollection_Lists_Entries{
		Media:    media,
		Progress: new(0),
		Score:    new(0.0),
		Repeat:   new(0),
		Status:   &status,
	}
}
