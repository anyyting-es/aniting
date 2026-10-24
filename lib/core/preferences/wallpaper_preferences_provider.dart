import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_palette.dart';
import '../theme/theme_provider.dart';

class AppWallpaperState {
  final bool enabled;
  final String? filePath;
  final double opacity; // 0.05 to 0.95, default 0.35
  final double blur;    // 0.0 to 40.0, default 10.0
  final int? seedColorValue;

  const AppWallpaperState({
    this.enabled = false,
    this.filePath,
    this.opacity = 0.35,
    this.blur = 10.0,
    this.seedColorValue,
  });

  bool get hasValidWallpaper =>
      enabled &&
      filePath != null &&
      filePath!.isNotEmpty &&
      File(filePath!).existsSync();

  Color? get seedColor =>
      seedColorValue != null ? Color(seedColorValue!) : null;

  String get fileName {
    if (filePath == null || filePath!.isEmpty) return '';
    return filePath!.split(Platform.pathSeparator).last;
  }

  AppWallpaperState copyWith({
    bool? enabled,
    String? filePath,
    bool clearFilePath = false,
    double? opacity,
    double? blur,
    int? seedColorValue,
    bool clearSeedColor = false,
  }) {
    return AppWallpaperState(
      enabled: enabled ?? this.enabled,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      seedColorValue: clearSeedColor
          ? null
          : (seedColorValue ?? this.seedColorValue),
    );
  }
}

class AppWallpaperNotifier extends Notifier<AppWallpaperState> {
  static const _keyEnabled = 'app_wallpaper_enabled';
  static const _keyPath = 'app_wallpaper_path';
  static const _keyOpacity = 'app_wallpaper_opacity';
  static const _keyBlur = 'app_wallpaper_blur';
  static const _keySeedColor = 'app_wallpaper_seed_color';

  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
    // Apply the saved seed synchronously so the Material You palette built by
    // ThemeNotifier on the first frame already matches the wallpaper.
    final seed = prefs.getInt(_keySeedColor);
    if (seed != null) {
      AppPalettes.wallpaperSeedColor = Color(seed);
    }
  }

  @override
  AppWallpaperState build() {
    if (_cachedPrefs != null) {
      final enabled = _cachedPrefs!.getBool(_keyEnabled) ?? false;
      final path = _cachedPrefs!.getString(_keyPath);
      final opacity = _cachedPrefs!.getDouble(_keyOpacity) ?? 0.35;
      final blur = _cachedPrefs!.getDouble(_keyBlur) ?? 10.0;
      final seed = _cachedPrefs!.getInt(_keySeedColor);
      if (seed != null) {
        AppPalettes.wallpaperSeedColor = Color(seed);
      }
      return AppWallpaperState(
        enabled: enabled,
        filePath: path,
        opacity: opacity.clamp(0.05, 0.95),
        blur: blur.clamp(0.0, 40.0),
        seedColorValue: seed,
      );
    }
    _loadFromPrefs();
    return const AppWallpaperState();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final path = prefs.getString(_keyPath);
    final opacity = prefs.getDouble(_keyOpacity) ?? 0.35;
    final blur = prefs.getDouble(_keyBlur) ?? 10.0;
    final seed = prefs.getInt(_keySeedColor);
    if (seed != null) {
      AppPalettes.wallpaperSeedColor = Color(seed);
    }
    state = AppWallpaperState(
      enabled: enabled,
      filePath: path,
      opacity: opacity.clamp(0.05, 0.95),
      blur: blur.clamp(0.0, 40.0),
      seedColorValue: seed,
    );
  }

  Future<void> setWallpaperPath(String? path) async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    if (path == null || path.isEmpty) {
      await prefs.remove(_keyPath);
      await prefs.remove(_keySeedColor);
      await prefs.setBool(_keyEnabled, false);
      AppPalettes.wallpaperSeedColor = null;
      state = state.copyWith(
        clearFilePath: true,
        clearSeedColor: true,
        enabled: false,
      );
      return;
    }

    await prefs.setString(_keyPath, path);
    await prefs.setBool(_keyEnabled, true);

    // Extract Material Design seed color from image
    int? seedValue;
    try {
      final file = File(path);
      if (file.existsSync()) {
        final scheme = await ColorScheme.fromImageProvider(
          provider: FileImage(file),
          brightness: Brightness.dark,
        );
        final extracted = scheme.primary;
        seedValue = extracted.toARGB32();
        AppPalettes.wallpaperSeedColor = extracted;
        await prefs.setInt(_keySeedColor, seedValue);
      }
    } catch (e) {
      debugPrint('Error extracting seed from wallpaper: $e');
    }

    state = state.copyWith(
      filePath: path,
      enabled: true,
      seedColorValue: seedValue,
    );

    // Switch to wallpaper palette and turn off OLED mode so wallpaper and dynamic Material 3 colors are visible!
    await ref.read(themeProvider.notifier).setOled(false);
    await ref.read(themeProvider.notifier).setPaletteId(
          AppPalettes.materialWallpaperId,
          resetCustomAccent: true,
        );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setBool(_keyEnabled, enabled);
  }

  Future<void> setOpacity(double opacity) async {
    final clamped = opacity.clamp(0.05, 0.95);
    state = state.copyWith(opacity: clamped);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setDouble(_keyOpacity, clamped);
  }

  Future<void> setBlur(double blur) async {
    final clamped = blur.clamp(0.0, 40.0);
    state = state.copyWith(blur: clamped);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setDouble(_keyBlur, clamped);
  }

  Future<void> clearWallpaper() async {
    await setWallpaperPath(null);
  }
}

final wallpaperPreferencesProvider =
    NotifierProvider<AppWallpaperNotifier, AppWallpaperState>(
  AppWallpaperNotifier.new,
);
