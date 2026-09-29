import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/widgets/extensions/marketplace_extension_card.dart';

class MarketplaceTabView extends ConsumerStatefulWidget {
  final bool isLoading;
  final String? error;
  final List<ExtensionItem> extensions;
  final Set<String> installedIds;
  final String? installingExtensionId;
  final String currentRepoUrl;
  final Future<void> Function({bool forceRefresh}) onRefresh;
  final VoidCallback onChangeRepo;
  final void Function(ExtensionItem) onInstall;

  const MarketplaceTabView({
    super.key,
    required this.isLoading,
    this.error,
    required this.extensions,
    required this.installedIds,
    this.installingExtensionId,
    required this.currentRepoUrl,
    required this.onRefresh,
    required this.onChangeRepo,
    required this.onInstall,
  });

  @override
  ConsumerState<MarketplaceTabView> createState() => _MarketplaceTabViewState();
}

class _MarketplaceTabViewState extends ConsumerState<MarketplaceTabView> {
  String _selectedType = 'All Types';
  String _selectedLanguage = 'All Languages';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filterTypes = [
    'All Types',
    'Anime Torrents',
    'Manga',
    'Online Streaming',
    'Custom Sources',
  ];

  String _getTypeLabel(String type, AppTranslations l10n) {
    switch (type) {
      case 'All Types':
        return l10n.allTypes;
      case 'Anime Torrents':
        return l10n.animeTorrents;
      case 'Manga':
        return l10n.manga;
      case 'Online Streaming':
        return l10n.onlineStreamingTab;
      case 'Custom Sources':
        return l10n.customSources;
      default:
        return type;
    }
  }

  String _getLanguageLabel(String lang, AppTranslations l10n) {
    if (lang == 'All Languages') return l10n.allLanguages;
    return lang;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getAvailableLanguages() {
    final langs = <String>{'All Languages'};
    for (final ext in widget.extensions) {
      if (ext.lang.isNotEmpty && ext.lang.toLowerCase() != 'multi') {
        langs.add(ext.lang);
      }
    }
    return langs.toList();
  }

  List<ExtensionItem> _filterExtensions(List<ExtensionItem> items) {
    return items.where((ext) {
      // Exclude plugins completely
      if (ext.type.toLowerCase() == 'plugin') return false;

      // Type filter
      if (_selectedType != 'All Types') {
        if (_selectedType == 'Anime Torrents' && ext.type != 'anime-torrent-provider') return false;
        if (_selectedType == 'Manga' && ext.type != 'manga-provider') return false;
        if (_selectedType == 'Online Streaming' && ext.type != 'onlinestream-provider') return false;
        if (_selectedType == 'Custom Sources' && ext.type != 'custom-source') return false;
      }

      // Language filter
      if (_selectedLanguage != 'All Languages') {
        if (ext.lang.toLowerCase() != _selectedLanguage.toLowerCase()) return false;
      }

      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = ext.name.toLowerCase().contains(q);
        final matchId = ext.id.toLowerCase().contains(q);
        final matchDesc = ext.description.toLowerCase().contains(q);
        final matchAuthor = ext.author.toLowerCase().contains(q);
        if (!matchName && !matchId && !matchDesc && !matchAuthor) return false;
      }

      return true;
    }).toList();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Anime Torrents':
        return Icons.cloud_download_outlined;
      case 'Online Streaming':
        return Icons.play_circle_outline_rounded;
      case 'Manga':
        return Icons.menu_book_outlined;
      case 'Custom Sources':
        return Icons.folder_shared_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.loadingMarketplaceRepo),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(widget.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => widget.onRefresh(),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onChangeRepo,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(l10n.changeRepo),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filterExtensions(widget.extensions);

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 650) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 950) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1300) {
          crossAxisCount = 3;
        }

        final groups = <_ExtensionGroup>[];
        if (_selectedType == 'All Types') {
          final torrents = filtered.where((e) => e.type == 'anime-torrent-provider').toList();
          if (torrents.isNotEmpty) {
            groups.add(_ExtensionGroup(l10n.animeTorrents, Icons.cloud_download_outlined, torrents));
          }
          final streaming = filtered.where((e) => e.type == 'onlinestream-provider').toList();
          if (streaming.isNotEmpty) {
            groups.add(_ExtensionGroup(l10n.onlineStreamingTab, Icons.play_circle_outline_rounded, streaming));
          }
          final manga = filtered.where((e) => e.type == 'manga-provider').toList();
          if (manga.isNotEmpty) {
            groups.add(_ExtensionGroup(l10n.manga, Icons.menu_book_outlined, manga));
          }
          final custom = filtered.where((e) => e.type == 'custom-source').toList();
          if (custom.isNotEmpty) {
            groups.add(_ExtensionGroup(l10n.customSources, Icons.folder_shared_outlined, custom));
          }
        } else {
          groups.add(_ExtensionGroup(_getTypeLabel(_selectedType, l10n), _getIconForType(_selectedType), filtered));
        }

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // 1. Marketplace Header & Controls
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 600;
                        if (isDesktop) {
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.marketplace,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Explora e instala extensiones desde el repositorio.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => widget.onRefresh(forceRefresh: true),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: Text(l10n.update),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: widget.onChangeRepo,
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                label: Text(l10n.changeRepo),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.marketplace,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Explora e instala extensiones desde el repositorio.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => widget.onRefresh(forceRefresh: true),
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: Text(l10n.update, maxLines: 1),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: widget.onChangeRepo,
                                      icon: const Icon(Icons.tune_rounded, size: 16),
                                      label: Text(l10n.changeRepo, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: widget.onChangeRepo,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${l10n.sourceLabel} ${widget.currentRepoUrl.split('/').last}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterTypes.map((t) {
                          final isSelected = _selectedType == t;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_getTypeLabel(t, l10n)),
                              selected: isSelected,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.black : theme.colorScheme.onSurfaceVariant,
                              ),
                              selectedColor: Colors.white,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                              onSelected: (val) {
                                setState(() => _selectedType = t);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search & Language bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _getAvailableLanguages().contains(_selectedLanguage)
                                  ? _selectedLanguage
                                  : 'All Languages',
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              items: _getAvailableLanguages().map((l) {
                                return DropdownMenuItem<String>(
                                  value: l,
                                  child: Text(_getLanguageLabel(l, l10n), style: const TextStyle(fontSize: 12.5)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedLanguage = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: l10n.searchExtensionsHint,
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 2. Content Sections
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noExtensionsFound,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.noExtensionsFoundDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...groups.expand((group) {
                return [
                  // Section Header
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Icon(group.icon, size: 19, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 8),
                          Text(
                            group.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${group.items.length})',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Virtualized SliverGrid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 175,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ext = group.items[index];
                          final isInstalled = widget.installedIds.contains(ext.id.toLowerCase());
                          return MarketplaceExtensionCard(
                            extension: ext,
                            isInstalled: isInstalled,
                            isInstalling: widget.installingExtensionId == ext.id,
                            onInstall: () => widget.onInstall(ext),
                          );
                        },
                        childCount: group.items.length,
                      ),
                    ),
                  ),
                ];
              }),

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        );
      },
    );
  }
}

class _ExtensionGroup {
  final String title;
  final IconData icon;
  final List<ExtensionItem> items;

  _ExtensionGroup(this.title, this.icon, this.items);
}
