package scanner

import (
	"seanime/internal/platforms/platform"
	"seanime/internal/util"
	"testing"
)

func TestScanLogger(t *testing.T) {
	wrapper := newScannerFixtureWrapper(t)
	logger := wrapper.Logger
	animeCollection, err := wrapper.Platform.GetAnimeCollectionWithRelations(t.Context())
	if err != nil {
		t.Fatal(err.Error())
	}
	if animeCollection == nil {
		t.Fatal("expected anime collection, got nil")
	}
	allMedia := animeCollection.GetAllAnime()

	tests := []struct {
		name            string
		paths           []string
		expectedMediaId int
	}{
		{
			name: "should be hydrated with id 131586",
			paths: []string{
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 20v2 (1080p) [30072859].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 21v2 (1080p) [4B1616A5].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 22v2 (1080p) [58BF43B4].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 23v2 (1080p) [D94B4894].mkv",
			},
			expectedMediaId: 131586, // 86 - Eighty Six Part 2
		},
	}

	for _, tt := range tests {

		t.Run(tt.name, func(t *testing.T) {

			scanLogger, err := NewScanLogger(wrapper.Env.RootPath("logs"))
			if err != nil {
				t.Fatal("expected result, got error:", err.Error())
			}

			// +---------------------+
			// |   Local Files       |
			// +---------------------+

			lfs := wrapper.LocalFiles(tt.paths...)

			// +---------------------+
			// |   MediaContainer    |
			// +---------------------+

			mc := NewMediaContainer(&MediaContainerOptions{
				AllMedia:   NormalizedMediaFromAnilistComplete(allMedia),
				ScanLogger: scanLogger,
			})

			for _, nm := range mc.NormalizedMedia {
				t.Logf("media id: %d, title: %s", nm.ID, nm.GetTitleSafe())
			}

			// +---------------------+
			// |      Matcher        |
			// +---------------------+

			matcher := &Matcher{
				LocalFiles:        lfs,
				MediaContainer:    mc,
				Logger:            util.NewLogger(),
				ScanLogger:        scanLogger,
				ScanSummaryLogger: nil,
			}

			err = matcher.MatchLocalFilesWithMedia()
			if err != nil {
				t.Fatal("expected result, got error:", err.Error())
			}

			// +---------------------+
			// |   FileHydrator      |
			// +---------------------+

			fh := FileHydrator{
				LocalFiles:          lfs,
				AllMedia:            mc.NormalizedMedia,
				CompleteAnimeCache:  wrapper.CompleteAnimeCache,
				PlatformRef:         util.NewRef[platform.Platform](wrapper.Platform),
				MetadataProviderRef: util.NewRef(wrapper.MetadataProvider),
				AnilistRateLimiter:  wrapper.AnilistRateLimiter,
				Logger:              logger,
				ScanLogger:          scanLogger,
				ScanSummaryLogger:   nil,
				ForceMediaId:        0,
			}

			fh.HydrateMetadata()

			for _, lf := range fh.LocalFiles {
				if lf.MediaId != tt.expectedMediaId {
					t.Fatalf("expected media id %d, got %d", tt.expectedMediaId, lf.MediaId)
				}

				t.Logf("local file: %s,\nmedia id: %d\n", lf.Name, lf.MediaId)
			}

		})
	}

}
