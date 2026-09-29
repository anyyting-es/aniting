import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/api/ws_events.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/manga_reader_screen.dart';
import 'package:seanime_app/presentation/widgets/edit_entry_modal.dart';
import 'package:seanime_app/presentation/widgets/manga/manga_details_modal_sheet.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/manga_detail_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/manga_detail_mobile_layout.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final int mediaId;
  final MangaEntry? initialEntry;
  final bool fromDownloads;

  const MangaDetailScreen({
    super.key,
    required this.mediaId,
    this.initialEntry,
    this.fromDownloads = false,
  });

  static Future<T?> navigate<T>(
    BuildContext context, {
    required int mediaId,
    MangaEntry? initialEntry,
    bool fromDownloads = false,
  }) {
    return Navigator.push<T>(
      context,
      SmoothPageRoute(
        child: MangaDetailScreen(
          mediaId: mediaId,
          initialEntry: initialEntry,
          fromDownloads: fromDownloads,
        ),
      ),
    );
  }

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  static const String _prefLastMangaProviderKey = 'last_selected_manga_provider';

  MangaEntry? _entry;
  bool _isLoadingDetails = true;

  List<MangaProvider> _providers = [];
  MangaProvider? _selectedProvider;
  bool _isLoadingProviders = true;

  List<MangaChapter> _chapters = [];
  bool _isLoadingChapters = false;
  String? _chaptersError;

  bool _showOnlyDownloaded = false;

  Set<String> _downloadedChapterIds = {};
  final Set<String> _downloadingChapterIds = {};
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _wsDebounceTimer;
  bool _isRefreshingDownloadState = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.initialEntry;
    _showOnlyDownloaded = widget.fromDownloads;

    _loadDetails();
    _loadProviders();
    _checkDownloadedChapters();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ws = ref.read(webSocketServiceProvider);
      _wsSubscription = ws.eventStream.listen(_handleWsEvent);
    });
  }

  @override
  void dispose() {
    _wsDebounceTimer?.cancel();
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final repo = ref.read(repositoryProvider);
    try {
      var details = await repo.getMangaDetails(widget.mediaId, initialEntry: widget.initialEntry);
      if (details == null) {
        final saved = await ref.read(mangaOfflineServiceProvider).getSavedMangaMetadata(widget.mediaId);
        if (saved != null) {
          details = saved;
        }
      }

      int localProgress = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        localProgress = prefs.getInt('manga_local_progress_${widget.mediaId}') ?? 0;
      } catch (_) {}

      if (mounted) {
        setState(() {
          var entry = details ?? widget.initialEntry;
          if (entry != null && localProgress > entry.progress) {
            entry = entry.copyWith(progress: localProgress);
          }
          _entry = entry;
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      int localProgress = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        localProgress = prefs.getInt('manga_local_progress_${widget.mediaId}') ?? 0;
      } catch (_) {}

      final saved = await ref.read(mangaOfflineServiceProvider).getSavedMangaMetadata(widget.mediaId);

      if (mounted) {
        setState(() {
          var fallback = saved ?? widget.initialEntry;
          if (fallback != null && localProgress > fallback.progress) {
            fallback = fallback.copyWith(progress: localProgress);
          }
          _entry = fallback;
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoadingProviders = true);
    final repo = ref.read(repositoryProvider);
    try {
      final providers = await repo.getMangaProviders();
      MangaProvider? initialProvider;

      if (providers.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getString(_prefLastMangaProviderKey);
          if (savedId != null && providers.any((p) => p.id == savedId)) {
            initialProvider = providers.firstWhere((p) => p.id == savedId);
          }
        } catch (_) {}
        initialProvider ??= providers.first;
      }

      if (mounted) {
        setState(() {
          _providers = providers;
          _selectedProvider = initialProvider;
          _isLoadingProviders = false;
        });

        if (_selectedProvider != null) {
          _loadChapters();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProviders = false);
      }
    }
  }

  void _openEditEntryModal([String? customTitle]) {
    final liveEntry = ref.read(mangaCollectionProvider).whenOrNull(
      data: (entries) => entries
          .where((e) => e.mediaId == widget.mediaId)
          .firstOrNull,
    );
    final entry = liveEntry ?? _entry ?? widget.initialEntry;

    final progress = entry?.progress ?? 0;
    final status = entry?.status;
    final score = entry?.score;
    final totalChapters = entry?.totalChapters;
    final isEntryInList = entry != null;

    final titleLang = ref.read(titleLanguageProvider);
    final title = customTitle ?? entry?.displayTitle(titleLang) ?? 'Manga';

    EditEntryModal.show(
      context: context,
      mediaId: widget.mediaId,
      title: title,
      type: 'manga',
      initialStatus: status,
      initialScore: score,
      initialProgress: progress,
      totalCount: totalChapters,
      isEntryInList: isEntryInList,
    ).then((updated) {
      if (updated == true && mounted) {
        ref.invalidate(mangaCollectionProvider);
        ref.invalidate(continueReadingMangaProvider);
        _loadDetails();
      }
    });
  }

  Future<void> _checkDownloadedChapters() async {
    try {
      final repo = ref.read(repositoryProvider);
      final serverIds = await repo.getServerDownloadedChapterIds(widget.mediaId);
      if (serverIds.isNotEmpty) {
        if (mounted) {
          setState(() {
            _downloadedChapterIds = serverIds;
          });
        }
        if (_chapters.isEmpty) {
          final serverChapters = await repo.getServerDownloadedChapters(widget.mediaId);
          if (serverChapters.isNotEmpty && mounted) {
            setState(() {
              _chapters = serverChapters;
              _chaptersError = null;
            });
          }
        }
        return;
      }
    } catch (_) {}

    try {
      final offlineService = ref.read(mangaOfflineServiceProvider);
      final downloaded = await offlineService.getDownloadedChapters(widget.mediaId);
      final ids = downloaded.map((c) => c.chapterId).toSet();
      if (mounted) {
        setState(() {
          _downloadedChapterIds = ids;
          if (_chapters.isEmpty && downloaded.isNotEmpty) {
            _chapters = downloaded.map((d) {
              final parsedNum = double.tryParse(d.chapterNumber) ?? 0.0;
              return MangaChapter(
                id: d.chapterId,
                url: '',
                title: 'Capítulo ${d.chapterNumber} (Descargado)',
                chapter: d.chapterNumber,
                index: parsedNum.toInt(),
              );
            }).toList();
            _chaptersError = null;
          }
        });
      }
    } catch (_) {}
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == WsEvents.chapterDownloadQueueUpdated ||
        type == WsEvents.refreshedMangaDownloadData) {
      _wsDebounceTimer?.cancel();
      _wsDebounceTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          _refreshDownloadState();
        }
      });
    }
  }

  Future<void> _refreshDownloadState() async {
    if (!mounted || _isRefreshingDownloadState) return;
    _isRefreshingDownloadState = true;
    try {
      final repo = ref.read(repositoryProvider);
      final info = await repo.getMangaDownloadInfo(widget.mediaId);

      if (mounted) {
        setState(() {
          _downloadedChapterIds = info.downloadedIds;
          _downloadingChapterIds.clear();
          _downloadingChapterIds.addAll(
            info.queuedIds.where((id) => !info.downloadedIds.contains(id)),
          );
        });
      }
    } catch (e) {
      debugPrint('Error refreshing download state: $e');
    } finally {
      _isRefreshingDownloadState = false;
    }
  }

  Future<void> _loadChapters() async {
    if (_selectedProvider == null) {
      await _checkDownloadedChapters();
      return;
    }

    setState(() {
      _isLoadingChapters = true;
      _chaptersError = null;
    });

    final repo = ref.read(repositoryProvider);
    try {
      final container = await repo.getMangaChapters(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
      );

      if (mounted) {
        setState(() {
          _chapters = container?.chapters ?? [];
          _isLoadingChapters = false;
          if (_chapters.isEmpty) {
            _chaptersError = 'No se encontraron capítulos con este proveedor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
          _chaptersError = 'Error cargando capítulos: $e';
        });
      }
    }

    await _checkDownloadedChapters();
  }

  Future<void> _downloadChapter(MangaChapter chapter) async {
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un proveedor para descargar'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _downloadingChapterIds.add(chapter.id);
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Descargando capítulo ${chapter.chapter}...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      if (_entry != null) {
        await ref.read(mangaOfflineServiceProvider).saveMangaMetadata(_entry!);
      }

      final repo = ref.read(repositoryProvider);
      final ok = await repo.downloadMangaChapters(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
        chapterIds: [chapter.id],
        startNow: true,
      );

      if (ok) {
        await repo.startMangaDownloadQueue();
      }

      await _refreshDownloadState();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al programar descarga: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) {
        setState(() {
          _downloadingChapterIds.remove(chapter.id);
        });
      }
    }
  }

  void _showBatchDownloadModal(BuildContext context) {
    if (_selectedProvider == null || _chapters.isEmpty) return;

    final progress = _entry?.progress ?? 0;
    final unreadChapters = _chapters.where((c) => c.chapterNumber > progress).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Descargar Capítulos',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Proveedor: ${_selectedProvider!.name} • ${unreadChapters.length} no leídos',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Descargar siguientes 5 no leídos'),
                  subtitle: const Text('Guarda los próximos 5 capítulos para leer sin conexión'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _downloadMultiple(unreadChapters.take(5).toList());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_rounded),
                  title: const Text('Descargar siguientes 10 no leídos'),
                  subtitle: const Text('Guarda los próximos 10 capítulos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _downloadMultiple(unreadChapters.take(10).toList());
                  },
                ),
                if (unreadChapters.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.download_done_rounded),
                    title: Text('Descargar todos los no leídos (${unreadChapters.length})'),
                    subtitle: const Text('Descarga completa de todos los capítulos pendientes'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _downloadMultiple(unreadChapters);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadMultiple(List<MangaChapter> chaptersToDownload) async {
    if (chaptersToDownload.isEmpty || _selectedProvider == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Descargando ${chaptersToDownload.length} capítulos...'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      for (final c in chaptersToDownload) {
        _downloadingChapterIds.add(c.id);
      }
    });

    try {
      if (_entry != null) {
        await ref.read(mangaOfflineServiceProvider).saveMangaMetadata(_entry!);
      }

      final repo = ref.read(repositoryProvider);
      await repo.downloadMangaChapters(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
        chapterIds: chaptersToDownload.map((c) => c.id).toList(),
        startNow: true,
      );
      await repo.startMangaDownloadQueue();
      await _refreshDownloadState();
    } catch (e) {
      debugPrint('Error queuing multiple chapters: $e');
      if (mounted) {
        setState(() {
          _downloadingChapterIds.clear();
        });
      }
    }
  }

  void _onProviderChanged(MangaProvider? provider) {
    if (provider == null || provider.id == _selectedProvider?.id) return;
    setState(() {
      _selectedProvider = provider;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefLastMangaProviderKey, provider.id);
    });
    _loadChapters();
  }

  void _openReader(MangaChapter chapter) {
    final titleLang = ref.read(titleLanguageProvider);
    final title = _entry?.displayTitle(titleLang) ?? 'Manga';
    final providerId = _selectedProvider?.id ?? 'local';

    MangaReaderScreen.navigate(
      context,
      mediaId: widget.mediaId,
      mangaTitle: title,
      provider: providerId,
      chapter: chapter,
      allChapters: _chapters,
      coverImage: _entry?.coverImage,
    ).then((_) {
      _loadDetails();
      _checkDownloadedChapters();
    });
  }

  void _continueReading() {
    final progress = _entry?.progress ?? 0;
    final nextChapter = progress + 1;
    final chapter = _chapters.where((c) => c.chapterNumber.toInt() == nextChapter).firstOrNull
        ?? (_chapters.isNotEmpty ? _chapters.first : null);
    if (chapter != null) {
      _openReader(chapter);
    }
  }

  void _showDetailsModal(BuildContext context) {
    MangaDetailsModalSheet.show(
      context,
      description: _entry?.description ?? widget.initialEntry?.description,
      genres: _entry?.genres ?? widget.initialEntry?.genres ?? const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final hexColor = _entry?.coverColor ?? widget.initialEntry?.coverColor;

    final baseTheme = Theme.of(context);
    ThemeData effectiveTheme = baseTheme;
    if (themeSettings.animeDynamicTheme && hexColor != null) {
      final parsedColor = parseHexColor(hexColor);
      if (parsedColor != null) {
        final isDark = baseTheme.brightness == Brightness.dark;
        final isOled = themeSettings.isOled && isDark;
        final colorScheme = ColorScheme.fromSeed(
          seedColor: parsedColor,
          brightness: baseTheme.brightness,
          surface: isOled ? Colors.black : null,
        );
        effectiveTheme = baseTheme.copyWith(
          colorScheme: colorScheme,
          scaffoldBackgroundColor: isOled ? Colors.black : colorScheme.surface,
        );
      }
    }

    final layoutPref = ref.watch(layoutModeProvider);
    final effectiveLayout = LayoutModeNotifier.resolve(context, layoutPref);

    if (_entry == null && _isLoadingDetails) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Theme(
      data: effectiveTheme,
      child: Builder(
        builder: (context) {
          if (effectiveLayout == LayoutMode.desktop) {
            return MangaDetailDesktopLayout(
              mediaId: widget.mediaId,
              entry: _entry,
              initialEntry: widget.initialEntry,
              isLoadingDetails: _isLoadingDetails,
              providers: _providers,
              selectedProvider: _selectedProvider,
              chapters: _chapters,
              isLoadingChapters: _isLoadingChapters,
              chaptersError: _chaptersError,
              downloadedChapterIds: _downloadedChapterIds,
              downloadingChapterIds: _downloadingChapterIds,
              onProviderChanged: _onProviderChanged,
              onRefreshChapters: _loadChapters,
              onChapterClicked: _openReader,
              onDownloadChapter: _downloadChapter,
              onBatchDownload: () => _showBatchDownloadModal(context),
              onOpenEditModal: () => _openEditEntryModal(),
              onContinueReading: _continueReading,
            );
          }

          return MangaDetailMobileLayout(
            mediaId: widget.mediaId,
            entry: _entry,
            initialEntry: widget.initialEntry,
            isLoadingDetails: _isLoadingDetails,
            providers: _providers,
            selectedProvider: _selectedProvider,
            isLoadingProviders: _isLoadingProviders,
            chapters: _chapters,
            isLoadingChapters: _isLoadingChapters,
            chaptersError: _chaptersError,
            downloadedChapterIds: _downloadedChapterIds,
            downloadingChapterIds: _downloadingChapterIds,
            showOnlyDownloaded: _showOnlyDownloaded,
            onToggleShowOnlyDownloaded: (val) {
              setState(() => _showOnlyDownloaded = val);
            },
            onProviderChanged: _onProviderChanged,
            onRefreshChapters: _loadChapters,
            onChapterClicked: _openReader,
            onDownloadChapter: _downloadChapter,
            onBatchDownload: () => _showBatchDownloadModal(context),
            onOpenEditModal: () => _openEditEntryModal(),
            onShowDetailsModal: () => _showDetailsModal(context),
            onContinueReading: _continueReading,
          );
        },
      ),
    );
  }
}
