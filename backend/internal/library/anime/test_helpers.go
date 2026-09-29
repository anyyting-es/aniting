package anime

import (
	"strconv"
	"strings"
)

type TestLocalFileEpisode struct {
	Episode      int
	AniDBEpisode string
	Type         LocalFileType
}

type TestLocalFileGroup struct {
	LibraryPath      string
	FilePathTemplate string
	MediaID          int
	Episodes         []TestLocalFileEpisode
}

// NewTestLocalFiles expands one or more local-file groups into hydrated LocalFiles.
// FilePathTemplate replaces each %ep token with the episode number.
func NewTestLocalFiles(groups ...TestLocalFileGroup) []*LocalFile {
	localFiles := make([]*LocalFile, 0)
	for _, group := range groups {
		for _, episode := range group.Episodes {
			lf := NewLocalFile(strings.ReplaceAll(group.FilePathTemplate, "%ep", strconv.Itoa(episode.Episode)), group.LibraryPath)
			if lf.ParsedData != nil && lf.ParsedData.Episode == "" {
				lf.ParsedData.Episode = strconv.Itoa(episode.Episode)
			}
			lf.MediaId = group.MediaID
			lf.Metadata = &LocalFileMetadata{
				AniDBEpisode: episode.AniDBEpisode,
				Episode:      episode.Episode,
				Type:         episode.Type,
			}
			localFiles = append(localFiles, lf)
		}
	}

	return localFiles
}
