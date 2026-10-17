import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/i18n_provider.dart';
import '../../core/preferences/onboarding_provider.dart';
import '../../core/preferences/section_visibility_provider.dart';
import '../../data/models/extension_item.dart';
import '../providers/app_providers.dart';
import '../widgets/anilist_auth_sheet.dart';
import '../widgets/welcome/welcome_step_content_preferences.dart';
import '../widgets/welcome/welcome_step_debrid.dart';
import '../widgets/welcome/welcome_step_downloads.dart';
import '../widgets/welcome/welcome_step_extensions.dart';
import '../widgets/welcome/welcome_step_language.dart';
import '../widgets/welcome/welcome_step_sections.dart';
import '../widgets/welcome/welcome_step_theme.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  final bool isDevPreview;

  const WelcomeScreen({
    super.key,
    this.isDevPreview = false,
  });

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Extensions step state
  List<ExtensionItem> _marketplaceExtensions = [];
  bool _isLoadingExtensions = true;
  final Set<String> _selectedExtensionIds = {};
  final Set<String> _installingExtensionIds = {};
  final Set<String> _installedExtensionIds = {};

  static const List<String> _esRecommendedIds = [
    // Streaming
    'aniting-universal',
    'animeav1',
    'jkanime',
    // Torrents
    'animetosho-new',
    'nekobt',
    // Manga
    'leercapitulo',
    'capibaratraductordev',
    'manhwaweb',
    'mangadex',
  ];

  static const List<String> _enRecommendedIds = [
    // Streaming
    'aniting-universal',
    'hianime',
    'aq-animepahe-beta',
    'animeav1',
    // Torrents
    'SubsPlease-Provider',
    'animetosho-new',
    'nekobt',
    // Manga
    'asurascans',
    'mangadex',
    'mangafire',
  ];

  // Background Image Animated Carousel & Continuous Ken Burns Camera Motion
  static const List<String> _backgroundImages = [
    'https://image.tmdb.org/t/p/original/kT1ZkLmG9oNUz2Z10PqKCh8CwLI.jpg', // Frieren
    'https://image.tmdb.org/t/p/original/4502U4n9cfgw33v0xTQMZhTDS6p.jpg', // Shingeki no Kyojin / Attack on Titan
  ];
  int _currentBgIndex = 0;
  Timer? _bgTimer;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

    _loadExtensions();
    _startBgTimer();
  }

  void _startBgTimer() {
    _bgTimer = Timer.periodic(const Duration(seconds: 9), (timer) {
      if (mounted) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _backgroundImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    _bgTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExtensions() async {
    try {
      final repo = ref.read(repositoryProvider);
      final list = await repo.getMarketplaceExtensions(
        'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/marketplace.json',
      );
      final installed = await repo.getAllExtensions();
      if (mounted) {
        setState(() {
          _marketplaceExtensions = list.where((ext) => ext.type.toLowerCase() != 'plugin').toList();
          _installedExtensionIds.addAll(installed.map((e) => e.id));
          _updateSelectedRecommendations(ref.read(appLanguageProvider));
          _isLoadingExtensions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingExtensions = false;
        });
      }
    }
  }

  void _updateSelectedRecommendations(AppLanguage lang) {
    final recs = _getRecommendedExtensions(lang);
    for (final ext in recs) {
      if (!_installedExtensionIds.contains(ext.id)) {
        _selectedExtensionIds.add(ext.id);
      }
    }
  }

  List<ExtensionItem> _getRecommendedExtensions(AppLanguage lang) {
    final targetIds = lang == AppLanguage.es ? _esRecommendedIds : _enRecommendedIds;
    final recommended = <ExtensionItem>[];
    for (final id in targetIds) {
      final match = _marketplaceExtensions.cast<ExtensionItem?>().firstWhere(
        (ext) =>
            ext != null &&
            (ext.id.toLowerCase() == id.toLowerCase() || ext.id.toLowerCase().contains(id.toLowerCase())),
        orElse: () => null,
      );
      if (match != null && !recommended.contains(match)) {
        recommended.add(match);
      }
    }
    if (recommended.isEmpty && _marketplaceExtensions.isNotEmpty) {
      recommended.addAll(_marketplaceExtensions.where((e) => e.type != 'plugin').take(7));
    }
    return recommended;
  }

  void _toggleExtensionSelection(ExtensionItem ext) {
    setState(() {
      if (_selectedExtensionIds.contains(ext.id)) {
        _selectedExtensionIds.remove(ext.id);
      } else {
        _selectedExtensionIds.add(ext.id);
      }
    });
  }

  Future<void> _installSingleExtension(ExtensionItem ext) async {
    setState(() => _installingExtensionIds.add(ext.id));
    try {
      final repo = ref.read(repositoryProvider);
      final ok = await repo.installExtension(ext.manifestUri);
      if (ok && mounted) {
        setState(() {
          _installingExtensionIds.remove(ext.id);
          _installedExtensionIds.add(ext.id);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _installingExtensionIds.remove(ext.id));
      }
    }
  }

  Future<void> _installSelectedExtensions() async {
    final toInstall = _marketplaceExtensions.where((e) => _selectedExtensionIds.contains(e.id)).toList();
    if (toInstall.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    for (final ext in toInstall) {
      if (_installedExtensionIds.contains(ext.id)) continue;
      if (mounted) {
        setState(() => _installingExtensionIds.add(ext.id));
      }
      try {
        final ok = await repo.installExtension(ext.manifestUri);
        if (ok && mounted) {
          setState(() {
            _installingExtensionIds.remove(ext.id);
            _installedExtensionIds.add(ext.id);
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _installingExtensionIds.remove(ext.id));
        }
      }
    }
  }

  void _nextPage(int totalSteps) {
    if (_currentPage < totalSteps - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (widget.isDevPreview) {
      Navigator.of(context).pop();
      final l10n = ref.read(translationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await ref.read(onboardingProvider.notifier).completeOnboarding();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    final animeEnabled = ref.watch(animeSectionEnabledProvider);

    // Total steps without redundant final AniList step
    final steps = <Widget>[
      WelcomeStepLanguage(
        onLanguageChanged: _updateSelectedRecommendations,
      ),
      const WelcomeStepTheme(),
      const WelcomeStepSections(),
      if (animeEnabled) const WelcomeStepContentPreferences(),
      const WelcomeStepDebrid(),
      const WelcomeStepDownloads(),
      WelcomeStepExtensions(
        marketplaceExtensions: _marketplaceExtensions,
        isLoading: _isLoadingExtensions,
        selectedExtensionIds: _selectedExtensionIds,
        installedExtensionIds: _installedExtensionIds,
        installingExtensionIds: _installingExtensionIds,
        onToggleSelect: _toggleExtensionSelection,
        onInstallSelected: _installSelectedExtensions,
        onInstallSingle: _installSingleExtension,
        getRecommendedExtensions: _getRecommendedExtensions,
      ),
    ];

    final currentTotalSteps = steps.length;
    final safeCurrentPage = _currentPage.clamp(0, currentTotalSteps - 1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── ANIMATED BACKGROUND IMAGES (Cinematic Ken Burns Slow Motion & Cross-fade) ───
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _motionController,
              builder: (context, child) {
                // Subtle camera drift: pan +/- 20px horizontally, +/- 12px vertically, scale 1.05 to 1.15
                final t = _motionController.value;
                final scale = 1.08 + (0.07 * t);
                final dx = -18.0 + (36.0 * t);
                final dy = -10.0 + (20.0 * t);

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1400),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: Opacity(
                  key: ValueKey<String>(_backgroundImages[_currentBgIndex]),
                  opacity: isDark ? 0.65 : 0.40,
                  child: Image.network(
                    _backgroundImages[_currentBgIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),

          // Gentle ambient gradient overlay: kept light so Liquid Glass is crystal clear and vivid
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.15),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.35),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // ─── FOREGROUND CONTENT ───
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  children: [
                    // Top Bar: Indicator Dots in center, and Glass X button on right
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 44, height: 44),
                          const Spacer(),
                          // ─── INDICATOR DOTS AT TOP ───
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(currentTotalSteps, (idx) {
                              final isActive = idx == safeCurrentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                height: 5,
                                width: isActive ? 18 : 5,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : Colors.black.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const Spacer(),
                          // ─── GLASS 'X' CLOSE / SKIP BUTTON ───
                          GlassCard(
                            borderRadius: BorderRadius.circular(20),
                            padding: EdgeInsets.zero,
                            child: IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              tooltip: l10n.welcomeSkipAll,
                              onPressed: _finishOnboarding,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Stepped Content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        children: steps,
                      ),
                    ),

                    // ─── UNIFIED LIQUID GLASS BOTTOM NAVIGATION BAR ───
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Row(
                        children: [
                          // Left Section: Smooth morphing between AniList (expanded on Step 0) and Back Button (compact on Steps > 0)
                          Expanded(
                            flex: safeCurrentPage == 0 ? 1 : 0,
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.centerLeft,
                              child: safeCurrentPage == 0
                                  ? Consumer(
                                      builder: (context, ref, _) {
                                        final serverState = ref.watch(serverNotifierProvider);
                                        final status = serverState.status;
                                        final isLoggedIn = status?.isLoggedIn == true;

                                        return GlassButton(
                                          onPressed: () => AnilistAuthSheet.show(context),
                                          borderRadius: BorderRadius.circular(22),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (isLoggedIn) ...[
                                                CircleAvatar(
                                                  radius: 13,
                                                  backgroundImage: status?.avatarUrl != null
                                                      ? NetworkImage(status!.avatarUrl!)
                                                      : null,
                                                  child: status?.avatarUrl == null
                                                      ? const Icon(Icons.person, size: 14)
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    status?.username ?? 'AniList',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Color(0xFF10B981),
                                                  size: 17,
                                                ),
                                              ] else ...[
                                                Image.asset(
                                                  'assets/icons/AniList_logo.png',
                                                  width: 22,
                                                  height: 22,
                                                  fit: BoxFit.contain,
                                                ),
                                                const SizedBox(width: 10),
                                                const Text(
                                                  'AniList',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  : GlassButton(
                                      onPressed: _previousPage,
                                      borderRadius: BorderRadius.circular(22),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                      child: Icon(
                                        LucideIcons.arrowLeft,
                                        color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                                        size: 22,
                                      ),
                                    ),
                            ),
                          ),
                          if (safeCurrentPage > 0) const Spacer(),

                          const SizedBox(width: 12),

                          // Siguiente / Finalizar Arrow Button on the RIGHT (Liquid Glass Button)
                          GlassButton(
                            onPressed: () => _nextPage(currentTotalSteps),
                            borderRadius: BorderRadius.circular(22),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Icon(
                              safeCurrentPage == currentTotalSteps - 1
                                  ? LucideIcons.check
                                  : LucideIcons.arrowRight,
                              color: isDark ? Colors.white : theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
