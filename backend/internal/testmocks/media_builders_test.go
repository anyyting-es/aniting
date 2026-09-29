package testmocks

import (
	"testing"

	"seanime/internal/api/anilist"

	"github.com/stretchr/testify/require"
)

// makes sure the anime builder can override the fields tests usually care about.
func TestBaseAnimeBuilder(t *testing.T) {
	anime := NewBaseAnimeBuilder(44, "seed title").
		WithIDMal(404).
		WithSiteURL("https://example.com/anime/44").
		WithTitles("English Title", "Romaji Title", "Native Title", "Preferred Title").
		WithStatus(anilist.MediaStatusReleasing).
		WithFormat(anilist.MediaFormatMovie).
		WithEpisodes(24).
		WithIsAdult(true).
		WithSynonyms("Alt 1", "Alt 2").
		WithStartDate(2022, 7, 10).
		WithEndDate(2022, 12, 25).
		WithCoverImage("https://example.com/anime/44.jpg").
		WithBannerImage("https://example.com/anime/44-banner.jpg").
		WithNextAiringEpisode(5, 123456, 7890).
		Build()

	require.Equal(t, 44, anime.ID)
	require.NotNil(t, anime.IDMal)
	require.Equal(t, 404, *anime.IDMal)
	require.NotNil(t, anime.Type)
	require.Equal(t, anilist.MediaTypeAnime, *anime.Type)
	require.NotNil(t, anime.SiteURL)
	require.Equal(t, "https://example.com/anime/44", *anime.SiteURL)
	require.Equal(t, "English Title", *anime.Title.English)
	require.Equal(t, "Romaji Title", *anime.Title.Romaji)
	require.Equal(t, "Native Title", *anime.Title.Native)
	require.Equal(t, "Preferred Title", *anime.Title.UserPreferred)
	require.Equal(t, anilist.MediaStatusReleasing, *anime.Status)
	require.Equal(t, anilist.MediaFormatMovie, *anime.Format)
	require.Equal(t, 24, *anime.Episodes)
	require.Equal(t, true, *anime.IsAdult)
	require.Len(t, anime.Synonyms, 2)
	require.Equal(t, "Alt 1", *anime.Synonyms[0])
	require.Equal(t, 2022, *anime.StartDate.Year)
	require.Equal(t, 7, *anime.StartDate.Month)
	require.Equal(t, 10, *anime.StartDate.Day)
	require.Equal(t, 2022, *anime.EndDate.Year)
	require.Equal(t, 12, *anime.EndDate.Month)
	require.Equal(t, 25, *anime.EndDate.Day)
	require.Equal(t, "https://example.com/anime/44.jpg", *anime.CoverImage.Large)
	require.Equal(t, "https://example.com/anime/44-banner.jpg", *anime.BannerImage)
	require.Equal(t, 5, anime.NextAiringEpisode.Episode)
	require.Equal(t, 123456, anime.NextAiringEpisode.AiringAt)
	require.Equal(t, 7890, anime.NextAiringEpisode.TimeUntilAiring)
}

// makes sure the manga builder covers the common overrides too.
func TestBaseMangaBuilder(t *testing.T) {
	manga := NewBaseMangaBuilder(88, "seed manga").
		WithIDMal(808).
		WithSiteURL("https://example.com/manga/88").
		WithTitles("English Manga", "Romaji Manga", "Native Manga", "Preferred Manga").
		WithStatus(anilist.MediaStatusHiatus).
		WithFormat(anilist.MediaFormatOneShot).
		WithChapters(10).
		WithVolumes(2).
		WithIsAdult(true).
		WithSynonyms("Manga Alt").
		WithStartDate(2021, 5, 3).
		WithEndDate(2021, 9, 1).
		WithCoverImage("https://example.com/manga/88.jpg").
		WithBannerImage("https://example.com/manga/88-banner.jpg").
		Build()

	require.Equal(t, 88, manga.ID)
	require.NotNil(t, manga.IDMal)
	require.Equal(t, 808, *manga.IDMal)
	require.NotNil(t, manga.Type)
	require.Equal(t, anilist.MediaTypeManga, *manga.Type)
	require.NotNil(t, manga.SiteURL)
	require.Equal(t, "https://example.com/manga/88", *manga.SiteURL)
	require.Equal(t, "English Manga", *manga.Title.English)
	require.Equal(t, "Romaji Manga", *manga.Title.Romaji)
	require.Equal(t, "Native Manga", *manga.Title.Native)
	require.Equal(t, "Preferred Manga", *manga.Title.UserPreferred)
	require.Equal(t, anilist.MediaStatusHiatus, *manga.Status)
	require.Equal(t, anilist.MediaFormatOneShot, *manga.Format)
	require.Equal(t, 10, *manga.Chapters)
	require.Equal(t, 2, *manga.Volumes)
	require.Equal(t, true, *manga.IsAdult)
	require.Len(t, manga.Synonyms, 1)
	require.Equal(t, "Manga Alt", *manga.Synonyms[0])
	require.Equal(t, 2021, *manga.StartDate.Year)
	require.Equal(t, 5, *manga.StartDate.Month)
	require.Equal(t, 3, *manga.StartDate.Day)
	require.Equal(t, 2021, *manga.EndDate.Year)
	require.Equal(t, 9, *manga.EndDate.Month)
	require.Equal(t, 1, *manga.EndDate.Day)
	require.Equal(t, "https://example.com/manga/88.jpg", *manga.CoverImage.Large)
	require.Equal(t, "https://example.com/manga/88-banner.jpg", *manga.BannerImage)
}

// keeps the old helper around for tests that only need the seeded defaults.
func TestSeededMediaHelpers(t *testing.T) {
	anime := NewBaseAnime(11, "default anime")
	manga := NewBaseManga(22, "default manga")

	require.Equal(t, 11, anime.ID)
	require.Equal(t, 22, manga.ID)
	require.Equal(t, "default anime", *anime.Title.English)
	require.Equal(t, "default manga", *manga.Title.English)
}
