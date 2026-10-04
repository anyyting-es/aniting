import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/data/models/explore_carousel_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get _isInTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class ExploreCarouselNotifier extends Notifier<ExploreCarouselConfig> {
  static const String kRemoteUrl =
      'https://raw.githubusercontent.com/anyyting-es/aniting/main/data/explore_carousel.json';
  static const String _kPrefsKeyConfig = 'explore_carousel_config_json_v1';
  static const String _kPrefsKeyVersion = 'explore_carousel_version_v1';

  static SharedPreferences? _cachedPrefs;
  static bool _hasSyncedOnStartup = false;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  static const ExploreCarouselConfig defaultFallbackConfig = ExploreCarouselConfig(
    version: 3,
    updatedAt: '2026-10-04T03:35:00Z',
    items: [
      ExploreFeaturedItem(
        mediaId: 195604,
        title: 'Black Clover Season 2',
        horizontalBackground: 'https://image.tmdb.org/t/p/w1280/qu9epTZh29fGUkY7ZYc9PVsv0Ig.jpg',
        verticalBackground: 'https://image.tmdb.org/t/p/w780/hPz1086iC2NSPgs8PKtBplddpvs.jpg',
        logo: 'https://image.tmdb.org/t/p/w500/j9ZZ7WV5pwLLXbbebyGdMUxbqrc.png',
        year: 2026,
        format: 'TV',
      ),
      ExploreFeaturedItem(
        mediaId: 195516,
        title: 'The Apothecary Diaries Season 3',
        horizontalBackground: 'https://image.tmdb.org/t/p/w1280/4kR7cOsf6r86nrHL9UHzxgoQXAz.jpg',
        verticalBackground: 'https://image.tmdb.org/t/p/w780/dCJ0OyPQfRvsgP5IvlgT0zoE6bc.jpg',
        logo: 'https://image.tmdb.org/t/p/w500/6JpmIe9cJcbG6hecyN6ml8AG6RC.png',
        year: 2026,
        format: 'TV',
        score: 8.6,
      ),
      ExploreFeaturedItem(
        mediaId: 189123,
        title: 'Blue Box Season 2',
        horizontalBackground: 'https://image.tmdb.org/t/p/w1280/edb6wIacGgLI1PzPd3ua4mY3Vne.jpg',
        verticalBackground: 'https://image.tmdb.org/t/p/w780/r3BISdv0sAqfzNaBDSjwsRzIgo6.jpg',
        logo: 'https://image.tmdb.org/t/p/w500/ubw6k78dv5SU9y9JoHRkBW8pGuN.png',
        year: 2026,
        format: 'TV',
      ),
      ExploreFeaturedItem(
        mediaId: 213805,
        title: 'The Ramparts of Ice Season 2',
        horizontalBackground: 'https://image.tmdb.org/t/p/w1280/xwoRomUq2YmpgXlDgBQCZIcgXEc.jpg',
        verticalBackground: 'https://image.tmdb.org/t/p/w780/al6q31WdsER7ailNIDelCPCRGWB.jpg',
        logo: 'https://image.tmdb.org/t/p/w500/a5okATkpmXxAClSnAjGP4ums77c.png',
        year: 2026,
        format: 'TV',
        score: 8.4,
      ),
      ExploreFeaturedItem(
        mediaId: 178083,
        title: 'Tokyo Revengers: Santen Sensou-hen',
        horizontalBackground: 'https://image.tmdb.org/t/p/w1280/4R9nNlt23s66GYrRRy1mcD6NIFI.jpg',
        verticalBackground: 'https://image.tmdb.org/t/p/w780/nMti438Lk0Sp5aAFkRBk4cnkwz4.jpg',
        logo: 'https://image.tmdb.org/t/p/w500/65tCEJcUZud5Pwixqv6xsKNjqYf.png',
        year: 2026,
        format: 'TV',
        score: 7.8,
      ),
    ],
  );

  @override
  ExploreCarouselConfig build() {
    if (_cachedPrefs != null) {
      final storedJson = _cachedPrefs!.getString(_kPrefsKeyConfig);
      if (storedJson != null && storedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(storedJson) as Map<String, dynamic>;
          final parsed = ExploreCarouselConfig.fromJson(decoded);
          // If stored version is older than fallback version, discard stale 4K cache
          if (parsed.version >= defaultFallbackConfig.version) {
            return parsed;
          }
        } catch (_) {}
      }
    }
    return defaultFallbackConfig;
  }

  /// Checks for updates ONLY once on application startup in the background.
  /// Never executes repeatedly during app navigation or Explore visits.
  Future<void> syncOnStartup() async {
    if (_hasSyncedOnStartup || _isInTest) return;
    _hasSyncedOnStartup = true;

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      final response = await dio.get<String>(
        kRemoteUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final decoded = jsonDecode(response.data!) as Map<String, dynamic>;
        final remoteConfig = ExploreCarouselConfig.fromJson(decoded);
        final currentVersion = state.version;

        if (remoteConfig.version > currentVersion || remoteConfig.items.length != state.items.length) {
          state = remoteConfig;
          final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
          await prefs.setString(_kPrefsKeyConfig, response.data!);
          await prefs.setInt(_kPrefsKeyVersion, remoteConfig.version);
        }
      }
    } catch (_) {
      // Offline or network error: silent fallback to local state
    }
  }

  /// Manually checks for update (e.g. if the user explicitly triggers a pull-to-refresh).
  Future<void> refresh() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      final response = await dio.get<String>(
        '$kRemoteUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final decoded = jsonDecode(response.data!) as Map<String, dynamic>;
        final remoteConfig = ExploreCarouselConfig.fromJson(decoded);
        state = remoteConfig;
        final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
        await prefs.setString(_kPrefsKeyConfig, response.data!);
        await prefs.setInt(_kPrefsKeyVersion, remoteConfig.version);
      }
    } catch (_) {}
  }
}

/// Optimizes TMDB image URLs to deliver native lightweight dimensions instead of huge 4K originals.
/// Prevents uncompressed texture memory spikes and decode hitches.
String optimizeTmdbImageUrl(
  String? url, {
  required bool isDesktop,
  bool isLogo = false,
}) {
  if (url == null || url.isEmpty) return '';
  if (!url.contains('image.tmdb.org/t/p/')) return url;

  if (isLogo) {
    return url.replaceFirst(RegExp(r'/t/p/(?:original|w\d+)/'), '/t/p/w500/');
  } else {
    final targetSize = isDesktop ? 'w1280' : 'w780';
    return url.replaceFirst(RegExp(r'/t/p/(?:original|w\d+)/'), '/t/p/$targetSize/');
  }
}

final exploreCarouselNotifierProvider =
    NotifierProvider<ExploreCarouselNotifier, ExploreCarouselConfig>(ExploreCarouselNotifier.new);
