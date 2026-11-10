package onlinestream

import (
	"testing"

	hibikeonlinestream "aniting/internal/extension/hibike/onlinestream"

	"github.com/stretchr/testify/require"
)

func TestEpisodeDataToSourcePreservesTorrentFields(t *testing.T) {
	fileIndex := 7

	source := episodeDataToSource(&episodeData{
		Number: 3,
		Servers: []*hibikeonlinestream.EpisodeServer{
			{
				Server: "Torrentio",
				VideoSources: []*hibikeonlinestream.VideoSource{
					{
						URL:           "magnet:?xt=urn:btih:abc",
						Type:          hibikeonlinestream.VideoSourceTorrent,
						Quality:       "1080p",
						Label:         "Episode.03.1080p.mkv",
						InfoHash:      "abc",
						FileIndex:     &fileIndex,
						Seeders:       27,
						Size:          3521873183,
						SizeFormatted: "3.28 GB",
						Languages:     []string{"EN", "ES"},
						Codec:         "HEVC",
						Indexer:       "NyaaSi",
						ReleaseName:   "Episode 03",
					},
				},
			},
		},
	})

	require.Equal(t, 3, source.Number)
	require.Len(t, source.VideoSources, 1)
	require.Equal(t, "torrent", string(source.VideoSources[0].Type))
	require.Equal(t, "magnet:?xt=urn:btih:abc", source.VideoSources[0].URL)
	require.Equal(t, "abc", source.VideoSources[0].InfoHash)
	require.NotNil(t, source.VideoSources[0].FileIndex)
	require.Equal(t, 7, *source.VideoSources[0].FileIndex)
	require.Equal(t, 27, source.VideoSources[0].Seeders)
	require.Equal(t, int64(3521873183), source.VideoSources[0].Size)
	require.Equal(t, "3.28 GB", source.VideoSources[0].SizeFormatted)
	require.Equal(t, []string{"EN", "ES"}, source.VideoSources[0].Languages)
	require.Equal(t, "HEVC", source.VideoSources[0].Codec)
	require.Equal(t, "NyaaSi", source.VideoSources[0].Indexer)
	require.Equal(t, "Episode 03", source.VideoSources[0].ReleaseName)
}
