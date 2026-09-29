package library_explorer

import (
	"seanime/internal/library/anime"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidateSuperUpdateFile(t *testing.T) {
	lfs := []*anime.LocalFile{
		{Path: "/library/show/episode-01.mkv"},
	}

	t.Run("accepts scanned local files", func(t *testing.T) {
		// rename targets should resolve to an existing scanned file first
		lf, err := validateSuperUpdateFile(&SuperUpdateFileOptions{
			Path:    "/library/show/episode-01.mkv",
			NewName: "episode-02.mkv",
		}, lfs)

		require.NoError(t, err)
		assert.Equal(t, "/library/show/episode-01.mkv", lf.Path)
	})

	t.Run("rejects unknown paths", func(t *testing.T) {
		// unknown paths should not be renamed by the explorer helper
		lf, err := validateSuperUpdateFile(&SuperUpdateFileOptions{
			Path:    "/etc/passwd",
			NewName: "passwd.bak",
		}, lfs)

		require.Error(t, err)
		assert.Nil(t, lf)
	})
}

func TestIsValidSuperUpdateName(t *testing.T) {
	tests := []struct {
		name string
		want bool
	}{
		{name: "episode-02.mkv", want: true},
		{name: "../episode-02.mkv", want: false},
		{name: "subdir/episode-02.mkv", want: false},
		{name: `subdir\episode-02.mkv`, want: false},
		{name: "/tmp/episode-02.mkv", want: false},
		{name: "..", want: false},
		{name: " ", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// new names must stay plain filenames, never paths
			assert.Equal(t, tt.want, isValidSuperUpdateName(tt.name))
		})
	}
}
