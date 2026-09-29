package anilist

import (
	"seanime/internal/testutil"
	"testing"
)

func newLiveAnilistClient(t testing.TB) AnilistClient {
	t.Helper()

	cfg := testutil.InitTestProvider(t, testutil.Anilist(), testutil.Live())
	if cfg.Provider.AnilistJwt == "" {
		t.Skip("anilist live tests require anilist_jwt")
	}

	return NewAnilistClient(cfg.Provider.AnilistJwt, "")
}
