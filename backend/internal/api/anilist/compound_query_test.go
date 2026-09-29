package anilist

import (
	"fmt"
	"seanime/internal/testutil"
	"seanime/internal/util"
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/goccy/go-json"
	"github.com/stretchr/testify/require"
)

func TestCompoundQueryLive(t *testing.T) {
	testutil.InitTestProvider(t, testutil.Anilist(), testutil.Live())

	var ids = []int{171457, 21}

	query := fmt.Sprintf(compoundQueryFormatTest, newCompoundQuery(ids))

	t.Log(query)

	requestBody, err := json.Marshal(map[string]interface{}{
		"query":     query,
		"variables": nil,
	})
	require.NoError(t, err)

	data, err := customQuery(requestBody, util.NewLogger())
	require.NoError(t, err)

	var res map[string]*BaseAnime

	dataB, err := json.Marshal(data)
	require.NoError(t, err)

	err = json.Unmarshal(dataB, &res)
	require.NoError(t, err)

	spew.Dump(res)

}

const compoundQueryFormatTest = `query CompoundQueryTest {
%s
}
fragment baseAnime on Media {
	id
	idMal
	siteUrl
	status(version: 2)
	season
	type
	format
	bannerImage
	episodes
	synonyms
	isAdult
	countryOfOrigin
	meanScore
	description
	genres
	duration
	trailer {
		id
		site
		thumbnail
	}
	title {
		userPreferred
		romaji
		english
		native
	}
	coverImage {
		extraLarge
		large
		medium
		color
	}
	startDate {
		year
		month
		day
	}
	endDate {
		year
		month
		day
	}
	nextAiringEpisode {
		airingAt
		timeUntilAiring
		episode
	}
}`
