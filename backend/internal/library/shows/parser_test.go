package shows

import (
	"testing"
)

func TestParseShowPath(t *testing.T) {
	tests := []struct {
		path        string
		hint        string
		expectedTitle string
		expectedYear  int
		expectedSeason int
		expectedEp     int
		expectedType   string
	}{
		{
			path:        "/media/tv/Breaking Bad (2008)/Season 01/Breaking.Bad.S01E01.Pilot.1080p.BluRay.x264.mkv",
			hint:        "tv",
			expectedTitle: "Breaking Bad",
			expectedYear:  2008,
			expectedSeason: 1,
			expectedEp:     1,
			expectedType:   "tv",
		},
		{
			path:        "/media/tv/The Last of Us/Temporada 1/1x04 - Please Hold to My Hand.mp4",
			hint:        "tv",
			expectedTitle: "The Last of Us",
			expectedYear:  0,
			expectedSeason: 1,
			expectedEp:     4,
			expectedType:   "tv",
		},
		{
			path:        "/media/tv/Stranger Things/Stranger.Things.S04E09.720p.WEB-DL.mkv",
			hint:        "tv",
			expectedTitle: "Stranger Things",
			expectedYear:  0,
			expectedSeason: 4,
			expectedEp:     9,
			expectedType:   "tv",
		},
		{
			path:        "/media/movies/Dune Part Two (2024)/Dune.Part.Two.2024.2160p.UHD.Remux.mkv",
			hint:        "movie",
			expectedTitle: "Dune Part Two",
			expectedYear:  2024,
			expectedSeason: 1,
			expectedEp:     1,
			expectedType:   "movie",
		},
		{
			path:        "/media/movies/Oppenheimer (2023).mkv",
			hint:        "",
			expectedTitle: "Oppenheimer",
			expectedYear:  2023,
			expectedSeason: 1,
			expectedEp:     1,
			expectedType:   "movie",
		},
	}

	for _, tt := range tests {
		t.Run(tt.path, func(t *testing.T) {
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
			if res.MediaType != tt.expectedType {
				t.Errorf("expected mediaType %q, got %q", tt.expectedType, res.MediaType)
			}
		})
	}
}
