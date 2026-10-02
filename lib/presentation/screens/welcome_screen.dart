import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n_provider.dart';
import '../../core/icons/app_icons.dart';
import '../../core/preferences/onboarding_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../data/models/extension_item.dart';
import '../providers/app_providers.dart';
import '../widgets/welcome/welcome_step_anilist.dart';
import '../widgets/welcome/welcome_step_content_preferences.dart';
import '../widgets/welcome/welcome_step_extensions.dart';
import '../widgets/welcome/welcome_step_language.dart';
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

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalSteps = 5;

  // Extensions step state
  List<ExtensionItem> _marketplaceExtensions = [];
  bool _isLoadingExtensions = true;
  final Set<String> _selectedExtensionIds = {};
  final Set<String> _installingExtensionIds = {};
  final Set<String> _installedExtensionIds = {};

  static const List<String> _esRecommendedIds = [
    // Torrents
    'animetosho-new',
    'nekobt',
    // Streaming
    'animeav1',
    'jkanime',
    // Manga
    'leercapitulo',
    'capibaratraductordev',
    'manhwaweb',
  ];

  static const List<String> _enRecommendedIds = [
    // Torrents
    'SubsPlease-Provider',
    'animetosho-new',
    'nekobt',
    // Streaming
    'hianime',
    'aq-animepahe-beta',
    'animeav1',
    // Manga
    'asurascans',
    'mangadex',
    'mangafire',
  ];

  @override
  void initState() {
    super.initState();
    _loadExtensions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExtensions() async {
    try {
      final repo = ref.read(repositoryProvider);
      final list = await repo.getMarketplaceExtensions(
        'https://raw.githubusercontent.com/Bas1874/Seanime-Marketplace/refs/heads/main/Marketplace/Main.json',
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

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
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
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // Top Bar: Brand, Step indicator and Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (widget.isDevPreview)
                        IconButton(
                          icon: Icon(AppIcons.close(iconPack)),
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      else
                        const SizedBox(width: 44),
                      const Spacer(),
                      // Step pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentPage + 1} / $_totalSteps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l10n.welcomeSkipAll),
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
                    children: [
                      WelcomeStepLanguage(
                        onLanguageChanged: _updateSelectedRecommendations,
                      ),
                      const WelcomeStepTheme(),
                      const WelcomeStepContentPreferences(),
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
                      WelcomeStepAniList(
                        onFinish: _finishOnboarding,
                      ),
                    ],
                  ),
                ),

                // Bottom Navigation Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        IconButton.filledTonal(
                          onPressed: _previousPage,
                          icon: Icon(AppIcons.arrowLeft(iconPack), size: 20),
                          tooltip: l10n.welcomeBack,
                        )
                      else
                        const SizedBox(width: 44, height: 44),
                      const Spacer(),
                      // Indicator dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_totalSteps, (idx) {
                          final isActive = idx == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 6,
                            width: isActive ? 20 : 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: _nextPage,
                        icon: Icon(
                          _currentPage == _totalSteps - 1
                              ? AppIcons.check(iconPack)
                              : AppIcons.arrowRight(iconPack),
                          size: 20,
                        ),
                        tooltip: _currentPage == _totalSteps - 1 ? l10n.welcomeFinish : l10n.welcomeNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
