package shows

import (
	"path/filepath"
)

// ShowLocalFile represents a video file on the local filesystem mapped to TV show or movie metadata.
type ShowLocalFile struct {
	Path        string `json:"path"`
	Name        string `json:"name"`
	ParsedTitle string `json:"parsedTitle"`
	Year        int    `json:"year,omitempty"`
	Season      int    `json:"season"`
	Episode     int    `json:"episode"`
	Resolution  string `json:"resolution,omitempty"`
	TmdbId      int    `json:"tmdbId"`
	MediaType   string `json:"mediaType"` // "tv" or "movie"
	Locked      bool   `json:"locked"`
	Ignored     bool   `json:"ignored"`
	FolderPath  string `json:"folderPath"`
	FolderName  string `json:"folderName"`
}

// NewShowLocalFile creates a ShowLocalFile by parsing the file path.
func NewShowLocalFile(path string, hintMediaType string) *ShowLocalFile {
	info := ParseShowPath(path, hintMediaType)
	dir := filepath.Dir(path)
	folderName := filepath.Base(dir)

	mediaType := info.MediaType
	if hintMediaType != "" {
		mediaType = hintMediaType
	}

	return &ShowLocalFile{
		Path:        path,
		Name:        info.OriginalName,
		ParsedTitle: info.ShowTitle,
		Year:        info.Year,
		Season:      info.Season,
		Episode:     info.Episode,
		Resolution:  info.Resolution,
		TmdbId:      0,
		MediaType:   mediaType,
		Locked:      false,
		Ignored:     false,
		FolderPath:  dir,
		FolderName:  folderName,
	}
}

// IsMatched returns true if this file is assigned to a TMDB item.
func (f *ShowLocalFile) IsMatched() bool {
	return f.TmdbId > 0
}

// IsUnmatched returns true if this file is not assigned to any TMDB item.
func (f *ShowLocalFile) IsUnmatched() bool {
	return f.TmdbId == 0 && !f.Ignored
}
