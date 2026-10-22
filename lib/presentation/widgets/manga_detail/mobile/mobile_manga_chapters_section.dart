import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/presentation/widgets/manga/manga_chapter_item.dart';

enum MangaFilterOption {
  all,
  unread,
  read,
}

class MobileMangaChaptersSection extends ConsumerStatefulWidget {
  final List<MangaProvider> providers;
  final MangaProvider? selectedProvider;
  final bool isLoadingProviders;
  final List<MangaChapter> chapters;
  final bool isLoadingChapters;
  final String? chaptersError;
  final int progress;
  final Set<String> downloadedChapterIds;
  final Set<String> downloadingChapterIds;
  final bool showOnlyDownloaded;
  final bool hideRead;
  final bool isAscending;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<bool> onToggleShowOnlyDownloaded;
  final ValueChanged<bool> onToggleHideRead;
  final VoidCallback onToggleSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MangaProvider?> onProviderChanged;
  final VoidCallback onRefreshChapters;
  final ValueChanged<MangaChapter> onChapterClicked;
  final ValueChanged<MangaChapter> onDownloadChapter;
  final VoidCallback onBatchDownload;
  final void Function(List<MangaChapter>)? onDownloadSelected;

  const MobileMangaChaptersSection({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.isLoadingProviders,
    required this.chapters,
    required this.isLoadingChapters,
    required this.chaptersError,
    required this.progress,
    required this.downloadedChapterIds,
    required this.downloadingChapterIds,
    required this.showOnlyDownloaded,
    required this.hideRead,
    required this.isAscending,
    required this.searchQuery,
    required this.searchController,
    required this.onToggleShowOnlyDownloaded,
    required this.onToggleHideRead,
    required this.onToggleSort,
    required this.onSearchChanged,
    required this.onProviderChanged,
    required this.onRefreshChapters,
    required this.onChapterClicked,
    required this.onDownloadChapter,
    required this.onBatchDownload,
    this.onDownloadSelected,
  });

  @override
  ConsumerState<MobileMangaChaptersSection> createState() =>
      _MobileMangaChaptersSectionState();
}

class _MobileMangaChaptersSectionState
    extends ConsumerState<MobileMangaChaptersSection> {
  MangaFilterOption _filterOption = MangaFilterOption.all;
  int _pageSize = 50; // default 50 items
  int _currentPage = 0;
  final Set<String> _selectedChapterIds = <String>{};

  @override
  void didUpdateWidget(covariant MobileMangaChaptersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProvider?.id != widget.selectedProvider?.id) {
      _selectedChapterIds.clear();
      _currentPage = 0;
    }
  }

  List<MangaChapter> get _filteredChapters {
    var list = List<MangaChapter>.from(widget.chapters);

    if (widget.showOnlyDownloaded) {
      list = list.where((c) => widget.downloadedChapterIds.contains(c.id)).toList();
    }

    final q = widget.searchQuery.trim();
    if (q.isNotEmpty) {
      final parsedNum = double.tryParse(q.replaceAll(',', '.'));
      if (parsedNum != null) {
        if (widget.isAscending) {
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
        case MangaFilterOption.unread:
          if (widget.progress > 0) {
            list = list.where((c) => c.chapterNumber > widget.progress).toList();
          }
          break;
        case MangaFilterOption.read:
          if (widget.progress > 0) {
            list = list.where((c) => c.chapterNumber <= widget.progress).toList();
          }
          break;
        case MangaFilterOption.all:
          if (widget.hideRead && widget.progress > 0) {
            list = list.where((c) => c.chapterNumber > widget.progress).toList();
          }
          break;
      }
    }

    if (widget.isAscending) {
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

    if (widget.isLoadingProviders) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.providers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.extension_off_rounded, color: theme.colorScheme.primary, size: 36),
              const SizedBox(height: 8),
              Text(
                l10n.noMangaProviders,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.installMangaExtensionNotice,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
        // Controls Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Top Title + Count + Sort & Refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.chapters,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (totalCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalCount',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (totalPages > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${safePage + 1}/$totalPages',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        tooltip: widget.isAscending ? l10n.oldestFirst : l10n.newestFirst,
                        icon: Icon(
                          widget.isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 20,
                        ),
                        onPressed: widget.onToggleSort,
                      ),
                      IconButton(
                        tooltip: l10n.reloadChapters,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        onPressed: widget.onRefreshChapters,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search Bar + Liquid Glass Source Button (matches anime detail)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: widget.searchController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: l10n.searchChapterPlaceholder,
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          suffixIcon: widget.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () {
                                    widget.searchController.clear();
                                    widget.onSearchChanged('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
                        onChanged: widget.onSearchChanged,
                      ),
                    ),
                  ),

                  // Liquid Glass Manga Source Selector Dropdown (matches anime detail)
                  if (widget.providers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GlassMenuAnchor(
                      width: 230,
                      items: widget.providers.map((p) {
                        final isCurrent = widget.selectedProvider?.id == p.id;
                        return GlassMenuItem(
                          label: p.name,
                          icon: Icon(
                            isCurrent ? AppIcons.checkCircleFilled(iconPack) : AppIcons.manga(iconPack),
                            size: 18,
                            color: isCurrent ? theme.colorScheme.primary : null,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            widget.onProviderChanged(p);
                          },
                        );
                      }).toList(),
                      builder: (context, controller) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: controller.open,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.16)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.manga(iconPack),
                                    size: 15,
                                    color: isDark ? Colors.white : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 95),
                                    child: Text(
                                      widget.selectedProvider?.name ?? l10n.source,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    AppIcons.arrowDropDown(iconPack),
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              // Filter Chips: Todos / No leídos / Leídos / Solo descargados / Page Size
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Filter All
                    ChoiceChip(
                      label: Text(l10n.filterAll),
                      selected: _filterOption == MangaFilterOption.all,
                      onSelected: (sel) {
                        if (sel) setState(() => _filterOption = MangaFilterOption.all);
                      },
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _filterOption == MangaFilterOption.all ? FontWeight.bold : FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(width: 6),

                    // Filter Unread
                    ChoiceChip(
                      avatar: const Icon(Icons.menu_book_rounded, size: 14),
                      label: Text(l10n.filterUnread),
                      selected: _filterOption == MangaFilterOption.unread,
                      onSelected: (sel) {
                        if (sel) setState(() => _filterOption = MangaFilterOption.unread);
                      },
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _filterOption == MangaFilterOption.unread ? FontWeight.bold : FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(width: 6),

                    // Filter Read
                    ChoiceChip(
                      avatar: const Icon(Icons.check_rounded, size: 14),
                      label: Text(l10n.filterRead),
                      selected: _filterOption == MangaFilterOption.read,
                      onSelected: (sel) {
                        if (sel) setState(() => _filterOption = MangaFilterOption.read);
                      },
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _filterOption == MangaFilterOption.read ? FontWeight.bold : FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(width: 6),

                    // Only Downloaded
                    if (widget.downloadedChapterIds.isNotEmpty || widget.showOnlyDownloaded) ...[
                      FilterChip(
                        avatar: Icon(
                          widget.showOnlyDownloaded
                              ? Icons.download_done_rounded
                              : Icons.download_for_offline_outlined,
                          size: 14,
                        ),
                        label: Text(
                          widget.showOnlyDownloaded
                              ? l10n.downloadedCount(widget.downloadedChapterIds.length)
                              : l10n.onlyDownloaded,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: widget.showOnlyDownloaded ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        selected: widget.showOnlyDownloaded,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: widget.onToggleShowOnlyDownloaded,
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Page size selector (50 / 100 / Todos)
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pageSize,
                          borderRadius: BorderRadius.circular(12),
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
                  ],
                ),
              ),

              // Selection Action Bar (when chapters are multi-selected)
              if (_selectedChapterIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          final selectedList = widget.chapters
                              .where((c) => _selectedChapterIds.contains(c.id))
                              .toList();
                          widget.onDownloadSelected?.call(selectedList);
                          setState(() => _selectedChapterIds.clear());
                        },
                        icon: const Icon(Icons.download_rounded, size: 15),
                        label: Text(l10n.downloadSelected, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Chapters List (Virtualized ListView.builder)
        if (widget.isLoadingChapters)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.chaptersError != null)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.menu_book_outlined, color: theme.colorScheme.outline, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    widget.chaptersError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: widget.onRefreshChapters,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          )
        else if (paginatedChapters.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.showOnlyDownloaded ? Icons.download_done_rounded : Icons.menu_book_outlined,
                    size: 40,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.showOnlyDownloaded
                        ? l10n.noDownloadedChaptersForManga
                        : l10n.noChaptersAvailable,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginatedChapters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = paginatedChapters[index];
                final epNum = c.chapterNumber.toInt();
                final isRead = widget.progress >= epNum && epNum > 0;
                final isSelected = _selectedChapterIds.contains(c.id);

                return MangaChapterItem(
                  chapter: c,
                  isRead: isRead,
                  isDownloaded: widget.downloadedChapterIds.contains(c.id),
                  isDownloading: widget.downloadingChapterIds.contains(c.id),
                  canDownload: widget.selectedProvider != null,
                  borderRadius: 12,
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
          ),

        // Pagination Stepper Controls (if multiple pages)
        if (totalPages > 1) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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
          ),
        ],

        const SizedBox(height: 90),
      ],
    );
  }
}
