package testmocks

import "seanime/internal/api/anilist"

type BaseAnimeBuilder struct {
	anime *anilist.BaseAnime
}

func NewBaseAnimeBuilder(id int, title string) *BaseAnimeBuilder {
	return &BaseAnimeBuilder{anime: &anilist.BaseAnime{
		ID:       id,
		IDMal:    new(501),
		Status:   new(anilist.MediaStatusFinished),
		Type:     new(anilist.MediaTypeAnime),
		Format:   new(anilist.MediaFormatTv),
		Episodes: new(12),
		IsAdult:  new(false),
		Title: &anilist.BaseAnime_Title{
			English: new(title),
			Romaji:  new(title),
		},
		Synonyms: []*string{new(title), new("Sample Anime Season 1")},
		StartDate: &anilist.BaseAnime_StartDate{
			Year:  new(2024),
			Month: new(1),
			Day:   new(2),
		},
	}}
}

func NewBaseAnime(id int, title string) *anilist.BaseAnime {
	return NewBaseAnimeBuilder(id, title).Build()
}

func (b *BaseAnimeBuilder) WithIDMal(idMal int) *BaseAnimeBuilder {
	b.anime.IDMal = new(idMal)
	return b
}

func (b *BaseAnimeBuilder) WithSiteURL(siteURL string) *BaseAnimeBuilder {
	b.anime.SiteURL = new(siteURL)
	return b
}

func (b *BaseAnimeBuilder) WithTitles(english string, romaji string, native string, userPreferred string) *BaseAnimeBuilder {
	ensureAnimeTitle(b.anime)
	b.anime.Title.English = new(english)
	b.anime.Title.Romaji = new(romaji)
	b.anime.Title.Native = new(native)
	b.anime.Title.UserPreferred = new(userPreferred)
	return b
}

func (b *BaseAnimeBuilder) WithEnglishTitle(title string) *BaseAnimeBuilder {
	ensureAnimeTitle(b.anime)
	b.anime.Title.English = new(title)
	return b
}

func (b *BaseAnimeBuilder) WithRomajiTitle(title string) *BaseAnimeBuilder {
	ensureAnimeTitle(b.anime)
	b.anime.Title.Romaji = new(title)
	return b
}

func (b *BaseAnimeBuilder) WithNativeTitle(title string) *BaseAnimeBuilder {
	ensureAnimeTitle(b.anime)
	b.anime.Title.Native = new(title)
	return b
}

func (b *BaseAnimeBuilder) WithUserPreferredTitle(title string) *BaseAnimeBuilder {
	ensureAnimeTitle(b.anime)
	b.anime.Title.UserPreferred = new(title)
	return b
}

func (b *BaseAnimeBuilder) WithStatus(status anilist.MediaStatus) *BaseAnimeBuilder {
	b.anime.Status = new(status)
	return b
}

func (b *BaseAnimeBuilder) WithFormat(format anilist.MediaFormat) *BaseAnimeBuilder {
	b.anime.Format = new(format)
	return b
}

func (b *BaseAnimeBuilder) WithEpisodes(episodes int) *BaseAnimeBuilder {
	b.anime.Episodes = new(episodes)
	return b
}

func (b *BaseAnimeBuilder) WithIsAdult(isAdult bool) *BaseAnimeBuilder {
	b.anime.IsAdult = new(isAdult)
	return b
}

func (b *BaseAnimeBuilder) WithSynonyms(synonyms ...string) *BaseAnimeBuilder {
	b.anime.Synonyms = stringPointers(synonyms...)
	return b
}

func (b *BaseAnimeBuilder) WithStartDate(year int, month int, day int) *BaseAnimeBuilder {
	b.anime.StartDate = &anilist.BaseAnime_StartDate{
		Year:  new(year),
		Month: new(month),
		Day:   new(day),
	}
	return b
}

func (b *BaseAnimeBuilder) WithEndDate(year int, month int, day int) *BaseAnimeBuilder {
	b.anime.EndDate = &anilist.BaseAnime_EndDate{
		Year:  new(year),
		Month: new(month),
		Day:   new(day),
	}
	return b
}

func (b *BaseAnimeBuilder) WithCoverImage(url string) *BaseAnimeBuilder {
	b.anime.CoverImage = &anilist.BaseAnime_CoverImage{
		ExtraLarge: new(url),
		Large:      new(url),
		Medium:     new(url),
	}
	return b
}

func (b *BaseAnimeBuilder) WithBannerImage(url string) *BaseAnimeBuilder {
	b.anime.BannerImage = new(url)
	return b
}

func (b *BaseAnimeBuilder) WithNextAiringEpisode(episode int, airingAt int, timeUntilAiring int) *BaseAnimeBuilder {
	b.anime.NextAiringEpisode = &anilist.BaseAnime_NextAiringEpisode{
		Episode:         episode,
		AiringAt:        airingAt,
		TimeUntilAiring: timeUntilAiring,
	}
	return b
}

func (b *BaseAnimeBuilder) Build() *anilist.BaseAnime {
	return b.anime
}

type BaseMangaBuilder struct {
	manga *anilist.BaseManga
}

func NewBaseMangaBuilder(id int, title string) *BaseMangaBuilder {
	return &BaseMangaBuilder{manga: &anilist.BaseManga{
		ID:      id,
		Status:  new(anilist.MediaStatusFinished),
		Type:    new(anilist.MediaTypeManga),
		Format:  new(anilist.MediaFormatManga),
		IsAdult: new(false),
		Title: &anilist.BaseManga_Title{
			English: new(title),
			Romaji:  new(title),
		},
		Synonyms: []*string{new(title), new(title + " Alternative")},
		StartDate: &anilist.BaseManga_StartDate{
			Year: new(2023),
		},
	}}
}

func NewBaseManga(id int, title string) *anilist.BaseManga {
	return NewBaseMangaBuilder(id, title).Build()
}

func (b *BaseMangaBuilder) WithIDMal(idMal int) *BaseMangaBuilder {
	b.manga.IDMal = new(idMal)
	return b
}

func (b *BaseMangaBuilder) WithSiteURL(siteURL string) *BaseMangaBuilder {
	b.manga.SiteURL = new(siteURL)
	return b
}

func (b *BaseMangaBuilder) WithTitles(english string, romaji string, native string, userPreferred string) *BaseMangaBuilder {
	ensureMangaTitle(b.manga)
	b.manga.Title.English = new(english)
	b.manga.Title.Romaji = new(romaji)
	b.manga.Title.Native = new(native)
	b.manga.Title.UserPreferred = new(userPreferred)
	return b
}

func (b *BaseMangaBuilder) WithEnglishTitle(title string) *BaseMangaBuilder {
	ensureMangaTitle(b.manga)
	b.manga.Title.English = new(title)
	return b
}

func (b *BaseMangaBuilder) WithRomajiTitle(title string) *BaseMangaBuilder {
	ensureMangaTitle(b.manga)
	b.manga.Title.Romaji = new(title)
	return b
}

func (b *BaseMangaBuilder) WithNativeTitle(title string) *BaseMangaBuilder {
	ensureMangaTitle(b.manga)
	b.manga.Title.Native = new(title)
	return b
}

func (b *BaseMangaBuilder) WithUserPreferredTitle(title string) *BaseMangaBuilder {
	ensureMangaTitle(b.manga)
	b.manga.Title.UserPreferred = new(title)
	return b
}

func (b *BaseMangaBuilder) WithStatus(status anilist.MediaStatus) *BaseMangaBuilder {
	b.manga.Status = new(status)
	return b
}

func (b *BaseMangaBuilder) WithFormat(format anilist.MediaFormat) *BaseMangaBuilder {
	b.manga.Format = new(format)
	return b
}

func (b *BaseMangaBuilder) WithChapters(chapters int) *BaseMangaBuilder {
	b.manga.Chapters = new(chapters)
	return b
}

func (b *BaseMangaBuilder) WithVolumes(volumes int) *BaseMangaBuilder {
	b.manga.Volumes = new(volumes)
	return b
}

func (b *BaseMangaBuilder) WithIsAdult(isAdult bool) *BaseMangaBuilder {
	b.manga.IsAdult = new(isAdult)
	return b
}

func (b *BaseMangaBuilder) WithSynonyms(synonyms ...string) *BaseMangaBuilder {
	b.manga.Synonyms = stringPointers(synonyms...)
	return b
}

func (b *BaseMangaBuilder) WithStartDate(year int, month int, day int) *BaseMangaBuilder {
	b.manga.StartDate = &anilist.BaseManga_StartDate{
		Year:  new(year),
		Month: new(month),
		Day:   new(day),
	}
	return b
}

func (b *BaseMangaBuilder) WithEndDate(year int, month int, day int) *BaseMangaBuilder {
	b.manga.EndDate = &anilist.BaseManga_EndDate{
		Year:  new(year),
		Month: new(month),
		Day:   new(day),
	}
	return b
}

func (b *BaseMangaBuilder) WithCoverImage(url string) *BaseMangaBuilder {
	b.manga.CoverImage = &anilist.BaseManga_CoverImage{
		ExtraLarge: new(url),
		Large:      new(url),
		Medium:     new(url),
	}
	return b
}

func (b *BaseMangaBuilder) WithBannerImage(url string) *BaseMangaBuilder {
	b.manga.BannerImage = new(url)
	return b
}

func (b *BaseMangaBuilder) Build() *anilist.BaseManga {
	return b.manga
}

func ensureAnimeTitle(anime *anilist.BaseAnime) {
	if anime.Title == nil {
		anime.Title = &anilist.BaseAnime_Title{}
	}
}

func ensureMangaTitle(manga *anilist.BaseManga) {
	if manga.Title == nil {
		manga.Title = &anilist.BaseManga_Title{}
	}
}

func stringPointers(values ...string) []*string {
	ret := make([]*string, 0, len(values))
	for _, value := range values {
		ret = append(ret, new(value))
	}
	return ret
}
