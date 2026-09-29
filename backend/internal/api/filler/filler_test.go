package filler_test

import (
	"seanime/internal/api/filler"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"
)

func TestAnimeFillerList_Search(t *testing.T) {
	testutil.InitTestProvider(t, testutil.Live())

	af := filler.NewAnimeFillerList(util.NewLogger())

	opts := filler.SearchOptions{
		Titles: []string{"Hunter x Hunter (2011)"},
	}

	ret, err := af.Search(opts)
	if err != nil {
		t.Error(err)
	}

	util.Spew(ret)
}
