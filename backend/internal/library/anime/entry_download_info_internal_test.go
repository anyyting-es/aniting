package anime

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestEpisodeSliceHelpers(t *testing.T) {
	// this is a tiny direct test for the helper methods at the bottom of entry_download_info.go.
	// the higher-level tests already cover the real behavior, this one just keeps the utility methods exercised.
	slice := newEpisodeSlice(3)
	require.Len(t, slice.getSlice(), 3)
	require.Equal(t, 1, slice.get(0).episodeNumber)
	require.Equal(t, "2", slice.getEpisodeNumber(2).aniDBEpisode)
	require.Nil(t, slice.getEpisodeNumber(99))

	clone := slice.copy()
	require.NotSame(t, slice, clone)
	require.Len(t, clone.getSlice(), 3)

	slice.trimStart(1)
	require.Len(t, slice.getSlice(), 2)
	require.Equal(t, 2, slice.get(0).episodeNumber)

	clone.print()
}
