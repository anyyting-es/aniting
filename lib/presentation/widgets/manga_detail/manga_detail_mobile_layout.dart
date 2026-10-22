import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/banner_blur_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

import 'mobile/mobile_manga_chapters_section.dart';
import 'mobile/mobile_manga_header.dart';
import 'mobile/mobile_manga_hero_banner.dart';

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
  final void Function(List<MangaChapter>)? onDownloadSelected;
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
    this.onDownloadSelected,
    required this.onOpenEditModal,
    required this.onShowDetailsModal,
    required this.onContinueReading,
  });

  @override
  ConsumerState<MangaDetailMobileLayout> createState() =>
      _MangaDetailMobileLayoutState();
}

class _MangaDetailMobileLayoutState extends ConsumerState<MangaDetailMobileLayout> {
  static const String _prefHideReadChaptersKey = 'manga_hide_read_chapters';

  bool _isAscending = true;
  String _searchQuery = '';
  bool _hideRead = true;
  bool _isHeaderScrolled = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = SmoothScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onMangaScroll);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleLang = ref.watch(titleLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;

    final liveCollectionEntry = ref.watch(mangaCollectionProvider).whenOrNull(
          data: (entries) => entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
    final resolved = liveCollectionEntry ?? widget.entry ?? widget.initialEntry;
    final title = resolved?.displayTitle(titleLang) ?? 'Manga';
    final hasRealBanner = (resolved?.bannerImage != null && resolved!.bannerImage!.isNotEmpty);
    final bannerUrl = resolved?.bannerImage ?? resolved?.coverImage;
    final posterUrl = widget.initialEntry?.coverImage ?? resolved?.coverImage;
    final isBlurSetting = ref.watch(bannerBlurProvider);
    final shouldBlur = (!hasRealBanner && posterUrl != null) || isBlurSetting;
    final progress = resolved?.progress ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Passive Parallax Hero Banner (0 FPS at idle)
          MobileMangaHeroBanner(
            scrollController: _scrollController,
            bannerUrl: bannerUrl,
            shouldBlur: shouldBlur,
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
                    tooltip: l10n.details,
                    onPressed: widget.onShowDetailsModal,
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Poster & Header Section
              SliverToBoxAdapter(
                child: MobileMangaHeader(
                  resolved: resolved,
                  title: title,
                  posterUrl: posterUrl,
                  progress: progress,
                  hasChapters: widget.chapters.isNotEmpty,
                  onOpenEditModal: widget.onOpenEditModal,
                  onContinueReading: widget.onContinueReading,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Chapters Section (Controls, Search, Provider, Chapter list)
              SliverToBoxAdapter(
                child: MobileMangaChaptersSection(
                  providers: widget.providers,
                  selectedProvider: widget.selectedProvider,
                  isLoadingProviders: widget.isLoadingProviders,
                  chapters: widget.chapters,
                  isLoadingChapters: widget.isLoadingChapters,
                  chaptersError: widget.chaptersError,
                  progress: progress,
                  downloadedChapterIds: widget.downloadedChapterIds,
                  downloadingChapterIds: widget.downloadingChapterIds,
                  showOnlyDownloaded: widget.showOnlyDownloaded,
                  hideRead: _hideRead,
                  isAscending: _isAscending,
                  searchQuery: _searchQuery,
                  searchController: _searchController,
                  onToggleShowOnlyDownloaded: widget.onToggleShowOnlyDownloaded,
                  onToggleHideRead: (val) {
                    setState(() => _hideRead = val);
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setBool(_prefHideReadChaptersKey, val);
                    });
                  },
                  onToggleSort: () => setState(() => _isAscending = !_isAscending),
                  onSearchChanged: (val) => setState(() => _searchQuery = val),
                  onProviderChanged: widget.onProviderChanged,
                  onRefreshChapters: widget.onRefreshChapters,
                  onChapterClicked: widget.onChapterClicked,
                  onDownloadChapter: widget.onDownloadChapter,
                  onBatchDownload: widget.onBatchDownload,
                  onDownloadSelected: widget.onDownloadSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
