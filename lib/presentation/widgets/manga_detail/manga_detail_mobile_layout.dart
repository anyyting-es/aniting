import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/banner_blur_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/presentation/widgets/manga/manga_chapter_item.dart';

class MangaDetailMobileLayout extends ConsumerStatefulWidget {
  final int mediaId;
  final MangaEntry? entry;
  final MangaEntry? initialEntry;
  final bool isLoadingDetails;
  final List<MangaProvider> providers;
  final MangaProvider? selectedProvider;
  final bool isLoadingProviders;
  final List<MangaChapter> chapters;
  final bool isLoadingChapters;
  final String? chaptersError;
  final Set<String> downloadedChapterIds;
  final Set<String> downloadingChapterIds;
  final bool showOnlyDownloaded;
  final ValueChanged<bool> onToggleShowOnlyDownloaded;
  final ValueChanged<MangaProvider?> onProviderChanged;
  final VoidCallback onRefreshChapters;
  final ValueChanged<MangaChapter> onChapterClicked;
  final ValueChanged<MangaChapter> onDownloadChapter;
  final VoidCallback onBatchDownload;
  final VoidCallback onOpenEditModal;
  final VoidCallback onShowDetailsModal;
  final VoidCallback onContinueReading;

  const MangaDetailMobileLayout({
    super.key,
    required this.mediaId,
    required this.entry,
    this.initialEntry,
    required this.isLoadingDetails,
    required this.providers,
    required this.selectedProvider,
    required this.isLoadingProviders,
    required this.chapters,
    required this.isLoadingChapters,
    required this.chaptersError,
    required this.downloadedChapterIds,
    required this.downloadingChapterIds,
    required this.showOnlyDownloaded,
    required this.onToggleShowOnlyDownloaded,
    required this.onProviderChanged,
    required this.onRefreshChapters,
    required this.onChapterClicked,
    required this.onDownloadChapter,
    required this.onBatchDownload,
    required this.onOpenEditModal,
    required this.onShowDetailsModal,
    required this.onContinueReading,
  });

  @override
  ConsumerState<MangaDetailMobileLayout> createState() =>
      _MangaDetailMobileLayoutState();
}

class _MangaDetailMobileLayoutState extends ConsumerState<MangaDetailMobileLayout>
    with SingleTickerProviderStateMixin {
  static const String _prefHideReadChaptersKey = 'manga_hide_read_chapters';

  bool _isAscending = true;
  String _searchQuery = '';
  bool _hideRead = true;
  bool _isHeaderScrolled = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _bannerAnimController;
  late final Animation<double> _bannerScaleAnimation;
  late final Animation<double> _bannerTranslateAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onMangaScroll);
    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _bannerScaleAnimation = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeInOutSine,
    );

    _bannerTranslateAnimation = Tween<double>(begin: -8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _bannerAnimController,
        curve: Curves.easeInOutSine,
      ),
    );

    SharedPreferences.getInstance().then((prefs) {
      final savedHide = prefs.getBool(_prefHideReadChaptersKey);
      if (savedHide != null && mounted) {
        setState(() => _hideRead = savedHide);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onMangaScroll);
    _bannerAnimController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMangaScroll() {
    if (!_scrollController.hasClients) return;
    final isScrolled = _scrollController.offset > 120.0;
    if (isScrolled != _isHeaderScrolled) {
      setState(() => _isHeaderScrolled = isScrolled);
    }
  }

  List<MangaChapter> get _filteredChapters {
    var list = List<MangaChapter>.from(widget.chapters);
    final liveCol = ref.read(mangaCollectionProvider).whenOrNull(
          data: (entries) => entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
    final progress = liveCol?.progress ?? widget.entry?.progress ?? 0;

    if (widget.showOnlyDownloaded) {
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
    } else if (_hideRead && progress > 0) {
      list = list.where((c) => c.chapterNumber > progress).toList();
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
    final colors = context.themeColors;
    final borderRadius = colors.borderRadius;
    final titleLang = ref.watch(titleLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;
    final textShadows = isDark
        ? [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4)]
        : null;

    final liveCollectionEntry = ref.watch(mangaCollectionProvider).whenOrNull(
          data: (entries) => entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
    final resolved = liveCollectionEntry ?? widget.entry ?? widget.initialEntry;
    final title = resolved?.displayTitle(titleLang) ?? 'Manga';
    final hasRealBanner = (resolved?.bannerImage != null && resolved!.bannerImage!.isNotEmpty);
    final bannerUrl = resolved?.bannerImage ?? resolved?.coverImage;
    final posterUrl = resolved?.coverImage;
    final isBlurSetting = ref.watch(bannerBlurProvider);
    final shouldBlur = (!hasRealBanner && posterUrl != null) || isBlurSetting;

    final progress = resolved?.progress ?? 0;
    final totalChapters = resolved?.totalChapters;
    final format = resolved?.format ?? 'MANGA';
    final year = resolved?.year;
    final status = resolved?.status ?? 'RELEASING';
    final score = resolved?.score;

    final displayChapters = _filteredChapters;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fixed Cinematic Parallax Banner
          Positioned(
            top: -16,
            left: 0,
            right: 0,
            height: 345,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: ClipRect(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bannerAnimController, _scrollController]),
                    builder: (context, _) {
                      final scrollOffset = _scrollController.hasClients
                          ? _scrollController.offset.clamp(0.0, double.infinity)
                          : 0.0;
                      final ambientScale = 1.0 + (_bannerScaleAnimation.value * 0.05);
                      final ambientTranslateY = _bannerTranslateAnimation.value;
                      final parallaxTranslateY =
                          scrollOffset > 0 ? -scrollOffset * 0.35 : 0.0;
                      final totalTranslateY = ambientTranslateY + parallaxTranslateY;
                      final scrollDarkening = (scrollOffset / 200.0).clamp(0.0, 1.0);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Parallax Banner Image (strictly clipped to bounds to avoid blur bleed)
                          Transform.translate(
                            offset: Offset(0, totalTranslateY),
                            child: Transform.scale(
                              scale: ambientScale,
                              alignment: Alignment.topCenter,
                              child: bannerUrl != null
                                  ? (shouldBlur
                                      ? ClipRect(
                                          child: ImageFiltered(
                                            imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                                            child: Transform.scale(
                                              scale: 1.25,
                                              child: CachedNetworkImage(
                                                imageUrl: bannerUrl,
                                                fit: BoxFit.cover,
                                                alignment: Alignment.topCenter,
                                                memCacheWidth: 1080,
                                                errorWidget: (_, _, _) =>
                                                    Container(color: theme.colorScheme.surfaceContainer),
                                              ),
                                            ),
                                          ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: bannerUrl,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topCenter,
                                          memCacheWidth: 1080,
                                          errorWidget: (_, _, _) =>
                                              Container(color: theme.colorScheme.surfaceContainer),
                                        ))
                                  : Container(color: theme.colorScheme.surfaceContainer),
                            ),
                          ),

                          // Stationary Multi-Stop Cinematic Gradient into Theme Background
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        Colors.black.withValues(alpha: 0.65),
                                        Colors.black.withValues(alpha: 0.15),
                                        Colors.black.withValues(alpha: 0.45),
                                        Colors.black.withValues(alpha: 0.85),
                                        theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
                                        theme.scaffoldBackgroundColor,
                                      ]
                                    : [
                                        Colors.black.withValues(alpha: 0.35),
                                        Colors.white.withValues(alpha: 0.10),
                                        Colors.white.withValues(alpha: 0.50),
                                        Colors.white.withValues(alpha: 0.88),
                                        theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
                                        theme.scaffoldBackgroundColor,
                                      ],
                                stops: const [0.0, 0.20, 0.45, 0.70, 0.90, 1.0],
                              ),
                            ),
                          ),

                          // Scroll-driven darkening: seamlessly turns into active theme background
                          Container(
                            color: theme.scaffoldBackgroundColor.withValues(alpha: scrollDarkening),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 2. Scrollable Content
          CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Top Transparent App Bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                pinned: true,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : (_isHeaderScrolled ? Brightness.dark : Brightness.light),
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : (_isHeaderScrolled ? Brightness.light : Brightness.dark),
                  systemNavigationBarColor: theme.scaffoldBackgroundColor,
                  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: (isDark || !_isHeaderScrolled)
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    size: 22,
                    shadows: (isDark || !_isHeaderScrolled)
                        ? const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: (isDark || !_isHeaderScrolled)
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      size: 22,
                      shadows: (isDark || !_isHeaderScrolled)
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    tooltip: 'Detalles',
                    onPressed: widget.onShowDetailsModal,
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Poster & Header Metadata Area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Poster
                      Container(
                        width: 125,
                        height: 185,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(borderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                                memCacheHeight: 440,
                                errorWidget: (_, _, _) => Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.menu_book_rounded, size: 40),
                                ),
                              )
                            : Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.menu_book_rounded, size: 40),
                              ),
                      ),

                      const SizedBox(width: 16),

                      // Foot-aligned Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Title
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: textShadows,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Line 1: Year • Format • Status
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    color: iconColor, size: 12),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    [
                                      if (year != null) '$year',
                                      format,
                                      l10n.formatStatus(status),
                                    ].join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11.5,
                                      shadows: textShadows,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Line 2: Rating Score & Genres
                            Row(
                              children: [
                                Icon(
                                  Icons.favorite_rounded,
                                  color: isDark ? iconColor : theme.colorScheme.primary,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    score != null && score > 0
                                        ? '${score.toStringAsFixed(1)} • ${resolved?.genres.take(2).join(', ') ?? ""}'
                                        : (resolved?.genres.take(2).join(', ') ?? 'Manga'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11.5,
                                      shadows: textShadows,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Line 3: Chapters Progress & Edit Status
                            InkWell(
                              onTap: widget.onOpenEditModal,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : theme.colorScheme.primaryContainer
                                                .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : theme.colorScheme.outlineVariant
                                                  .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit_note_rounded,
                                        size: 13,
                                        color: isDark
                                            ? Colors.white
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        totalChapters != null && totalChapters > 0
                                            ? '$progress / $totalChapters ${l10n.chapters.toLowerCase()}'
                                            : '${l10n.chapter} $progress',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: titleColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          shadows: textShadows,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Continue Reading Button
              if (progress > 0 && widget.chapters.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: widget.onContinueReading,
                        icon: const Icon(Icons.menu_book_rounded, size: 20),
                        label: Text('Continuar Leyendo • Cap. ${progress + 1}'),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (widget.isLoadingProviders)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (widget.providers.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.extension_off_rounded,
                              color: theme.colorScheme.primary, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noMangaProviders,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Instala una extensión de manga para leer capítulos.',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ExtensionsMarketplaceScreen()),
                              ).then((_) => widget.onRefreshChapters());
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Explorar Extensiones'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Chapters Header & Search Filters with Provider Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  l10n.chapters,
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                if (displayChapters.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius:
                                          BorderRadius.circular(borderRadius),
                                    ),
                                    child: Text(
                                      '${displayChapters.length}',
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
                                if (progress > 0)
                                  IconButton(
                                    tooltip: _hideRead
                                        ? 'Mostrar leídos ($progress)'
                                        : 'Ocultar leídos ($progress)',
                                    icon: Icon(
                                      _hideRead
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 20,
                                      color: _hideRead
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () {
                                      setState(() => _hideRead = !_hideRead);
                                      SharedPreferences.getInstance().then((prefs) {
                                        prefs.setBool(_prefHideReadChaptersKey, _hideRead);
                                      });
                                    },
                                  ),
                                IconButton(
                                  tooltip: _isAscending
                                      ? 'Más recientes primero'
                                      : 'Primeros capítulos primero',
                                  icon: Icon(
                                    _isAscending
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() {
                                    _isAscending = !_isAscending;
                                  }),
                                ),
                                IconButton(
                                  tooltip: 'Recargar capítulos',
                                  icon: const Icon(Icons.refresh_rounded, size: 20),
                                  onPressed: widget.onRefreshChapters,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Slim & Compact Search Input & Provider Selector Row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _searchController,
                                  keyboardType: TextInputType.text,
                                  style: const TextStyle(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar cap...',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                    prefixIcon:
                                        const Icon(Icons.search_rounded, size: 17),
                                    prefixIconConstraints:
                                        const BoxConstraints(minWidth: 32, minHeight: 32),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded,
                                                size: 15),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 28, minHeight: 28),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          (borderRadius * 0.75).clamp(0.0, 14.0)),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (val) => setState(() {
                                    _searchQuery = val;
                                  }),
                                ),
                              ),
                            ),
                            if (widget.providers.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                height: 36,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(
                                      (borderRadius * 0.75).clamp(0.0, 14.0)),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<MangaProvider>(
                                    value: widget.selectedProvider,
                                    icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16),
                                    borderRadius:
                                        BorderRadius.circular(borderRadius),
                                    isDense: true,
                                    items: widget.providers.map((p) {
                                      return DropdownMenuItem<MangaProvider>(
                                        value: p,
                                        child: ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 120),
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (p) {
                                      widget.onProviderChanged(p);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (widget.downloadedChapterIds.isNotEmpty ||
                            widget.showOnlyDownloaded ||
                            (widget.selectedProvider != null && widget.chapters.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          // Secondary Filters row (Downloaded, Batch Download)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (widget.downloadedChapterIds.isNotEmpty ||
                                    widget.showOnlyDownloaded) ...[
                                  FilterChip(
                                    avatar: Icon(
                                      widget.showOnlyDownloaded
                                          ? Icons.download_done_rounded
                                          : Icons.download_for_offline_outlined,
                                      size: 14,
                                      color: widget.showOnlyDownloaded
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    label: Text(
                                      widget.showOnlyDownloaded
                                          ? 'Descargados (${widget.downloadedChapterIds.length})'
                                          : 'Solo descargados',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: widget.showOnlyDownloaded
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: widget.showOnlyDownloaded
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    selected: widget.showOnlyDownloaded,
                                    selectedColor: theme.colorScheme.primary,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            (borderRadius * 0.75).clamp(0.0, 14.0))),
                                    onSelected: (val) {
                                      widget.onToggleShowOnlyDownloaded(val);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.selectedProvider != null &&
                                    widget.chapters.isNotEmpty) ...[
                                  ActionChip(
                                    avatar: Icon(
                                      Icons.download_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    label: const Text(
                                      'Descargar lote',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            (borderRadius * 0.75).clamp(0.0, 14.0))),
                                    onPressed: widget.onBatchDownload,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Chapters List View
              if (widget.isLoadingChapters)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (widget.chaptersError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              color: theme.colorScheme.outline, size: 40),
                          const SizedBox(height: 8),
                          Text(widget.chaptersError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: widget.onRefreshChapters,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (displayChapters.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.showOnlyDownloaded
                                ? Icons.download_done_rounded
                                : Icons.menu_book_outlined,
                            size: 40,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.showOnlyDownloaded
                                ? 'No hay capítulos descargados para esta obra'
                                : 'No hay capítulos disponibles',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.showOnlyDownloaded) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                widget.onToggleShowOnlyDownloaded(false);
                              },
                              icon: const Icon(Icons.list_rounded, size: 18),
                              label: const Text('Ver todos los capítulos'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(displayChapters.length, (index) {
                          final c = displayChapters[index];
                          final epNum = c.chapterNumber.toInt();
                          final isRead = progress >= epNum && epNum > 0;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                Divider(
                                  height: 1,
                                  indent: 14,
                                  endIndent: 14,
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.2),
                                ),
                              MangaChapterItem(
                                chapter: c,
                                isRead: isRead,
                                isDownloaded:
                                    widget.downloadedChapterIds.contains(c.id),
                                isDownloading:
                                    widget.downloadingChapterIds.contains(c.id),
                                canDownload: widget.selectedProvider != null,
                                borderRadius: borderRadius,
                                onTap: () => widget.onChapterClicked(c),
                                onDownload: () => widget.onDownloadChapter(c),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
