package handlers

import (
	"seanime/internal/library/anime"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLocalFilesForPaths(t *testing.T) {
	lfs := []*anime.LocalFile{
		{Path: "/library/show/episode-01.mkv"},
		{Path: "/library/show/episode-02.mkv"},
	}

	t.Run("returns scanned files only", func(t *testing.T) {
		// delete requests should resolve to files already known by the scanner
		selected, err := localFilesForPaths(lfs, []string{
			"/library/show/episode-01.mkv",
			"/library/show/episode-01.mkv",
		})

		require.NoError(t, err)
		require.Len(t, selected, 1)
		assert.Equal(t, "/library/show/episode-01.mkv", selected[0].Path)
	})

	t.Run("rejects arbitrary paths", func(t *testing.T) {
		// request body paths should not become raw filesystem delete targets
		selected, err := localFilesForPaths(lfs, []string{"/etc/passwd"})

		require.Error(t, err)
		assert.Nil(t, selected)
	})
}
