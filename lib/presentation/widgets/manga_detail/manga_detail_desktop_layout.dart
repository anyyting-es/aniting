import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/core/utils/synopsis_utils.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_hero_banner.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_relations_tab.dart';
import 'desktop/desktop_manga_chapters_tab.dart';
import 'desktop/desktop_manga_characters_section.dart';
import 'desktop/desktop_manga_header.dart';
import 'desktop/desktop_manga_recommendations_row.dart';
import 'desktop/desktop_manga_sidebar.dart';
import 'package:aniting/core/theme/smooth_scroll_controller.dart';

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
  final void Function(List<MangaChapter>)? onDownloadSelected;
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
    this.onDownloadSelected,
    required this.onOpenEditModal,
    required this.onContinueReading,
  });

  @override
  ConsumerState<MangaDetailDesktopLayout> createState() =>
      _MangaDetailDesktopLayoutState();
}

class _MangaDetailDesktopLayoutState extends ConsumerState<MangaDetailDesktopLayout> {
  final ScrollController _scrollController = SmoothScrollController();
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final progress = (offset / 200.0).clamp(0.0, 1.0);
    if ((progress - _scrollProgressNotifier.value).abs() > 0.02 ||
        (offset <= 0 && _scrollProgressNotifier.value > 0) ||
        (offset >= 200 && _scrollProgressNotifier.value < 1.0)) {
      _scrollProgressNotifier.value = progress;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgressNotifier.dispose();
    super.dispose();
  }

  String _cleanHtml(String? html) {
    return cleanSynopsis(html);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
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

    final startDateMap = raw['startDate'] as Map<String, dynamic>?;
    String? startDateStr;
    if (startDateMap != null && startDateMap['year'] != null) {
      final y = startDateMap['year'];
      final m = startDateMap['month'] as int?;
      if (m != null && m >= 1 && m <= 12) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        startDateStr = '${months[m - 1]} $y';
      } else {
        startDateStr = '$y';
      }
    } else if (year != null) {
      startDateStr = '$year';
    }

    final romaji = resolvedEntry?.romajiTitle;
    final english = resolvedEntry?.englishTitle;
    final native = resolvedEntry?.nativeTitle;
    String? subtitleStr;
    if (titleLang == TitleLanguage.english) {
      subtitleStr = romaji ?? native;
    } else if (titleLang == TitleLanguage.romaji) {
      subtitleStr = english ?? native;
    } else {
      subtitleStr = english ?? romaji;
    }
    if (subtitleStr == title) {
      subtitleStr = null;
    }

    final iconPack = ref.watch(iconPackProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── 1. Full-Page Cinematic Backdrop (No harsh black cuts!) ───
          DesktopHeroBanner(
            bannerUrl: bannerUrl,
            isBlurredCover: isBlurredCover,
            scrollProgressListenable: _scrollProgressNotifier,
            scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
            isFullPage: true,
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
                    // Back button with elegant glass capsule styling
                    Padding(
                      padding: const EdgeInsets.only(top: 28, bottom: 20),
                      child: M3EIconButton(
                        decoration: M3EIconButtonDecoration(
                          backgroundColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.pressed)) {
                              return Colors.white.withValues(alpha: 0.24);
                            }
                            if (states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused)) {
                              return Colors.white.withValues(alpha: 0.18);
                            }
                            return Colors.white.withValues(alpha: 0.10);
                          }),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1.0,
                            ),
                          ),
                        ),
                        size: M3EIconButtonSize.sm,
                        icon: Icon(
                          AppIcons.arrowLeft(iconPack),
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: l10n.back,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // ── TOP SECTION: Cover Poster on Left + All Data on Right ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Poster Cover with [ ⋮ ] and [ 👤 ] buttons underneath
                        DesktopMangaSidebar(
                          mediaId: widget.mediaId,
                          title: title,
                          idMal: idMal,
                          coverUrl: coverUrl,
                          format: format,
                          status: status,
                          year: year,
                          score: score,
                          totalChapters: totalChapters,
                          totalVolumes: totalVolumes,
                          progress: progress,
                          onOpenEditModal: widget.onOpenEditModal,
                          onBatchDownload: widget.onBatchDownload,
                          showMetadata: false,
                          width: 220,
                        ),

                        const SizedBox(width: 32),

                        // Right: Title, Subtitle, Badges, Score/Genres, Synopsis, Format
                        Expanded(
                          child: DesktopMangaHeader(
                            title: title,
                            subtitleStr: subtitleStr,
                            progress: progress,
                            totalChapters: totalChapters,
                            userStatus: liveCollectionEntry?.status,
                            releaseStatus: status,
                            startDateStr: startDateStr,
                            score: score,
                            genres: resolvedEntry?.genres ?? const [],
                            description: description,
                            format: format,
                            onOpenEditModal: widget.onOpenEditModal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // ── BOTTOM SECTION: Two Columns (Chapters on Left, Characters on Right) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Controls & Chapters Table (flex: 62)
                        Expanded(
                          flex: 62,
                          child: DesktopMangaChaptersTab(
                            mediaId: widget.mediaId,
                            mangaTitle: title,
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
                            onDownloadSelected: widget.onDownloadSelected,
                            onContinueReading: widget.onContinueReading,
                          ),
                        ),

                        const SizedBox(width: 36),

                        // Right: Characters & Relations (flex: 38)
                        Expanded(
                          flex: 38,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Characters section header
                              Text(
                                l10n.charactersHeader,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DesktopMangaCharactersSection(
                                characters: charactersEdges,
                                isLoading: widget.isLoadingDetails,
                                mediaId: widget.mediaId,
                                bannerUrl: bannerUrl,
                              ),

                              // Relations (if available)
                              if (relationsEdges.isNotEmpty) ...[
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Icon(Icons.hub_outlined, size: 20, color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.relations,
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
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── RECOMMENDATIONS: Full-width horizontal scroll at the bottom ──
                    if (recommendationsEdges.isNotEmpty) ...[
                      const SizedBox(height: 44),
                      Text(
                        l10n.recommendations,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DesktopMangaRecommendationsRow(
                        recommendations: recommendationsEdges,
                        isLoading: widget.isLoadingDetails,
                      ),
                    ],
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
