import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';

import 'desktop_manga_chapter_card.dart';

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
  });

  @override
  ConsumerState<DesktopMangaChaptersTab> createState() => _DesktopMangaChaptersTabState();
}

class _DesktopMangaChaptersTabState extends ConsumerState<DesktopMangaChaptersTab> {
  static const String _prefHideReadChaptersKey = 'manga_hide_read_chapters';
  static const int _chaptersBlockSize = 30;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAscending = true;
  bool _hideRead = true;
  bool _showOnlyDownloaded = false;
  int _selectedBlockIndex = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final savedHide = prefs.getBool(_prefHideReadChaptersKey);
      if (savedHide != null && mounted) {
        setState(() => _hideRead = savedHide);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatChapterNum(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toString();
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
    } else if (_hideRead && widget.progress > 0) {
      list = list.where((c) => c.chapterNumber > widget.progress).toList();
    }

    if (_isAscending) {
      list.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    } else {
      list.sort((a, b) => b.chapterNumber.compareTo(a.chapterNumber));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    if (widget.providers.isEmpty && !widget.isLoadingChapters) {
      return _buildNoProvidersView(theme, l10n);
    }

    final allFiltered = _filteredChapters;
    final totalBlocks = (allFiltered.length / _chaptersBlockSize).ceil();
    final currentBlockIndex = _selectedBlockIndex.clamp(0, totalBlocks > 0 ? totalBlocks - 1 : 0);

    final List<MangaChapter> displayChapters;
    if (totalBlocks <= 1) {
      displayChapters = allFiltered;
    } else {
      final start = currentBlockIndex * _chaptersBlockSize;
      final end = (start + _chaptersBlockSize).clamp(0, allFiltered.length);
      displayChapters = allFiltered.sublist(start, end);
    }

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Top Controls Bar: Provider Dropdown + Search + Sort + Refresh ──
        Row(
          children: [
            // Provider Dropdown
            if (widget.providers.isNotEmpty) ...[
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MangaProvider>(
                    value: widget.selectedProvider,
                    dropdownColor: theme.colorScheme.surfaceContainer,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    items: widget.providers.map((p) {
                      return DropdownMenuItem<MangaProvider>(
                        value: p,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.extension_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (p) {
                      setState(() => _selectedBlockIndex = 0);
                      widget.onProviderChanged(p);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Search chapters TextField
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Buscar o N° de capítulo...',
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
                                _selectedBlockIndex = 0;
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _selectedBlockIndex = 0;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Asc / Desc Sort Button
            IconButton(
              tooltip: _isAscending ? 'Más antiguos primero' : 'Más recientes primero',
              style: IconButton.styleFrom(
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                _selectedBlockIndex = 0;
              }),
            ),
            const SizedBox(width: 6),

            // Refresh Chapters Button
            IconButton(
              tooltip: 'Recargar capítulos',
              style: IconButton.styleFrom(
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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

        // ── 2. Filters Wrap (Ocultar leídos, Solo descargados, Descargar, Conteo) ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.progress > 0) ...[
              FilterChip(
                avatar: Icon(
                  _hideRead ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 14,
                  color: _hideRead ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  _hideRead ? 'Ocultando leídos (${widget.progress})' : 'Ocultar leídos (${widget.progress})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _hideRead ? FontWeight.w700 : FontWeight.w500,
                    color: _hideRead ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: _hideRead,
                selectedColor: theme.colorScheme.primaryContainer,
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                showCheckmark: false,
                side: BorderSide(
                  color: _hideRead
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (val) {
                  setState(() {
                    _hideRead = val;
                    _selectedBlockIndex = 0;
                  });
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setBool(_prefHideReadChaptersKey, val);
                  });
                },
              ),
            ],

            if (widget.downloadedChapterIds.isNotEmpty || _showOnlyDownloaded) ...[
              FilterChip(
                avatar: Icon(
                  _showOnlyDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_outlined,
                  size: 14,
                  color: _showOnlyDownloaded ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  _showOnlyDownloaded
                      ? 'Descargados (${widget.downloadedChapterIds.length})'
                      : 'Solo descargados (${widget.downloadedChapterIds.length})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _showOnlyDownloaded ? FontWeight.w700 : FontWeight.w500,
                    color: _showOnlyDownloaded ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: _showOnlyDownloaded,
                selectedColor: theme.colorScheme.primaryContainer,
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                showCheckmark: false,
                side: BorderSide(
                  color: _showOnlyDownloaded
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (val) {
                  setState(() {
                    _showOnlyDownloaded = val;
                    _selectedBlockIndex = 0;
                  });
                },
              ),
            ],

            if (widget.selectedProvider != null && widget.chapters.isNotEmpty) ...[
              ActionChip(
                avatar: Icon(
                  Icons.download_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Descargar lote',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onPressed: widget.onBatchDownload,
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                '${allFiltered.length} capítulos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ── 3. 30-Chapter Pagination Bar ──
        if (totalBlocks > 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.chevron_left_rounded, size: 22, color: theme.colorScheme.onSurface),
                  tooltip: '30 anteriores',
                  onPressed: currentBlockIndex > 0
                      ? () => setState(() => _selectedBlockIndex = currentBlockIndex - 1)
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: totalBlocks,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final isSelected = i == currentBlockIndex;
                        final start = i * _chaptersBlockSize;
                        final end = (start + _chaptersBlockSize).clamp(0, allFiltered.length);
                        final firstEp = allFiltered[start];
                        final lastEp = allFiltered[end - 1];
                        final startNum = _formatChapterNum(firstEp.chapterNumber);
                        final endNum = _formatChapterNum(lastEp.chapterNumber);
                        final label = startNum == endNum ? 'Cap. $startNum' : '$startNum - $endNum';

                        return ChoiceChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerLow,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedBlockIndex = i);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.chevron_right_rounded, size: 22, color: theme.colorScheme.onSurface),
                  tooltip: 'Siguientes 30',
                  onPressed: currentBlockIndex < totalBlocks - 1
                      ? () => setState(() => _selectedBlockIndex = currentBlockIndex + 1)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 4. Chapters Grid / States ──
        if (widget.isLoadingChapters)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (widget.chaptersError != null)
          _buildErrorView(theme)
        else if (displayChapters.isEmpty)
          _buildEmptyView()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayChapters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final c = displayChapters[index];
              final epNum = c.chapterNumber.toInt();
              final isRead = widget.progress >= epNum && epNum > 0;

              return DesktopMangaChapterCard(
                chapter: c,
                isRead: isRead,
                isDownloaded: widget.downloadedChapterIds.contains(c.id),
                isDownloading: widget.downloadingChapterIds.contains(c.id),
                canDownload: widget.selectedProvider != null,
                onTap: () => widget.onChapterClicked(c),
                onDownload: () => widget.onDownloadChapter(c),
              );
            },
          ),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Instala una extensión de manga para leer capítulos en tu biblioteca.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExtensionsMarketplaceScreen()),
                ).then((_) => widget.onRefreshChapters());
              },
              icon: Icon(Icons.download_rounded, size: 18, color: theme.colorScheme.onPrimary),
              label: Text(
                'Explorar Extensiones de Manga',
                style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
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
            Icon(Icons.menu_book_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 40),
            const SizedBox(height: 12),
            Text(
              widget.chaptersError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: widget.onRefreshChapters,
              icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onPrimary),
              label: Text(
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showOnlyDownloaded ? Icons.download_done_rounded : Icons.menu_book_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _showOnlyDownloaded
                  ? 'No hay capítulos descargados para esta obra'
                  : 'No se encontraron capítulos con los filtros actuales',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13.5),
              textAlign: TextAlign.center,
            ),
            if (_showOnlyDownloaded || _searchQuery.isNotEmpty || _hideRead) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : theme.colorScheme.outlineVariant,
                  ),
                ),
                onPressed: () => setState(() {
                  _showOnlyDownloaded = false;
                  _hideRead = false;
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedBlockIndex = 0;
                }),
                icon: const Icon(Icons.list_rounded, size: 18),
                label: const Text('Restablecer filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
