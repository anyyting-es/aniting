package util

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func writeLocalSubtitleTestFile(t *testing.T, dir string, filename string) string {
	t.Helper()

	path := filepath.Join(dir, filename)
	require.NoError(t, os.WriteFile(path, []byte("subtitle"), 0o644))
	return path
}

func TestFindLocalSubtitleFiles(t *testing.T) {
	// picks up sidecars that media players commonly associate with the episode
	dir := t.TempDir()
	videoPath := filepath.Join(dir, "Episode 01.mkv")
	require.NoError(t, os.WriteFile(videoPath, []byte("video"), 0o644))
	writeLocalSubtitleTestFile(t, dir, "Episode 01.ass")
	writeLocalSubtitleTestFile(t, dir, "Episode 01.zh-Hans.ass")
	writeLocalSubtitleTestFile(t, dir, "Episode 01.zh-Hant.srt")
	writeLocalSubtitleTestFile(t, dir, "Episode 010.ass")
	writeLocalSubtitleTestFile(t, dir, "Episode 01.txt.bak")

	files, err := FindLocalSubtitleFiles(videoPath)

	require.NoError(t, err)
	require.Len(t, files, 3)
	require.Equal(t, "Episode 01.ass", files[0].Filename)
	require.Equal(t, "und", files[0].Language)
	require.Equal(t, "ass", files[0].Type)
	require.Equal(t, "Episode 01.zh-Hans.ass", files[1].Filename)
	require.Equal(t, "zh-Hans", files[1].Language)
	require.Equal(t, "Episode 01.zh-Hant.srt", files[2].Filename)
	require.Equal(t, "zh-Hant", files[2].Language)
}

func TestFindLocalSubtitleFiles2(t *testing.T) {
	// keeps matching reliable on case-sensitive filesystems too
	dir := t.TempDir()
	videoPath := filepath.Join(dir, "Episode 01.MKV")
	require.NoError(t, os.WriteFile(videoPath, []byte("video"), 0o644))
	writeLocalSubtitleTestFile(t, dir, "episode 01.ENG.SRT")

	files, err := FindLocalSubtitleFiles(videoPath)

	require.NoError(t, err)
	require.Len(t, files, 1)
	require.Equal(t, "episode 01.ENG.SRT", files[0].Filename)
	require.Equal(t, "ENG", files[0].Language)
	require.Equal(t, "srt", files[0].Type)
}
