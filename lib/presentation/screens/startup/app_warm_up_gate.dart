import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/main_shell.dart';

bool get _isInTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// AppWarmUpGate coordinates a smooth, flicker-free app launch.
///
/// It holds a sleek startup splash screen while the background Go server
/// initializes and the primary feed providers settle, avoiding cumulative
/// layout shifts (CLS), jumping carousels, and poster flickering on startup.
class AppWarmUpGate extends ConsumerStatefulWidget {
  const AppWarmUpGate({super.key});

  @override
  ConsumerState<AppWarmUpGate> createState() => _AppWarmUpGateState();
}

class _AppWarmUpGateState extends ConsumerState<AppWarmUpGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isWarmedUp = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!_isInTest) {
      _pulseController.repeat(reverse: true);
    }

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Safety watchdog: ensure AppWarmUpGate unconditionally dismisses within 3.5s under any circumstance
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && !_isWarmedUp) {
        setState(() {
          _isWarmedUp = true;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runWarmUp().timeout(
        const Duration(milliseconds: 3200),
        onTimeout: () {
          if (mounted && !_isWarmedUp) {
            setState(() {
              _isWarmedUp = true;
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runWarmUp() async {
    final startTime = DateTime.now();

    try {
      // 1. Wait for server to finish starting (max 2.5s timeout)
      final serverDeadline = DateTime.now().add(const Duration(milliseconds: 2500));
      while (mounted && DateTime.now().isBefore(serverDeadline)) {
        final serverState = ref.read(serverNotifierProvider);
        if (serverState.state != ServerState.starting) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 60));
      }

      if (!mounted) return;

      // 2. Pre-warm primary providers when online
      final serverState = ref.read(serverNotifierProvider);
      if (serverState.isOnline) {
        if (mounted) {
          setState(() {
            _statusText = ref.read(translationsProvider).startupWarmUpSyncing;
          });
        }

        final mangaEnabled = ref.read(mangaSectionEnabledProvider);

        final warmupFutures = <Future<dynamic>>[
          ref.read(continueWatchingProvider.future).catchError((_) => <AnimeEntry>[]),
          ref.read(downloadedAnimeProvider.future).catchError((_) => <AnimeEntry>[]),
          ref.read(animeCollectionProvider.future).catchError((_) => <AnimeEntry>[]),
        ];

        if (mangaEnabled) {
          warmupFutures.add(
            ref.read(continueReadingMangaProvider.future).catchError((_) => <MangaEntry>[]),
          );
        }

        // Wait for core providers with a strict 1.8s timeout
        await Future.wait(warmupFutures).timeout(
          const Duration(milliseconds: 1800),
          onTimeout: () => [],
        );

        if (!mounted) return;

        // 3. Pre-warm AniZip 16:9 episode thumbnails for top continue watching items
        final cwEntries = ref.read(continueWatchingProvider).value ?? <AnimeEntry>[];
        if (cwEntries.isNotEmpty) {
          final topMediaIds = cwEntries
              .take(4)
              .map((e) => e.mediaId)
              .where((id) => id > 0)
              .toList();

          if (topMediaIds.isNotEmpty) {
            await Future.wait([
              for (final id in topMediaIds)
                ref.read(aniZipDataProvider(id).future).catchError((_) => null),
            ]).timeout(
              const Duration(milliseconds: 700),
              onTimeout: () => [],
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _statusText = ref.read(translationsProvider).startupWarmUpReady;
        });
      }

      // 4. Ensure a minimum display time of 550ms for a deliberate, fluid feel
      final elapsed = DateTime.now().difference(startTime);
      const minDuration = Duration(milliseconds: 550);
      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }
    } catch (_) {
      // In case of unexpected startup errors, never block the user
    } finally {
      if (mounted) {
        setState(() {
          _isWarmedUp = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _isWarmedUp
            ? const MainShell(key: ValueKey('main_shell_warmed'))
            : _buildSplash(context, theme, l10n),
      ),
    );
  }

  Widget _buildSplash(BuildContext context, ThemeData theme, AppTranslations l10n) {
    final currentStatus = _statusText ?? l10n.startupWarmUpStarting;

    return Scaffold(
      key: const ValueKey('app_warmup_splash'),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Breathing Logo
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/icons/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // App Name
            Text(
              'Aniting',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Expressive Progress Indicator
            SizedBox(
              width: 140,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Subtle Status Description
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                currentStatus,
                key: ValueKey(currentStatus),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
