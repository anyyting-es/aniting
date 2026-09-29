package anilist

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"sort"
	"strings"

	"github.com/goccy/go-json"
	"github.com/gqlgo/gqlgenc/clientv2"
	"github.com/rs/zerolog"
)

// This file contains helper functions for testing the anilist package

func NewTestAnilistClient() AnilistClient {
	return NewFixtureAnilistClient()
}

// FixtureAnilistClient is a fixture-backed test implementation of AnilistClient.
// It reads committed fixtures first and can fall back to the live client when
// a fixture is missing. Fixture writes are opt-in via SEANIME_TEST_RECORD_ANILIST_FIXTURES.
type FixtureAnilistClient struct {
	realAnilistClient AnilistClient
	logger            *zerolog.Logger
}

type fixtureCustomQueryRequest struct {
	Query     string          `json:"query"`
	Variables json.RawMessage `json:"variables"`
}

type fixtureListAnimeVariables struct {
	Page                *int           `json:"page"`
	Search              *string        `json:"search"`
	PerPage             *int           `json:"perPage"`
	Sort                []*MediaSort   `json:"sort"`
	Status              []*MediaStatus `json:"status"`
	Genres              []*string      `json:"genres"`
	Tags                []*string      `json:"tags"`
	AverageScoreGreater *int           `json:"averageScore_greater"`
	Season              *MediaSeason   `json:"season"`
	SeasonYear          *int           `json:"seasonYear"`
	Format              *MediaFormat   `json:"format"`
	IsAdult             *bool          `json:"isAdult"`
	CountryOfOrigin     *string        `json:"countryOfOrigin"`
}

type fixtureListRecentAnimeVariables struct {
	Page            *int          `json:"page"`
	PerPage         *int          `json:"perPage"`
	AiringAtGreater *int          `json:"airingAt_greater"`
	AiringAtLesser  *int          `json:"airingAt_lesser"`
	NotYetAired     *bool         `json:"notYetAired"`
	Sort            []*AiringSort `json:"sort"`
}

func NewFixtureAnilistClient() *FixtureAnilistClient {
	return NewFixtureAnilistClientWithToken("")
}

func NewFixtureAnilistClientWithToken(token string) *FixtureAnilistClient {
	return &FixtureAnilistClient{
		realAnilistClient: NewAnilistClient(token, ""),
		logger:            util.NewLogger(),
	}
}

func (ac *FixtureAnilistClient) IsAuthenticated() bool {
	return ac.realAnilistClient.IsAuthenticated()
}

func (ac *FixtureAnilistClient) GetCacheDir() string {
	return ""
}

func (ac *FixtureAnilistClient) CustomQuery(body []byte, logger *zerolog.Logger, token ...string) (data interface{}, err error) {
	var req fixtureCustomQueryRequest
	if err := json.Unmarshal(body, &req); err != nil {
		return nil, err
	}

	switch strings.TrimSpace(req.Query) {
	case strings.TrimSpace(ListAnimeDocument):
		var vars fixtureListAnimeVariables
		if len(req.Variables) > 0 && string(req.Variables) != "null" {
			if err := json.Unmarshal(req.Variables, &vars); err != nil {
				return nil, err
			}
		}

		return ac.ListAnime(
			context.Background(),
			vars.Page,
			vars.Search,
			vars.PerPage,
			vars.Sort,
			vars.Status,
			vars.Genres,
			vars.Tags,
			vars.AverageScoreGreater,
			vars.Season,
			vars.SeasonYear,
			vars.Format,
			vars.IsAdult,
		)
	case strings.TrimSpace(ListRecentAiringAnimeQuery):
		var vars fixtureListRecentAnimeVariables
		if len(req.Variables) > 0 && string(req.Variables) != "null" {
			if err := json.Unmarshal(req.Variables, &vars); err != nil {
				return nil, err
			}
		}

		return ac.ListRecentAnime(
			context.Background(),
			vars.Page,
			vars.PerPage,
			vars.AiringAtGreater,
			vars.AiringAtLesser,
			vars.NotYetAired,
		)
	}

	fixturePath := customQueryFixturePath(body)
	var cached interface{}
	loaded, err := loadJSONFixture(fixturePath, &cached)
	if err != nil {
		return nil, err
	}
	if loaded {
		ac.logger.Trace().Str("path", fixturePath).Msg("FixtureAnilistClient: CACHE HIT [CustomQuery]")
		return cached, nil
	}

	if ac.canUseLiveFallback() {
		ac.logger.Warn().Str("path", fixturePath).Msg("FixtureAnilistClient: CACHE MISS [CustomQuery]")
		data, err := customQuery(body, logger, token...)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, data, ac.logger); err != nil {
			return nil, err
		}
		return data, nil
	}

	return nil, ac.missingFixtureError("CustomQuery", req.Query)
}

func loadJSONFixture(path string, out interface{}) (bool, error) {
	file, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	defer file.Close()

	if err := json.NewDecoder(file).Decode(out); err != nil {
		return false, err
	}

	return true, nil
}

func requireJSONFixture(path string, out interface{}) error {
	loaded, err := loadJSONFixture(path, out)
	if err != nil {
		return err
	}
	if !loaded {
		return fmt.Errorf("missing required AniList fixture: %s", path)
	}

	return nil
}

func maybeWriteJSONFixture(path string, value interface{}, logger *zerolog.Logger) error {
	if !testutil.ShouldRecordAnilistFixtures() {
		if logger != nil {
			logger.Debug().Str("path", path).Msg("anilist: skipped fixture write; record mode disabled")
		}
		return nil
	}

	data, err := json.Marshal(value)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

func customQueryFixturePath(body []byte) string {
	sum := sha256.Sum256(body)
	return filepath.Join(testutil.ProjectRoot(), "test", "testdata", "anilist-custom-query", hex.EncodeToString(sum[:])+".json")
}

func (ac *FixtureAnilistClient) canUseLiveFallback() bool {
	return ac.realAnilistClient.IsAuthenticated() && testutil.ShouldRecordAnilistFixtures()
}

func (ac *FixtureAnilistClient) missingFixtureError(name string, key interface{}) error {
	return fmt.Errorf(
		"missing AniList fixture for %s (%v); use an authenticated client and set %s=true to refresh fixtures",
		name,
		key,
		testutil.RecordAnilistFixturesEnvName,
	)
}

func fixtureCollectionKey(userName *string) string {
	if userName == nil || *userName == "" {
		return "default"
	}

	return *userName
}

func loadAnimeCollectionFixtures() ([]*AnimeCollection, error) {
	paths := []string{
		testutil.TestDataPath("AnimeCollection"),
	}

	collections := make([]*AnimeCollection, 0, len(paths))
	for _, path := range paths {
		var collection *AnimeCollection
		loaded, err := loadJSONFixture(path, &collection)
		if err != nil {
			return nil, err
		}
		if loaded && collection != nil {
			collections = append(collections, collection)
		}
	}

	return collections, nil
}

func loadAnimeCollectionWithRelationsFixtures() ([]*AnimeCollectionWithRelations, error) {
	paths := []string{
		testutil.TestDataPath("AnimeCollectionWithRelations"),
	}

	collections := make([]*AnimeCollectionWithRelations, 0, len(paths))
	for _, path := range paths {
		var collection *AnimeCollectionWithRelations
		loaded, err := loadJSONFixture(path, &collection)
		if err != nil {
			return nil, err
		}
		if loaded && collection != nil {
			collections = append(collections, collection)
		}
	}

	return collections, nil
}

func findBaseAnimeInFixtureCollections(match func(*BaseAnime) bool) (*BaseAnime, bool, error) {
	collections, err := loadAnimeCollectionFixtures()
	if err != nil {
		return nil, false, err
	}

	for _, collection := range collections {
		for _, media := range collection.GetAllAnime() {
			if match(media) {
				return media, true, nil
			}
		}
	}

	return nil, false, nil
}

func findCompleteAnimeInFixtureCollections(id int) (*CompleteAnime, bool, error) {
	collections, err := loadAnimeCollectionWithRelationsFixtures()
	if err != nil {
		return nil, false, err
	}

	for _, collection := range collections {
		for _, media := range collection.GetAllAnime() {
			if media.ID == id {
				return media, true, nil
			}
		}
	}

	return nil, false, nil
}

func baseAnimeFixtureSlice(page *int, perPage *int) ([]*BaseAnime, *ListAnime_Page_PageInfo, error) {
	collections, err := loadAnimeCollectionFixtures()
	if err != nil {
		return nil, nil, err
	}

	allMedia := make([]*BaseAnime, 0)
	seen := make(map[int]struct{})
	for _, collection := range collections {
		for _, media := range collection.GetAllAnime() {
			if media == nil {
				continue
			}
			if _, ok := seen[media.ID]; ok {
				continue
			}
			seen[media.ID] = struct{}{}
			allMedia = append(allMedia, media)
		}
	}

	currentPage := 1
	if page != nil && *page > 0 {
		currentPage = *page
	}
	perPageValue := 20
	if perPage != nil && *perPage > 0 {
		perPageValue = *perPage
	}

	total := len(allMedia)
	lastPage := 1
	if total > 0 {
		lastPage = (total + perPageValue - 1) / perPageValue
	}

	start := (currentPage - 1) * perPageValue
	if start > total {
		start = total
	}
	end := start + perPageValue
	if end > total {
		end = total
	}

	hasNextPage := end < total
	pageInfo := &ListAnime_Page_PageInfo{
		CurrentPage: &currentPage,
		HasNextPage: &hasNextPage,
		LastPage:    &lastPage,
		PerPage:     &perPageValue,
		Total:       &total,
	}

	return allMedia[start:end], pageInfo, nil
}

func (ac *FixtureAnilistClient) BaseAnimeByMalID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*BaseAnimeByMalID, error) {
	fixturePath := testutil.TestDataPath("BaseAnimeByMalID")
	var media []*BaseAnimeByMalID
	loaded, err := loadJSONFixture(fixturePath, &media)
	if err != nil {
		return nil, err
	}
	if loaded {
		for _, entry := range media {
			malID := entry.GetMedia().GetIDMal()
			if malID != nil && *malID == *id {
				ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [BaseAnimeByMalID]: %d", *id)
				return entry, nil
			}
		}
	}

	baseAnime, found, err := findBaseAnimeInFixtureCollections(func(media *BaseAnime) bool {
		malID := media.GetIDMal()
		return malID != nil && *malID == *id
	})
	if err != nil {
		return nil, err
	}
	if found {
		ac.logger.Trace().Msgf("FixtureAnilistClient: FIXTURE HIT [BaseAnimeByMalID]: %d", *id)
		return &BaseAnimeByMalID{Media: baseAnime}, nil
	}

	if ac.canUseLiveFallback() {
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [BaseAnimeByMalID]: %d", *id)
		ret, err := ac.realAnilistClient.BaseAnimeByMalID(ctx, id)
		if err != nil {
			return nil, err
		}
		writeTarget := media
		writeTarget = append(writeTarget, ret)
		if err := maybeWriteJSONFixture(fixturePath, writeTarget, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	return nil, ac.missingFixtureError("BaseAnimeByMalID", *id)
}

func (ac *FixtureAnilistClient) BaseAnimeByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*BaseAnimeByID, error) {
	fixturePath := testutil.TestDataPath("BaseAnimeByID")
	var media []*BaseAnimeByID
	loaded, err := loadJSONFixture(fixturePath, &media)
	if err != nil {
		return nil, err
	}
	if loaded {
		for _, entry := range media {
			if entry.GetMedia().ID == *id {
				ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [BaseAnimeByID]: %d", *id)
				return entry, nil
			}
		}
	}

	baseAnime, found, err := findBaseAnimeInFixtureCollections(func(media *BaseAnime) bool {
		return media.ID == *id
	})
	if err != nil {
		return nil, err
	}
	if found {
		ac.logger.Trace().Msgf("FixtureAnilistClient: FIXTURE HIT [BaseAnimeByID]: %d", *id)
		return &BaseAnimeByID{Media: baseAnime}, nil
	}

	if ac.canUseLiveFallback() {
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [BaseAnimeByID]: %d", *id)
		ret, err := ac.realAnilistClient.BaseAnimeByID(ctx, id)
		if err != nil {
			return nil, err
		}
		writeTarget := media
		writeTarget = append(writeTarget, ret)
		if err := maybeWriteJSONFixture(fixturePath, writeTarget, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	return nil, ac.missingFixtureError("BaseAnimeByID", *id)
}

// AnimeCollection
//   - Uses the committed AnimeCollection fixture during normal test runs.
//   - In record mode, cache misses are refreshed from the live client.
func (ac *FixtureAnilistClient) AnimeCollection(ctx context.Context, userName *string, interceptors ...clientv2.RequestInterceptor) (*AnimeCollection, error) {
	key := fixtureCollectionKey(userName)
	fixturePath := testutil.TestDataPath("AnimeCollection")
	var ret *AnimeCollection
	loaded, err := loadJSONFixture(fixturePath, &ret)
	if err != nil {
		return nil, err
	}
	if !loaded {
		if !ac.canUseLiveFallback() {
			return nil, ac.missingFixtureError("AnimeCollection", key)
		}
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [AnimeCollection]: %s", key)
		ret, err := ac.realAnilistClient.AnimeCollection(ctx, userName)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, ret, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	if ret == nil {
		if !ac.canUseLiveFallback() {
			return nil, ac.missingFixtureError("AnimeCollection", key)
		}
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [AnimeCollection]: %s", key)
		ret, err := ac.realAnilistClient.AnimeCollection(ctx, userName)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, ret, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [AnimeCollection]: %s", key)
	return ret, nil

}

func (ac *FixtureAnilistClient) AnimeCollectionTags(ctx context.Context, userName *string, interceptors ...clientv2.RequestInterceptor) (*AnimeCollectionTags, error) {
	ac.logger.Debug().Msg("anilist: Fetching anime collection tags")
	return ac.realAnilistClient.AnimeCollectionTags(ctx, userName, interceptors...)
}

func (ac *FixtureAnilistClient) AnimeCollectionWithRelations(ctx context.Context, userName *string, interceptors ...clientv2.RequestInterceptor) (*AnimeCollectionWithRelations, error) {
	key := fixtureCollectionKey(userName)
	fixturePath := testutil.TestDataPath("AnimeCollectionWithRelations")
	var ret *AnimeCollectionWithRelations
	loaded, err := loadJSONFixture(fixturePath, &ret)
	if err != nil {
		return nil, err
	}
	if !loaded {
		if !ac.canUseLiveFallback() {
			return nil, ac.missingFixtureError("AnimeCollectionWithRelations", key)
		}
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [AnimeCollectionWithRelations]: %s", key)
		ret, err := ac.realAnilistClient.AnimeCollectionWithRelations(ctx, userName)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, ret, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	if ret == nil {
		if !ac.canUseLiveFallback() {
			return nil, ac.missingFixtureError("AnimeCollectionWithRelations", key)
		}
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [AnimeCollectionWithRelations]: %s", key)
		ret, err := ac.realAnilistClient.AnimeCollectionWithRelations(ctx, userName)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, ret, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [AnimeCollectionWithRelations]: %s", key)
	return ret, nil

}

//
// WILL NOT IMPLEMENT
//

func (ac *FixtureAnilistClient) UpdateMediaListEntry(ctx context.Context, mediaID *int, status *MediaListStatus, scoreRaw *int, progress *int, startedAt *FuzzyDateInput, completedAt *FuzzyDateInput, interceptors ...clientv2.RequestInterceptor) (*UpdateMediaListEntry, error) {
	ac.logger.Debug().Int("mediaId", *mediaID).Msg("anilist: Updating media list entry")
	return &UpdateMediaListEntry{}, nil
}

func (ac *FixtureAnilistClient) UpdateMediaListEntryProgress(ctx context.Context, mediaID *int, progress *int, status *MediaListStatus, interceptors ...clientv2.RequestInterceptor) (*UpdateMediaListEntryProgress, error) {
	ac.logger.Debug().Int("mediaId", *mediaID).Msg("anilist: Updating media list entry progress")
	return &UpdateMediaListEntryProgress{}, nil
}

func (ac *FixtureAnilistClient) UpdateMediaListEntryRepeat(ctx context.Context, mediaID *int, repeat *int, interceptors ...clientv2.RequestInterceptor) (*UpdateMediaListEntryRepeat, error) {
	ac.logger.Debug().Int("mediaId", *mediaID).Msg("anilist: Updating media list entry repeat")
	return &UpdateMediaListEntryRepeat{}, nil
}

func (ac *FixtureAnilistClient) DeleteEntry(ctx context.Context, mediaListEntryID *int, interceptors ...clientv2.RequestInterceptor) (*DeleteEntry, error) {
	ac.logger.Debug().Int("entryId", *mediaListEntryID).Msg("anilist: Deleting media list entry")
	return &DeleteEntry{}, nil
}

func (ac *FixtureAnilistClient) AnimeDetailsByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*AnimeDetailsByID, error) {
	ac.logger.Debug().Int("mediaId", *id).Msg("anilist: Fetching anime details")
	fixturePath := testutil.TestDataPath("AnimeDetailsByID")
	var fixtures []*AnimeDetailsByID
	loaded, err := loadJSONFixture(fixturePath, &fixtures)
	if err != nil {
		return nil, err
	}
	if loaded {
		for _, entry := range fixtures {
			if entry.GetMedia().ID == *id {
				ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [AnimeDetailsByID]: %d", *id)
				return entry, nil
			}
		}
	}

	if ac.canUseLiveFallback() {
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [AnimeDetailsByID]: %d", *id)
		ret, err := ac.realAnilistClient.AnimeDetailsByID(ctx, id, interceptors...)
		if err != nil {
			return nil, err
		}
		fixtures = append(fixtures, ret)
		if err := maybeWriteJSONFixture(fixturePath, fixtures, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	return nil, ac.missingFixtureError("AnimeDetailsByID", *id)
}

func (ac *FixtureAnilistClient) CompleteAnimeByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*CompleteAnimeByID, error) {
	ac.logger.Debug().Int("mediaId", *id).Msg("anilist: Fetching complete media")
	fixturePath := testutil.TestDataPath("CompleteAnimeByID")
	var fixtures []*CompleteAnimeByID
	loaded, err := loadJSONFixture(fixturePath, &fixtures)
	if err != nil {
		return nil, err
	}
	if loaded {
		for _, entry := range fixtures {
			if entry.GetMedia().ID == *id {
				ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [CompleteAnimeByID]: %d", *id)
				return entry, nil
			}
		}
	}

	media, found, err := findCompleteAnimeInFixtureCollections(*id)
	if err != nil {
		return nil, err
	}
	if found {
		ac.logger.Trace().Msgf("FixtureAnilistClient: FIXTURE HIT [CompleteAnimeByID]: %d", *id)
		return &CompleteAnimeByID{Media: media}, nil
	}
	if ac.canUseLiveFallback() {
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [CompleteAnimeByID]: %d", *id)
		ret, err := ac.realAnilistClient.CompleteAnimeByID(ctx, id, interceptors...)
		if err != nil {
			return nil, err
		}
		fixtures = append(fixtures, ret)
		if err := maybeWriteJSONFixture(fixturePath, fixtures, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	return nil, ac.missingFixtureError("CompleteAnimeByID", *id)
}

func (ac *FixtureAnilistClient) ListAnime(ctx context.Context, page *int, search *string, perPage *int, sort []*MediaSort, status []*MediaStatus, genres []*string, tags []*string, averageScoreGreater *int, season *MediaSeason, seasonYear *int, format *MediaFormat, isAdult *bool, interceptors ...clientv2.RequestInterceptor) (*ListAnime, error) {
	ac.logger.Debug().Msg("anilist: Fetching media list")
	media, pageInfo, err := baseAnimeFixtureSlice(page, perPage)
	if err != nil {
		return nil, err
	}

	return &ListAnime{
		Page: &ListAnime_Page{
			Media:    media,
			PageInfo: pageInfo,
		},
	}, nil
}

func (ac *FixtureAnilistClient) ListRecentAnime(ctx context.Context, page *int, perPage *int, airingAtGreater *int, airingAtLesser *int, notYetAired *bool, interceptors ...clientv2.RequestInterceptor) (*ListRecentAnime, error) {
	ac.logger.Debug().Msg("anilist: Fetching recent media list")
	media, _, err := baseAnimeFixtureSlice(nil, nil)
	if err != nil {
		return nil, err
	}

	schedules := make([]*ListRecentAnime_Page_AiringSchedules, 0)
	for _, anime := range media {
		next := anime.GetNextAiringEpisode()
		if next == nil {
			continue
		}
		schedules = append(schedules, &ListRecentAnime_Page_AiringSchedules{
			ID:              anime.ID,
			AiringAt:        next.GetAiringAt(),
			Episode:         next.GetEpisode(),
			Media:           anime,
			TimeUntilAiring: next.GetTimeUntilAiring(),
		})
	}

	sort.Slice(schedules, func(i, j int) bool {
		return schedules[i].AiringAt < schedules[j].AiringAt
	})

	currentPage := 1
	if page != nil && *page > 0 {
		currentPage = *page
	}
	perPageValue := 20
	if perPage != nil && *perPage > 0 {
		perPageValue = *perPage
	}
	total := len(schedules)
	lastPage := 1
	if total > 0 {
		lastPage = (total + perPageValue - 1) / perPageValue
	}
	start := (currentPage - 1) * perPageValue
	if start > total {
		start = total
	}
	end := start + perPageValue
	if end > total {
		end = total
	}
	hasNextPage := end < total
	pageInfo := &ListRecentAnime_Page_PageInfo{
		CurrentPage: &currentPage,
		HasNextPage: &hasNextPage,
		LastPage:    &lastPage,
		PerPage:     &perPageValue,
		Total:       &total,
	}

	return &ListRecentAnime{
		Page: &ListRecentAnime_Page{
			AiringSchedules: schedules[start:end],
			PageInfo:        pageInfo,
		},
	}, nil
}

func (ac *FixtureAnilistClient) GetViewer(ctx context.Context, interceptors ...clientv2.RequestInterceptor) (*GetViewer, error) {
	ac.logger.Debug().Msg("anilist: Fetching viewer")
	return ac.realAnilistClient.GetViewer(ctx, interceptors...)
}

func (ac *FixtureAnilistClient) MangaCollection(ctx context.Context, userName *string, interceptors ...clientv2.RequestInterceptor) (*MangaCollection, error) {
	key := fixtureCollectionKey(userName)
	fixturePath := testutil.TestDataPath("MangaCollection")
	var ret *MangaCollection
	loaded, err := loadJSONFixture(fixturePath, &ret)
	if err != nil {
		return nil, err
	}
	if !loaded {
		if !ac.canUseLiveFallback() {
			return nil, ac.missingFixtureError("MangaCollection", key)
		}
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [MangaCollection]: %s", key)
		ret, err = ac.realAnilistClient.MangaCollection(ctx, userName, interceptors...)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, ret, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	if ret == nil {
		if !ac.canUseLiveFallback() {
			return nil, ac.missingFixtureError("MangaCollection", key)
		}
		ac.logger.Warn().Msgf("FixtureAnilistClient: CACHE MISS [MangaCollection]: %s", key)
		ret, err = ac.realAnilistClient.MangaCollection(ctx, userName, interceptors...)
		if err != nil {
			return nil, err
		}
		if err := maybeWriteJSONFixture(fixturePath, ret, ac.logger); err != nil {
			return nil, err
		}
		return ret, nil
	}

	ac.logger.Trace().Msgf("FixtureAnilistClient: CACHE HIT [MangaCollection]: %s", key)
	return ret, nil
}

func (ac *FixtureAnilistClient) MangaCollectionTags(ctx context.Context, userName *string, interceptors ...clientv2.RequestInterceptor) (*MangaCollectionTags, error) {
	ac.logger.Debug().Msg("anilist: Fetching manga collection tags")
	return ac.realAnilistClient.MangaCollectionTags(ctx, userName, interceptors...)
}

func (ac *FixtureAnilistClient) SearchBaseManga(ctx context.Context, page *int, perPage *int, sort []*MediaSort, search *string, status []*MediaStatus, interceptors ...clientv2.RequestInterceptor) (*SearchBaseManga, error) {
	ac.logger.Debug().Msg("anilist: Searching manga")
	return ac.realAnilistClient.SearchBaseManga(ctx, page, perPage, sort, search, status, interceptors...)
}

func (ac *FixtureAnilistClient) BaseMangaByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*BaseMangaByID, error) {
	ac.logger.Debug().Int("mediaId", *id).Msg("anilist: Fetching manga")
	return ac.realAnilistClient.BaseMangaByID(ctx, id, interceptors...)
}

func (ac *FixtureAnilistClient) MangaDetailsByID(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*MangaDetailsByID, error) {
	ac.logger.Debug().Int("mediaId", *id).Msg("anilist: Fetching manga details")
	return ac.realAnilistClient.MangaDetailsByID(ctx, id, interceptors...)
}

func (ac *FixtureAnilistClient) ListManga(ctx context.Context, page *int, search *string, perPage *int, sort []*MediaSort, status []*MediaStatus, genres []*string, tags []*string, averageScoreGreater *int, startDateGreater *string, startDateLesser *string, format *MediaFormat, countryOfOrigin *string, isAdult *bool, interceptors ...clientv2.RequestInterceptor) (*ListManga, error) {
	ac.logger.Debug().Msg("anilist: Fetching manga list")
	return ac.realAnilistClient.ListManga(ctx, page, search, perPage, sort, status, genres, tags, averageScoreGreater, startDateGreater, startDateLesser, format, countryOfOrigin, isAdult, interceptors...)
}

func (ac *FixtureAnilistClient) StudioDetails(ctx context.Context, id *int, interceptors ...clientv2.RequestInterceptor) (*StudioDetails, error) {
	ac.logger.Debug().Int("studioId", *id).Msg("anilist: Fetching studio details")
	return ac.realAnilistClient.StudioDetails(ctx, id, interceptors...)
}

func (ac *FixtureAnilistClient) ViewerStats(ctx context.Context, interceptors ...clientv2.RequestInterceptor) (*ViewerStats, error) {
	ac.logger.Debug().Msg("anilist: Fetching stats")
	return ac.realAnilistClient.ViewerStats(ctx, interceptors...)
}

func (ac *FixtureAnilistClient) SearchBaseAnimeByIds(ctx context.Context, ids []*int, page *int, perPage *int, status []*MediaStatus, inCollection *bool, sort []*MediaSort, season *MediaSeason, year *int, genre *string, format *MediaFormat, interceptors ...clientv2.RequestInterceptor) (*SearchBaseAnimeByIds, error) {
	ac.logger.Debug().Msg("anilist: Searching anime by ids")
	return ac.realAnilistClient.SearchBaseAnimeByIds(ctx, ids, page, perPage, status, inCollection, sort, season, year, genre, format, interceptors...)
}

func (ac *FixtureAnilistClient) AnimeAiringSchedule(ctx context.Context, ids []*int, season *MediaSeason, seasonYear *int, previousSeason *MediaSeason, previousSeasonYear *int, nextSeason *MediaSeason, nextSeasonYear *int, interceptors ...clientv2.RequestInterceptor) (*AnimeAiringSchedule, error) {
	ac.logger.Debug().Msg("anilist: Fetching schedule")
	return ac.realAnilistClient.AnimeAiringSchedule(ctx, ids, season, seasonYear, previousSeason, previousSeasonYear, nextSeason, nextSeasonYear, interceptors...)
}

func (ac *FixtureAnilistClient) AnimeAiringScheduleRaw(ctx context.Context, ids []*int, interceptors ...clientv2.RequestInterceptor) (*AnimeAiringScheduleRaw, error) {
	ac.logger.Debug().Msg("anilist: Fetching schedule")
	return ac.realAnilistClient.AnimeAiringScheduleRaw(ctx, ids, interceptors...)
}
