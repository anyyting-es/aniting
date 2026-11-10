import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/section_visibility_provider.dart';
import 'package:aniting/core/server/server_manager.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/main_shell.dart';
import 'package:aniting/presentation/screens/startup/startup_image_warmer.dart';

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
  final ValueNotifier<String?> _statusNotifier = ValueNotifier<String?>(null);
  late final AnimationController _splashFadeController;
  late final Animation<double> _splashOpacity;
  Timer? _watchdog;
  Timer? _fadeDelay;

  bool _isWarmedUp = false;
  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();

    _splashFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: 1,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed &&
            _splashVisible &&
            mounted) {
          setState(() => _splashVisible = false);
        }
      });
    _splashOpacity = CurvedAnimation(
      parent: _splashFadeController,
      curve: Curves.easeInOutCubic,
    );

    // Safety watchdog: ensure AppWarmUpGate unconditionally dismisses within
    // 3.5s under any circumstance.
    _watchdog = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && !_isWarmedUp) {
        _markWarmedUp();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runWarmUp().timeout(
        const Duration(milliseconds: 3200),
        onTimeout: () {
          if (mounted && !_isWarmedUp) {
            _markWarmedUp();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _fadeDelay?.cancel();
    _splashFadeController.dispose();
    _statusNotifier.dispose();
    super.dispose();
  }

  /// Marks the app as ready and fades the splash out **after** the first
  /// [MainShell] frame has been laid out. Building the shell while the splash
  /// is still fully opaque avoids the frame drop that happened when the splash
  /// fade and the shell's first build shared the same animation frames.
  void _markWarmedUp() {
    if (!mounted || _isWarmedUp) return;
    setState(() => _isWarmedUp = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Let the freshly built shell render a couple of frames first. The
      // splash keeps spinning during this short beat, so the transition does
      // not read as a frozen frame followed immediately by a fade.
      _fadeDelay?.cancel();
      _fadeDelay = Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _splashFadeController.reverse();
      });
    });
  }

  Future<void> _runWarmUp() async {
    final startTime = DateTime.now();

    try {
      // 1. Wait for server to finish starting (max 2.5s timeout)
      final serverDeadline = DateTime.now().add(
        const Duration(milliseconds: 2500),
      );
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
        _statusNotifier.value = ref
            .read(translationsProvider)
            .startupWarmUpSyncing;

        final mangaEnabled = ref.read(mangaSectionEnabledProvider);

        final warmupFutures = <Future<dynamic>>[
          ref
              .read(continueWatchingProvider.future)
              .catchError((_) => <AnimeEntry>[]),
          ref
              .read(downloadedAnimeProvider.future)
              .catchError((_) => <AnimeEntry>[]),
          ref
              .read(animeCollectionProvider.future)
              .catchError((_) => <AnimeEntry>[]),
        ];

        if (mangaEnabled) {
          warmupFutures.add(
            ref
                .read(continueReadingMangaProvider.future)
                .catchError((_) => <MangaEntry>[]),
          );
        }

        // Wait for core providers with a strict 1.8s timeout
        await Future.wait(warmupFutures).timeout(
          const Duration(milliseconds: 1800),
          onTimeout: () => [],
        );

        if (!mounted) return;

        // 3. Pre-warm AniZip 16:9 episode thumbnails for top continue watching items
        final cwEntries =
            ref.read(continueWatchingProvider).value ?? <AnimeEntry>[];
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

          // 3b. Decode the covers that will be on screen the moment the splash
          //     hands over. Without this the first shell frames start a burst of
          //     simultaneous image decodes exactly when the splash fades, which
          //     is what read as a stutter. The widths mirror the two variants
          //     `ContinueWatchingCard` uses (`memCacheWidth`), because those are
          //     part of the provider cache key.
          if (mounted && !_isInTest) {
            await StartupImageWarmer.precacheCovers(
              context,
              cwEntries.take(StartupImageWarmer.maxImages).map(
                (e) => e.coverImage,
              ),
              memCacheWidths: const [450, 600],
              budget: const Duration(milliseconds: 800),
            );
          }
        }
      }

      if (mounted) {
        _statusNotifier.value = ref
            .read(translationsProvider)
            .startupWarmUpReady;
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
        _markWarmedUp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isWarmedUp)
            const MainShell(key: ValueKey('main_shell_warmed')),

          if (_splashVisible)
            IgnorePointer(
              ignoring: _isWarmedUp,
              child: FadeTransition(
                opacity: _splashOpacity,
                child: RepaintBoundary(
                  child: _buildSplash(context, theme, l10n),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSplash(
    BuildContext context,
    ThemeData theme,
    AppTranslations l10n,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: const ValueKey('app_warmup_splash'),
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated, slowly blending colour field. No neon glows: the palette
          // is muted and overlaps itself until the colours melt together.
          _StartupAuroraBackground(
            baseColor: theme.scaffoldBackgroundColor,
            isDark: isDark,
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/logo.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(height: 26),
                Text(
                  'Aniting',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 30),
                _SmoothArcSpinner(
                  key: const ValueKey('app_warmup_spinner'),
                  size: 42,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String?>(
                  valueListenable: _statusNotifier,
                  builder: (context, status, _) {
                    final currentStatus =
                        status ?? l10n.startupWarmUpStarting;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        currentStatus,
                        key: ValueKey(currentStatus),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.78,
                          ),
                          letterSpacing: 0.1,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen animated background made of a few overlapping radial gradients.
///
/// It deliberately avoids blurs and backdrop filters: the soft gradient edges
/// already blend into each other, and repainting a single [CustomPaint] layer
/// is far cheaper than compositing several blurred widgets every frame.
class _StartupAuroraBackground extends StatefulWidget {
  final Color baseColor;
  final bool isDark;

  const _StartupAuroraBackground({
    required this.baseColor,
    required this.isDark,
  });

  @override
  State<_StartupAuroraBackground> createState() =>
      _StartupAuroraBackgroundState();
}

class _StartupAuroraBackgroundState extends State<_StartupAuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    if (_isInTest) {
      _controller.value = 0.2;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: widget.baseColor),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AuroraPainter(
                  progress: _controller,
                  isDark: widget.isDark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      widget.baseColor.withValues(alpha: 0),
                      widget.baseColor.withValues(
                        alpha: widget.isDark ? 0.56 : 0.38,
                      ),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBlob {
  final Color color;
  final double phase;
  final double speed;
  final double radius;
  final double baseX;
  final double baseY;
  final double driftX;
  final double driftY;

  const _AuroraBlob({
    required this.color,
    required this.phase,
    required this.speed,
    required this.radius,
    required this.baseX,
    required this.baseY,
    required this.driftX,
    required this.driftY,
  });
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> progress;
  final bool isDark;

  _AuroraPainter({required this.progress, required this.isDark})
    : super(repaint: progress);

  static const List<_AuroraBlob> _darkBlobs = [
    _AuroraBlob(
      color: Color(0xFF3B4D8A),
      phase: 0.0,
      speed: 0.55,
      radius: 0.72,
      baseX: 0.24,
      baseY: 0.30,
      driftX: 0.16,
      driftY: 0.12,
    ),
    _AuroraBlob(
      color: Color(0xFF2A6A6B),
      phase: 1.7,
      speed: 0.42,
      radius: 0.64,
      baseX: 0.78,
      baseY: 0.36,
      driftX: 0.13,
      driftY: 0.16,
    ),
    _AuroraBlob(
      color: Color(0xFF5E3F75),
      phase: 3.4,
      speed: 0.50,
      radius: 0.70,
      baseX: 0.52,
      baseY: 0.76,
      driftX: 0.18,
      driftY: 0.11,
    ),
    _AuroraBlob(
      color: Color(0xFF6B4D33),
      phase: 5.1,
      speed: 0.36,
      radius: 0.58,
      baseX: 0.16,
      baseY: 0.80,
      driftX: 0.12,
      driftY: 0.14,
    ),
  ];

  static const List<_AuroraBlob> _lightBlobs = [
    _AuroraBlob(
      color: Color(0xFFC3CFF7),
      phase: 0.0,
      speed: 0.55,
      radius: 0.72,
      baseX: 0.24,
      baseY: 0.30,
      driftX: 0.16,
      driftY: 0.12,
    ),
    _AuroraBlob(
      color: Color(0xFFBAE4E0),
      phase: 1.7,
      speed: 0.42,
      radius: 0.64,
      baseX: 0.78,
      baseY: 0.36,
      driftX: 0.13,
      driftY: 0.16,
    ),
    _AuroraBlob(
      color: Color(0xFFE3CDF0),
      phase: 3.4,
      speed: 0.50,
      radius: 0.70,
      baseX: 0.52,
      baseY: 0.76,
      driftX: 0.18,
      driftY: 0.11,
    ),
    _AuroraBlob(
      color: Color(0xFFF1D8C1),
      phase: 5.1,
      speed: 0.36,
      radius: 0.58,
      baseX: 0.16,
      baseY: 0.80,
      driftX: 0.12,
      driftY: 0.14,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final t = progress.value * math.pi * 2;
    final blobs = isDark ? _darkBlobs : _lightBlobs;
    final blobAlpha = isDark ? 0.58 : 0.68;

    for (final blob in blobs) {
      final angle = t * blob.speed + blob.phase;
      final center = Offset(
        size.width * (blob.baseX + blob.driftX * math.sin(angle)),
        size.height * (blob.baseY + blob.driftY * math.cos(angle * 0.92)),
      );
      final radius = size.shortestSide * blob.radius;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withValues(alpha: blobAlpha),
            blob.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return false;
  }
}

/// Minimal arc spinner whose visible arc grows and contracts while rotating.
class _SmoothArcSpinner extends StatefulWidget {
  final double size;
  final Color color;

  const _SmoothArcSpinner({super.key, required this.size, required this.color});

  @override
  State<_SmoothArcSpinner> createState() => _SmoothArcSpinnerState();
}

class _SmoothArcSpinnerState extends State<_SmoothArcSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_isInTest) {
      _controller.value = 0.35;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SmoothArcPainter(
          progress: _controller,
          color: widget.color,
        ),
      ),
    );
  }
}

class _SmoothArcPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _SmoothArcPainter({required this.progress, required this.color})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = size.center(Offset.zero);
    final strokeWidth = math.max(3.4, size.shortestSide * 0.105);
    final radius = size.shortestSide / 2 - strokeWidth / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final t = progress.value;
    final rotation = t * math.pi * 2;
    const sweep = math.pi * 1.55;

    // Soft, blurred halo (the "blur" of the Windows 11 style ring) without
    // turning the splash into a neon glow.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.0
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6);
    canvas.drawArc(rect, rotation, sweep, false, glow);

    final shader = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.35),
        color,
      ],
      stops: const [0.0, 0.22, 0.55],
      transform: GradientRotation(rotation),
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawArc(rect, rotation, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _SmoothArcPainter oldDelegate) {
    return false;
  }
}
