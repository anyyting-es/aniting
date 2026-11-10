import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/presentation/providers/app_providers.dart';

import 'explore_carousel_models.dart';
import 'explore_hero_carousel.dart';
import 'explore_manga_banner_carousel.dart';

/// Top-level coordinator for Explore carousels (Anime AniZip Hero, TMDB Shows Hero, Manga Banner).
class ExploreCarouselSection extends ConsumerWidget {
  final String mediaType;
  final double contentLeftInset;

  const ExploreCarouselSection({
    super.key,
    required this.mediaType,
    this.contentLeftInset = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleLang = ref.watch(titleLanguageProvider);

    switch (mediaType.toUpperCase()) {
      case 'SHOWS':
        return _ShowsCarouselView(
          titleLang: titleLang,
          contentLeftInset: contentLeftInset,
        );
      case 'MANGA':
        return _MangaCarouselView(titleLang: titleLang);
      case 'ANIME':
      default:
        return _AnimeCarouselView(
          titleLang: titleLang,
          contentLeftInset: contentLeftInset,
        );
    }
  }
}

/// Anime Top 5 Trending Carousel with AniZip integration.
class _AnimeCarouselView extends ConsumerWidget {
  final TitleLanguage titleLang;
  final double contentLeftInset;

  const _AnimeCarouselView({
    required this.titleLang,
    required this.contentLeftInset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingAnimeProvider);

    return trendingAsync.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final top5 = items.take(5).toList();

        final carouselItems = top5.map((anime) {
          final aniZip = ref
              .watch(exploreAniZipProvider(anime.mediaId))
              .asData
              ?.value;
          return ExploreCarouselItem.fromAnime(
            anime: anime,
            titleLang: titleLang,
            aniZip: aniZip,
          );
        }).toList();

        return ExploreHeroCarousel(
          key: ValueKey('anime_hero_${top5.map((e) => e.mediaId).join('_')}'),
          items: carouselItems,
          contentLeftInset: contentLeftInset,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// TMDB Top 5 Trending Shows & Movies Carousel with TMDB API assets.
class _ShowsCarouselView extends ConsumerWidget {
  final TitleLanguage titleLang;
  final double contentLeftInset;

  const _ShowsCarouselView({
    required this.titleLang,
    required this.contentLeftInset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingShowsAsync = ref.watch(tmdbTrendingShowsProvider);

    return trendingShowsAsync.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final top5 = items.take(5).toList();

        final carouselItems = top5.map((show) {
          final isMovie = show.format?.toUpperCase() == 'MOVIE';
          final tmdbAssets = ref
              .watch(
                exploreTmdbAssetsProvider((
                  tmdbId: show.mediaId,
                  isMovie: isMovie,
                )),
              )
              .asData
              ?.value;
          return ExploreCarouselItem.fromTmdbShow(
            show: show,
            titleLang: titleLang,
            assets: tmdbAssets,
          );
        }).toList();

        return ExploreHeroCarousel(
          key: ValueKey('shows_hero_${top5.map((e) => e.mediaId).join('_')}'),
          items: carouselItems,
          contentLeftInset: contentLeftInset,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Manga Top 5 Trending Banner Carousel.
class _MangaCarouselView extends ConsumerWidget {
  final TitleLanguage titleLang;

  const _MangaCarouselView({required this.titleLang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingMangaAsync = ref.watch(trendingMangaProvider);
    final popularMangaAsync = ref.watch(popularMangaProvider);

    final items =
        trendingMangaAsync.asData?.value ??
        popularMangaAsync.asData?.value ??
        [];

    if (items.isEmpty) return const SizedBox.shrink();
    final top5 = items.take(5).toList();

    final carouselItems = top5
        .map(
          (manga) =>
              ExploreCarouselItem.fromManga(manga: manga, titleLang: titleLang),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExploreMangaBannerCarousel(
        key: ValueKey('manga_banner_${top5.map((e) => e.mediaId).join('_')}'),
        items: carouselItems,
      ),
    );
  }
}
