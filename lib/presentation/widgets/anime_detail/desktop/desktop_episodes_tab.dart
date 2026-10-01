import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/local_library_view.dart';

import 'desktop_episode_grid_card.dart';
import 'desktop_episode_list_card.dart';
import 'desktop_episode_models.dart';
import 'desktop_episode_pagination.dart';

export 'desktop_episode_models.dart';

class DesktopEpisodesTab extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeDetails? details;
  final AniZipData? aniZipData;
  final int progress;
  final bool isLocalMode;
  final AnimeDetailTab currentTab;
  final List<OnlinestreamProvider> providers;
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final List<OnlinestreamEpisode> onlineEpisodes;
  final bool isLoadingOnlineEpisodes;
  final int? loadingEpisodeNumber;
  final String? fallbackCoverImage;

  final ValueChanged<OnlinestreamProvider?> onProviderChanged;
  final VoidCallback onToggleDubbed;
  final void Function(DesktopEpisodeItemData ep) onEpisodeClicked;
  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;

  const DesktopEpisodesTab({
    super.key,
    required this.mediaId,
    required this.details,
    required this.aniZipData,
    required this.progress,
    required this.isLocalMode,
    required this.currentTab,
    required this.providers,
    required this.selectedProvider,
    required this.isDubbed,
    required this.onlineEpisodes,
    this.isLoadingOnlineEpisodes = false,
    required this.loadingEpisodeNumber,
    required this.fallbackCoverImage,
    required this.onProviderChanged,
    required this.onToggleDubbed,
    required this.onEpisodeClicked,
    required this.onToggleLocalMode,
    required this.onTabChanged,
  });

  @override
  ConsumerState<DesktopEpisodesTab> createState() => _DesktopEpisodesTabState();
}

class _DesktopEpisodesTabState extends ConsumerState<DesktopEpisodesTab> {
  bool _isGridView = true;
  bool _isSortAscending = true;
  int _currentPage = 0;
  static const int _episodesPerPage = 20;

  @override
  void didUpdateWidget(covariant DesktopEpisodesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab != widget.currentTab ||
        oldWidget.selectedProvider?.id != widget.selectedProvider?.id ||
        oldWidget.isDubbed != widget.isDubbed) {
      setState(() {
        _currentPage = 0;
      });
    }
  }

  String _formatEpisodeTitle(DesktopEpisodeItemData ep) {
    final t = ep.title.trim();
    if (t.toLowerCase() == 'episodio ${ep.number}' ||
        t.toLowerCase() == 'episode ${ep.number}' ||
        t.isEmpty) {
      return 'EP ${ep.number}';
    }
    final cleanT = t.replaceFirst(
        RegExp(r'^(episodio|episode)\s*\d+\s*[:.-]?\s*', caseSensitive: false),
        '');
    if (cleanT.isNotEmpty) {
      return 'EP ${ep.number}. $cleanT';
    }
    return 'EP ${ep.number}. $t';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocalMode) {
      return LocalLibraryView(
        mediaId: widget.mediaId,
        animeDetails: widget.details,
        progress: widget.progress,
        onSwitchToTorrent: () {
          widget.onToggleLocalMode();
          widget.onTabChanged(AnimeDetailTab.torrent);
        },
        onSwitchToOnline: () {
          widget.onToggleLocalMode();
          widget.onTabChanged(AnimeDetailTab.online);
        },
      );
    }

    final currentLanguage = ref.watch(appLanguageProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isEn = currentLanguage == AppLanguage.en;
    final langCode = currentLanguage.name;

    final aniZipData = widget.aniZipData ?? widget.details?.aniZipData;
    final aniZipMainEps = aniZipData?.mainEpisodes ??
        aniZipData?.episodes.where((e) => !e.isSpecial).toList() ??
        [];
    final fallbackEps = widget.details?.episodes ?? [];
    final maxTotal = widget.details?.totalEpisodes;
    final totalCount = maxTotal ??
        (aniZipMainEps.isNotEmpty
            ? aniZipMainEps.length
            : (fallbackEps.isNotEmpty ? fallbackEps.length : 12));

    bool isRealMainEpisode(String title, bool isSpecial, int episodeNum) {
      if (isSpecial) return false;
      if (episodeNum <= 0) return false;
      if (maxTotal != null && maxTotal > 0 && episodeNum > maxTotal) {
        return false;
      }
      final lower = title.toLowerCase();
      const forbiddenTerms = [
        'extra episode',
        'special episode',
        'opening',
        'ending',
        'creditless',
        'ncop',
        'nced',
        'preview',
        'teaser',
        'music video',
        'web teaser',
        'recap',
      ];
      for (final term in forbiddenTerms) {
        if (lower.contains(term)) return false;
      }
      return true;
    }

    final List<DesktopEpisodeItemData> items = [];

    if (widget.currentTab == AnimeDetailTab.online) {
      // ─── Mode: Online Streaming (Consult the selected source) ───
      final Map<int, dynamic> aniZipByNumber = {
        for (final ep in aniZipMainEps) ep.episodeNumber: ep,
      };

      final Set<int> seenOnline = {};
      for (final ep in widget.onlineEpisodes) {
        if (!isRealMainEpisode(ep.displayTitle, false, ep.number)) continue;
        if (!seenOnline.add(ep.number)) continue;

        final aniZipEp = aniZipByNumber[ep.number];
        final thumb = (ep.image != null && ep.image!.isNotEmpty)
            ? ep.image
            : aniZipEp?.image;
        final synopsis = (ep.description != null && ep.description!.isNotEmpty)
            ? ep.description
            : aniZipEp?.synopsis;
        final rawTitle = ep.displayTitle;
        final isGenericOnlineTitle = rawTitle.isEmpty ||
            rawTitle.toLowerCase() == 'episode ${ep.number}' ||
            rawTitle.toLowerCase() == 'episodio ${ep.number}';
        final epTitle = !isGenericOnlineTitle
            ? rawTitle
            : (aniZipEp?.displayTitleForLang(langCode) ??
                (isEn ? 'Episode ${ep.number}' : 'Episodio ${ep.number}'));

        items.add(DesktopEpisodeItemData(
          number: ep.number,
          title: epTitle,
          synopsis: synopsis,
          image: thumb,
          aniDBEpisode: aniZipEp?.episode,
          isWatched: widget.progress >= ep.number,
        ));
      }
    } else {
      // ─── Mode: Torrent / Default (100% Real AniList / AniZip canon episode list) ───
      final Set<int> seenTorrent = {};
      if (aniZipMainEps.isNotEmpty) {
        for (final ep in aniZipMainEps) {
          if (!isRealMainEpisode(ep.displayTitle, ep.isSpecial, ep.episodeNumber)) {
            continue;
          }
          if (seenTorrent.add(ep.episodeNumber)) {
            items.add(DesktopEpisodeItemData(
              number: ep.episodeNumber,
              title: ep.displayTitleForLang(langCode),
              synopsis: ep.synopsis,
              image: ep.image,
              aniDBEpisode: ep.episode,
              isWatched: widget.progress >= ep.episodeNumber,
            ));
          }
        }
      } else if (fallbackEps.isNotEmpty) {
        for (final ep in fallbackEps) {
          if (!isRealMainEpisode(ep.title, false, ep.episodeNumber)) {
            continue;
          }
          if (seenTorrent.add(ep.episodeNumber)) {
            items.add(DesktopEpisodeItemData(
              number: ep.episodeNumber,
              title: ep.title,
              synopsis: ep.description,
              image: ep.image,
              isWatched: widget.progress >= ep.episodeNumber,
            ));
          }
        }
      }

      if (items.isEmpty) {
        for (int i = 1; i <= totalCount; i++) {
          items.add(DesktopEpisodeItemData(
            number: i,
            title: isEn ? 'Episode $i' : 'Episodio $i',
            isWatched: widget.progress >= i,
          ));
        }
      }
    }

    if (!_isSortAscending) {
      items.sort((a, b) => b.number.compareTo(a.number));
    } else {
      items.sort((a, b) => a.number.compareTo(b.number));
    }

    final totalEpisodes = items.length;
    final totalPages = (totalEpisodes / _episodesPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _episodesPerPage;
    final endIndex = (startIndex + _episodesPerPage).clamp(0, totalEpisodes);
    final pagedItems = totalEpisodes == 0
        ? <DesktopEpisodeItemData>[]
        : items.sublist(startIndex, endIndex);

    final headerCountText = totalPages > 1
        ? '${items.length} ${isEn ? "Episodes" : "Episodios"} • ${isEn ? "Page" : "Pág."} ${_currentPage + 1}/$totalPages'
        : '${items.length} ${isEn ? "Episodes" : "Episodios"}';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: [Episodes Count] on left, Provider & Toggles on right ───
        Row(
          children: [
            Text(
              headerCountText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                letterSpacing: -0.2,
              ),
            ),

            const Spacer(),

            // If Online mode, show provider selector and dub toggle
            if (widget.currentTab == AnimeDetailTab.online && widget.providers.isNotEmpty) ...[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<OnlinestreamProvider>(
                    value: widget.selectedProvider,
                    dropdownColor: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(AppIcons.chevronDown(iconPack), size: 15, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    items: widget.providers
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: widget.onProviderChanged,
                  ),
                ),
              ),
              if (widget.selectedProvider?.supportsDub ?? false) ...[
                const SizedBox(width: 4),
                IconButton(
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    hoverColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
                  ),
                  icon: Icon(
                    widget.isDubbed ? AppIcons.voice(iconPack) : AppIcons.subtitles(iconPack),
                    size: 18,
                    color: widget.isDubbed
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : (isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                  ),
                  tooltip: widget.isDubbed
                      ? (isEn ? 'Dubbed Audio' : 'Audio Doblado')
                      : (isEn ? 'Subtitled Audio' : 'Audio Subtitulado'),
                  onPressed: widget.onToggleDubbed,
                ),
              ],
              const SizedBox(width: 6),
            ],

            // Toggle Grid / List View
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView
                  ? (isEn ? 'List view' : 'Vista en lista')
                  : (isEn ? 'Grid view' : 'Vista en cuadrícula'),
              icon: Icon(
                _isGridView ? AppIcons.list(iconPack) : AppIcons.grid(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),

            // Toggle Sort Ascending / Descending
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
              ),
              onPressed: () => setState(() {
                _isSortAscending = !_isSortAscending;
                _currentPage = 0;
              }),
              tooltip: _isSortAscending
                  ? (isEn ? 'Ascending order' : 'Orden ascendente')
                  : (isEn ? 'Descending order' : 'Orden descendente'),
              icon: Icon(
                AppIcons.swapVert(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Loading State for Online Mode ───
        if (widget.currentTab == AnimeDetailTab.online && widget.isLoadingOnlineEpisodes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: isDark ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando episodios de ${widget.selectedProvider?.name ?? 'la fuente'}...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        // ─── Empty State for Online Mode ───
        else if (widget.currentTab == AnimeDetailTab.online && items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_collection_outlined,
                    size: 40,
                    color: isDark ? Colors.white.withValues(alpha: 0.3) : theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron episodios en ${widget.selectedProvider?.name ?? 'esta fuente'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Prueba seleccionando otro servidor o cambiando entre subtitulado y doblado',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withValues(alpha: 0.45) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        // ─── Mode 1: Grid Mode (Bigger cards, clean thumbnails, max 20 per page) ───
        else if (_isGridView)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 210).floor().clamp(2, 5);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagedItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                ),
                itemBuilder: (context, index) {
                  final ep = pagedItems[index];
                  return DesktopGridEpisodeCard(
                    ep: ep,
                    isLoading: widget.loadingEpisodeNumber == ep.number,
                    formattedTitle: _formatEpisodeTitle(ep),
                    fallbackCoverImage: widget.fallbackCoverImage,
                    onTap: () => widget.onEpisodeClicked(ep),
                  );
                },
              );
            },
          )
        // ─── Mode 2: 2-Column List Mode (Unboxed, Bigger Cards, Clean Image + Text, max 20 per page) ───
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDual = constraints.maxWidth > 860;
              final crossAxisCount = isDual ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagedItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 136,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final ep = pagedItems[index];
                  return DesktopListEpisodeCard(
                    ep: ep,
                    isLoading: widget.loadingEpisodeNumber == ep.number,
                    formattedTitle: _formatEpisodeTitle(ep),
                    fallbackCoverImage: widget.fallbackCoverImage,
                    onTap: () => widget.onEpisodeClicked(ep),
                  );
                },
              );
            },
          ),

        // ─── Pagination Controls (Next / Prev / Page Buttons) ───
        if (totalPages > 1)
          DesktopEpisodePagination(
            currentPage: _currentPage,
            totalPages: totalPages,
            startIndex: startIndex,
            endIndex: endIndex,
            onPageChanged: (newPage) => setState(() => _currentPage = newPage),
          ),
      ],
    );
  }
}
