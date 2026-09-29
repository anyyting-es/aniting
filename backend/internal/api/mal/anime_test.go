package mal

import (
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"

	"github.com/davecgh/go-spew/spew"
)

func TestGetAnimeDetailsLive(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.Live())

	malWrapper := NewWrapper(cfg.Provider.MalJwt, util.NewLogger())

	res, err := malWrapper.GetAnimeDetails(51179)

	spew.Dump(res)

	if err != nil {
		t.Fatalf("error while fetching media, %v", err)
	}

	t.Log(res.Title)
}

func TestGetAnimeCollectionLive(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.Live())

	malWrapper := NewWrapper(cfg.Provider.MalJwt, util.NewLogger())

	res, err := malWrapper.GetAnimeCollection()

	if err != nil {
		t.Fatalf("error while fetching anime collection, %v", err)
	}

	for _, entry := range res {
		t.Log(entry.Node.Title)
		if entry.Node.ID == 51179 {
			spew.Dump(entry)
		}
	}
}

func TestUpdateAnimeListStatusLive(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.MyAnimeListMutation(), testutil.Live())

	malWrapper := NewWrapper(cfg.Provider.MalJwt, util.NewLogger())

	mId := 51179
	progress := 2
	status := MediaListStatusWatching

	err := malWrapper.UpdateAnimeListStatus(&AnimeListStatusParams{
		Status:             &status,
		NumEpisodesWatched: &progress,
	}, mId)

	if err != nil {
		t.Fatalf("error while fetching media, %v", err)
	}
}
