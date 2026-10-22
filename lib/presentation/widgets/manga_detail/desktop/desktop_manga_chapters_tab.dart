import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';

import 'desktop_manga_chapter_card.dart';

enum DesktopMangaFilter {
  all,
  unread,
  read,
}

class DesktopMangaChaptersTab extends ConsumerStatefulWidget {
  final int mediaId;
  final List<MangaProvider> providers;
  final MangaProvider? selectedProvider;
  final List<MangaChapter> chapters;
  final bool isLoadingChapters;
  final String? chaptersError;
  final int progress;
  final Set<String> downloadedChapterIds;
  final Set<String> downloadingChapterIds;
  final ValueChanged<MangaProvider?> onProviderChanged;
  final VoidCallback onRefreshChapters;
  final ValueChanged<MangaChapter> onChapterClicked;
  final ValueChanged<MangaChapter> onDownloadChapter;
  final VoidCallback onBatchDownload;
  final void Function(List<MangaChapter>)? onDownloadSelected;

  const DesktopMangaChaptersTab({
    super.key,
    required this.mediaId,
    required this.providers,
    required this.selectedProvider,
    required this.chapters,
    required this.isLoadingChapters,
    required this.chaptersError,
    required this.progress,
    required this.downloadedChapterIds,
    required this.downloadingChapterIds,
    required this.onProviderChanged,
    required this.onRefreshChapters,
    required this.onChapterClicked,
    required this.onDownloadChapter,
    required this.onBatchDownload,
    this.onDownloadSelected,
  });

  @override
  ConsumerState<DesktopMangaChaptersTab> createState() => _DesktopMangaChaptersTabState();
}

class _DesktopMangaChaptersTabState extends ConsumerState<DesktopMangaChaptersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAscending = true;
  DesktopMangaFilter _filterOption = DesktopMangaFilter.all;
  bool _showOnlyDownloaded = false;
  int _pageSize = 50; // default 50
  int _currentPage = 0;
  final Set<String> _selectedChapterIds = <String>{};

  @override
  void didUpdateWidget(covariant DesktopMangaChaptersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProvider?.id != widget.selectedProvider?.id) {
      _selectedChapterIds.clear();
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MangaChapter> get _filteredChapters {
    var list = List<MangaChapter>.from(widget.chapters);

    if (_showOnlyDownloaded) {
      list = list.where((c) => widget.downloadedChapterIds.contains(c.id)).toList();
    }

    final q = _searchQuery.trim();
    if (q.isNotEmpty) {
      final parsedNum = double.tryParse(q.replaceAll(',', '.'));
      if (parsedNum != null) {
        if (_isAscending) {
          list = list.where((c) => c.chapterNumber >= parsedNum).toList();
        } else {
          list = list.where((c) => c.chapterNumber <= parsedNum).toList();
        }
      } else {
        final queryLower = q.toLowerCase();
        list = list.where((c) {
          return c.chapter.toLowerCase().contains(queryLower) ||
              c.title.toLowerCase().contains(queryLower) ||
              (c.scanlator?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }
    } else {
      switch (_filterOption) {
        case DesktopMangaFilter.unread:
          if (widget.progress > 0) {
            list = list.where((c) => c.chapterNumber > widget.progress).toList();
          }
          break;
        case DesktopMangaFilter.read:
          if (widget.progress > 0) {
            list = list.where((c) => c.chapterNumber <= widget.progress).toList();
          }
          break;
        case DesktopMangaFilter.all:
          break;
      }
    }

    if (_isAscending) {
      list.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    } else {
      list.sort((a, b) => b.chapterNumber.compareTo(a.chapterNumber));
    }

    return list;
  }

  void _toggleSelectChapter(String id) {
    setState(() {
      if (_selectedChapterIds.contains(id)) {
        _selectedChapterIds.remove(id);
      } else {
        _selectedChapterIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.providers.isEmpty && !widget.isLoadingChapters) {
      return _buildNoProvidersView(theme, l10n);
    }

    final allFiltered = _filteredChapters;
    final totalCount = allFiltered.length;
    final effectivePageSize = _pageSize > 0 ? _pageSize : totalCount;
    final totalPages = effectivePageSize > 0
        ? (totalCount / effectivePageSize).ceil().clamp(1, 9999)
        : 1;

    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = (safePage * effectivePageSize).clamp(0, totalCount);
    final endIndex = (startIndex + effectivePageSize).clamp(0, totalCount);
    final paginatedChapters = allFiltered.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Top Controls Bar: Liquid Glass Provider Menu + Search + Sort + Refresh ──
        Row(
          children: [
            // Liquid Glass Source Selector (Mirrors Anime Detail)
            if (widget.providers.isNotEmpty) ...[
              GlassMenuAnchor(
                width: 220,
                items: widget.providers.map((p) {
                  final isCurrent = widget.selectedProvider?.id == p.id;
                  return GlassMenuItem(
                    label: p.name,
                    icon: Icon(
                      isCurrent ? AppIcons.checkCircleFilled(iconPack) : AppIcons.manga(iconPack),
                      size: 18,
                      color: isCurrent ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () => widget.onProviderChanged(p),
                  );
                }).toList(),
                builder: (context, controller) {
                  return GlassButton(
                    onPressed: controller.open,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.manga(iconPack),
                          size: 16,
                          color: isDark ? Colors.white : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.selectedProvider?.name ?? l10n.source,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          AppIcons.chevronDown(iconPack),
                          size: 17,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],

            // Search chapters TextField (modern rounded style)
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: l10n.searchChapterPlaceholder,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Asc / Desc Sort Button
            IconButton(
              tooltip: _isAscending ? l10n.oldestFirst : l10n.newestFirst,
              style: IconButton.styleFrom(
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(10),
              ),
              icon: Icon(
                _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => setState(() {
                _isAscending = !_isAscending;
              }),
            ),
            const SizedBox(width: 6),

            // Refresh Chapters Button
            IconButton(
              tooltip: l10n.reloadChapters,
              style: IconButton.styleFrom(
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(10),
              ),
              icon: Icon(Icons.refresh_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: widget.onRefreshChapters,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── 2. Filters Wrap (Todos / No leídos / Leídos / Solo descargados / Tamaño de lista) ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Filter All
            ChoiceChip(
              label: Text(l10n.filterAll),
              selected: _filterOption == DesktopMangaFilter.all,
              onSelected: (sel) {
                if (sel) setState(() => _filterOption = DesktopMangaFilter.all);
              },
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: _filterOption == DesktopMangaFilter.all ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),

            // Filter Unread
            ChoiceChip(
              avatar: const Icon(Icons.menu_book_rounded, size: 14),
              label: Text(l10n.filterUnread),
              selected: _filterOption == DesktopMangaFilter.unread,
              onSelected: (sel) {
                if (sel) setState(() => _filterOption = DesktopMangaFilter.unread);
              },
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: _filterOption == DesktopMangaFilter.unread ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),

            // Filter Read
            ChoiceChip(
              avatar: const Icon(Icons.check_rounded, size: 14),
              label: Text(l10n.filterRead),
              selected: _filterOption == DesktopMangaFilter.read,
              onSelected: (sel) {
                if (sel) setState(() => _filterOption = DesktopMangaFilter.read);
              },
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: _filterOption == DesktopMangaFilter.read ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),

            if (widget.downloadedChapterIds.isNotEmpty || _showOnlyDownloaded) ...[
              FilterChip(
                avatar: Icon(
                  _showOnlyDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_outlined,
                  size: 14,
                ),
                label: Text(
                  _showOnlyDownloaded
                      ? l10n.downloadedCount(widget.downloadedChapterIds.length)
                      : '${l10n.onlyDownloaded} (${widget.downloadedChapterIds.length})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _showOnlyDownloaded ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: _showOnlyDownloaded,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (val) => setState(() => _showOnlyDownloaded = val),
              ),
            ],

            // Page Size Selector (30 / 50 / 100 / Todos)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  borderRadius: BorderRadius.circular(10),
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                  items: [
                    DropdownMenuItem(value: 30, child: Text('30 ${l10n.episodes.toLowerCase()}', style: const TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 50, child: Text('50 ${l10n.episodes.toLowerCase()}', style: const TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 100, child: Text('100 ${l10n.episodes.toLowerCase()}', style: const TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 0, child: Text(l10n.all, style: const TextStyle(fontSize: 11.5))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),

            if (widget.selectedProvider != null && widget.chapters.isNotEmpty) ...[
              ActionChip(
                avatar: Icon(
                  Icons.download_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  l10n.downloadBatch,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onPressed: widget.onBatchDownload,
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                l10n.chaptersCount(totalCount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),

        // ── Multi-selection Action Bar (Desktop) ──
        if (_selectedChapterIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.mangaChaptersSelected(_selectedChapterIds.length),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedChapterIds.clear()),
                  child: Text(l10n.cancel, style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    final selectedList = widget.chapters
                        .where((c) => _selectedChapterIds.contains(c.id))
                        .toList();
                    widget.onDownloadSelected?.call(selectedList);
                    setState(() => _selectedChapterIds.clear());
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(l10n.downloadSelected, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── 3. Chapters List / States ──
        if (widget.isLoadingChapters)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (widget.chaptersError != null)
          _buildErrorView(theme)
        else if (paginatedChapters.isEmpty)
          _buildEmptyView()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedChapters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final c = paginatedChapters[index];
              final epNum = c.chapterNumber.toInt();
              final isRead = widget.progress >= epNum && epNum > 0;
              final isSelected = _selectedChapterIds.contains(c.id);

              return DesktopMangaChapterCard(
                chapter: c,
                isRead: isRead,
                isDownloaded: widget.downloadedChapterIds.contains(c.id),
                isDownloading: widget.downloadingChapterIds.contains(c.id),
                canDownload: widget.selectedProvider != null,
                isSelected: isSelected,
                onToggleSelect: () => _toggleSelectChapter(c.id),
                onTap: () {
                  if (_selectedChapterIds.isNotEmpty) {
                    _toggleSelectChapter(c.id);
                  } else {
                    widget.onChapterClicked(c);
                  }
                },
                onDownload: () => widget.onDownloadChapter(c),
              );
            },
          ),

        // Pagination Stepper Controls (Desktop)
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                '${l10n.page} ${safePage + 1} / $totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNoProvidersView(ThemeData theme, AppTranslations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.extension_off_rounded, color: theme.colorScheme.primary, size: 44),
            const SizedBox(height: 12),
            Text(
              l10n.noMangaProviders,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.installMangaExtensionNotice,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExtensionsMarketplaceScreen()),
                ).then((_) => widget.onRefreshChapters());
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(l10n.exploreMangaExtensions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined, color: theme.colorScheme.outline, size: 40),
            const SizedBox(height: 10),
            Text(
              widget.chaptersError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.onRefreshChapters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(ref.read(translationsProvider).retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final theme = Theme.of(context);
    final l10n = ref.read(translationsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showOnlyDownloaded ? Icons.download_done_rounded : Icons.menu_book_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              _showOnlyDownloaded ? l10n.noDownloadedChaptersForManga : l10n.noChaptersAvailable,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
