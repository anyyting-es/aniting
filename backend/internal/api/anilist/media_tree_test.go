package anilist

import (
	"context"
	"seanime/internal/util"
	"seanime/internal/util/limiter"
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/stretchr/testify/assert"
)

func TestBaseAnime_FetchMediaTree_BaseAnime(t *testing.T) {
	anilistClient := NewTestAnilistClient()
	lim := limiter.NewAnilistLimiter()
	completeAnimeCache := NewCompleteAnimeCache()

	tests := []struct {
		name    string
		mediaId int
		edgeIds []int
	}{
		{
			name:    "Bungo Stray Dogs",
			mediaId: 103223,
			edgeIds: []int{
				21311,  // BSD1
				21679,  // BSD2
				103223, // BSD3
				141249, // BSD4
				163263, // BSD5
			},
		},
	}

	for _, tt := range tests {

		t.Run(tt.name, func(t *testing.T) {

			mediaF, err := anilistClient.CompleteAnimeByID(context.Background(), &tt.mediaId)

			if assert.NoError(t, err) {

				media := mediaF.GetMedia()

				tree := NewCompleteAnimeRelationTree()

				err = media.FetchMediaTree(
					FetchMediaTreeAll,
					anilistClient,
					lim,
					tree,
					completeAnimeCache,
				)

				if assert.NoError(t, err) {

					for _, treeId := range tt.edgeIds {
						a, found := tree.Get(treeId)
						assert.Truef(t, found, "expected tree to contain %d", treeId)
						util.Spew(a.GetTitleSafe())
					}

				}

			}
		})

	}

}

func TestBaseAnime_FetchMediaTree_BaseAnimeLive(t *testing.T) {
	anilistClient := newLiveAnilistClient(t)
	lim := limiter.NewAnilistLimiter()
	completeAnimeCache := NewCompleteAnimeCache()
	mediaID := 21355
	edgeIDs := []int{21355, 108632, 119661, 163134}

	mediaF, err := anilistClient.CompleteAnimeByID(context.Background(), &mediaID)
	if !assert.NoError(t, err) {
		return
	}

	media := mediaF.GetMedia()
	tree := NewCompleteAnimeRelationTree()

	err = media.FetchMediaTree(
		FetchMediaTreeAll,
		anilistClient,
		lim,
		tree,
		completeAnimeCache,
	)
	if !assert.NoError(t, err) {
		return
	}

	for _, treeID := range edgeIDs {
		a, found := tree.Get(treeID)
		assert.Truef(t, found, "expected tree to contain %d", treeID)
		spew.Dump(a.GetTitleSafe())
	}
}
