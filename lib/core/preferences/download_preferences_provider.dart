import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPreferencesState {
  final String customBasePath;
  final String resolvedBasePath;
  final bool isLoading;

  const DownloadPreferencesState({
    this.customBasePath = '',
    this.resolvedBasePath = '',
    this.isLoading = true,
  });

  DownloadPreferencesState copyWith({
    String? customBasePath,
    String? resolvedBasePath,
    bool? isLoading,
  }) {
    return DownloadPreferencesState(
      customBasePath: customBasePath ?? this.customBasePath,
      resolvedBasePath: resolvedBasePath ?? this.resolvedBasePath,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DownloadPreferencesNotifier extends Notifier<DownloadPreferencesState> {
  static const String _prefKey = 'app_custom_downloads_path';
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

    state = DownloadPreferencesState(
      customBasePath: saved,
      resolvedBasePath: resolved,
      isLoading: false,
    );
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
    );
  }

  Future<void> resetToDefault() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    final defaultPath = await AppStoragePaths.getDefaultDownloadsBasePath();

    state = state.copyWith(
      customBasePath: '',
      resolvedBasePath: defaultPath,
    );
  }
}

final downloadPreferencesProvider =
    NotifierProvider<DownloadPreferencesNotifier, DownloadPreferencesState>(
        DownloadPreferencesNotifier.new);
