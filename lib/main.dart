import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:window_manager/window_manager.dart';
import 'package:seanime_app/core/constants/feature_flags.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/anime_playback_source_provider.dart';
import 'package:seanime_app/core/preferences/desktop_nav_style_provider.dart';
import 'package:seanime_app/core/preferences/desktop_scrollbar_provider.dart';
import 'package:seanime_app/core/preferences/onboarding_provider.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/preferences/player_engine_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/settings_sidebar_width_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/core/theme/app_scroll_behavior.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seanime_app/core/preferences/track_preferences_provider.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/startup/app_warm_up_gate.dart';
import 'package:seanime_app/presentation/screens/welcome_screen.dart';
import 'package:seanime_app/data/services/explore_carousel_service.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';
import 'package:seanime_app/data/services/offline_sync_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/preferences/desktop_window_transparency_provider.dart';
import 'package:seanime_app/core/preferences/wallpaper_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/app_wallpaper_background.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/core/player/mpris_service.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/presentation/widgets/dpad_navigation_scope.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast_host.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/core/services/deep_link_service.dart';
import 'package:seanime_app/data/services/tmdb_mapping_service.dart';
import 'package:seanime_app/data/services/tmdb_service.dart';
import 'package:seanime_app/data/services/custom_anime_assets_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFocusCoordinator.initialize();
  DeepLinkService.instance.initialize();
  unawaited(TmdbMappingService.init());
  unawaited(CustomAnimeAssetsService.init());
  try {
    await GlassHost.precache();
  } catch (_) {}
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB
  PaintingBinding.instance.imageCache.maximumSize = 250;

  if (!kIsWeb && Platform.isAndroid) {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final filesDir = Directory('${appSupport.parent.path}/files');
      final candidates = [
        filesDir,
        appSupport,
        Directory('/data/user/0/com.anyyting.aniting/files'),
        Directory('/data/data/com.anyyting.aniting/files'),
        Directory('/data/user/0/com.seanime.app.seanime_app/files'),
        Directory('/data/data/com.seanime.app.seanime_app/files'),
      ];
      for (final dir in candidates) {
        if (dir.existsSync()) {
          for (final entity in dir.listSync()) {
            if (entity is File && entity.path.contains('NativeReferenceHolder')) {
              try {
                entity.deleteSync();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    final windowOptions = WindowOptions(
      size: const Size(1280, 800),
      minimumSize: const Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Aniting',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  if (!kIsWeb && Platform.isLinux) {
    unawaited(MprisService.instance.init());
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    FeedCacheService.setCachedPrefs(prefs);
    OfflineLibraryService.setCachedPrefs(prefs);
    OfflineSyncService.setCachedPrefs(prefs);
    PlayerEngineNotifier.setCachedPrefs(prefs);
    AppLanguageNotifier.setCachedPrefs(prefs);
    DesktopScrollbarNotifier.setCachedPrefs(prefs);
    SettingsSidebarWidthNotifier.setCachedPrefs(prefs);
    AppWallpaperNotifier.setCachedPrefs(prefs);
    ThemeNotifier.setCachedPrefs(prefs);
    IconPackNotifier.setCachedPrefs(prefs);
    PlaybackProgressNotifier.setCachedPrefs(prefs);
    AnimePlaybackSourceNotifier.setCachedPrefs(prefs);
    LastSessionNotifier.setCachedPrefs(prefs);
    ResumeBarEnabledNotifier.setCachedPrefs(prefs);
    OnboardingNotifier.setCachedPrefs(prefs);
    AnimeSectionEnabledNotifier.setCachedPrefs(prefs);
    MangaSectionEnabledNotifier.setCachedPrefs(prefs);
    ExploreCarouselNotifier.setCachedPrefs(prefs);
    DesktopNavStyleNotifier.setCachedPrefs(prefs);
    DesktopWindowTransparencyNotifier.setCachedPrefs(prefs);
    GlassEffectsEnabledNotifier.setCachedPrefs(prefs);
    DownloadHistoryNotifier.setCachedPrefs(prefs);
    TrackPreferencesNotifier.setCachedPrefs(prefs);
    AnimeDetailScreen.setCachedPrefs(prefs);
    TmdbService.setCachedPrefs(prefs);
  } catch (_) {}
  runApp(
    const ProviderScope(
      child: AnitingFlutterApp(),
    ),
  );
}

class AnitingFlutterApp extends ConsumerStatefulWidget {
  const AnitingFlutterApp({super.key});

  @override
  ConsumerState<AnitingFlutterApp> createState() => _AnitingFlutterAppState();
}

class _AnitingFlutterAppState extends ConsumerState<AnitingFlutterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.read(offlineSyncServiceProvider).syncPending();
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider.select((s) => s.themeMode));
    final palette = ref.watch(themeProvider.select((s) => s.currentPalette));
    final isOled = ref.watch(themeProvider.select((s) => s.isOled));
    final fontId = ref.watch(themeProvider.select((s) => s.fontId));
    final customAccent = ref.watch(themeProvider.select((s) => s.customAccent));
    final showScrollbar = ref.watch(desktopScrollbarProvider);
    final glassEffectsEnabled = ref.watch(glassEffectsEnabledProvider);

    ThemeMode mode;
    switch (themeMode) {
      case AppThemeMode.system:
        mode = ThemeMode.system;
        break;
      case AppThemeMode.light:
        mode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        mode = ThemeMode.dark;
        break;
    }

    final initialRadius = ref.read(themeProvider).borderRadius;

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Aniting',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(showScrollbar: showScrollbar),
      theme: AppThemeBuilder.buildTheme(
        palette: palette,
        isDark: false,
        fontId: fontId,
        customAccent: customAccent,
        borderRadius: initialRadius,
      ),
      darkTheme: AppThemeBuilder.buildTheme(
        palette: palette,
        isDark: true,
        isOled: isOled,
        fontId: fontId,
        customAccent: customAccent,
        borderRadius: initialRadius,
      ),
      themeMode: mode,
      home: ref.watch(onboardingProvider) ? const AppWarmUpGate() : const WelcomeScreen(),
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final currentRadius = ref.watch(themeProvider.select((s) => s.borderRadius));
            final windowTrans = ref.watch(desktopWindowTransparencyProvider);
            final wallpaperState = ref.watch(wallpaperPreferencesProvider);
            final hasWallpaper =
                FeatureFlags.customWallpaper && wallpaperState.hasValidWallpaper;
            final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
            final isVideoPlayerActive = ref.watch(isVideoPlayerActiveProvider);
            final effectiveWindowTransparency = (FeatureFlags.desktopWindowTransparency &&
                isDesktop &&
                windowTrans.enabled) || isVideoPlayerActive;

            final baseTheme = Theme.of(context);
            final baseColors = baseTheme.extension<AppThemeColors>() ??
                AppThemeColors.fromPalette(palette, borderRadius: currentRadius);

            final effectiveScaffoldBg = (effectiveWindowTransparency || hasWallpaper)
                ? Colors.transparent
                : baseTheme.scaffoldBackgroundColor;

            final updatedTheme = baseTheme.copyWith(
              scaffoldBackgroundColor: effectiveScaffoldBg,
              cardTheme: baseTheme.cardTheme.copyWith(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(currentRadius),
                  side: (baseTheme.cardTheme.shape as RoundedRectangleBorder?)?.side ?? BorderSide.none,
                ),
              ),
              dialogTheme: baseTheme.dialogTheme.copyWith(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(currentRadius),
                ),
              ),
              popupMenuTheme: baseTheme.popupMenuTheme.copyWith(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(currentRadius),
                ),
              ),
              extensions: [
                baseColors.copyWith(borderRadius: currentRadius),
              ],
            );

            final isDark = updatedTheme.brightness == Brightness.dark;
            final overlayStyle = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: updatedTheme.scaffoldBackgroundColor,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: Theme(
                data: updatedTheme.copyWith(
                  appBarTheme: updatedTheme.appBarTheme.copyWith(
                    systemOverlayStyle: overlayStyle,
                  ),
                ),
                child: M3ETheme(
                  data: isDark
                      ? M3EThemeData.dark(seedColor: updatedTheme.colorScheme.primary)
                      : M3EThemeData.light(seedColor: updatedTheme.colorScheme.primary),
                  child: GlassHost(
                    richBackdrop: true,
                    finish: isDark ? GlassFinish.regularDark : GlassFinish.regularLight,
                    backdrop: (effectiveWindowTransparency || hasWallpaper)
                        ? Colors.transparent
                        : baseTheme.scaffoldBackgroundColor,
                    tier: GlassTierChoice(
                      glassEffectsEnabled.toGlassTier(),
                      GlassTierReason.pinnedByHost,
                    ),
                    child: DpadNavigationScope(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isVideoPlayerActive)
                            const SizedBox.shrink()
                          else if (effectiveWindowTransparency)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(
                                  color: (isOled && isDark
                                          ? Colors.black
                                          : baseTheme.scaffoldBackgroundColor)
                                      .withValues(alpha: windowTrans.opacity),
                                ),
                              ),
                            )
                          else if (hasWallpaper)
                            AppWallpaperBackground(wallpaper: wallpaperState)
                          else
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(
                                  color: isOled && isDark
                                      ? Colors.black
                                      : baseTheme.scaffoldBackgroundColor,
                                ),
                              ),
                            ),
                          child ?? const SizedBox.shrink(),
                          const AppToastHost(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

