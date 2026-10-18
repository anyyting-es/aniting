import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/extension_item.dart';
import '../../providers/app_providers.dart';
import '../toast/app_toast.dart';

enum _SourceMode { repository, individual }

class WelcomeStepExtensions extends ConsumerStatefulWidget {
  final List<ExtensionItem> marketplaceExtensions;
  final bool isLoading;
  final Set<String> selectedExtensionIds;
  final Set<String> installedExtensionIds;
  final Set<String> installingExtensionIds;
  final void Function(ExtensionItem ext) onToggleSelect;
  final Future<void> Function() onInstallSelected;
  final Future<void> Function(ExtensionItem ext) onInstallSingle;
  final List<ExtensionItem> Function(AppLanguage lang) getRecommendedExtensions;

  const WelcomeStepExtensions({
    super.key,
    required this.marketplaceExtensions,
    required this.isLoading,
    required this.selectedExtensionIds,
    required this.installedExtensionIds,
    required this.installingExtensionIds,
    required this.onToggleSelect,
    required this.onInstallSelected,
    required this.onInstallSingle,
    required this.getRecommendedExtensions,
  });

  @override
  ConsumerState<WelcomeStepExtensions> createState() =>
      _WelcomeStepExtensionsState();
}

class _WelcomeStepExtensionsState
    extends ConsumerState<WelcomeStepExtensions> {
  static const String _defaultRepoUrl =
      'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/marketplace.json';

  _SourceMode _mode = _SourceMode.repository;

  // Repositorio
  final TextEditingController _repoController =
      TextEditingController(text: _defaultRepoUrl);
  List<ExtensionItem> _repoExtensions = [];
  bool _isLoadingRepo = false;
  String? _repoError;

  // Filtros
  late String _selectedLang; // 'es', 'en', 'all'
  int _extensionsFilterIndex = 0; // 0: Todas, 1: Torrents, 2: Streaming, 3: Manga

  // Extensión individual
  final TextEditingController _manifestController = TextEditingController();
  ExtensionItem? _individualExtension;
  bool _isLoadingIndividual = false;
  bool _isInstallingIndividual = false;
  String? _individualError;

  @override
  void initState() {
    super.initState();
    _repoExtensions = widget.marketplaceExtensions;

    // Selector de idioma: por defecto toma el idioma elegido en el paso 1
    final initialLang = ref.read(appLanguageProvider);
    _selectedLang = initialLang == AppLanguage.es ? 'es' : 'en';

    _initSavedRepoUrl();
  }

  @override
  void didUpdateWidget(WelcomeStepExtensions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marketplaceExtensions != widget.marketplaceExtensions &&
        _repoExtensions.isEmpty) {
      setState(() {
        _repoExtensions = widget.marketplaceExtensions;
      });
    }
  }

  @override
  void dispose() {
    _repoController.dispose();
    _manifestController.dispose();
    super.dispose();
  }

  Future<void> _initSavedRepoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('seanime_marketplace_repo_url');
      if (saved != null && saved.trim().isNotEmpty) {
        _repoController.text = saved.trim();
      }
    } catch (_) {}
  }

  Future<void> _loadRepo() async {
    final url = _repoController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoadingRepo = true;
      _repoError = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final list = await repo.getMarketplaceExtensions(url, forceRefresh: true);
      final filtered =
          list.where((e) => e.type.toLowerCase() != 'plugin').toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('seanime_marketplace_repo_url', url);

      if (mounted) {
        setState(() {
          _repoExtensions = filtered;
          _isLoadingRepo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _repoError = e.toString();
          _isLoadingRepo = false;
        });
      }
    }
  }

  Future<void> _fetchIndividualManifest() async {
    final url = _manifestController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoadingIndividual = true;
      _individualError = null;
      _individualExtension = null;
    });

    try {
      final dio = Dio();
      final res = await dio.get(url);
      Map<String, dynamic> data;
      if (res.data is Map<String, dynamic>) {
        data = res.data as Map<String, dynamic>;
      } else if (res.data is String) {
        data = jsonDecode(res.data as String) as Map<String, dynamic>;
      } else {
        throw 'Formato no compatible';
      }

      if (data['manifestUri'] == null ||
          (data['manifestUri'] as String).isEmpty) {
        data['manifestUri'] = url;
      }

      final ext = ExtensionItem.fromJson(data);
      if (mounted) {
        setState(() {
          _individualExtension = ext;
          _isLoadingIndividual = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _individualError = e.toString();
          _isLoadingIndividual = false;
        });
      }
    }
  }

  Future<void> _installSingle(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);
    await widget.onInstallSingle(ext);

    if (mounted) {
      if (widget.installedExtensionIds.contains(ext.id)) {
        showGlassToast(
          context,
          message: '${ext.name} ${l10n.extensionInstalledSuccessfully}',
          isSuccess: true,
          icon: LucideIcons.checkCircle2,
        );
      } else {
        showGlassToast(
          context,
          message: '${ext.name}: ${l10n.extensionInstallFailed}',
          isError: true,
          icon: LucideIcons.alertCircle,
        );
      }
    }
  }

  Future<void> _installIndividual(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);
    setState(() => _isInstallingIndividual = true);

    try {
      final repo = ref.read(repositoryProvider);
      final ok = await repo.installExtension(ext.manifestUri);
      if (mounted) {
        setState(() {
          _isInstallingIndividual = false;
          if (ok) {
            widget.installedExtensionIds.add(ext.id);
          }
        });
        showGlassToast(
          context,
          message: ok
              ? '${ext.name} ${l10n.extensionInstalledSuccessfully}'
              : '${ext.name}: ${l10n.extensionInstallFailed}',
          isSuccess: ok,
          isError: !ok,
          icon: ok ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isInstallingIndividual = false);
        showGlassToast(
          context,
          message: '${ext.name}: ${l10n.extensionInstallFailed}',
          isError: true,
          icon: LucideIcons.alertCircle,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Icon + Title only (clean, matching all steps) ───
          Row(
            children: [
              GlassCard(
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  LucideIcons.blocks,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                l10n.welcomeStepExtensions,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ─── Selector Lado a Lado compacto (Repositorio | Extensión Individual) ───
          Row(
            children: [
              Expanded(
                child: _CompactModeButton(
                  icon: LucideIcons.boxes,
                  title: l10n.welcomeSourceRepository,
                  isSelected: _mode == _SourceMode.repository,
                  onTap: () => setState(() => _mode = _SourceMode.repository),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactModeButton(
                  icon: LucideIcons.puzzle,
                  title: l10n.welcomeSourceIndividual,
                  isSelected: _mode == _SourceMode.individual,
                  onTap: () => setState(() => _mode = _SourceMode.individual),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── Input Bar según modo seleccionado ───
          _buildInputBar(context, theme, l10n),
          const SizedBox(height: 14),

          // ─── Contenido dinámico (Repositorio vs Extensión Individual) ───
          AnimatedCrossFade(
            firstChild: SizedBox(
              width: double.infinity,
              child: _buildRepositoryContent(context, theme, colors, l10n),
            ),
            secondChild: SizedBox(
              width: double.infinity,
              child: _buildIndividualContent(context, theme, colors, l10n),
            ),
            crossFadeState: _mode == _SourceMode.repository
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
            reverseDuration: const Duration(milliseconds: 260),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            sizeCurve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INPUT BAR COMPACTO
  // ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(BuildContext context, ThemeData theme, dynamic l10n) {
    if (_mode == _SourceMode.repository) {
      return GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(LucideIcons.globe, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _repoController,
                style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: _defaultRepoUrl,
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (_repoController.text.trim() != _defaultRepoUrl) ...[
              IconButton(
                icon: const Icon(LucideIcons.rotateCcw, size: 15),
                tooltip: l10n.restoreDefaultRepo,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _repoController.text = _defaultRepoUrl;
                  _loadRepo();
                },
              ),
            ],
            IconButton.filledTonal(
              tooltip: l10n.saveAndLoad,
              visualDensity: VisualDensity.compact,
              onPressed: _isLoadingRepo ? null : _loadRepo,
              icon: _isLoadingRepo
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 15),
            ),
          ],
        ),
      );
    } else {
      return GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(LucideIcons.link, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _manifestController,
                style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'https://.../manifest.json',
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: l10n.installManifest,
              visualDensity: VisualDensity.compact,
              onPressed:
                  _isLoadingIndividual ? null : _fetchIndividualManifest,
              icon: _isLoadingIndividual
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.search, size: 15),
            ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. VISTA DE REPOSITORIO (Contenedor único compartido, sin checkboxes)
  // ─────────────────────────────────────────────────────────────
  Widget _buildRepositoryContent(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    dynamic l10n,
  ) {
    // 1. Filtrar por idioma
    List<ExtensionItem> langFiltered = _repoExtensions;
    if (_selectedLang != 'all') {
      langFiltered = _repoExtensions.where((e) {
        final elang = e.lang.toLowerCase();
        return elang == _selectedLang || elang == 'multi' || elang == 'all';
      }).toList();
    }

    // 2. Filtrar por tipo
    final List<ExtensionItem> finalFiltered;
    if (_extensionsFilterIndex == 1) {
      finalFiltered = langFiltered
          .where((e) => e.type == 'anime-torrent-provider')
          .toList();
    } else if (_extensionsFilterIndex == 2) {
      finalFiltered =
          langFiltered.where((e) => e.type == 'onlinestream-provider').toList();
    } else if (_extensionsFilterIndex == 3) {
      finalFiltered =
          langFiltered.where((e) => e.type == 'manga-provider').toList();
    } else {
      finalFiltered = langFiltered;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── FILA DE FILTROS: IDIOMA & TIPO ───
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Idioma Selector
              _buildFilterChip(
                label: 'Español',
                icon: LucideIcons.languages,
                isSelected: _selectedLang == 'es',
                theme: theme,
                onTap: () => setState(() => _selectedLang = 'es'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'English',
                icon: LucideIcons.languages,
                isSelected: _selectedLang == 'en',
                theme: theme,
                onTap: () => setState(() => _selectedLang = 'en'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: l10n.allLanguages,
                isSelected: _selectedLang == 'all',
                theme: theme,
                onTap: () => setState(() => _selectedLang = 'all'),
              ),

              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: theme.dividerColor),
              const SizedBox(width: 10),

              // Categorías
              _buildFilterChip(
                label: l10n.allRecommended,
                isSelected: _extensionsFilterIndex == 0,
                theme: theme,
                onTap: () => setState(() => _extensionsFilterIndex = 0),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Torrents',
                isSelected: _extensionsFilterIndex == 1,
                theme: theme,
                onTap: () => setState(() => _extensionsFilterIndex = 1),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Streaming',
                isSelected: _extensionsFilterIndex == 2,
                theme: theme,
                onTap: () => setState(() => _extensionsFilterIndex = 2),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Manga',
                isSelected: _extensionsFilterIndex == 3,
                theme: theme,
                onTap: () => setState(() => _extensionsFilterIndex = 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── CONTENEDOR COMPARTIDO ÚNICO CON TODAS LAS FUENTES ───
        if (finalFiltered.isNotEmpty)
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: finalFiltered.length,
              separatorBuilder: (_, _) => Divider(
                height: 16,
                thickness: 0.8,
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, idx) {
                final ext = finalFiltered[idx];
                final isInstalled =
                    widget.installedExtensionIds.contains(ext.id);
                final isInstalling =
                    widget.installingExtensionIds.contains(ext.id);

                return _ExtensionCleanRow(
                  ext: ext,
                  isInstalled: isInstalled,
                  isInstalling: isInstalling,
                  theme: theme,
                  onInstall: () => _installSingle(ext),
                );
              },
            ),
          )
        else if (_isLoadingRepo || widget.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _repoError ?? l10n.welcomeExtensionsEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. VISTA DE EXTENSIÓN INDIVIDUAL
  // ─────────────────────────────────────────────────────────────
  Widget _buildIndividualContent(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    dynamic l10n,
  ) {
    if (_isLoadingIndividual) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_individualExtension != null) {
      final ext = _individualExtension!;
      final isInstalled = widget.installedExtensionIds.contains(ext.id);

      return GlassCard(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ext.typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ext.icon != null && ext.icon!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ext.icon!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Icon(ext.typeIcon,
                              color: ext.typeColor, size: 22),
                        )
                      : Icon(ext.typeIcon, color: ext.typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ext.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ext.typeColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ext.typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ext.typeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${ext.version} • ${ext.author}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (ext.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                ext.description,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: isInstalled
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.checkCircle2,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Instalada',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade400,
                          ),
                        ),
                      ],
                    )
                  : FilledButton.icon(
                      onPressed: _isInstallingIndividual
                          ? null
                          : () => _installIndividual(ext),
                      icon: _isInstallingIndividual
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.download, size: 16),
                      label: Text(l10n.installManifest),
                    ),
            ),
          ],
        ),
      );
    }

    if (_individualError != null) {
      return GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.alertCircle,
                color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _individualError!,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.welcomeSourceIndividualEmptyHint,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactModeButton({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.7)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: GlassCard(
          borderRadius: BorderRadius.circular(13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          finish: isSelected
              ? (isDark ? GlassFinish.regularDark : GlassFinish.regularLight)
                  .copyWith(
                  tint: theme.colorScheme.primary.withValues(alpha: 0.14),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionCleanRow extends StatelessWidget {
  final ExtensionItem ext;
  final bool isInstalled;
  final bool isInstalling;
  final ThemeData theme;
  final VoidCallback onInstall;

  const _ExtensionCleanRow({
    required this.ext,
    required this.isInstalled,
    required this.isInstalling,
    required this.theme,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ext.typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ext.icon != null && ext.icon!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: ext.icon!,
                    fit: BoxFit.cover,
                    memCacheWidth: 72,
                    memCacheHeight: 72,
                    fadeInDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) =>
                        Icon(ext.typeIcon, color: ext.typeColor, size: 18),
                  )
                : Icon(ext.typeIcon, color: ext.typeColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ext.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: ext.typeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ext.typeLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: ext.typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ext.description.isNotEmpty
                      ? ext.description
                      : 'v${ext.version} • ${ext.author}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isInstalling)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isInstalled)
            const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 20)
          else
            IconButton.filledTonal(
              icon: const Icon(LucideIcons.download, size: 16),
              tooltip: 'Instalar',
              visualDensity: VisualDensity.compact,
              onPressed: onInstall,
            ),
        ],
      ),
    );
  }
}
