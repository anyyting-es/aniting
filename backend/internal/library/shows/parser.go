package shows

import (
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// ParsedShowInfo contains the extracted metadata from a media file path according to Plex/Jellyfin conventions.
type ParsedShowInfo struct {
	OriginalPath string `json:"originalPath"`
	OriginalName string `json:"originalName"`
	ShowTitle    string `json:"showTitle"`
	Year         int    `json:"year,omitempty"`
	Season       int    `json:"season"`
	Episode      int    `json:"episode"`
	Resolution   string `json:"resolution,omitempty"`
	MediaType    string `json:"mediaType"` // "tv" or "movie"
	CleanTitle   string `json:"cleanTitle"`
}

var (
	// S01E02 or s1e2 or S01E02E03
	seasonEpisodeRegex = regexp.MustCompile(`(?i)[sS]([0-9]{1,3})[eE]([0-9]{1,3})`)
	// 1x02 or 01x02
	crossEpisodeRegex = regexp.MustCompile(`(?i)\b([0-9]{1,2})x([0-9]{1,3})\b`)
	// Temporada 1 ... Episodio 2
	esSeasonEpRegex = regexp.MustCompile(`(?i)(?:temporada|season)\s*([0-9]{1,2})[\s\.\-_]+.*?(?:episodio|episode|capitulo|capítulo)\s*([0-9]{1,3})`)
	// Season folders: Season 1, Temporada 02, S1
	seasonFolderRegex = regexp.MustCompile(`(?i)(?:season|temporada|s)\s*([0-9]{1,3})`)
	// Episode standalone: Ep 02, Episodio 2, E02
	standaloneEpRegex = regexp.MustCompile(`(?i)\b(?:ep|episodio|episode|capitulo|capítulo|e)\.?\s*([0-9]{1,3})\b`)
	// Standalone dash episode: "Show - 01 - Title.mkv"
	dashEpRegex = regexp.MustCompile(`\s+-\s+([0-9]{1,3})\s+`)

	// Year in parentheses or brackets: (2023), [2024], or word boundary
	yearParenthesisRegex = regexp.MustCompile(`[\(\[]\s*(19\d\d|20\d\d)\s*[\)\]]`)
	yearBoundaryRegex    = regexp.MustCompile(`\b(19\d\d|20\d\d)\b`)

	// Resolution patterns
	resolutionRegex = regexp.MustCompile(`(?i)\b(2160p|4k|1080p|1080i|720p|576p|480p)\b`)

	// Junk release tags to strip
	tagsToClean = regexp.MustCompile(`(?i)\b(2160p|1080p|1080i|720p|576p|480p|4k|uhd|web-dl|webrip|web|bluray|bdrip|brrip|dvdrip|hdtv|x264|x265|h264|h265|hevc|avc|10bit|aac|ac3|dts|dts-hd|ddp\d?\.?\d?|dd\+?|flac|atmos|remux|repack|proper)\b`)
	bracketsRegex = regexp.MustCompile(`\[.*?\]|\{.*?\}`)
)

// ParseShowPath extracts show metadata from a file path using Plex/Jellyfin naming heuristics.
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

	// 1. Detect resolution
	if match := resolutionRegex.FindStringSubmatch(baseName); len(match) > 1 {
		info.Resolution = strings.ToUpper(match[1])
	}

	// 2. Detect Season & Episode
	seasonFound := false
	epFound := false

	// Try S01E02 pattern first
	if match := seasonEpisodeRegex.FindStringSubmatch(baseName); len(match) > 2 {
		if s, err := strconv.Atoi(match[1]); err == nil {
			info.Season = s
			seasonFound = true
		}
		if ep, err := strconv.Atoi(match[2]); err == nil {
			info.Episode = ep
			epFound = true
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

	// Check parent folder for Season if season not yet found in file name
	if !seasonFound {
		if match := seasonFolderRegex.FindStringSubmatch(parentDir); len(match) > 1 {
			if s, err := strconv.Atoi(match[1]); err == nil {
				info.Season = s
				seasonFound = true
			}
		}
	}

	// If episode still not found, try standalone episode tags
	if !epFound {
		if match := standaloneEpRegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	if !epFound {
		if match := dashEpRegex.FindStringSubmatch(baseName); len(match) > 1 {
			if ep, err := strconv.Atoi(match[1]); err == nil {
				info.Episode = ep
				epFound = true
			}
		}
	}

	// 3. Extract Year from filename or parent folder
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

	// If no episode found and hint is movie or parent doesn't look like season, consider movie
	if !epFound && (hintMediaType == "movie" || info.Year > 0) {
		info.MediaType = "movie"
		info.Episode = 1
		info.Season = 1
	}

	// 4. Extract Show / Movie Title
	rawTitle := ""
	if seasonFolderRegex.MatchString(parentDir) && grandParentDir != "" {
		// e.g. "Breaking Bad (2008)/Season 1/S01E01.mkv" -> show title is grandparent dir
		rawTitle = grandParentDir
	} else if parentDir != "" && !isGenericFolder(parentDir) {
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
	return l == "." || l == "/" || l == "tv" || l == "movies" || l == "series" || l == "películas" || l == "peliculas" || l == "anime" || l == "video" || l == "videos" || l == "downloads"
}

// cleanTitle removes release tags, years, brackets, dots, and formats a clean display title.
func cleanTitle(s string) string {
	// Remove bracketed groups [Group], {Tag}
	cleaned := bracketsRegex.ReplaceAllString(s, " ")
	// Remove year in parentheses e.g. (2024)
	cleaned = yearParenthesisRegex.ReplaceAllString(cleaned, " ")
	// Remove resolution and release tags
	cleaned = tagsToClean.ReplaceAllString(cleaned, " ")
	// Remove season/episode markers from title
	cleaned = seasonEpisodeRegex.ReplaceAllString(cleaned, " ")
	cleaned = crossEpisodeRegex.ReplaceAllString(cleaned, " ")
	cleaned = seasonFolderRegex.ReplaceAllString(cleaned, " ")

	// Replace dots, underscores, dashes with spaces
	cleaned = strings.ReplaceAll(cleaned, ".", " ")
	cleaned = strings.ReplaceAll(cleaned, "_", " ")
	cleaned = strings.ReplaceAll(cleaned, "-", " ")

	// Collapse multiple spaces
	spaceRegex := regexp.MustCompile(`\s+`)
	cleaned = spaceRegex.ReplaceAllString(cleaned, " ")
	return strings.TrimSpace(cleaned)
}
