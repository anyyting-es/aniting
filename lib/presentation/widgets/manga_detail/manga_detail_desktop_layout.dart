import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_characters_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_hero_banner.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_recommendations_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_relations_tab.dart';
import 'desktop/desktop_manga_action_bar.dart';
import 'desktop/desktop_manga_chapters_tab.dart';
import 'desktop/desktop_manga_header.dart';
import 'desktop/desktop_manga_sidebar.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';

class MangaDetailDesktopLayout extends ConsumerStatefulWidget {
  final int mediaId;
  final MangaEntry? entry;
  final MangaEntry? initialEntry;
  final bool isLoadingDetails;
  final List<MangaProvider> providers;
  final MangaProvider? selectedProvider;
  final List<MangaChapter> chapters;
  final bool isLoadingChapters;
  final String? chaptersError;
  final Set<String> downloadedChapterIds;
  final Set<String> downloadingChapterIds;
  final ValueChanged<MangaProvider?> onProviderChanged;
  final VoidCallback onRefreshChapters;
  final ValueChanged<MangaChapter> onChapterClicked;
  final ValueChanged<MangaChapter> onDownloadChapter;
  final VoidCallback onBatchDownload;
  final VoidCallback onOpenEditModal;
  final VoidCallback onContinueReading;

  const MangaDetailDesktopLayout({
    super.key,
    required this.mediaId,
    required this.entry,
    this.initialEntry,
    required this.isLoadingDetails,
    required this.providers,
    required this.selectedProvider,
    required this.chapters,
    required this.isLoadingChapters,
    required this.chaptersError,
    required this.downloadedChapterIds,
    required this.downloadingChapterIds,
    required this.onProviderChanged,
    required this.onRefreshChapters,
    required this.onChapterClicked,
    required this.onDownloadChapter,
    required this.onBatchDownload,
    required this.onOpenEditModal,
    required this.onContinueReading,
  });

  @override
  ConsumerState<MangaDetailDesktopLayout> createState() =>
      _MangaDetailDesktopLayoutState();
}

class _MangaDetailDesktopLayoutState extends ConsumerState<MangaDetailDesktopLayout> {
  final ScrollController _scrollController = SmoothScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    if ((offset - _scrollOffset).abs() > 3 ||
        (offset <= 0 && _scrollOffset > 0) ||
        (offset >= 250 && _scrollOffset < 250)) {
      setState(() {
        _scrollOffset = offset.clamp(0.0, 500.0);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _cleanHtml(String? html) {
    if (html == null) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</?i>'), '')
        .replaceAll(RegExp(r'</?b>'), '')
        .replaceAll(RegExp(r'</?p>'), '\n\n')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&#039;'), "'")
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleLang = ref.watch(titleLanguageProvider);

    final resolvedEntry = widget.entry ?? widget.initialEntry;
    final title = resolvedEntry?.displayTitle(titleLang) ?? 'Manga';

    final coverUrl = resolvedEntry?.coverImage;
    final bannerImage = resolvedEntry?.bannerImage;
    final hasRealBanner = bannerImage != null && bannerImage.isNotEmpty;
    final bannerUrl = hasRealBanner ? bannerImage : coverUrl;
    final isBlurredCover = !hasRealBanner && coverUrl != null;

    final score = resolvedEntry?.score;
    final format = resolvedEntry?.format ?? 'MANGA';
    final status = resolvedEntry?.status ?? 'RELEASING';
    final year = resolvedEntry?.year;
    final totalChapters = resolvedEntry?.totalChapters;
    final totalVolumes = resolvedEntry?.totalVolumes;

    final liveCollectionEntry = ref.watch(mangaCollectionProvider).whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
    final progress = liveCollectionEntry?.progress ?? resolvedEntry?.progress ?? 0;

    final description = _cleanHtml(resolvedEntry?.description);

    final raw = resolvedEntry?.rawMedia ?? {};
    final idMal = raw['idMal'] as int?;

    final charactersEdges = resolvedEntry?.characters.isNotEmpty == true
        ? resolvedEntry!.characters
        : ((raw['characters']?['edges'] as List?) ?? []);
    final relationsEdges = resolvedEntry?.relations.isNotEmpty == true
        ? resolvedEntry!.relations
        : ((raw['relations']?['edges'] as List?) ?? []);
    final recommendationsEdges = resolvedEntry?.recommendations.isNotEmpty == true
        ? resolvedEntry!.recommendations
        : ((raw['recommendations']?['edges'] as List?) ?? []);

    final subtitleParts = <String>[];
    if (year != null) subtitleParts.add('$year');
    subtitleParts.add(format.replaceAll('_', ' '));
    final subtitleStr = subtitleParts.join(' • ').toUpperCase();

    final scrollProgress = (_scrollOffset / 200.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── 1. Panoramic Top Hero Backdrop with scroll-driven dissolve ───
          DesktopHeroBanner(
            bannerUrl: bannerUrl,
            isBlurredCover: isBlurredCover,
            scrollProgress: scrollProgress,
            scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
          ),

          // ─── 2. Main Scrollable Container (1580px max-width) ───
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1580),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(36, 0, 36, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button (clean icon without heavy background)
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 120),
                      child: IconButton(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          hoverColor: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
                          highlightColor: isDark ? Colors.white.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHigh,
                        ),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: bannerUrl != null ? Colors.white : (isDark ? Colors.white : theme.colorScheme.onSurface),
                          size: 22,
                          shadows: bannerUrl != null
                              ? const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        tooltip: 'Volver',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // ── TOP SECTION: Cover Poster on Left + All Data on Right ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Poster Cover
                        DesktopMangaSidebar(
                          coverUrl: coverUrl,
                          format: format,
                          status: status,
                          year: year,
                          score: score,
                          totalChapters: totalChapters,
                          totalVolumes: totalVolumes,
                          progress: progress,
                          onOpenEditModal: widget.onOpenEditModal,
                          showMetadata: false,
                          width: 220,
                        ),

                        const SizedBox(width: 32),

                        // Right: Header + Action Bar
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DesktopMangaHeader(
                                subtitleStr: subtitleStr,
                                title: title,
                                genres: resolvedEntry?.genres ?? const [],
                                description: description,
                                format: format,
                                status: status,
                                year: year,
                                score: score,
                                totalChapters: totalChapters,
                                totalVolumes: totalVolumes,
                              ),
                              const SizedBox(height: 16),
                              DesktopMangaActionBar(
                                mediaId: widget.mediaId,
                                title: title,
                                progress: progress,
                                idMal: idMal,
                                onContinueReading: widget.onContinueReading,
                                onOpenEditEntryModal: (_) => widget.onOpenEditModal(),
                                onBatchDownload: widget.onBatchDownload,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // ── BOTTOM SECTION: Two Columns ──
                    // Left column: Chapters in their box
                    // Right column: Characters, then Related, then Similar Works
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Chapters Box
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.35)
                                  : theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.list_alt_rounded, size: 20, color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Capítulos',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.chapters.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${widget.chapters.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                DesktopMangaChaptersTab(
                                  mediaId: widget.mediaId,
                                  providers: widget.providers,
                                  selectedProvider: widget.selectedProvider,
                                  chapters: widget.chapters,
                                  isLoadingChapters: widget.isLoadingChapters,
                                  chaptersError: widget.chaptersError,
                                  progress: progress,
                                  downloadedChapterIds: widget.downloadedChapterIds,
                                  downloadingChapterIds: widget.downloadingChapterIds,
                                  onProviderChanged: widget.onProviderChanged,
                                  onRefreshChapters: widget.onRefreshChapters,
                                  onChapterClicked: widget.onChapterClicked,
                                  onDownloadChapter: widget.onDownloadChapter,
                                  onBatchDownload: widget.onBatchDownload,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 32),

                        // Right: Characters, Related, Recommendations
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Personajes
                              Row(
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 20, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Personajes',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              DesktopCharactersTab(
                                characters: charactersEdges,
                                isLoading: widget.isLoadingDetails,
                              ),

                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Icon(Icons.hub_outlined, size: 20, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Relaciones',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              DesktopRelationsTab(
                                relations: relationsEdges,
                                isLoading: widget.isLoadingDetails,
                              ),

                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Obras similares',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              DesktopRecommendationsTab(
                                recommendations: recommendationsEdges,
                                isLoading: widget.isLoadingDetails,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
