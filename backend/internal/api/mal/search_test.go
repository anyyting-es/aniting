package mal

import (
	"seanime/internal/testutil"
	"testing"
)

func TestSearchWithMALLive(t *testing.T) {
	testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.Live())

	res, err := SearchWithMAL("bungo stray dogs", 4)

	if err != nil {
		t.Fatalf("error while fetching media, %v", err)
	}

	for _, m := range res {
		t.Log(m.Name)
	}

}

func TestAdvancedSearchWithMalLive(t *testing.T) {
	testutil.InitTestProvider(t, testutil.MyAnimeList(), testutil.Live())

	res, err := AdvancedSearchWithMAL("sousou no frieren")

	if err != nil {
		t.Fatal("expected result, got error: ", err)
	}

	t.Log(res.Name)

}
