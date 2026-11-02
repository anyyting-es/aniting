package shows

import (
	"testing"
)

func TestParseShowPath(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		hint           string
		expectedTitle  string
		expectedYear   int
		expectedSeason int
		expectedEp     int
		expectedEnding int
		expectedType   string
		expectedTmdbId int
	}{
		{
			name:           "Standard Jellyfin TV Episode with Year in Series Folder",
			path:           "/media/tv/Breaking Bad (2008)/Season 01/Breaking.Bad.S01E01.Pilot.1080p.BluRay.x264.mkv",
			hint:           "tv",
			expectedTitle:  "Breaking Bad",
			expectedYear:   2008,
			expectedSeason: 1,
			expectedEp:     1,
			expectedType:   "tv",
		},
		{
			name:           "Spanish Season folder and 1x04 episode format",
			path:           "/media/tv/The Last of Us/Temporada 1/1x04 - Please Hold to My Hand.mp4",
			hint:           "tv",
			expectedTitle:  "The Last of Us",
			expectedYear:   0,
			expectedSeason: 1,
			expectedEp:     4,
			expectedType:   "tv",
		},
		{
			name:           "S04E09 flat inside show folder",
			path:           "/media/tv/Stranger Things/Stranger.Things.S04E09.720p.WEB-DL.mkv",
			hint:           "tv",
			expectedTitle:  "Stranger Things",
			expectedYear:   0,
			expectedSeason: 4,
			expectedEp:     9,
			expectedType:   "tv",
		},
		{
			name:           "Dune Movie folder",
			path:           "/media/movies/Dune Part Two (2024)/Dune.Part.Two.2024.2160p.UHD.Remux.mkv",
			hint:           "movie",
			expectedTitle:  "Dune Part Two",
			expectedYear:   2024,
			expectedSeason: 1,
			expectedEp:     1,
			expectedType:   "movie",
		},
		{
			name:           "Oppenheimer Movie standalone file",
			path:           "/media/movies/Oppenheimer (2023).mkv",
			hint:           "",
			expectedTitle:  "Oppenheimer",
			expectedYear:   2023,
			expectedSeason: 1,
			expectedEp:     1,
			expectedType:   "movie",
		},
		{
			name:           "Season 2 with plain number episode 01.mkv",
			path:           "/media/tv/Frieren/Season 2/01.mkv",
			hint:           "tv",
			expectedTitle:  "Frieren",
			expectedYear:   0,
			expectedSeason: 2,
			expectedEp:     1,
			expectedType:   "tv",
		},
		{
			name:           "Season 2 with dash title 01 - The Journey Continues.mkv",
			path:           "/media/tv/Frieren/Season 02/01 - The Journey Continues.mkv",
			hint:           "tv",
			expectedTitle:  "Frieren",
			expectedYear:   0,
			expectedSeason: 2,
			expectedEp:     1,
			expectedType:   "tv",
		},
		{
			name:           "Numeric season folder 02/05.mkv",
			path:           "/media/tv/Arcane/02/05.mkv",
			hint:           "tv",
			expectedTitle:  "Arcane",
			expectedYear:   0,
			expectedSeason: 2,
			expectedEp:     5,
			expectedType:   "tv",
		},
		{
			name:           "Specials folder should map to Season 0",
			path:           "/media/tv/Attack on Titan/Specials/S00E01.mkv",
			hint:           "tv",
			expectedTitle:  "Attack on Titan",
			expectedYear:   0,
			expectedSeason: 0,
			expectedEp:     1,
			expectedType:   "tv",
		},
		{
			name:           "Extras folder with plain number maps to Season 0",
			path:           "/media/tv/Attack on Titan/Extras/02 - OVA.mkv",
			hint:           "tv",
			expectedTitle:  "Attack on Titan",
			expectedYear:   0,
			expectedSeason: 0,
			expectedEp:     2,
			expectedType:   "tv",
		},
		{
			name:           "Multi-episode file S01E01-E02 with embedded Jellyfin tmdbid tag",
			path:           "/media/tv/Severance (2022) [tmdbid-112836]/Season 1/Severance.S01E01-E02.mkv",
			hint:           "tv",
			expectedTitle:  "Severance",
			expectedYear:   2022,
			expectedSeason: 1,
			expectedEp:     1,
			expectedEnding: 2,
			expectedType:   "tv",
			expectedTmdbId: 112836,
		},
		{
			name:           "German Staffel season folder",
			path:           "/media/tv/Dark/Staffel 3/Dark.S03E01.mkv",
			hint:           "tv",
			expectedTitle:  "Dark",
			expectedYear:   0,
			expectedSeason: 3,
			expectedEp:     1,
			expectedType:   "tv",
		},
		{
			name:           "Anime bracket release format",
			path:           "/media/tv/Demon Slayer/Season 2/[SubsPlease] Kimetsu no Yaiba - 05 (1080p) [ABCD1234].mkv",
			hint:           "tv",
			expectedTitle:  "Demon Slayer",
			expectedYear:   0,
			expectedSeason: 2,
			expectedEp:     5,
			expectedType:   "tv",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := ParseShowPath(tt.path, tt.hint)
			if res.ShowTitle != tt.expectedTitle {
				t.Errorf("expected title %q, got %q", tt.expectedTitle, res.ShowTitle)
			}
			if res.Year != tt.expectedYear {
				t.Errorf("expected year %d, got %d", tt.expectedYear, res.Year)
			}
			if res.Season != tt.expectedSeason {
				t.Errorf("expected season %d, got %d", tt.expectedSeason, res.Season)
			}
			if res.Episode != tt.expectedEp {
				t.Errorf("expected episode %d, got %d", tt.expectedEp, res.Episode)
			}
			if tt.expectedEnding > 0 && res.EndingEpisode != tt.expectedEnding {
				t.Errorf("expected ending episode %d, got %d", tt.expectedEnding, res.EndingEpisode)
			}
			if res.MediaType != tt.expectedType {
				t.Errorf("expected mediaType %q, got %q", tt.expectedType, res.MediaType)
			}
			if tt.expectedTmdbId > 0 && res.TmdbId != tt.expectedTmdbId {
				t.Errorf("expected tmdbId %d, got %d", tt.expectedTmdbId, res.TmdbId)
			}
		})
	}
}
