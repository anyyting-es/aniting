import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/constants/feature_flags.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/data/services/custom_anime_assets_service.dart';
import 'package:aniting/data/services/tmdb_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';

/// Cached provider for AniZip data by AniList media ID.
final exploreAniZipProvider =
    FutureProvider.family<AniZipData?, int>((ref, mediaId) async {
  if (mediaId <= 0) return null;
  final repo = ref.watch(repositoryProvider);
  final cached = repo.getCachedAniZipData(mediaId);
  if (cached != null) return cached;
  return repo.getAniZipData(mediaId).catchError((_) => null);
});

/// Cached provider for TMDB assets (backdrop & logo) by TMDB ID.
final exploreTmdbAssetsProvider = FutureProvider.family<
    TmdbMediaAssets?,
    ({int tmdbId, bool isMovie})>((ref, arg) async {
  if (!FeatureFlags.tmdb) return null;
  final tmdb = ref.watch(tmdbServiceProvider);
  final cached =
      TmdbService.getCachedAssets(arg.tmdbId, arg.isMovie);
  if (cached != null) return cached;
  return tmdb
      .getMediaAssets(tmdbId: arg.tmdbId, isMovie: arg.isMovie)
      .catchError((_) => null);
});

/// Canonical data representation of an Explore Carousel slide.
class ExploreCarouselItem {
  final int mediaId;
  final String title;
  final String? backdropUrl;
  final String? posterUrl;
  final String? logoUrl;
  final String? description;
  final double? score;
  final int? year;
  final String? format;
  final List<String> genres;
  final bool isMovie;
  final bool isManga;
  final AnimeEntry? animeEntry;
  final MangaEntry? mangaEntry;

  const ExploreCarouselItem({
    required this.mediaId,
    required this.title,
    this.backdropUrl,
    this.posterUrl,
    this.logoUrl,
    this.description,
    this.score,
    this.year,
    this.format,
    this.genres = const [],
    this.isMovie = false,
    this.isManga = false,
    this.animeEntry,
    this.mangaEntry,
  });

  /// Builds a carousel slide from an AniList anime entry and optional AniZip metadata.
  factory ExploreCarouselItem.fromAnime({
    required AnimeEntry anime,
    required TitleLanguage titleLang,
    AniZipData? aniZip,
  }) {
    int? year = anime.year;
    if (year == null && anime.airDate != null && anime.airDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(anime.airDate!);
      year = parsed?.year ?? int.tryParse(anime.airDate!.split('-').first);
    }

    final customAssets =
        CustomAnimeAssetsService.getAssets(anime.mediaId);

    final backdrop =
        customAssets?.background ?? aniZip?.fanartUrl ?? anime.bannerImage ?? anime.coverImage;
    final logo = customAssets?.logo ?? aniZip?.clearlogoUrl;

    return ExploreCarouselItem(
      mediaId: anime.mediaId,
      title: anime.displayTitle(titleLang),
      backdropUrl: backdrop,
      posterUrl: anime.coverImage,
      logoUrl: logo,
      description: anime.description,
      score: anime.score,
      year: year,
      format: anime.format ?? 'TV',
      genres: anime.genres,
      isMovie: anime.format?.toUpperCase() == 'MOVIE',
      isManga: false,
      animeEntry: anime,
    );
  }

  /// Builds a carousel slide from a TMDB show/movie entry and optional TMDB assets.
  factory ExploreCarouselItem.fromTmdbShow({
    required AnimeEntry show,
    required TitleLanguage titleLang,
    TmdbMediaAssets? assets,
  }) {
    final isMovie = show.format?.toUpperCase() == 'MOVIE';
    final backdrop = assets?.backdropUrl ?? show.bannerImage ?? show.coverImage;
    final logo = assets?.logoUrl;

    return ExploreCarouselItem(
      mediaId: show.mediaId,
      title: show.displayTitle(titleLang),
      backdropUrl: backdrop,
      posterUrl: show.coverImage,
      logoUrl: logo,
      description: show.description,
      score: show.score,
      year: show.year,
      format: show.format ?? (isMovie ? 'PELÍCULA' : 'SERIE'),
      genres: show.genres,
      isMovie: isMovie,
      isManga: false,
      animeEntry: show,
    );
  }

  /// Builds a banner carousel slide from a Manga entry.
  factory ExploreCarouselItem.fromManga({
    required MangaEntry manga,
    required TitleLanguage titleLang,
  }) {
    return ExploreCarouselItem(
      mediaId: manga.mediaId,
      title: manga.displayTitle(titleLang),
      backdropUrl: manga.bannerImage ?? manga.coverImage,
      posterUrl: manga.coverImage,
      description: manga.description,
      score: manga.score,
      year: manga.year,
      format: manga.format ?? 'MANGA',
      genres: manga.genres,
      isMovie: false,
      isManga: true,
      mangaEntry: manga,
    );
  }
}
