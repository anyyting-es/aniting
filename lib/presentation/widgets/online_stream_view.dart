import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/presentation/widgets/episode_item_widget.dart';

class OnlineStreamViewController {
  _OnlineStreamViewState? _state;
  void refresh() => _state?._refreshAndClearCache();
  void openManualMapping(BuildContext context) => _state?._showManualMappingSheet(context);
}

class OnlineStreamView extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeDetails? animeDetails;
  final int progress;
  final bool hideTopBar;
  final OnlineStreamViewController? controller;
  final OnlinestreamProvider? selectedProvider;
  final bool? isDubbed;
  final ValueChanged<List<OnlinestreamProvider>>? onProvidersLoaded;
  final ValueChanged<OnlinestreamProvider?>? onProviderChanged;
  final ValueChanged<bool>? onDubbedChanged;

  const OnlineStreamView({
    super.key,
    required this.mediaId,
    this.animeDetails,
    this.progress = 0,
    this.hideTopBar = false,
    this.controller,
    this.selectedProvider,
    this.isDubbed,
    this.onProvidersLoaded,
    this.onProviderChanged,
    this.onDubbedChanged,
  });

  @override
  ConsumerState<OnlineStreamView> createState() => _OnlineStreamViewState();
}

class _OnlineStreamViewState extends ConsumerState<OnlineStreamView> {
  static const String _prefLastProviderKey = 'last_selected_online_provider';
  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedProvider;
  bool _isLoadingProviders = true;

  bool _isDubbed = false;
  List<OnlinestreamEpisode> _episodes = [];
  bool _isLoadingEpisodes = false;
  String? _episodesError;
  String? _currentMappedAnimeId;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  static const int _listPageSize = 24;
  int _currentListPage = 0;

  int? _loadingEpisodeNumber;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    if (widget.selectedProvider != null) {
      _selectedProvider = widget.selectedProvider;
    }
    if (widget.isDubbed != null) {
      _isDubbed = widget.isDubbed!;
    }
    _loadProviders();
  }

  @override
  void didUpdateWidget(covariant OnlineStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._state = this;
    if (widget.selectedProvider != null &&
        widget.selectedProvider?.id != _selectedProvider?.id) {
      setState(() {
        _selectedProvider = widget.selectedProvider;
      });
      _loadEpisodes();
    }
    if (widget.isDubbed != null && widget.isDubbed != _isDubbed) {
      setState(() {
        _isDubbed = widget.isDubbed!;
      });
      _loadEpisodes();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoadingProviders = true;
    });

    final repo = ref.read(repositoryProvider);
    try {
      final list = await repo.getOnlinestreamProviders();
      OnlinestreamProvider? initialProvider;
      if (list.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getString(_prefLastProviderKey);
          if (savedId != null && list.any((p) => p.id == savedId)) {
            initialProvider = list.firstWhere((p) => p.id == savedId);
          }
        } catch (_) {}
        initialProvider ??= list.first;
      }

      if (mounted) {
        final chosen = widget.selectedProvider ?? initialProvider;
        setState(() {
          _providers = list;
          _selectedProvider = chosen;
          _isLoadingProviders = false;
        });

        widget.onProvidersLoaded?.call(list);
        if (chosen != null) {
          widget.onProviderChanged?.call(chosen);
          _loadEpisodes();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProviders = false;
        });
      }
    }
  }

  Future<void> _loadEpisodes() async {
    if (_selectedProvider == null) return;

    setState(() {
      _isLoadingEpisodes = true;
      _episodesError = null;
    });

    final repo = ref.read(repositoryProvider);
    try {
      // Check for existing manual mapping
      final mapping = await repo.getOnlinestreamMapping(
        provider: _selectedProvider!.id,
        mediaId: widget.mediaId,
      );
      if (mounted) {
        setState(() {
          _currentMappedAnimeId = mapping;
        });
      }

      final list = await repo.getOnlinestreamEpisodes(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
        dubbed: _isDubbed,
      );

      if (mounted) {
        final l10n = ref.read(translationsProvider);
        setState(() {
          _episodes = list;
          _isLoadingEpisodes = false;
          _currentListPage = 0;
          if (list.isEmpty) {
            _episodesError = l10n.noEpisodesFoundAuto(_selectedProvider!.name);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = ref.read(translationsProvider);
        setState(() {
          _episodesError = '${l10n.errorLoadingEpisodes} $e';
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  Future<void> _refreshAndClearCache() async {
    final repo = ref.read(repositoryProvider);
    await repo.emptyOnlinestreamCache(widget.mediaId);
    await _loadEpisodes();
  }

  Future<void> _showManualMappingSheet(BuildContext context) async {
    if (_selectedProvider == null) return;

    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);
    final l10n = ref.read(translationsProvider);
    final prov = _selectedProvider!;

    final defaultQuery = widget.animeDetails?.romajiTitle ??
        widget.animeDetails?.englishTitle ??
        widget.animeDetails?.title ??
        '';

    final textController = TextEditingController(text: defaultQuery);
    bool isSearching = false;
    List<OnlinestreamSearchResult> searchResults = [];
    String? searchError;
    bool hasSearched = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> doSearch([String? customQuery]) async {
              final query = (customQuery ?? textController.text).trim();
              if (query.isEmpty) return;
              if (customQuery != null) {
                textController.text = customQuery;
              }

              setModalState(() {
                isSearching = true;
                searchError = null;
                hasSearched = true;
              });

              try {
                final results = await repo.searchOnlinestreamManual(
                  provider: prov.id,
                  query: query,
                  dubbed: _isDubbed,
                );
                setModalState(() {
                  searchResults = results;
                  isSearching = false;
                  if (results.isEmpty) {
                    searchError = l10n.noAnimeFoundInProvider(prov.name, query);
                  }
                });
              } catch (e) {
                setModalState(() {
                  searchError = '${l10n.error}: $e';
                  isSearching = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.75).clamp(0.0, 14.0)),
                          ),
                          child: Icon(Icons.link_rounded, color: theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.linkWith} ${prov.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                l10n.searchAndSelectInProvider,
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Existing mapping notice
                    if (_currentMappedAnimeId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.75).clamp(0.0, 14.0)),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${l10n.linkedTo} $_currentMappedAnimeId',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await repo.removeOnlinestreamMapping(
                                  provider: prov.id,
                                  mediaId: widget.mediaId,
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                if (ok && mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(l10n.linkRemoved)),
                                  );
                                  _loadEpisodes();
                                }
                              },
                              icon: const Icon(Icons.link_off_rounded, size: 14),
                              label: Text(l10n.unlink, style: const TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Search input & button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: l10n.searchAnimePlaceholder,
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.themeColors.borderRadius)),
                            ),
                            onSubmitted: (_) => doSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: isSearching ? null : () => doSearch(),
                          icon: isSearching
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search_rounded, size: 18),
                          label: Text(l10n.search),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title suggestion chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (widget.animeDetails?.romajiTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(widget.animeDetails!.romajiTitle!, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => doSearch(widget.animeDetails!.romajiTitle),
                              ),
                            ),
                          if (widget.animeDetails?.englishTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(widget.animeDetails!.englishTitle!, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => doSearch(widget.animeDetails!.englishTitle),
                              ),
                            ),
                          if (widget.animeDetails?.aniZipData?.titles['es'] != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text('ES: ${widget.animeDetails!.aniZipData!.titles['es']}', style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => doSearch(widget.animeDetails!.aniZipData!.titles['es']),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 18),

                    // Results or Loading
                    Expanded(
                      child: isSearching
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  Text(l10n.searchingProviderCatalog, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            )
                          : searchError != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      searchError!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              : !hasSearched
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_rounded, size: 40, color: theme.colorScheme.outline),
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.searchPromptMapping,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: searchResults.length,
                                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                                      itemBuilder: (ctx, i) {
                                        final res = searchResults[i];
                                        final isCurrentlySelected = _currentMappedAnimeId == res.id;

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: isCurrentlySelected
                                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                                : theme.colorScheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
                                            border: Border.all(
                                              color: isCurrentlySelected
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: ListTile(
                                            title: Text(
                                              res.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            subtitle: Text(
                                              'ID: ${res.id}',
                                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: FilledButton.tonal(
                                              onPressed: () async {
                                                final messenger = ScaffoldMessenger.of(context);
                                                final ok = await repo.setOnlinestreamManualMapping(
                                                  provider: prov.id,
                                                  mediaId: widget.mediaId,
                                                  animeId: res.id,
                                                );
                                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                                if (ok && mounted) {
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text('${l10n.animeLinkedSuccess} "${res.title}"'),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                  _loadEpisodes();
                                                }
                                              },
                                              child: Text(isCurrentlySelected ? l10n.linked : l10n.link, style: const TextStyle(fontSize: 12)),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleEpisodeTap(OnlinestreamEpisode ep) {
    if (_selectedProvider == null) return;

    final animeTitle = widget.animeDetails?.title ?? 'Anime';
    final providerName = _selectedProvider?.name ?? 'Online';
    final l10n = ref.read(translationsProvider);

    Navigator.of(context).push(
      VideoPlayerScreen.route(
        mediaId: widget.mediaId,
        videoUrl: '',
        title: animeTitle,
        episodeTitle: ep.localizedDisplayTitle(l10n),
        episodeNumber: ep.number,
        videoSource: providerName,
        animeDetails: widget.animeDetails,
        aniZipData: widget.animeDetails?.aniZipData,
        onlineStreamProvider: _selectedProvider?.id,
        onlineStreamDubbed: _isDubbed,
        onlineStreamServer: null,
      ),
    );
  }

  List<OnlinestreamEpisode> _getFilteredEpisodes() {
    if (_searchQuery.trim().isEmpty) return _episodes;
    final q = _searchQuery.trim().toLowerCase();
    return _episodes.where((ep) {
      final matchesNum = ep.number.toString() == q;
      final matchesTitle = ep.title?.toLowerCase().contains(q) ?? false;
      return matchesNum || matchesTitle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    // 1. Loading providers
    if (_isLoadingProviders) {
      return Container(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.loadingStreamingExtensions, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // 2. No providers installed
    if (_providers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off_rounded,
              size: 46,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noOnlineExtensionsInstalled,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noOnlineExtensionsInstalledDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ExtensionsMarketplaceScreen(),
                  ),
                ).then((_) => _loadProviders());
              },
              icon: const Icon(Icons.store_mall_directory_rounded, size: 18),
              label: Text(l10n.openExtensionsMarketplace),
            ),
          ],
        ),
      );
    }

    final filtered = _getFilteredEpisodes();
    final fallbackImage = widget.animeDetails?.bannerImage ?? widget.animeDetails?.coverImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hideTopBar) ...[
          // Top Bar: Provider Selector, Dub Toggle, Refresh
          Container(
            padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Provider Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.75).clamp(0.0, 14.0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<OnlinestreamProvider>(
                          value: _selectedProvider,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          items: _providers.map((p) {
                            return DropdownMenuItem<OnlinestreamProvider>(
                              value: p,
                              child: Row(
                                children: [
                                  const Icon(Icons.public, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (p.lang.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.lang.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newProv) {
                            if (newProv != null && newProv.id != _selectedProvider?.id) {
                              setState(() {
                                _selectedProvider = newProv;
                              });
                              SharedPreferences.getInstance().then((prefs) {
                                prefs.setString(_prefLastProviderKey, newProv.id);
                              }).catchError((_) {});
                              _loadEpisodes();
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  // Sub/Dub Toggle (Icon-only)
                  if (_selectedProvider?.supportsDub ?? false) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isDubbed ? Icons.record_voice_over_rounded : Icons.subtitles_rounded,
                        size: 20,
                        color: _isDubbed ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: _isDubbed ? l10n.audioDubbed : l10n.audioSubtitled,
                      onPressed: () {
                        setState(() {
                          _isDubbed = !_isDubbed;
                        });
                        _loadEpisodes();
                      },
                    ),
                  ],

                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      _currentMappedAnimeId != null ? Icons.link_rounded : Icons.add_link_rounded,
                      size: 20,
                      color: _currentMappedAnimeId != null ? theme.colorScheme.primary : null,
                    ),
                    tooltip: _currentMappedAnimeId != null
                        ? '${l10n.linkedTo} $_currentMappedAnimeId (${l10n.tapToEdit})'
                        : l10n.linkAnimeManually,
                    onPressed: () => _showManualMappingSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: l10n.reloadEpisodes,
                    onPressed: _isLoadingEpisodes ? null : _loadEpisodes,
                  ),
                ],
              ),

              // Mapping active badge
              if (_currentMappedAnimeId != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showManualMappingSheet(context),
                  borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.6).clamp(0.0, 10.0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.6).clamp(0.0, 10.0)),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.manualMappingActive} $_currentMappedAnimeId',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.edit_rounded, size: 13, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ],

              // Search episodes input
              if (_episodes.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n.filterEpisodesHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentListPage = 0;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentListPage = 0;
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],

      // Count / Info Header + ViewMode toggle
      Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '${l10n.episodes} (${_selectedProvider?.name ?? ''})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isLoadingEpisodes) ...[
                  const SizedBox(width: 6),
                  Text(
                    '• ${filtered.length} ${l10n.availableCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (widget.hideTopBar && _episodes.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                _isSearchExpanded ? Icons.search_off_rounded : Icons.search_rounded,
                size: 20,
                color: _searchQuery.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: l10n.search,
              onPressed: () {
                setState(() => _isSearchExpanded = !_isSearchExpanded);
              },
            ),
            const SizedBox(width: 2),
          ],
          IconButton(
            icon: Icon(
              ref.watch(episodeViewModeProvider) == EpisodeViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: ref.watch(episodeViewModeProvider) == EpisodeViewMode.grid
                ? l10n.switchToList
                : l10n.switchToGrid,
            onPressed: () {
              ref.read(episodeViewModeProvider.notifier).toggleMode();
            },
          ),
        ],
      ),

      if (widget.hideTopBar && _isSearchExpanded && _episodes.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: l10n.filterEpisodesHint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _currentListPage = 0;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (val) => setState(() {
            _searchQuery = val;
            _currentListPage = 0;
          }),
        ),
      ],

        const SizedBox(height: 4),

        // Episodes Body
        if (_isLoadingEpisodes)
          _buildLoadingSkeletons(theme)
        else if (_episodesError != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 36, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  _episodesError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showManualMappingSheet(context),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: Text('${l10n.searchAndLinkIn} ${_selectedProvider?.name ?? ""}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refreshAndClearCache,
                      icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                      label: Text(l10n.clearCacheAndRetry),
                    ),
                  ],
                ),
              ],
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_filter_outlined, size: 38, color: theme.colorScheme.outline),
                  const SizedBox(height: 10),
                  Text(
                    _searchQuery.isNotEmpty
                        ? '${l10n.noEpisodesFoundMatching} "$_searchQuery".'
                        : l10n.noEpisodesInProvider(_selectedProvider?.name ?? ""),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _showManualMappingSheet(context),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: Text('${l10n.searchAndLinkIn} ${_selectedProvider?.name ?? ""}'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else if (ref.watch(episodeViewModeProvider) == EpisodeViewMode.grid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.35,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final ep = filtered[index];
              final isLoading = _loadingEpisodeNumber == ep.number;
              final aniZipEp = widget.animeDetails?.aniZipData?.episodes
                  .where((e) => e.episodeNumber == ep.number)
                  .firstOrNull;

              final epImg = (ep.image != null && ep.image!.isNotEmpty) ? ep.image : aniZipEp?.image;
              final epSynopsis = (ep.description != null && ep.description!.isNotEmpty) ? ep.description : aniZipEp?.synopsis;

              return EpisodeGridItem(
                episodeNumber: ep.number,
                title: ep.localizedDisplayTitle(l10n),
                originalTitle: aniZipEp?.originalTitle,
                duration: aniZipEp?.formattedDuration,
                synopsis: epSynopsis,
                image: epImg,
                fallbackImage: fallbackImage,
                airDate: aniZipEp?.formattedAirDate,
                rating: aniZipEp?.rating,
                badgeText: ep.isFiller ? l10n.filler.toUpperCase() : null,
                isLoading: isLoading,
                isWatched: widget.progress >= ep.number && ep.number > 0,
                onTap: isLoading ? null : () => _handleEpisodeTap(ep),
              );
            },
          )
        else ...[
          Builder(
            builder: (context) {
              final totalEpisodes = filtered.length;
              final totalPages = (totalEpisodes / _listPageSize).ceil();
              final page = _currentListPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
              final start = page * _listPageSize;
              final end = (start + _listPageSize).clamp(0, totalEpisodes);
              final pagedEpisodes = totalEpisodes > 0 ? filtered.sublist(start, end) : <OnlinestreamEpisode>[];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: pagedEpisodes.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ep = pagedEpisodes[index];
                      final isLoading = _loadingEpisodeNumber == ep.number;
                      final aniZipEp = widget.animeDetails?.aniZipData?.episodes
                          .where((e) => e.episodeNumber == ep.number)
                          .firstOrNull;

                      final epImg = (ep.image != null && ep.image!.isNotEmpty) ? ep.image : aniZipEp?.image;
                      final epSynopsis = (ep.description != null && ep.description!.isNotEmpty) ? ep.description : aniZipEp?.synopsis;

                      return EpisodeListItem(
                        episodeNumber: ep.number,
                        title: ep.localizedDisplayTitle(l10n),
                        originalTitle: aniZipEp?.originalTitle,
                        duration: aniZipEp?.formattedDuration,
                        synopsis: epSynopsis,
                        image: epImg,
                        fallbackImage: fallbackImage,
                        airDate: aniZipEp?.formattedAirDate,
                        rating: aniZipEp?.rating,
                        badgeText: ep.isFiller ? l10n.filler.toUpperCase() : null,
                        isLoading: isLoading,
                        isWatched: widget.progress >= ep.number && ep.number > 0,
                        onTap: isLoading ? null : () => _handleEpisodeTap(ep),
                        onPlay: isLoading ? null : () => _handleEpisodeTap(ep),
                      );
                    },
                  ),
                  if (totalPages > 1) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: page > 0
                              ? () => setState(() => _currentListPage = page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          label: Text(l10n.previousPage),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${page + 1} / $totalPages',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: page < totalPages - 1
                              ? () => setState(() => _currentListPage = page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                          label: Text('${l10n.nextPage} ($_listPageSize ep)'),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingSkeletons(ThemeData theme) {
    return Column(
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
            ),
            child: Row(
              children: [
                Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(context.themeColors.borderRadius)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 130,
                        height: 14,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
