import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPreferencesState {
  final String customBasePath;
  final String resolvedBasePath;
  final bool isUnified;
  final String customAnimePath;
  final String resolvedAnimePath;
  final String customMangaPath;
  final String resolvedMangaPath;
  final String customShowsPath;
  final String resolvedShowsPath;
  final bool isLoading;

  const DownloadPreferencesState({
    this.customBasePath = '',
    this.resolvedBasePath = '',
    this.isUnified = true,
    this.customAnimePath = '',
    this.resolvedAnimePath = '',
    this.customMangaPath = '',
    this.resolvedMangaPath = '',
    this.customShowsPath = '',
    this.resolvedShowsPath = '',
    this.isLoading = true,
  });

  DownloadPreferencesState copyWith({
    String? customBasePath,
    String? resolvedBasePath,
    bool? isUnified,
    String? customAnimePath,
    String? resolvedAnimePath,
    String? customMangaPath,
    String? resolvedMangaPath,
    String? customShowsPath,
    String? resolvedShowsPath,
    bool? isLoading,
  }) {
    return DownloadPreferencesState(
      customBasePath: customBasePath ?? this.customBasePath,
      resolvedBasePath: resolvedBasePath ?? this.resolvedBasePath,
      isUnified: isUnified ?? this.isUnified,
      customAnimePath: customAnimePath ?? this.customAnimePath,
      resolvedAnimePath: resolvedAnimePath ?? this.resolvedAnimePath,
      customMangaPath: customMangaPath ?? this.customMangaPath,
      resolvedMangaPath: resolvedMangaPath ?? this.resolvedMangaPath,
      customShowsPath: customShowsPath ?? this.customShowsPath,
      resolvedShowsPath: resolvedShowsPath ?? this.resolvedShowsPath,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DownloadPreferencesNotifier extends Notifier<DownloadPreferencesState> {
  static const String _prefKey = 'app_custom_downloads_path';
  static const String _isUnifiedKey = 'app_downloads_is_unified';
  static const String _animePathKey = 'app_downloads_anime_path';
  static const String _mangaPathKey = 'app_downloads_manga_path';
  static const String _showsPathKey = 'app_downloads_shows_path';

  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  DownloadPreferencesState build() {
    _init();
    return const DownloadPreferencesState();
  }

  Future<void> _init() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    var saved = prefs.getString(_prefKey) ?? '';
    if (saved.isNotEmpty &&
        (saved.contains('Downloads/Aniting/Downloads') ||
            saved.contains(r'Downloads\Aniting\Downloads') ||
            saved.contains('Download/Aniting/Downloads'))) {
      await prefs.remove(_prefKey);
      saved = '';
    }
    final defaultPath = await AppStoragePaths.getDefaultDownloadsBasePath();
    final resolved = saved.isNotEmpty ? saved : defaultPath;

    final isUnified = prefs.getBool(_isUnifiedKey) ?? true;
    final customAnime = prefs.getString(_animePathKey) ?? '';
    final customManga = prefs.getString(_mangaPathKey) ?? '';
    final customShows = prefs.getString(_showsPathKey) ?? '';

    state = DownloadPreferencesState(
      customBasePath: saved,
      resolvedBasePath: resolved,
      isUnified: isUnified,
      customAnimePath: customAnime,
      resolvedAnimePath: customAnime.isNotEmpty ? customAnime : '$resolved/Anime',
      customMangaPath: customManga,
      resolvedMangaPath: customManga.isNotEmpty ? customManga : '$resolved/Manga',
      customShowsPath: customShows,
      resolvedShowsPath: customShows.isNotEmpty ? customShows : '$resolved/Shows',
      isLoading: false,
    );
  }

  Future<void> setIsUnified(bool unified) async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_isUnifiedKey, unified);
    state = state.copyWith(isUnified: unified);
  }

  Future<void> setCustomBasePath(String path) async {
    final trimmed = path.trim();
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, trimmed);

    final defaultPath = await AppStoragePaths.getDefaultDownloadsBasePath();
    final resolved = trimmed.isNotEmpty ? trimmed : defaultPath;

    state = state.copyWith(
      customBasePath: trimmed,
      resolvedBasePath: resolved,
      resolvedAnimePath: state.customAnimePath.isNotEmpty ? state.customAnimePath : '$resolved/Anime',
      resolvedMangaPath: state.customMangaPath.isNotEmpty ? state.customMangaPath : '$resolved/Manga',
      resolvedShowsPath: state.customShowsPath.isNotEmpty ? state.customShowsPath : '$resolved/Shows',
    );
  }

  Future<void> setCustomAnimePath(String path) async {
    final trimmed = path.trim();
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_animePathKey, trimmed);
    final fallback = '${state.resolvedBasePath}/Anime';
    state = state.copyWith(
      customAnimePath: trimmed,
      resolvedAnimePath: trimmed.isNotEmpty ? trimmed : fallback,
    );
  }

  Future<void> setCustomMangaPath(String path) async {
    final trimmed = path.trim();
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_mangaPathKey, trimmed);
    final fallback = '${state.resolvedBasePath}/Manga';
    state = state.copyWith(
      customMangaPath: trimmed,
      resolvedMangaPath: trimmed.isNotEmpty ? trimmed : fallback,
    );
  }

  Future<void> setCustomShowsPath(String path) async {
    final trimmed = path.trim();
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_showsPathKey, trimmed);
    final fallback = '${state.resolvedBasePath}/Shows';
    state = state.copyWith(
      customShowsPath: trimmed,
      resolvedShowsPath: trimmed.isNotEmpty ? trimmed : fallback,
    );
  }

  Future<void> resetAnimePath() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_animePathKey);
    state = state.copyWith(
      customAnimePath: '',
      resolvedAnimePath: '${state.resolvedBasePath}/Anime',
    );
  }

  Future<void> resetMangaPath() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_mangaPathKey);
    state = state.copyWith(
      customMangaPath: '',
      resolvedMangaPath: '${state.resolvedBasePath}/Manga',
    );
  }

  Future<void> resetShowsPath() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_showsPathKey);
    state = state.copyWith(
      customShowsPath: '',
      resolvedShowsPath: '${state.resolvedBasePath}/Shows',
    );
  }

  Future<void> resetToDefault() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_isUnifiedKey);
    await prefs.remove(_animePathKey);
    await prefs.remove(_mangaPathKey);
    await prefs.remove(_showsPathKey);
    final defaultPath = await AppStoragePaths.getDefaultDownloadsBasePath();

    state = DownloadPreferencesState(
      customBasePath: '',
      resolvedBasePath: defaultPath,
      isUnified: true,
      customAnimePath: '',
      resolvedAnimePath: '$defaultPath/Anime',
      customMangaPath: '',
      resolvedMangaPath: '$defaultPath/Manga',
      customShowsPath: '',
      resolvedShowsPath: '$defaultPath/Shows',
      isLoading: false,
    );
  }
}

final downloadPreferencesProvider =
    NotifierProvider<DownloadPreferencesNotifier, DownloadPreferencesState>(
        DownloadPreferencesNotifier.new);
