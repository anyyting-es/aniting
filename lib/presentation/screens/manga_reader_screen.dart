import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/download_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/manga_reader_preferences_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/manga/manga_keep_alive_page.dart';
import 'package:seanime_app/presentation/widgets/manga/manga_reader_settings_sheet.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final int mediaId;
  final String mangaTitle;
  final String provider;
  final MangaChapter chapter;
  final List<MangaChapter> allChapters;
  final int initialPage;

  const MangaReaderScreen({
    super.key,
    required this.mediaId,
    required this.mangaTitle,
    required this.provider,
    required this.chapter,
    required this.allChapters,
    this.initialPage = 1,
    this.coverImage,
  });

  final String? coverImage;

  static Future<void> navigate(
    BuildContext context, {
    required int mediaId,
    required String mangaTitle,
    required String provider,
    required MangaChapter chapter,
    required List<MangaChapter> allChapters,
    int initialPage = 1,
    String? coverImage,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          mediaId: mediaId,
          mangaTitle: mangaTitle,
          provider: provider,
          chapter: chapter,
          allChapters: allChapters,
          initialPage: initialPage,
          coverImage: coverImage,
        ),
      ),
    );
  }

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  late MangaChapter _currentChapter;
  List<MangaPage> _pages = [];
  bool _isLoading = true;
  String? _error;
  bool _showControls = true;
  final ScrollController _scrollController = ScrollController();
  late final PageController _pageController;
  int _currentPage = 1;
  bool _hasUpdatedProgress = false;
  final Set<int> _precachedIndexes = <int>{};
  int _precacheGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Expandir el límite de memoria del ImageCache de Flutter (500MB y 400 imágenes)
    // para retener en RAM todas las páginas del capítulo decodificadas sin descartes.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 500 * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSize = 400;

    _currentChapter = widget.chapter;
    _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
    final startIdx = _currentPage - 1;
    _pageController = PageController(initialPage: startIdx > 0 ? startIdx : 0);
    _scrollController.addListener(_onScroll);
    _loadPages(widget.initialPage);
    _applySystemUiMode();
  }

  void _saveSessionToPreferences() {
    try {
      final chNum = _currentChapter.chapterNumber;
      final chText = chNum % 1 == 0 ? chNum.toInt().toString() : chNum.toString();
      ref.read(lastSessionProvider.notifier).saveSession(
        LastSessionItem(
          mediaType: 'MANGA',
          mediaId: widget.mediaId,
          title: widget.mangaTitle,
          coverImage: widget.coverImage,
          chapterNumber: _currentChapter.chapterNumber,
          chapterId: _currentChapter.id,
          mangaProvider: widget.provider,
          page: _currentPage,
          subtitle: 'Capítulo $chText • Pág $_currentPage',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _precacheGeneration++;
    // Restaurar límites estándar del ImageCache de Flutter al salir del lector
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSize = 1000;

    // Ensure progress is recorded if user read into the chapter
    _saveSessionToPreferences();
    if (_currentPage >= 2 || _hasUpdatedProgress) {
      _saveProgress();
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    // Restore system UI on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _applySystemUiMode() {
    final prefs = ref.read(mangaReaderPreferencesProvider);
    switch (prefs.statusBarMode) {
      case MangaStatusBarMode.hidden:
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        break;
      case MangaStatusBarMode.visible:
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        break;
      case MangaStatusBarMode.smart:
        if (_showControls) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        break;
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    _applySystemUiMode();
  }

  void _onScroll() {
    if (_pages.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll > 0) {
      final fraction = (currentScroll / maxScroll).clamp(0.0, 1.0);
      final pageIndex = (fraction * (_pages.length - 1)).round() + 1;
      if (pageIndex != _currentPage && mounted) {
        setState(() => _currentPage = pageIndex);
        _saveSessionToPreferences();
        _precachePagesAround(pageIndex - 1);
      }

      // Sync upon reaching penultimate page or >= 80% of webtoon scroll
      final isNearEnd = _pages.length <= 2
          ? fraction > 0.50
          : (pageIndex >= _pages.length - 1 || fraction >= 0.80);

      if (isNearEnd && !_hasUpdatedProgress) {
        _hasUpdatedProgress = true;
        _saveProgress();
      }
    }
  }

  void _onPageChanged(int index) {
    if (index < _pages.length) {
      final pageNumber = index + 1;
      setState(() => _currentPage = pageNumber);
      _saveSessionToPreferences();
      _precachePagesAround(index);

      // Sync upon reaching penultimate page or last page
      final isNearEnd = _pages.length <= 2
          ? pageNumber >= _pages.length
          : (pageNumber >= _pages.length - 1 || (pageNumber / _pages.length) >= 0.80);

      if (isNearEnd && !_hasUpdatedProgress) {
        _hasUpdatedProgress = true;
        _saveProgress();
      }
    }
  }

  Future<void> _saveProgress() async {
    _saveSessionToPreferences();
    final epNum = _currentChapter.chapterNumber.toInt();
    if (epNum > 0) {
      // 1. Guardar en almacenamiento local (SharedPreferences) para soporte offline / sin login
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentSaved = prefs.getInt('manga_local_progress_${widget.mediaId}') ?? 0;
        if (epNum > currentSaved) {
          await prefs.setInt('manga_local_progress_${widget.mediaId}', epNum);
        }
      } catch (e) {
        debugPrint('Error saving local manga progress: $e');
      }

      // 2. Sincronizar con Seanime server y trackers conectados (AniList, etc.)
      try {
        final repo = ref.read(repositoryProvider);
        await repo.updateMangaProgress(
          mediaId: widget.mediaId,
          chapterNumber: epNum,
        );
        ref.invalidate(mangaCollectionProvider);
        ref.invalidate(continueReadingMangaProvider);
      } catch (e) {
        debugPrint('Error syncing manga progress with trackers: $e');
      }
    }
  }

  String _resolvePageUrl(MangaPage page) {
    if (page.url.startsWith('http')) return page.url;
    final localFile = File(page.url);
    if (localFile.existsSync()) return page.url;
    final serverManager = ref.read(serverManagerProvider);
    final cleanPath = page.url.startsWith('/') ? page.url.substring(1) : page.url;
    return 'http://${serverManager.host}:${serverManager.port}/manga-downloads/$cleanPath';
  }

  void _preloadEntireChapter(List<MangaPage> pages, int initialPage) {
    if (!mounted || pages.isEmpty) return;
    final currentGen = ++_precacheGeneration;

    // 1. Prioridad Inmediata: la página actual y las 4 siguientes para que el inicio sea instantáneo
    final startIdx = (initialPage - 1).clamp(0, pages.length - 1);
    final immediateEnd = (startIdx + 4).clamp(0, pages.length - 1);

    for (int i = startIdx; i <= immediateEnd; i++) {
      _precacheSinglePage(pages[i], i);
    }

    // 2. Descarga y decodificación en paralelo de TODAS las demás páginas del capítulo
    Future.microtask(() async {
      final remainingIndices = <int>[];
      for (int i = immediateEnd + 1; i < pages.length; i++) {
        remainingIndices.add(i);
      }
      for (int i = startIdx - 1; i >= 0; i--) {
        remainingIndices.add(i);
      }

      // Concurrencia de 4 descargas en paralelo para saturar ancho de banda sin ahogar la red
      const chunkSize = 4;
      for (int i = 0; i < remainingIndices.length; i += chunkSize) {
        if (!mounted || _precacheGeneration != currentGen) return;
        final chunk = remainingIndices.sublist(
          i,
          (i + chunkSize).clamp(0, remainingIndices.length),
        );
        await Future.wait(
          chunk.map((idx) => _precacheSinglePageAsync(pages[idx], idx)),
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }
    });
  }

  void _precacheSinglePage(MangaPage page, int index) {
    if (!mounted || _precachedIndexes.contains(index)) return;
    _precachedIndexes.add(index);

    final resolvedUrl = _resolvePageUrl(page);
    try {
      if (resolvedUrl.startsWith('http')) {
        precacheImage(
          CachedNetworkImageProvider(
            resolvedUrl,
            headers: page.headers,
            maxWidth: 1200,
          ),
          context,
        ).catchError((_) {});
      } else {
        precacheImage(
          FileImage(File(resolvedUrl)),
          context,
        ).catchError((_) {});
      }
    } catch (_) {}
  }

  Future<void> _precacheSinglePageAsync(MangaPage page, int index) async {
    if (!mounted || _precachedIndexes.contains(index)) return;
    _precachedIndexes.add(index);

    final resolvedUrl = _resolvePageUrl(page);
    try {
      if (resolvedUrl.startsWith('http')) {
        await precacheImage(
          CachedNetworkImageProvider(
            resolvedUrl,
            headers: page.headers,
            maxWidth: 1200,
          ),
          context,
        ).catchError((_) {});
      } else {
        await precacheImage(
          FileImage(File(resolvedUrl)),
          context,
        ).catchError((_) {});
      }
    } catch (_) {}
  }

  void _precachePagesAround(int currentIndex) {
    if (!mounted || _pages.isEmpty) return;
    final end = (currentIndex + 4).clamp(0, _pages.length - 1);
    for (int i = currentIndex; i <= end; i++) {
      _precacheSinglePage(_pages[i], i);
    }
  }

  Future<void> _loadPages([int? targetPage]) async {
    final pageToRestore = targetPage ?? 1;
    _precacheGeneration++;
    _precachedIndexes.clear();
    setState(() {
      _isLoading = true;
      _error = null;
      _pages = [];
      _currentPage = pageToRestore > 0 ? pageToRestore : 1;
      _hasUpdatedProgress = false;
    });

    final repo = ref.read(repositoryProvider);
    try {
      List<MangaPage> pages = [];
      try {
        pages = await repo.getMangaPages(
          mediaId: widget.mediaId,
          provider: widget.provider,
          chapterId: _currentChapter.id,
        );
      } catch (_) {}

      // Fallback offline: si el repositorio no devolvió páginas o dio error (offline), consultar almacenamiento local
      if (pages.isEmpty) {
        try {
          final offlineService = ref.read(mangaOfflineServiceProvider);
          final downloadPrefs = ref.read(downloadPreferencesProvider);
          pages = await offlineService.getDownloadedChapterPages(
            mediaId: widget.mediaId,
            provider: widget.provider,
            chapterId: _currentChapter.id,
            customBase: downloadPrefs.customBasePath,
          );
        } catch (e) {
          debugPrint('Error loading offline pages: $e');
        }
      }

      if (mounted) {
        setState(() {
          _pages = pages;
          _isLoading = false;
          if (pages.isEmpty) {
            _error = 'No se encontraron páginas para este capítulo.';
          }
        });

        if (pages.isNotEmpty) {
          _preloadEntireChapter(pages, pageToRestore);

          if (pageToRestore > 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final targetIdx = (pageToRestore - 1).clamp(0, pages.length - 1);
              if (_pageController.hasClients) {
                _pageController.jumpToPage(targetIdx);
              }
              if (_scrollController.hasClients) {
                final maxExtent = _scrollController.position.maxScrollExtent;
                if (maxExtent > 0) {
                  final scrollRatio = targetIdx / (pages.length - 1);
                  _scrollController.jumpTo(scrollRatio * maxExtent);
                } else {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted && _scrollController.hasClients) {
                      final max = _scrollController.position.maxScrollExtent;
                      if (max > 0) {
                        final ratio = targetIdx / (pages.length - 1);
                        _scrollController.jumpTo(ratio * max);
                      }
                    }
                  });
                }
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error cargando páginas: $e';
        });
      }
    }
  }

  void _switchChapter(MangaChapter newChapter) {
    // Al pasar de capítulo, asegurar que el anterior se guarde y sincronice
    _saveProgress();
    _precacheGeneration++;
    _precachedIndexes.clear();
    setState(() {
      _currentChapter = newChapter;
    });
    _loadPages();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  int get _currentChapterIndex {
    return widget.allChapters.indexWhere((c) => c.id == _currentChapter.id);
  }

  bool get _hasNextChapter {
    final idx = _currentChapterIndex;
    return idx != -1 && idx < widget.allChapters.length - 1;
  }

  bool get _hasPrevChapter {
    final idx = _currentChapterIndex;
    return idx > 0;
  }

  void _goToNextChapter() {
    final idx = _currentChapterIndex;
    if (_hasNextChapter) {
      HapticFeedback.lightImpact();
      _switchChapter(widget.allChapters[idx + 1]);
    }
  }

  void _goToPrevChapter() {
    final idx = _currentChapterIndex;
    if (_hasPrevChapter) {
      HapticFeedback.lightImpact();
      _switchChapter(widget.allChapters[idx - 1]);
    }
  }

  void _handleTapNavigation(TapUpDetails details, BoxConstraints constraints, MangaReadingMode mode, bool isRtl) {
    final dx = details.localPosition.dx;
    final width = constraints.maxWidth;

    // Center 40% area toggles controls
    if (dx > width * 0.30 && dx < width * 0.70) {
      _toggleControls();
      return;
    }

    if (mode == MangaReadingMode.webtoon) {
      _toggleControls();
      return;
    }

    // Paged navigation
    final isLeftTap = dx <= width * 0.30;
    if (_pageController.hasClients) {
      if (isRtl) {
        // RTL: Left tap = Next page, Right tap = Previous page
        if (isLeftTap) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        } else {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      } else {
        // LTR: Right tap = Next page, Left tap = Previous page
        if (isLeftTap) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        } else {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  Widget _buildWebtoonView() {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 6000,
        addAutomaticKeepAlives: true,
        padding: const EdgeInsets.only(top: 60, bottom: 90),
        itemCount: _pages.length + 1,
        itemBuilder: (context, index) {
          if (index == _pages.length) {
            return _buildEndChapterCard();
          }
          final page = _pages[index];
          return MangaKeepAlivePage(
            key: ValueKey('webtoon_page_${_currentChapter.id}_$index'),
            child: _buildPageImage(page, index),
          );
        },
      ),
    );
  }

  Widget _buildPagedView({required bool isRtl}) {
    return PageView.builder(
      controller: _pageController,
      reverse: isRtl,
      physics: const BouncingScrollPhysics(),
      itemCount: _pages.length + 1,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        if (index == _pages.length) {
          return Center(
            child: SingleChildScrollView(
              child: _buildEndChapterCard(),
            ),
          );
        }
        final page = _pages[index];
        return MangaKeepAlivePage(
          key: ValueKey('paged_page_${_currentChapter.id}_$index'),
          child: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.5,
              child: _buildPageImage(page, index, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageImage(MangaPage page, int index, {BoxFit fit = BoxFit.fitWidth}) {
    final resolvedUrl = _resolvePageUrl(page);

    if (!resolvedUrl.startsWith('http')) {
      final localFile = File(resolvedUrl);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(index),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      httpHeaders: page.headers,
      fit: fit,
      memCacheWidth: 1200,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => _buildPagePlaceholder(index),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(index),
    );
  }

  Widget _buildPagePlaceholder(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final estimatedHeight = constraints.maxWidth > 0
            ? (constraints.maxWidth / 0.68).clamp(280.0, 900.0)
            : 480.0;
        return Container(
          height: estimatedHeight,
          width: double.infinity,
          color: const Color(0xFF111111),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Página ${index + 1}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorPlaceholder(int index) {
    return Container(
      height: 250,
      color: const Color(0xFF1E1E1E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.brokenImage(ref.watch(iconPackProvider)), color: Colors.white38, size: 36),
          const SizedBox(height: 8),
          Text(
            'Error al cargar página ${index + 1}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEndChapterCard() {
    final pack = ref.watch(iconPackProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.checkCircle(pack), color: Colors.greenAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            'Fin del ${_currentChapter.title.isNotEmpty ? _currentChapter.title : "Capítulo ${_currentChapter.chapter}"}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Progreso guardado en AniList',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (_hasNextChapter)
            FilledButton.icon(
              onPressed: _goToNextChapter,
              icon: Icon(AppIcons.arrowRight(pack)),
              label: const Text('Siguiente Capítulo'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(AppIcons.arrowLeft(pack)),
              label: const Text('Volver al Manga'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final prefs = ref.watch(mangaReaderPreferencesProvider);
    final iconPack = ref.watch(iconPackProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. Contenido del Lector
              GestureDetector(
                onTapUp: prefs.tapToTurnEnabled
                    ? (details) => _handleTapNavigation(
                          details,
                          constraints,
                          prefs.readingMode,
                          prefs.readingMode == MangaReadingMode.pagedRtl,
                        )
                    : (_) => _toggleControls(),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white70),
                            SizedBox(height: 16),
                            Text(
                              'Cargando páginas...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.error(iconPack), color: Colors.white60, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _loadPages,
                                    icon: Icon(AppIcons.refresh(iconPack)),
                                    label: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : switch (prefs.readingMode) {
                            MangaReadingMode.webtoon => _buildWebtoonView(),
                            MangaReadingMode.pagedLtr => _buildPagedView(isRtl: false),
                            MangaReadingMode.pagedRtl => _buildPagedView(isRtl: true),
                          },
              ),

              // 2. Sombra sutil en bordes (Confort visual)
              if (prefs.subtleShadowEnabled) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 36,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 36,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // 3. Top Bar Overlay Animado
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 4,
                    bottom: 12,
                    left: 12,
                    right: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(AppIcons.arrowLeft(iconPack), color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.mangaTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currentChapter.title.isNotEmpty
                                  ? _currentChapter.title
                                  : '${l10n.chapter} ${_currentChapter.chapter}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Botón de Ajustes del Lector
                      IconButton(
                        tooltip: 'Ajustes de lectura',
                        icon: Icon(AppIcons.sliders(iconPack), color: Colors.white),
                        onPressed: () => MangaReaderSettingsSheet.show(context),
                      ),

                      // Selector de Capítulos
                      IconButton(
                        tooltip: 'Lista de capítulos',
                        icon: Icon(AppIcons.listOrdered(iconPack), color: Colors.white),
                        onPressed: () => _showChapterSelectorSheet(context),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Bar Overlay Animado
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                bottom: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 14,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Prev Chapter
                      IconButton(
                        icon: Icon(AppIcons.skipPrevious(iconPack), color: Colors.white),
                        onPressed: _hasPrevChapter ? _goToPrevChapter : null,
                      ),

                      // Page Counter Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _pages.isNotEmpty
                              ? '$_currentPage / ${_pages.length}'
                              : 'Cargando...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Next Chapter
                      IconButton(
                        icon: Icon(AppIcons.skipNext(iconPack), color: Colors.white),
                        onPressed: _hasNextChapter ? _goToNextChapter : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChapterSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Capítulos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.allChapters.length} disponibles',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.allChapters.length,
                  itemBuilder: (context, index) {
                    final c = widget.allChapters[index];
                    final isSelected = c.id == _currentChapter.id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.white.withValues(alpha: 0.08),
                      title: Text(
                        c.title.isNotEmpty ? c.title : 'Capítulo ${c.chapter}',
                        style: TextStyle(
                          color: isSelected ? Colors.amber : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: c.scanlator != null
                          ? Text(
                              c.scanlator!,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            )
                          : null,
                      trailing: isSelected ? Icon(AppIcons.check(ref.watch(iconPackProvider)), color: Colors.amber, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchChapter(c);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

