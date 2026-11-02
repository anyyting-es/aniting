package shows

import (
	"path/filepath"
)

// ShowLocalFile represents a video file on the local filesystem mapped to TV show or movie metadata.
type ShowLocalFile struct {
	Path          string `json:"path"`
	Name          string `json:"name"`
	ParsedTitle   string `json:"parsedTitle"`
	Year          int    `json:"year,omitempty"`
	Season        int    `json:"season"`
	Episode       int    `json:"episode"`
	EndingEpisode int    `json:"endingEpisode,omitempty"`
	Resolution    string `json:"resolution,omitempty"`
	TmdbId        int    `json:"tmdbId"`
	TvdbId        int    `json:"tvdbId,omitempty"`
	MediaType     string `json:"mediaType"` // "tv" or "movie"
	Locked        bool   `json:"locked"`
	Ignored       bool   `json:"ignored"`
	FolderPath    string `json:"folderPath"`
	FolderName    string `json:"folderName"`
}

// NewShowLocalFile creates a ShowLocalFile by parsing the file path.
func NewShowLocalFile(path string, hintMediaType string) *ShowLocalFile {
	info := ParseShowPath(path, hintMediaType)
	dir := filepath.Dir(path)
	folderName := filepath.Base(dir)

	// If the immediate parent folder is a season folder, resolve to the show folder
	if isSeason, _ := ParseSeasonFromFolderName(folderName); isSeason {
		parent := filepath.Dir(dir)
		if parent != "." && parent != "/" {
			dir = parent
			folderName = filepath.Base(parent)
		}
	}

	mediaType := info.MediaType
	if hintMediaType != "" {
		mediaType = hintMediaType
	}

	locked := false
	tmdbId := 0
	if info.TmdbId > 0 {
		tmdbId = info.TmdbId
		locked = true
	}

	return &ShowLocalFile{
		Path:          path,
		Name:          info.OriginalName,
		ParsedTitle:   info.ShowTitle,
		Year:          info.Year,
		Season:        info.Season,
		Episode:       info.Episode,
		EndingEpisode: info.EndingEpisode,
		Resolution:    info.Resolution,
		TmdbId:        tmdbId,
		TvdbId:        info.TvdbId,
		MediaType:     mediaType,
		Locked:        locked,
		Ignored:       false,
		FolderPath:    dir,
		FolderName:    folderName,
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
