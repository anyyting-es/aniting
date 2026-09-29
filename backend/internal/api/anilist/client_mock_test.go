package anilist

import (
	"context"
	"os"
	"path/filepath"
	"seanime/internal/testutil"
	"strconv"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const recordCompleteAnimeIDsEnvName = "SEANIME_TEST_RECORD_COMPLETE_ANIME_IDS"

func TestMaybeWriteJSONFixtureCreatesDirectories(t *testing.T) {
	t.Setenv(testutil.RecordAnilistFixturesEnvName, "true")

	target := filepath.Join(t.TempDir(), "fixtures", "nested", "fixture.json")
	err := maybeWriteJSONFixture(target, map[string]string{"status": "ok"}, nil)
	assert.NoError(t, err)

	_, err = os.Stat(target)
	assert.NoError(t, err)
}

func TestCustomQueryFixturePathIsStable(t *testing.T) {
	body := []byte(`{"query":"query Example { Page { pageInfo { total } } }","variables":{"page":1}}`)

	path1 := customQueryFixturePath(body)
	path2 := customQueryFixturePath(body)

	assert.Equal(t, path1, path2)
	assert.Contains(t, path1, filepath.Join("test", "testdata", "anilist-custom-query"))
}

func TestFixtureMangaCollectionUsesCommittedFixture(t *testing.T) {
	client := NewFixtureAnilistClient()

	collection, err := client.MangaCollection(context.Background(), nil)
	require.NoError(t, err)
	require.NotNil(t, collection)

	entry, found := collection.GetListEntryFromMangaId(101517)
	require.True(t, found)
	require.Equal(t, MediaListStatusCurrent, *entry.GetStatus())
	require.Equal(t, 260, *entry.GetProgress())
}

func TestRecordCompleteAnimeByIDFixtures(t *testing.T) {
	if !testutil.ShouldRecordAnilistFixtures() {
		t.Skip("AniList fixture recording disabled")
	}

	rawIDs := strings.TrimSpace(os.Getenv(recordCompleteAnimeIDsEnvName))
	if rawIDs == "" {
		t.Skip("no CompleteAnimeByID fixture ids requested")
	}

	cfg := testutil.LoadConfig(t)
	if cfg.Provider.AnilistJwt == "" {
		t.Skip("AniList fixture recording requires provider.anilist_jwt")
	}

	client := NewFixtureAnilistClientWithToken(cfg.Provider.AnilistJwt)
	for _, mediaID := range parseFixtureMediaIDs(t, rawIDs) {
		_, err := client.CompleteAnimeByID(context.Background(), &mediaID)
		require.NoErrorf(t, err, "failed to record CompleteAnimeByID fixture for media %d", mediaID)
	}
}

func parseFixtureMediaIDs(t *testing.T, raw string) []int {
	t.Helper()

	parts := strings.FieldsFunc(raw, func(r rune) bool {
		switch r {
		case ',', ' ', '\n', '\t':
			return true
		default:
			return false
		}
	})
	require.NotEmpty(t, parts, "expected at least one media id")

	ids := make([]int, 0, len(parts))
	for _, part := range parts {
		mediaID, err := strconv.Atoi(part)
		require.NoErrorf(t, err, "invalid media id %q", part)
		ids = append(ids, mediaID)
	}

	return ids
}
