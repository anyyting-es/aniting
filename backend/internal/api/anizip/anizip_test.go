package anizip

import (
	"seanime/internal/testutil"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestFetchAniZipMedia(t *testing.T) {
	testutil.InitTestProvider(t, testutil.Live())

	tests := []struct {
		name          string
		provider      string
		id            int
		expectedTitle string
	}{
		{
			name:          "Cowboy Bebop",
			provider:      "anilist",
			id:            1,
			expectedTitle: "Cowboy Bebop",
		},
	}

	for _, test := range tests {

		t.Run(test.name, func(t *testing.T) {
			media, err := FetchAniZipMedia(test.provider, test.id)
			if assert.NoError(t, err) {
				if assert.NotNil(t, media) {
					assert.Equal(t, media.GetTitle(), test.expectedTitle)
				}
			}
		})

	}

}
