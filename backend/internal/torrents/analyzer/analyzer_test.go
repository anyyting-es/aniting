package torrent_analyzer

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"seanime/internal/api/anilist"
	"seanime/internal/library/anime"
	"seanime/internal/platforms/platform"
	"seanime/internal/util"
)

func TestNewAnalyzerInitializesFiles(t *testing.T) {
	root := t.TempDir()
	paths := []string{
		filepath.Join(root, "Season 1", "[Seanime] Example Show - 01.mkv"),
		filepath.Join(root, "Season 1", "[Seanime] Example Show - 02.mkv"),
	}
	media := &anilist.CompleteAnime{ID: 42}

	analyzer := NewAnalyzer(&NewAnalyzerOptions{
		Filepaths:   paths,
		Media:       media,
		ForceMatch:  true,
		PlatformRef: util.NewRef[platform.Platform](nil),
	})

	require.Len(t, analyzer.files, len(paths))
	require.Same(t, media, analyzer.media)
	require.True(t, analyzer.forceMatch)
	for index, file := range analyzer.files {
		require.Equal(t, index, file.GetIndex())
		require.Equal(t, filepath.ToSlash(paths[index]), file.GetPath())
		require.NotNil(t, file.GetLocalFile())
		require.Equal(t, filepath.ToSlash(paths[index]), file.GetLocalFile().Path)
	}
}

func TestAnalyzeTorrentFilesReturnsErrorWhenPlatformRefAbsent(t *testing.T) {
	analyzer := NewAnalyzer(&NewAnalyzerOptions{
		Filepaths: []string{filepath.Join(t.TempDir(), "[Seanime] Example Show - 01.mkv")},
		Media:     &anilist.CompleteAnime{ID: 42},
	})

	analysis, err := analyzer.AnalyzeTorrentFiles()

	require.Nil(t, analysis)
	require.EqualError(t, err, "anilist client wrapper is nil")
}

// Verifies that the helper methods for selecting files from the analysis work as expected
func TestAnalysisSelectionHelpers(t *testing.T) {
	analysis, files := newAnalysisFixture(t)

	correspondingFiles := analysis.GetCorrespondingFiles()
	require.Len(t, correspondingFiles, 3)
	require.Same(t, files[0], correspondingFiles[0])
	require.Same(t, files[1], correspondingFiles[1])
	require.Same(t, files[3], correspondingFiles[3])

	correspondingMainFiles := analysis.GetCorrespondingMainFiles()
	require.Len(t, correspondingMainFiles, 2)
	require.Same(t, files[0], correspondingMainFiles[0])
	require.Same(t, files[3], correspondingMainFiles[3])

	mainFile, ok := analysis.GetMainFileByEpisode(3)
	require.True(t, ok)
	require.Same(t, files[3], mainFile)

	missingMainFile, ok := analysis.GetMainFileByEpisode(99)
	require.False(t, ok)
	require.Nil(t, missingMainFile)

	aniDBFile, ok := analysis.GetFileByAniDBEpisode("3")
	require.True(t, ok)
	require.Same(t, files[3], aniDBFile)

	missingAniDBFile, ok := analysis.GetFileByAniDBEpisode("missing")
	require.False(t, ok)
	require.Nil(t, missingAniDBFile)

	unselectedFiles := analysis.GetUnselectedFiles()
	require.Len(t, unselectedFiles, 1)
	require.Same(t, files[2], unselectedFiles[2])

	require.ElementsMatch(t, []int{0, 3}, analysis.GetIndices(correspondingMainFiles))
	require.Equal(t, []int{1, 2}, analysis.GetUnselectedIndices(correspondingMainFiles))
	require.Equal(t, files, analysis.GetFiles())
}

func newAnalysisFixture(t *testing.T) (*Analysis, []*File) {
	t.Helper()
	root := t.TempDir()
	files := []*File{
		newAnalyzedFile(filepath.Join(root, "[Seanime] Example Show - 01.mkv"), 0, 42, 1, anime.LocalFileTypeMain, "1"),
		newAnalyzedFile(filepath.Join(root, "[Seanime] Example Show - OVA.mkv"), 1, 42, 0, anime.LocalFileTypeSpecial, "S1"),
		newAnalyzedFile(filepath.Join(root, "[Seanime] Other Show - 01.mkv"), 2, 7, 1, anime.LocalFileTypeMain, "1"),
		newAnalyzedFile(filepath.Join(root, "[Seanime] Example Show - 03.mkv"), 3, 42, 3, anime.LocalFileTypeMain, "3"),
	}

	return &Analysis{
		files: files,
		media: &anilist.CompleteAnime{ID: 42},
	}, files
}

func newAnalyzedFile(path string, index int, mediaID int, episode int, fileType anime.LocalFileType, aniDBEpisode string) *File {
	file := newFile(index, path)
	file.localFile.MediaId = mediaID
	file.localFile.Metadata = &anime.LocalFileMetadata{
		Episode:      episode,
		AniDBEpisode: aniDBEpisode,
		Type:         fileType,
	}
	return file
}
