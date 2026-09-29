package scanner

import (
	"seanime/internal/api/anilist"
	"seanime/internal/platforms/platform"
	"seanime/internal/util"
	"seanime/internal/util/limiter"
	"testing"

	"github.com/samber/lo"
	"github.com/stretchr/testify/assert"
)

func TestNewMediaFetcher(t *testing.T) {
	wrapper := newScannerFixtureWrapper(t)
	completeAnimeCache := anilist.NewCompleteAnimeCache()
	anilistRateLimiter := limiter.NewAnilistLimiter()

	tests := []struct {
		name                   string
		paths                  []string
		enhanced               bool
		disableAnimeCollection bool
	}{
		{
			name: "86 - Eighty Six Part 1 & 2",
			paths: []string{
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 20v2 (1080p) [30072859].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 21v2 (1080p) [4B1616A5].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 22v2 (1080p) [58BF43B4].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 23v2 (1080p) [D94B4894].mkv",
			},
			enhanced:               false,
			disableAnimeCollection: false,
		},
		{
			name: "86 - Eighty Six Part 1 & 2",
			paths: []string{
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 20v2 (1080p) [30072859].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 21v2 (1080p) [4B1616A5].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 22v2 (1080p) [58BF43B4].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 23v2 (1080p) [D94B4894].mkv",
			},
			enhanced:               true,
			disableAnimeCollection: true,
		},
	}

	for _, tt := range tests {

		t.Run(tt.name, func(t *testing.T) {

			scanLogger, err := NewConsoleScanLogger()
			if err != nil {
				t.Fatal("expected result, got error:", err.Error())
			}

			// +---------------------+
			// |   Local Files       |
			// +---------------------+

			lfs := wrapper.LocalFiles(tt.paths...)

			// +---------------------+
			// |    MediaFetcher     |
			// +---------------------+

			mf, err := NewMediaFetcher(t.Context(), &MediaFetcherOptions{
				Enhanced:               tt.enhanced,
				PlatformRef:            util.NewRef[platform.Platform](wrapper.Platform),
				LocalFiles:             lfs,
				CompleteAnimeCache:     completeAnimeCache,
				MetadataProviderRef:    util.NewRef(wrapper.MetadataProvider),
				Logger:                 util.NewLogger(),
				AnilistRateLimiter:     anilistRateLimiter,
				ScanLogger:             scanLogger,
				DisableAnimeCollection: tt.disableAnimeCollection,
			})
			if err != nil {
				t.Fatal("expected result, got error:", err.Error())
			}

			mc := NewMediaContainer(&MediaContainerOptions{
				AllMedia:   mf.AllMedia,
				ScanLogger: scanLogger,
			})

			for _, m := range mc.NormalizedMedia {
				t.Log(m.GetTitleSafe())
			}

		})

	}

}

func TestNewEnhancedMediaFetcher(t *testing.T) {
	wrapper := newScannerFixtureWrapper(t)
	completeAnimeCache := anilist.NewCompleteAnimeCache()
	anilistRateLimiter := limiter.NewAnilistLimiter()

	tests := []struct {
		name     string
		paths    []string
		enhanced bool
	}{
		{
			name: "86 - Eighty Six Part 1 & 2",
			paths: []string{
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 20v2 (1080p) [30072859].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 21v2 (1080p) [4B1616A5].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 22v2 (1080p) [58BF43B4].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 23v2 (1080p) [D94B4894].mkv",
			},
			enhanced: false,
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
			// |    MediaFetcher     |
			// +---------------------+

			mf, err := NewMediaFetcher(t.Context(), &MediaFetcherOptions{
				Enhanced:            tt.enhanced,
				PlatformRef:         util.NewRef[platform.Platform](wrapper.Platform),
				LocalFiles:          lfs,
				CompleteAnimeCache:  completeAnimeCache,
				MetadataProviderRef: util.NewRef(wrapper.MetadataProvider),
				Logger:              util.NewLogger(),
				AnilistRateLimiter:  anilistRateLimiter,
				ScanLogger:          scanLogger,
			})
			if err != nil {
				t.Fatal("expected result, got error:", err.Error())
			}

			mc := NewMediaContainer(&MediaContainerOptions{
				AllMedia:   mf.AllMedia,
				ScanLogger: scanLogger,
			})

			for _, m := range mc.NormalizedMedia {
				t.Log(m.GetTitleSafe())
			}

		})

	}

}

func TestFetchMediaFromLocalFiles(t *testing.T) {
	wrapper := newScannerFixtureWrapper(t)
	completeAnimeCache := anilist.NewCompleteAnimeCache()
	anilistRateLimiter := limiter.NewAnilistLimiter()

	tests := []struct {
		name            string
		paths           []string
		expectedMediaId []int
	}{
		{
			name: "86 - Eighty Six Part 1 & 2",
			paths: []string{
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 20v2 (1080p) [30072859].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 21v2 (1080p) [4B1616A5].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 22v2 (1080p) [58BF43B4].mkv",
				"E:/Anime/[SubsPlease] 86 - Eighty Six (01-23) (1080p) [Batch]/[SubsPlease] 86 - Eighty Six - 23v2 (1080p) [D94B4894].mkv",
			},
			expectedMediaId: []int{116589, 131586}, // 86 - Eighty Six Part 1 & 2
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

			// +--------------------------+
			// | FetchMediaFromLocalFiles |
			// +--------------------------+

			media, ok := FetchMediaFromLocalFiles(
				t.Context(),
				wrapper.Platform,
				lfs,
				completeAnimeCache,
				wrapper.MetadataProvider,
				anilistRateLimiter,
				scanLogger,
			)
			if !ok {
				t.Fatal("could not fetch media from local files")
			}

			ids := lo.Map(media, func(k *anilist.CompleteAnime, _ int) int {
				return k.ID
			})

			// Test if all expected media IDs are present
			for _, id := range tt.expectedMediaId {
				assert.Contains(t, ids, id)
			}

			t.Log("Media IDs:")
			for _, m := range media {
				t.Log(m.GetTitleSafe())
			}

		})
	}

}
