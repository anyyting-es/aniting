package mal

import (
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"

	"github.com/davecgh/go-spew/spew"
)

func TestGetMangaDetailsLive(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.Live())

	malWrapper := NewWrapper(cfg.Provider.MalJwt, util.NewLogger())

	res, err := malWrapper.GetMangaDetails(13)

	spew.Dump(res)

	if err != nil {
		t.Fatalf("error while fetching media, %v", err)
	}

	t.Log(res.Title)
}

func TestGetMangaCollectionLive(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.Live())

	malWrapper := NewWrapper(cfg.Provider.MalJwt, util.NewLogger())

	res, err := malWrapper.GetMangaCollection()

	if err != nil {
		t.Fatalf("error while fetching anime collection, %v", err)
	}

	for _, entry := range res {
		t.Log(entry.Node.Title)
		if entry.Node.ID == 13 {
			spew.Dump(entry)
		}
	}
}

func TestUpdateMangaListStatusLive(t *testing.T) {
	cfg := testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.MyAnimeListMutation(), testutil.Live())

	malWrapper := NewWrapper(cfg.Provider.MalJwt, util.NewLogger())

	mId := 13
	progress := 1000
	status := MediaListStatusReading

	err := malWrapper.UpdateMangaListStatus(&MangaListStatusParams{
		Status:          &status,
		NumChaptersRead: &progress,
	}, mId)

	if err != nil {
		t.Fatalf("error while fetching media, %v", err)
	}
}
