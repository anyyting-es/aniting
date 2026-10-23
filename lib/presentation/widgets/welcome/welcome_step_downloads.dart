import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/preferences/download_preferences_provider.dart';
import '../../../core/preferences/section_visibility_provider.dart';
import '../../../core/storage/app_storage_paths.dart';

class WelcomeStepDownloads extends ConsumerStatefulWidget {
  const WelcomeStepDownloads({super.key});

  @override
  ConsumerState<WelcomeStepDownloads> createState() =>
      _WelcomeStepDownloadsState();
}

class _WelcomeStepDownloadsState extends ConsumerState<WelcomeStepDownloads> {
  final TextEditingController _baseController = TextEditingController();
  final TextEditingController _animeController = TextEditingController();
  final TextEditingController _mangaController = TextEditingController();
  final TextEditingController _showsController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _baseController.dispose();
    _animeController.dispose();
    _mangaController.dispose();
    _showsController.dispose();
    super.dispose();
  }

  void _syncControllers(DownloadPreferencesState prefs) {
    if (_baseController.text != prefs.resolvedBasePath) {
      _baseController.text = prefs.resolvedBasePath;
    }
    if (_animeController.text != prefs.resolvedAnimePath) {
      _animeController.text = prefs.resolvedAnimePath;
    }
    if (_mangaController.text != prefs.resolvedMangaPath) {
      _mangaController.text = prefs.resolvedMangaPath;
    }
    if (_showsController.text != prefs.resolvedShowsPath) {
      _showsController.text = prefs.resolvedShowsPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final downloadPrefs = ref.watch(downloadPreferencesProvider);
    final downloadNotifier = ref.read(downloadPreferencesProvider.notifier);

    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);
    final showsEnabled = ref.watch(showsSectionEnabledProvider);

    final int activeCount = (animeEnabled ? 1 : 0) +
        (mangaEnabled ? 1 : 0) +
        (showsEnabled ? 1 : 0);

    if (!_initialized && !downloadPrefs.isLoading) {
      _syncControllers(downloadPrefs);
      _initialized = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Icon + Title only (clean, matching previous steps) ───
          Row(
            children: [
              GlassCard(
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  LucideIcons.hardDrive,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.welcomeStepDownloads,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Unified Storage Toggle (only when more than 1 module is active) ───
          if (activeCount > 1) ...[
            GlassCard(
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.welcomeDownloadsUnifiedTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.welcomeDownloadsUnifiedDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    M3ESwitch(
                      value: downloadPrefs.isUnified,
                      onChanged: (val) {
                        downloadNotifier.setIsUnified(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Path Selectors (Unified single vs Separate multiple) ───
          if (activeCount <= 1)
            _buildUnifiedView(
              context,
              theme,
              l10n,
              downloadPrefs,
              downloadNotifier,
              activeCount,
              animeEnabled,
              mangaEnabled,
              showsEnabled,
            )
          else
            AnimatedCrossFade(
              firstChild: SizedBox(
                width: double.infinity,
                child: _buildUnifiedView(
                  context,
                  theme,
                  l10n,
                  downloadPrefs,
                  downloadNotifier,
                  activeCount,
                  animeEnabled,
                  mangaEnabled,
                  showsEnabled,
                ),
              ),
              secondChild: SizedBox(
                width: double.infinity,
                child: _buildSeparateView(
                  context,
                  theme,
                  l10n,
                  downloadPrefs,
                  downloadNotifier,
                  animeEnabled,
                  mangaEnabled,
                  showsEnabled,
                ),
              ),
              crossFadeState: downloadPrefs.isUnified
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 340),
              reverseDuration: const Duration(milliseconds: 300),
              firstCurve: Curves.easeInOutCubic,
              secondCurve: Curves.easeInOutCubic,
              sizeCurve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
            ),
        ],
      ),
    );
  }

  /// Vista unificada o de módulo único
  Widget _buildUnifiedView(
    BuildContext context,
    ThemeData theme,
    AppTranslations l10n,
    DownloadPreferencesState downloadPrefs,
    DownloadPreferencesNotifier downloadNotifier,
    int activeCount,
    bool animeEnabled,
    bool mangaEnabled,
    bool showsEnabled,
  ) {
    // Si solo hay un módulo activo, adaptamos el título e ícono
    final String cardTitle;
    final IconData cardIcon;

    if (activeCount == 1) {
      if (animeEnabled) {
        cardTitle = l10n.welcomeDownloadsAnimeFolder;
        cardIcon = LucideIcons.film;
      } else if (mangaEnabled) {
        cardTitle = l10n.welcomeDownloadsMangaFolder;
        cardIcon = LucideIcons.bookOpen;
      } else {
        cardTitle = l10n.welcomeDownloadsShowsFolder;
        cardIcon = LucideIcons.tv;
      }
    } else {
      cardTitle = l10n.welcomeDownloadsBaseFolder;
      cardIcon = LucideIcons.folder;
    }

    return KeyedSubtree(
      key: const ValueKey('unified_view'),
      child: _DownloadFolderCard(
        icon: cardIcon,
        title: cardTitle,
        controller: _baseController,
        onChanged: (val) {
          downloadNotifier.setCustomBasePath(val);
        },
        onReset: () async {
          await downloadNotifier.resetToDefault();
          final def = await AppStoragePaths.getDefaultDownloadsBasePath();
          setState(() {
            _baseController.text = def;
            _animeController.text = '$def/Anime';
            _mangaController.text = '$def/Manga';
            _showsController.text = '$def/Shows';
          });
        },
        onOpen: () {
          final p = _baseController.text.trim();
          if (p.isNotEmpty) {
            AppStoragePaths.openDirectoryInFileManager(p);
          }
        },
        resetLabel: l10n.welcomeDownloadsDefault,
        openTooltip: l10n.welcomeDownloadsOpenFolder,
        extraFooter: activeCount > 1
            ? [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      l10n.welcomeDownloadsSubfoldersHint,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (animeEnabled)
                            _buildSubfolderChip(theme, 'Anime', LucideIcons.film),
                          if (mangaEnabled)
                            _buildSubfolderChip(theme, 'Manga', LucideIcons.bookOpen),
                          if (showsEnabled)
                            _buildSubfolderChip(theme, 'Shows', LucideIcons.tv),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),
    );
  }

  /// Vista separada: una tarjeta para cada módulo activo
  Widget _buildSeparateView(
    BuildContext context,
    ThemeData theme,
    AppTranslations l10n,
    DownloadPreferencesState downloadPrefs,
    DownloadPreferencesNotifier downloadNotifier,
    bool animeEnabled,
    bool mangaEnabled,
    bool showsEnabled,
  ) {
    return KeyedSubtree(
      key: const ValueKey('separate_view'),
      child: Column(
        children: [
          if (animeEnabled) ...[
            _DownloadFolderCard(
              icon: LucideIcons.film,
              title: l10n.welcomeDownloadsAnimeFolder,
              controller: _animeController,
              onChanged: (val) {
                downloadNotifier.setCustomAnimePath(val);
              },
              onReset: () async {
                await downloadNotifier.resetAnimePath();
                setState(() {
                  _animeController.text = downloadPrefs.resolvedBasePath.isNotEmpty
                      ? '${downloadPrefs.resolvedBasePath}/Anime'
                      : '';
                });
              },
              onOpen: () {
                final p = _animeController.text.trim();
                if (p.isNotEmpty) {
                  AppStoragePaths.openDirectoryInFileManager(p);
                }
              },
              resetLabel: l10n.welcomeDownloadsDefault,
              openTooltip: l10n.welcomeDownloadsOpenFolder,
            ),
            const SizedBox(height: 14),
          ],
          if (mangaEnabled) ...[
            _DownloadFolderCard(
              icon: LucideIcons.bookOpen,
              title: l10n.welcomeDownloadsMangaFolder,
              controller: _mangaController,
              onChanged: (val) {
                downloadNotifier.setCustomMangaPath(val);
              },
              onReset: () async {
                await downloadNotifier.resetMangaPath();
                setState(() {
                  _mangaController.text = downloadPrefs.resolvedBasePath.isNotEmpty
                      ? '${downloadPrefs.resolvedBasePath}/Manga'
                      : '';
                });
              },
              onOpen: () {
                final p = _mangaController.text.trim();
                if (p.isNotEmpty) {
                  AppStoragePaths.openDirectoryInFileManager(p);
                }
              },
              resetLabel: l10n.welcomeDownloadsDefault,
              openTooltip: l10n.welcomeDownloadsOpenFolder,
            ),
            const SizedBox(height: 14),
          ],
          if (showsEnabled) ...[
            _DownloadFolderCard(
              icon: LucideIcons.tv,
              title: l10n.welcomeDownloadsShowsFolder,
              controller: _showsController,
              onChanged: (val) {
                downloadNotifier.setCustomShowsPath(val);
              },
              onReset: () async {
                await downloadNotifier.resetShowsPath();
                setState(() {
                  _showsController.text = downloadPrefs.resolvedBasePath.isNotEmpty
                      ? '${downloadPrefs.resolvedBasePath}/Shows'
                      : '';
                });
              },
              onOpen: () {
                final p = _showsController.text.trim();
                if (p.isNotEmpty) {
                  AppStoragePaths.openDirectoryInFileManager(p);
                }
              },
              resetLabel: l10n.welcomeDownloadsDefault,
              openTooltip: l10n.welcomeDownloadsOpenFolder,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubfolderChip(ThemeData theme, String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '/$name',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadFolderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;
  final VoidCallback onOpen;
  final String resetLabel;
  final String openTooltip;
  final List<Widget>? extraFooter;

  const _DownloadFolderCard({
    required this.icon,
    required this.title,
    required this.controller,
    required this.onChanged,
    required this.onReset,
    required this.onOpen,
    required this.resetLabel,
    required this.openTooltip,
    this.extraFooter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. /storage/emulated/0/Documents/Anime/aniting',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            ...?extraFooter,
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: Text(
                    resetLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: openTooltip,
                  onPressed: onOpen,
                  icon: const Icon(LucideIcons.folderOpen, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
