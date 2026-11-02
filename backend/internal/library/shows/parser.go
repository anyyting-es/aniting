package shows

import (
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// ParsedShowInfo contains the extracted metadata from a media file path according to Jellyfin/Plex conventions.
type ParsedShowInfo struct {
	OriginalPath  string `json:"originalPath"`
	OriginalName  string `json:"originalName"`
	ShowTitle     string `json:"showTitle"`
	Year          int    `json:"year,omitempty"`
	Season        int    `json:"season"`
	Episode       int    `json:"episode"`
	EndingEpisode int    `json:"endingEpisode,omitempty"`
	Resolution    string `json:"resolution,omitempty"`
	MediaType     string `json:"mediaType"` // "tv" or "movie"
	CleanTitle    string `json:"cleanTitle"`
	TmdbId        int    `json:"tmdbId,omitempty"`
	TvdbId        int    `json:"tvdbId,omitempty"`
}

const seasonKeywordsPattern = `시즌|シーズン|сезон|season|sæson|saison|staffel|series|serie|stagione|säsong|seizoen|seasong|sezon|sezona|sezóna|sezonul|série|séria|seria|temporada|kausi`

var (
	// Jellyfin folder ID tags: [tmdbid-12345], [tmdb-12345], [tmdbid=12345]
	tmdbIdRegex = regexp.MustCompile(`(?i)\[(?:tmdbid|tmdb)[=\-]([0-9]+)\]`)
	// [tvdbid-12345], [tvdb-12345]
	tvdbIdRegex = regexp.MustCompile(`(?i)\[(?:tvdbid|tvdb)[=\-]([0-9]+)\]`)

	// Jellyfin Season folder regexes
	seasonPrefixFolderRegex = regexp.MustCompile(`(?i)^[sS]([0-9]{1,4})(?:[\._\-\s\[\]]|$)`)
	seasonPostKeywordRegex  = regexp.MustCompile(`(?i)^(?:` + seasonKeywordsPattern + `)[\s._-]*([0-9]{1,4})(?:[\._\-\s\[\]]|$)`)
	seasonPreKeywordRegex   = regexp.MustCompile(`(?i)^([0-9]{1,4})(?:st|nd|rd|th|\.)*[\s._-]*(?:` + seasonKeywordsPattern + `)(?:[\._\-\s\[\]]|$)`)
	numericSeasonFolder     = regexp.MustCompile(`^0*([0-9]{1,3})$`)

	// Episode naming patterns (Jellyfin NamingOptions priority)
	// S01E02, S01E01-E02, S01E01-02, S01E01E02, s1e2, S01.E02
	seasonEpisodeRegex = regexp.MustCompile(`(?i)[sS]([0-9]{1,4})[ ._-]*[eE]([0-9]{1,4})(?:(?:-| - |~|\.)?[xXeE]?([0-9]{1,4}))?`)
	// 1x02 or 01x02 or 01x02-03
	crossEpisodeRegex = regexp.MustCompile(`(?i)\b([0-9]{1,4})x([0-9]{1,4})(?:(?:-| - |~|\.)?[xXeE]?([0-9]{1,4}))?\b`)
	// Temporada 1 ... Episodio 2
	esSeasonEpRegex = regexp.MustCompile(`(?i)(?:temporada|season|staffel|saison)[\s._-]*([0-9]{1,4})[\s._-]+.*?(?:episodio|episode|capitulo|capítulo|ep)[\s._-]*([0-9]{1,4})`)
	// Standalone episode tags: Ep 02, Episodio 2, capitulo 2
	standaloneEpRegex = regexp.MustCompile(`(?i)[\._ -](?:ep|episodio|episode|capitulo|capítulo)[._ -]*([0-9]{1,4})\b`)
	// Standalone E02
	standaloneERegex = regexp.MustCompile(`(?i)\b[eE]([0-9]{1,4})\b`)
	// Dash episode: "Show - 01 - Title.mkv" or "Show - 01.mkv"
	dashEpRegex = regexp.MustCompile(`(?i)\s+-\s+([0-9]{1,4})(?:v[0-9])?(?:\s+|-|\.|$)`)
	// Number at start inside season folder: "01 - Title.mkv" or "01.mkv"
	startNumberEpRegex = regexp.MustCompile(`^0*([0-9]{1,4})(?:[\s._-]+|$)`)
	// Bracketed anime number: "[Group] Show - 01 [1080p].mkv"
	bracketAnimeEpRegex = regexp.MustCompile(`(?i)\[[^\]]+\][\s._-]*.*?[\s._-]+([0-9]{1,4})(?:v[0-9])?(?:[\s._-]+|\[|\.)`)

	// Year in parentheses or brackets: (2023), [2024], or word boundary
	yearParenthesisRegex = regexp.MustCompile(`[\(\[]\s*(19\d\d|20\d\d)\s*[\)\]]`)
	yearBoundaryRegex    = regexp.MustCompile(`\b(19\d\d|20\d\d)\b`)

	// Resolution patterns
	resolutionRegex = regexp.MustCompile(`(?i)\b(2160p|4k|1080p|1080i|720p|576p|480p)\b`)

	// Junk release tags to strip (from Jellyfin CleanStrings)
	tagsToClean = regexp.MustCompile(`(?i)\b(2160p|1080p|1080i|720p|576p|480p|4k|uhd|ultrahd|web-dl|webrip|web|bluray|blu-ray|bdrip|brrip|dvdrip|dvd|hdtv|x264|x265|h264|h265|hevc|avc|av1|xvid|10bit|aac|ac3|dts|dts-hd|ddp\d?\.?\d?|dd\+?|flac|atmos|truehd|remux|repack|proper|unrated|extended|directors cut)\b`)
	bracketsRegex = regexp.MustCompile(`\[.*?\]|\{.*?\}`)
)

// ParseSeasonFromFolderName checks if a directory name conforms to a Jellyfin season folder.
func ParseSeasonFromFolderName(folderName string) (bool, int) {
	name := strings.TrimSpace(folderName)
	if name == "" {
		return false, 0
	}

	lower := strings.ToLower(name)
	// Specials & Extras aliases
	if lower == "specials" || lower == "extras" || lower == "special" || lower == "extra" ||
		lower == "featurettes" || lower == "season 0" || lower == "season 00" ||
		lower == "s0" || lower == "s00" || lower == "temporada 0" || lower == "temporada 00" {
		return true, 0
	}

	// S01, S1, s02
	if match := seasonPrefixFolderRegex.FindStringSubmatch(name); len(match) > 1 {
		if s, err := strconv.Atoi(match[1]); err == nil && s < 200 {
			return true, s
		}
	}

	// Season 1, Temporada 02, Staffel 3, Series 1
	if match := seasonPostKeywordRegex.FindStringSubmatch(name); len(match) > 1 {
		if s, err := strconv.Atoi(match[1]); err == nil && s < 200 {
			return true, s
		}
	}

	// 1st Season, 2. Staffel
	if match := seasonPreKeywordRegex.FindStringSubmatch(name); len(match) > 1 {
		if s, err := strconv.Atoi(match[1]); err == nil && s < 200 {
			return true, s
		}
	}

	// Numeric folder: "01", "1", "02", "2"
	if match := numericSeasonFolder.FindStringSubmatch(name); len(match) > 1 {
		if s, err := strconv.Atoi(match[1]); err == nil && s < 200 && s >= 0 {
			return true, s
		}
	}

	return false, 0
}

// ParseShowPath extracts show metadata from a file path using Jellyfin naming heuristics.
func ParseShowPath(fullPath string, hintMediaType string) *ParsedShowInfo {
	fullPath = filepath.ToSlash(fullPath)
	filename := filepath.Base(fullPath)
	ext := filepath.Ext(filename)
	baseName := strings.TrimSuffix(filename, ext)

	parentDir := filepath.Base(filepath.Dir(fullPath))
	grandParentDir := ""
	if dir := filepath.Dir(fullPath); dir != "." && dir != "/" {
		grandParentDir = filepath.Base(filepath.Dir(dir))
	}

	info := &ParsedShowInfo{
		OriginalPath: fullPath,
		OriginalName: filename,
		MediaType:    "tv",
		Season:       1,
		Episode:      0,
	}

	if hintMediaType == "movie" {
		info.MediaType = "movie"
	}

	// Check for embedded Jellyfin ID tags in fullPath: [tmdbid-12345] / [tvdbid-12345]
	if match := tmdbIdRegex.FindStringSubmatch(fullPath); len(match) > 1 {
		if id, err := strconv.Atoi(match[1]); err == nil {
			info.TmdbId = id
		}
	}
	if match := tvdbIdRegex.FindStringSubmatch(fullPath); len(match) > 1 {
		if id, err := strconv.Atoi(match[1]); err == nil {
			info.TvdbId = id
		}
	}

	// 1. Detect resolution
	if match := resolutionRegex.FindStringSubmatch(baseName); len(match) > 1 {
		info.Resolution = strings.ToUpper(match[1])
	}

	// 2. Detect Season & Episode
	seasonFound := false
	epFound := false

	// Check if parent directory is a Season folder (Jellyfin SeasonPathParser)
	parentIsSeason, parentSeasonNum := ParseSeasonFromFolderName(parentDir)
	if parentIsSeason {
		info.Season = parentSeasonNum
		seasonFound = true
	}

	// Try S01E02 pattern first in filename
	if match := seasonEpisodeRegex.FindStringSubmatch(baseName); len(match) > 2 {
		if s, err := strconv.Atoi(match[1]); err == nil {
			info.Season = s
			seasonFound = true
		}
		if ep, err := strconv.Atoi(match[2]); err == nil {
			info.Episode = ep
			epFound = true
		}
		if len(match) > 3 && match[3] != "" {
			if endEp, err := strconv.Atoi(match[3]); err == nil && endEp >= info.Episode {
				info.EndingEpisode = endEp
			}
		}
	}

	// Try 1x02 pattern
	if !epFound {
		if match := crossEpisodeRegex.FindStringSubmatch(baseName); len(match) > 2 {
			if s, err := strconv.Atoi(match[1]); err == nil {
				info.Season = s
				seasonFound = true
			}
			if ep, err := strconv.Atoi(match[2]); err == nil {
				info.Episode = ep
				epFound = true
			}
			if len(match) > 3 && match[3] != "" {
				if endEp, err := strconv.Atoi(match[3]); err == nil && endEp >= info.Episode {
					info.EndingEpisode = endEp
				}
			}
		}
	}

	// Try Temporada X Episodio Y pattern
	if !epFound {
		if match := esSeasonEpRegex.FindStringSubmatch(baseName); len(match) > 2 {
			if s, err := strconv.Atoi(match[1]); err == nil {
				info.Season = s
				seasonFound = true
			}
			if ep, err := strconv.Atoi(match[2]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// If episode still not found, try standalone episode tags: Ep 02, Episodio 2
	if !epFound {
		if match := standaloneEpRegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// Try standalone E02
	if !epFound {
		if match := standaloneERegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// Try Dash episode: "Show - 01 - Title.mkv" or "Show - 01.mkv"
	if !epFound {
		if match := dashEpRegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// Try Anime Bracket format: "[Group] Show - 01 [1080p].mkv"
	if !epFound {
		if match := bracketAnimeEpRegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// If file is inside an identified season folder and episode is still not found:
	// check if the file starts with the episode number: "01.mkv", "01 - Pilot.mkv"
	if !epFound && parentIsSeason {
		if match := startNumberEpRegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// 3. Extract Year from filename, parent folder, or grandparent folder
	if match := yearParenthesisRegex.FindStringSubmatch(baseName); len(match) > 1 {
		if y, err := strconv.Atoi(match[1]); err == nil {
			info.Year = y
		}
	} else if match := yearParenthesisRegex.FindStringSubmatch(parentDir); len(match) > 1 {
		if y, err := strconv.Atoi(match[1]); err == nil {
			info.Year = y
		}
	} else if match := yearParenthesisRegex.FindStringSubmatch(grandParentDir); len(match) > 1 {
		if y, err := strconv.Atoi(match[1]); err == nil {
			info.Year = y
		}
	} else if match := yearBoundaryRegex.FindStringSubmatch(baseName); len(match) > 1 {
		if y, err := strconv.Atoi(match[1]); err == nil {
			info.Year = y
		}
	}

	// Determine MediaType
	if hintMediaType == "movie" {
		info.MediaType = "movie"
		if info.Episode == 0 {
			info.Episode = 1
		}
		if info.Season == 0 {
			info.Season = 1
		}
	} else if hintMediaType == "tv" {
		info.MediaType = "tv"
	} else {
		// Mixed or auto-detect
		if !epFound && !seasonFound && info.Year > 0 {
			info.MediaType = "movie"
			info.Episode = 1
			info.Season = 1
		} else {
			info.MediaType = "tv"
		}
	}

	// 4. Extract Show / Movie Title
	rawTitle := ""
	if parentIsSeason && grandParentDir != "" && !isGenericFolder(grandParentDir) {
		// e.g. "Breaking Bad (2008)/Season 1/S01E01.mkv" -> show title is grandparent dir
		rawTitle = grandParentDir
	} else if parentDir != "" && !isGenericFolder(parentDir) && !parentIsSeason {
		// Dedicated show/movie folder e.g. "Dune Part Two (2024)"
		rawTitle = parentDir
	} else {
		// Use filename as basis
		rawTitle = baseName
	}

	info.ShowTitle = cleanTitle(rawTitle)
	info.CleanTitle = cleanTitle(baseName)

	return info
}

func isGenericFolder(name string) bool {
	l := strings.ToLower(name)
	return l == "." || l == "/" || l == "tv" || l == "tv shows" || l == "shows" ||
		l == "movies" || l == "series" || l == "películas" || l == "peliculas" ||
		l == "anime" || l == "video" || l == "videos" || l == "downloads"
}

// cleanTitle removes release tags, years, brackets, dots, and formats a clean display title.
func cleanTitle(s string) string {
	// Remove provider ID tags: [tmdbid-12345]
	cleaned := tmdbIdRegex.ReplaceAllString(s, " ")
	cleaned = tvdbIdRegex.ReplaceAllString(cleaned, " ")

	// Remove bracketed groups [Group], {Tag}
	cleaned = bracketsRegex.ReplaceAllString(cleaned, " ")
	// Remove year in parentheses e.g. (2024)
	cleaned = yearParenthesisRegex.ReplaceAllString(cleaned, " ")
	// Remove resolution and release tags
	cleaned = tagsToClean.ReplaceAllString(cleaned, " ")
	// Remove season/episode markers from title
	cleaned = seasonEpisodeRegex.ReplaceAllString(cleaned, " ")
	cleaned = crossEpisodeRegex.ReplaceAllString(cleaned, " ")

	// Replace dots, underscores, dashes with spaces
	cleaned = strings.ReplaceAll(cleaned, ".", " ")
	cleaned = strings.ReplaceAll(cleaned, "_", " ")
	cleaned = strings.ReplaceAll(cleaned, "-", " ")

	// Collapse multiple spaces
	spaceRegex := regexp.MustCompile(`\s+`)
	cleaned = spaceRegex.ReplaceAllString(cleaned, " ")
	return strings.TrimSpace(cleaned)
}
