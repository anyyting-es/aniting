import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/presentation/screens/extensions_marketplace_screen.dart';

import 'desktop_manga_chapter_card.dart';
import 'manga_manual_match_dialog.dart';

class DesktopMangaChaptersTab extends ConsumerStatefulWidget {
  final int mediaId;
  final String mangaTitle;
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
  final VoidCallback onContinueReading;

  const DesktopMangaChaptersTab({
    super.key,
    required this.mediaId,
    required this.mangaTitle,
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
    required this.onContinueReading,
  });

  @override
  ConsumerState<DesktopMangaChaptersTab> createState() => _DesktopMangaChaptersTabState();
}

class _DesktopMangaChaptersTabState extends ConsumerState<DesktopMangaChaptersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final bool _isAscending = true;
  bool _showOnlyUnread = false;
  bool _showOnlyDownloaded = false;
  String? _selectedScanlator;
  final int _pageSize = 50;
  int _currentPage = 0;
  final Set<String> _selectedChapterIds = <String>{};

  @override
  void didUpdateWidget(covariant DesktopMangaChaptersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProvider?.id != widget.selectedProvider?.id) {
      _selectedChapterIds.clear();
      _selectedScanlator = null;
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _availableScanlators {
    final set = <String>{};
    for (final c in widget.chapters) {
      if (c.scanlator != null && c.scanlator!.trim().isNotEmpty) {
        set.add(c.scanlator!.trim());
      }
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<MangaChapter> get _filteredChapters {
    var list = List<MangaChapter>.from(widget.chapters);

    if (_selectedScanlator != null && _selectedScanlator!.isNotEmpty) {
      list = list.where((c) => c.scanlator?.trim() == _selectedScanlator).toList();
    }

    if (_showOnlyDownloaded) {
      list = list.where((c) => widget.downloadedChapterIds.contains(c.id)).toList();
    }

    if (_showOnlyUnread && widget.progress > 0) {
      list = list.where((c) => c.chapterNumber > widget.progress).toList();
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

    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Row 1: Source Dropdown, Refresh Source, Manual Match ──
        Row(
          children: [
            // Source Dropdown [ Source | ProviderName v ]
            if (widget.providers.isNotEmpty)
              GlassMenuAnchor(
                width: 220,
                items: widget.providers.map((p) {
                  final isCurrent = widget.selectedProvider?.id == p.id;
                  return GlassMenuItem(
                    label: p.name,
                    icon: Icon(
                      isCurrent ? AppIcons.checkCircleFilled(iconPack) : AppIcons.manga(iconPack),
                      size: 16,
                      color: isCurrent ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () => widget.onProviderChanged(p),
                  );
                }).toList(),
                builder: (context, controller) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: controller.open,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: pillBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.source,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 14,
                              color: isDark ? Colors.white.withValues(alpha: 0.2) : theme.colorScheme.outlineVariant,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            Text(
                              widget.selectedProvider?.name ?? l10n.source,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(width: 8),

            // Refresh Source Button [ ↻ Refresh source ]
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onRefreshChapters,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pillBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: isDark ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.refreshSource,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Manual Match Button [ 🔍 Manual match ]
            if (widget.selectedProvider != null)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    MangaManualMatchDialog.show(
                      context,
                      mediaId: widget.mediaId,
                      initialTitle: widget.mangaTitle,
                      provider: widget.selectedProvider!,
                      onMatched: widget.onRefreshChapters,
                    );
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: pillBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 15,
                          color: isDark ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.manualMatch,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // ── 2. Row 2: Scanlator Dropdown [ Scanlator | All v ] ──
        GlassMenuAnchor(
          width: 240,
          items: [
            GlassMenuItem(
              label: l10n.all,
              icon: Icon(
                _selectedScanlator == null ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 16,
                color: _selectedScanlator == null ? theme.colorScheme.primary : null,
              ),
              onPressed: () => setState(() => _selectedScanlator = null),
            ),
            for (final scanlator in _availableScanlators)
              GlassMenuItem(
                label: scanlator,
                icon: Icon(
                  _selectedScanlator == scanlator ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 16,
                  color: _selectedScanlator == scanlator ? theme.colorScheme.primary : null,
                ),
                onPressed: () => setState(() => _selectedScanlator = scanlator),
              ),
          ],
          builder: (context, controller) {
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: controller.open,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pillBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.scanlator,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 14,
                        color: isDark ? Colors.white.withValues(alpha: 0.2) : theme.colorScheme.outlineVariant,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Text(
                        _selectedScanlator ?? l10n.all,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ── 3. Row 3: Heading "Chapters" + "Continue reading" Pill Button ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.chapters,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),

            // White pill "Continue reading" button with black icon & text
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onContinueReading,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.continueReading,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ── 4. Row 4: Filter Chips & Rounded Search Bar ──
        Row(
          children: [
            // [ Show unread ] chip
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _showOnlyUnread = !_showOnlyUnread),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _showOnlyUnread
                        ? theme.colorScheme.primary.withValues(alpha: 0.22)
                        : pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showOnlyUnread ? theme.colorScheme.primary : pillBorder,
                      width: _showOnlyUnread ? 1.2 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _showOnlyUnread
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      l10n.showUnread,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _showOnlyUnread ? FontWeight.w700 : FontWeight.w500,
                        color: _showOnlyUnread ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // [ Show downloaded ] chip
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _showOnlyDownloaded = !_showOnlyDownloaded),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _showOnlyDownloaded
                        ? theme.colorScheme.primary.withValues(alpha: 0.22)
                        : pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showOnlyDownloaded ? theme.colorScheme.primary : pillBorder,
                      width: _showOnlyDownloaded ? 1.2 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _showOnlyDownloaded
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        size: 14,
                        color: _showOnlyDownloaded ? theme.colorScheme.primary : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.showDownloaded,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _showOnlyDownloaded ? FontWeight.w700 : FontWeight.w500,
                          color: _showOnlyDownloaded ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Rounded Search Bar
        SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: l10n.searchChapterPlaceholder,
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              filled: true,
              fillColor: pillBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: pillBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: pillBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        const SizedBox(height: 16),

        // ── Multi-selection Action Bar ──
        if (_selectedChapterIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
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

        // ── 5. Chapters Table (Header + Rows or Empty/Error State inside container) ──
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isLoadingChapters
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : widget.chaptersError != null
                  ? _buildErrorView(theme, l10n)
                  : paginatedChapters.isEmpty
                      ? _buildEmptyView(theme, l10n)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Column Headers
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const SizedBox(width: 32),
                                  Expanded(
                                    child: Text(
                                      l10n.chapterNameCol,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 170,
                                    child: Text(
                                      l10n.scanlatorCol,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      l10n.chapterNumberCol,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 72),
                                ],
                              ),
                            ),

                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                            ),

                            // Table Rows
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: paginatedChapters.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                thickness: 1,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.12),
                              ),
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
                          ],
                        ),
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

  Widget _buildErrorView(ThemeData theme, AppTranslations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: isDark ? Colors.white38 : theme.colorScheme.outline, size: 40),
            const SizedBox(height: 12),
            Text(
              widget.chaptersError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            M3EButton(
              onPressed: widget.onRefreshChapters,
              style: M3EButtonStyle.tonal,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme, AppTranslations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showOnlyDownloaded ? Icons.download_done_rounded : Icons.menu_book_outlined,
              size: 40,
              color: isDark ? Colors.white38 : theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              _showOnlyDownloaded ? l10n.noDownloadedChaptersForManga : l10n.noChaptersAvailable,
              style: TextStyle(
                color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
