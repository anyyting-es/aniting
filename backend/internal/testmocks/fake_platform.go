package testmocks

import (
	"context"
	"fmt"
	"seanime/internal/api/anilist"
)

type FakePlatformBuilder struct {
	platform *FakePlatform
}

type FakePlatform struct {
	animeByID                   map[int]*anilist.BaseAnime
	mangaByID                   map[int]*anilist.BaseManga
	animeCollection             *anilist.AnimeCollection
	rawAnimeCollection          *anilist.AnimeCollection
	animeCollectionWithRel      *anilist.AnimeCollectionWithRelations
	mangaCollection             *anilist.MangaCollection
	rawMangaCollection          *anilist.MangaCollection
	animeAiringSchedule         *anilist.AnimeAiringSchedule
	viewerStats                 *anilist.ViewerStats
	animeCollectionErr          error
	rawAnimeCollectionErr       error
	animeCollectionWithRelErr   error
	mangaCollectionErr          error
	rawMangaCollectionErr       error
	animeAiringScheduleErr      error
	viewerStatsErr              error
	updateEntryProgressErr      error
	animeCalls                  map[int]int
	mangaCalls                  map[int]int
	animeCollectionCalls        int
	rawAnimeCollectionCalls     int
	animeCollectionWithRelCalls int
	mangaCollectionCalls        int
	rawMangaCollectionCalls     int
	animeAiringScheduleCalls    int
	viewerStatsCalls            int
	updateEntryCalls            []FakeUpdateEntryCall
	updateEntryProgressCalls    []FakeUpdateEntryProgressCall
}

type FakeUpdateEntryCall struct {
	MediaID     int
	Status      *anilist.MediaListStatus
	ScoreRaw    *int
	Progress    *int
	StartedAt   *anilist.FuzzyDateInput
	CompletedAt *anilist.FuzzyDateInput
}

type FakeUpdateEntryProgressCall struct {
	MediaID       int
	Progress      int
	TotalEpisodes *int
}

func NewFakePlatformBuilder() *FakePlatformBuilder {
	return &FakePlatformBuilder{
		platform: &FakePlatform{
			animeByID:  make(map[int]*anilist.BaseAnime),
			mangaByID:  make(map[int]*anilist.BaseManga),
			animeCalls: make(map[int]int),
			mangaCalls: make(map[int]int),
		},
	}
}

func (b *FakePlatformBuilder) WithAnime(anime *anilist.BaseAnime) *FakePlatformBuilder {
	if anime != nil {
		b.platform.animeByID[anime.ID] = anime
	}
	return b
}

func (b *FakePlatformBuilder) WithManga(manga *anilist.BaseManga) *FakePlatformBuilder {
	if manga != nil {
		b.platform.mangaByID[manga.ID] = manga
	}
	return b
}

func (b *FakePlatformBuilder) WithAnimeCollection(collection *anilist.AnimeCollection) *FakePlatformBuilder {
	b.platform.animeCollection = collection
	return b
}

func (b *FakePlatformBuilder) WithAnimeCollectionError(err error) *FakePlatformBuilder {
	b.platform.animeCollectionErr = err
	return b
}

func (b *FakePlatformBuilder) WithRawAnimeCollection(collection *anilist.AnimeCollection) *FakePlatformBuilder {
	b.platform.rawAnimeCollection = collection
	return b
}

func (b *FakePlatformBuilder) WithAnimeCollectionWithRelations(collection *anilist.AnimeCollectionWithRelations) *FakePlatformBuilder {
	b.platform.animeCollectionWithRel = collection
	return b
}

func (b *FakePlatformBuilder) WithMangaCollection(collection *anilist.MangaCollection) *FakePlatformBuilder {
	b.platform.mangaCollection = collection
	return b
}

func (b *FakePlatformBuilder) WithAnimeAiringSchedule(schedule *anilist.AnimeAiringSchedule) *FakePlatformBuilder {
	b.platform.animeAiringSchedule = schedule
	return b
}

func (b *FakePlatformBuilder) WithViewerStats(stats *anilist.ViewerStats) *FakePlatformBuilder {
	b.platform.viewerStats = stats
	return b
}

func (b *FakePlatformBuilder) WithUpdateEntryProgressError(err error) *FakePlatformBuilder {
	b.platform.updateEntryProgressErr = err
	return b
}

func (b *FakePlatformBuilder) Build() *FakePlatform {
	return b.platform
}

func (f *FakePlatform) AnimeCalls(mediaID int) int {
	return f.animeCalls[mediaID]
}

func (f *FakePlatform) MangaCalls(mediaID int) int {
	return f.mangaCalls[mediaID]
}

func (f *FakePlatform) AnimeCollectionCalls() int {
	return f.animeCollectionCalls
}

func (f *FakePlatform) UpdateEntryProgressCalls() []FakeUpdateEntryProgressCall {
	ret := make([]FakeUpdateEntryProgressCall, len(f.updateEntryProgressCalls))
	copy(ret, f.updateEntryProgressCalls)
	return ret
}

func (f *FakePlatform) SetUsername(string) {}

func (f *FakePlatform) UpdateEntryCalls() []FakeUpdateEntryCall {
	ret := make([]FakeUpdateEntryCall, len(f.updateEntryCalls))
	copy(ret, f.updateEntryCalls)
	return ret
}

func (f *FakePlatform) UpdateEntry(_ context.Context, mediaID int, status *anilist.MediaListStatus, scoreRaw *int, progress *int, startedAt *anilist.FuzzyDateInput, completedAt *anilist.FuzzyDateInput) error {
	call := FakeUpdateEntryCall{MediaID: mediaID}
	if status != nil {
		statusCopy := *status
		call.Status = &statusCopy
	}
	if scoreRaw != nil {
		scoreCopy := *scoreRaw
		call.ScoreRaw = &scoreCopy
	}
	if progress != nil {
		progressCopy := *progress
		call.Progress = &progressCopy
	}
	if startedAt != nil {
		startedAtCopy := *startedAt
		call.StartedAt = &startedAtCopy
	}
	if completedAt != nil {
		completedAtCopy := *completedAt
		call.CompletedAt = &completedAtCopy
	}
	f.updateEntryCalls = append(f.updateEntryCalls, call)
	return nil
}

func (f *FakePlatform) UpdateEntryProgress(_ context.Context, mediaID int, progress int, totalEpisodes *int) error {
	call := FakeUpdateEntryProgressCall{}
	call.MediaID = mediaID
	call.Progress = progress
	if totalEpisodes != nil {
		call.TotalEpisodes = new(*totalEpisodes)
	}
	f.updateEntryProgressCalls = append(f.updateEntryProgressCalls, call)
	return f.updateEntryProgressErr
}

func (f *FakePlatform) UpdateEntryRepeat(context.Context, int, int) error {
	return nil
}

func (f *FakePlatform) DeleteEntry(context.Context, int, int) error {
	return nil
}

func (f *FakePlatform) GetAnime(_ context.Context, mediaID int) (*anilist.BaseAnime, error) {
	f.animeCalls[mediaID]++
	anime, ok := f.animeByID[mediaID]
	if !ok {
		return nil, fmt.Errorf("anime %d not found", mediaID)
	}
	return anime, nil
}

func (f *FakePlatform) GetAnimeByMalID(context.Context, int) (*anilist.BaseAnime, error) {
	return nil, nil
}

func (f *FakePlatform) GetAnimeWithRelations(context.Context, int) (*anilist.CompleteAnime, error) {
	return nil, nil
}

func (f *FakePlatform) GetAnimeDetails(context.Context, int) (*anilist.AnimeDetailsById_Media, error) {
	return nil, nil
}

func (f *FakePlatform) GetManga(_ context.Context, mediaID int) (*anilist.BaseManga, error) {
	f.mangaCalls[mediaID]++
	manga, ok := f.mangaByID[mediaID]
	if !ok {
		return nil, fmt.Errorf("manga %d not found", mediaID)
	}
	return manga, nil
}

func (f *FakePlatform) GetAnimeCollection(context.Context, bool) (*anilist.AnimeCollection, error) {
	f.animeCollectionCalls++
	if f.animeCollectionErr != nil {
		return nil, f.animeCollectionErr
	}
	if f.animeCollection == nil {
		f.animeCollection = &anilist.AnimeCollection{}
	}
	return f.animeCollection, nil
}

func (f *FakePlatform) GetRawAnimeCollection(context.Context, bool) (*anilist.AnimeCollection, error) {
	f.rawAnimeCollectionCalls++
	if f.rawAnimeCollectionErr != nil {
		return nil, f.rawAnimeCollectionErr
	}
	return f.rawAnimeCollection, nil
}

func (f *FakePlatform) GetMangaDetails(context.Context, int) (*anilist.MangaDetailsById_Media, error) {
	return nil, nil
}

func (f *FakePlatform) GetAnimeCollectionWithRelations(context.Context) (*anilist.AnimeCollectionWithRelations, error) {
	f.animeCollectionWithRelCalls++
	if f.animeCollectionWithRelErr != nil {
		return nil, f.animeCollectionWithRelErr
	}
	return f.animeCollectionWithRel, nil
}

func (f *FakePlatform) GetMangaCollection(context.Context, bool) (*anilist.MangaCollection, error) {
	f.mangaCollectionCalls++
	if f.mangaCollectionErr != nil {
		return nil, f.mangaCollectionErr
	}
	return f.mangaCollection, nil
}

func (f *FakePlatform) GetRawMangaCollection(context.Context, bool) (*anilist.MangaCollection, error) {
	f.rawMangaCollectionCalls++
	if f.rawMangaCollectionErr != nil {
		return nil, f.rawMangaCollectionErr
	}
	return f.rawMangaCollection, nil
}

func (f *FakePlatform) AddMediaToCollection(context.Context, []int) error {
	return nil
}

func (f *FakePlatform) GetStudioDetails(context.Context, int) (*anilist.StudioDetails, error) {
	return nil, nil
}

func (f *FakePlatform) GetAnilistClient() anilist.AnilistClient {
	return nil
}

func (f *FakePlatform) RefreshAnimeCollection(context.Context) (*anilist.AnimeCollection, error) {
	return nil, nil
}

func (f *FakePlatform) RefreshMangaCollection(context.Context) (*anilist.MangaCollection, error) {
	return nil, nil
}

func (f *FakePlatform) GetViewerStats(context.Context) (*anilist.ViewerStats, error) {
	f.viewerStatsCalls++
	if f.viewerStatsErr != nil {
		return nil, f.viewerStatsErr
	}
	return f.viewerStats, nil
}

func (f *FakePlatform) GetAnimeAiringSchedule(context.Context) (*anilist.AnimeAiringSchedule, error) {
	f.animeAiringScheduleCalls++
	if f.animeAiringScheduleErr != nil {
		return nil, f.animeAiringScheduleErr
	}
	return f.animeAiringSchedule, nil
}

func (f *FakePlatform) ClearCache() {}

func (f *FakePlatform) Close() {}
