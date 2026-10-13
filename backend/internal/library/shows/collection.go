package shows

import (
	"sort"
)

// ShowEntry groups local files associated with a single TMDB TV show or movie.
type ShowEntry struct {
	TmdbId       int                      `json:"tmdbId"`
	Title        string                   `json:"title"`
	Year         int                      `json:"year,omitempty"`
	MediaType    string                   `json:"mediaType"` // "tv" or "movie"
	Seasons      map[int][]*ShowLocalFile `json:"seasons"`
	Files        []*ShowLocalFile         `json:"files"`
	EpisodeCount int                      `json:"episodeCount"`
	SeasonCount  int                      `json:"seasonCount"`
}

// ShowCollection contains the grouped library of TV shows and movies, plus unmatched files.
type ShowCollection struct {
	Shows               []*ShowEntry     `json:"shows"`
	Unmatched           []*ShowLocalFile `json:"unmatched"`
	TotalFiles          int              `json:"totalFiles"`
	MatchedShowsCount   int              `json:"matchedShowsCount"`
	LocalEpisodesCount  int              `json:"localEpisodesCount"`
	UnmatchedFilesCount int              `json:"unmatchedFilesCount"`
}

// NewShowCollection builds a ShowCollection from a slice of ShowLocalFile items.
func NewShowCollection(files []*ShowLocalFile) *ShowCollection {
	showMap := make(map[int]*ShowEntry)
	unmatched := make([]*ShowLocalFile, 0)
	totalFiles := len(files)
	localEpisodesCount := 0

	for _, file := range files {
		if file.Ignored {
			continue
		}

		if file.IsMatched() {
			localEpisodesCount++
			entry, exists := showMap[file.TmdbId]
			if !exists {
				entry = &ShowEntry{
					TmdbId:    file.TmdbId,
					Title:     file.ParsedTitle,
					Year:      file.Year,
					MediaType: file.MediaType,
					Seasons:   make(map[int][]*ShowLocalFile),
					Files:     make([]*ShowLocalFile, 0),
				}
				showMap[file.TmdbId] = entry
			}

			if file.ParsedTitle != "" && entry.Title == "" {
				entry.Title = file.ParsedTitle
			}
			if file.Year > 0 && entry.Year == 0 {
				entry.Year = file.Year
			}
			if file.MediaType != "" {
				entry.MediaType = file.MediaType
			}

			entry.Files = append(entry.Files, file)
			seasonNum := file.Season
			if seasonNum <= 0 {
				seasonNum = 1
			}
			entry.Seasons[seasonNum] = append(entry.Seasons[seasonNum], file)
		} else {
			unmatched = append(unmatched, file)
		}
	}

	showsList := make([]*ShowEntry, 0, len(showMap))
	for _, entry := range showMap {
		entry.EpisodeCount = len(entry.Files)
		entry.SeasonCount = len(entry.Seasons)

		// Sort episodes inside each season by episode number ascending
		for _, seasonFiles := range entry.Seasons {
			sort.Slice(seasonFiles, func(i, j int) bool {
				return seasonFiles[i].Episode < seasonFiles[j].Episode
			})
		}

		// Sort overall files by season, then episode
		sort.Slice(entry.Files, func(i, j int) bool {
			if entry.Files[i].Season != entry.Files[j].Season {
				return entry.Files[i].Season < entry.Files[j].Season
			}
			return entry.Files[i].Episode < entry.Files[j].Episode
		})

		showsList = append(showsList, entry)
	}

	// Sort shows alphabetically by Title
	sort.Slice(showsList, func(i, j int) bool {
		return showsList[i].Title < showsList[j].Title
	})

	return &ShowCollection{
		Shows:               showsList,
		Unmatched:           unmatched,
		TotalFiles:          totalFiles,
		MatchedShowsCount:   len(showsList),
		LocalEpisodesCount:  localEpisodesCount,
		UnmatchedFilesCount: len(unmatched),
	}
}
