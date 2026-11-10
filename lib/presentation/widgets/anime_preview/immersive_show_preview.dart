import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/utils/synopsis_utils.dart';
import 'package:aniting/data/services/offline_library_service.dart';
import 'package:aniting/data/services/offline_sync_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_preview_data.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_status_panel.dart';
import 'package:aniting/presentation/widgets/edit_entry_modal.dart';

/// Opens the immersive preview as a transparent full-screen route, so the
/// background stays visible (dimmed) around it and the poster can fly with a [Hero].
Future<void> showImmersiveShowPreview({
  required BuildContext context,
  required ShowPreviewData data,
  Object? heroTag,
  VoidCallback? onOpenDetails,
}) {
  final navigator = Navigator.of(context);
  return navigator.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (pageContext, animation, secondaryAnimation) =>
          ImmersiveShowPreview(
            data: data,
            heroTag: heroTag,
            onOpenDetails: onOpenDetails,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Minimalist immersive preview: blurred cover backdrop, centered portrait
/// poster, title/year/description and a short list of quick actions.
class ImmersiveShowPreview extends ConsumerStatefulWidget {
  final ShowPreviewData data;
  final Object? heroTag;
  final VoidCallback? onOpenDetails;

  const ImmersiveShowPreview({
    super.key,
    required this.data,
    this.heroTag,
    this.onOpenDetails,
  });

  @override
  ConsumerState<ImmersiveShowPreview> createState() =>
      _ImmersiveShowPreviewState();
}

class _ImmersiveShowPreviewState extends ConsumerState<ImmersiveShowPreview> {
  late bool _isInList;
  late String? _userStatus;
  bool _busy = false;
  bool _editPanelOpen = false;

  /// Once opened, the side panel stays mounted so it can animate out.
  bool _editPanelActive = false;

  /// Ancho mínimo para abrir el panel lateral de edición en vez del modal.
  static const _panelMinWidth = 1000.0;

  /// Ancho total que reclama el panel (300 de panel + 18 de separación).

  ShowPreviewData get _data => widget.data;
  bool get _isManga => _data.isManga;
  bool get _canTrack =>
      _data.canTrack && _data.mediaId != null && _data.mediaId! > 0;

  @override
  void initState() {
    super.initState();
    _isInList = _data.isInList;
    _userStatus = _data.userStatus;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final accent = _data.accentColor ?? theme.colorScheme.primary;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;

    final coverWidth = compact ? math.min(size.width * 0.46, 190.0) : 232.0;
    final coverHeight = coverWidth / 0.70;

    final description = cleanSynopsis(
      (_data.episode?.synopsis?.trim().isNotEmpty ?? false)
          ? _data.episode!.synopsis!
          : (_data.description ?? ''),
    );

    final subtitle = _subtitleLine();
    final metaLine = _metaLine();
    final episodeLine = _episodeLine();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: _background(accent),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: _openDetails,
                                        child: _cover(coverWidth, coverHeight),
                                      ),
                                      const SizedBox(height: 22),
                                      Text(
                                        _data.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.96,
                                          ),
                                          fontSize: compact ? 20 : 23,
                                          fontWeight: FontWeight.w700,
                                          height: 1.18,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      if (episodeLine != null) ...[
                                        const SizedBox(height: 7),
                                        Text(
                                          episodeLine,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.52,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                      if (metaLine != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          metaLine,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.42,
                                            ),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.15,
                                          ),
                                        ),
                                      ],
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 470,
                                          ),
                                          child: Text(
                                            description,
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.66,
                                              ),
                                              fontSize: 12.8,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (_canTrack) ...[
                                        const SizedBox(height: 24),
                                        _actions(l10n),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Panel lateral glass de edición: se despliega
                              // reclamando espacio con un ancho animado y
                              // clip suave, desplazando el preview.
                              if (_editPanelActive) ...[
                                TweenAnimationBuilder<double>(
                                  tween: Tween(end: _editPanelOpen ? 1.0 : 0.0),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, t, panel) {
                                    return ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: t,
                                        child: IgnorePointer(
                                          ignoring: !_editPanelOpen,
                                          child: panel,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: EditEntryStatusPanel(
                                      mediaId: _data.mediaId!,
                                      title: _data.title,
                                      type: _isManga ? 'manga' : 'anime',
                                      accent: accent,
                                      initialStatus: _userStatus,
                                      initialScore: _data.userScore,
                                      initialProgress: _data.progress,
                                      totalCount: _data.totalCount,
                                      initialRepeat: _data.repeat,
                                      initialStartedAt: _data.startedAt,
                                      initialCompletedAt: _data.completedAt,
                                      isEntryInList: _isInList,
                                      onFinished: () {
                                        if (!mounted) return;
                                        _invalidateLists();
                                        Navigator.of(context).maybePop();
                                      },
                                    ),
                                  ),
                                ),
                              ] else
                                const SizedBox(width: 0, height: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 14,
                      child: IconButton(
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.32),
                          foregroundColor: Colors.white.withValues(alpha: 0.9),
                          minimumSize: const Size(38, 38),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _episodeLine() {
    final episode = _data.episode;
    if (episode == null) return null;
    final title = episode.title?.trim();
    if (title != null && title.isNotEmpty) {
      return '${episode.label} · $title';
    }
    return episode.label;
  }

  String? _subtitleLine() {
    if (_data.episode != null) return null;
    final subtitle = _data.subtitle?.trim();
    if (subtitle == null || subtitle.isEmpty) return null;
    if (subtitle.toLowerCase() == _data.title.trim().toLowerCase()) return null;
    return subtitle;
  }

  String? _metaLine() {
    final parts = <String>[];
    if (_data.year != null && _data.year! > 0) parts.add('${_data.year}');
    for (final item in _data.meta) {
      final label = item.label.trim();
      if (label.isEmpty) continue;
      if (parts.contains(label)) continue;
      parts.add(label);
      if (parts.length == 3) break;
    }
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  Widget _background(Color accent) {
    final imageUrl = _data.backgroundUrl ?? _data.coverUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF07080C)),
        if (imageUrl != null && imageUrl.isNotEmpty)
          Opacity(
            opacity: 0.42,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 70,
                sigmaY: 70,
                tileMode: TileMode.decal,
              ),
              child: Transform.scale(
                scale: 1.25,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  filterQuality: FilterQuality.low,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.25,
              colors: [
                accent.withValues(alpha: 0.22),
                accent.withValues(alpha: 0.06),
                Colors.transparent,
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.52),
                Colors.black.withValues(alpha: 0.66),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cover(double width, double height) {
    final imageUrl = _data.coverUrl ?? _data.backgroundUrl;
    Widget image = SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 560,
                memCacheHeight: 840,
                filterQuality: FilterQuality.medium,
                placeholder: (_, _) =>
                    const ColoredBox(color: Color(0xFF161922)),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Color(0xFF161922),
                  child: Icon(
                    Icons.movie_rounded,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              )
            : const ColoredBox(
                color: Color(0xFF161922),
                child: Icon(
                  Icons.movie_rounded,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
      ),
    );

    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 42,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: image,
      ),
    );
  }

  Widget _actions(AppTranslations l10n) {
    final firstLabel = _isInList ? l10n.editStatus : l10n.addToLibrary;
    final markLabel = _isManga ? l10n.markAsRead : l10n.markAsWatched;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.065),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PreviewAction(
                label: firstLabel,
                icon: _isInList ? Icons.tune_rounded : Icons.add_rounded,
                busy: _busy,
                onTap: _busy ? null : _primaryAction,
              ),
              Divider(
                height: 1,
                thickness: 0.6,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              _PreviewAction(
                label: markLabel,
                icon: Icons.check_circle_outline_rounded,
                busy: false,
                onTap: _busy ? null : _markCompleted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _primaryAction() async {
    if (_isInList) {
      await _openEditStatus();
    } else {
      await _applyStatus('PLANNING', progress: 0);
    }
  }

  Future<void> _markCompleted() async {
    final total = _data.totalCount;
    final current = _data.progress ?? 0;
    final target = (total != null && total > 0)
        ? total
        : math.max(current + 1, 1);
    await _applyStatus('COMPLETED', progress: target, closeAfter: true);
  }

  Future<void> _applyStatus(
    String status, {
    required int progress,
    bool closeAfter = false,
  }) async {
    final mediaId = _data.mediaId;
    if (mediaId == null || mediaId <= 0 || _busy) return;

    setState(() => _busy = true);

    final repo = ref.read(repositoryProvider);
    final isLoggedIn =
        ref.read(serverNotifierProvider).status?.isLoggedIn ?? false;
    final score = _data.userScore == null
        ? null
        : (_data.userScore! > 10 ? _data.userScore! / 10 : _data.userScore!);

    var remoteOk = true;
    if (isLoggedIn && !_data.isTmdb) {
      remoteOk = await repo.editAnilistListEntry(
        mediaId: mediaId,
        type: _isManga ? 'manga' : 'anime',
        status: status,
        progress: progress,
      );
    }

    if (_isManga) {
      await OfflineLibraryService.instance.saveMangaEntryFromEdit(
        mediaId: mediaId,
        title: _data.title,
        status: status,
        score: score,
        progress: progress,
        totalCount: _data.totalCount,
      );
    } else {
      await OfflineLibraryService.instance.saveAnimeEntryFromEdit(
        mediaId: mediaId,
        title: _data.title,
        status: status,
        score: score,
        progress: progress,
        totalCount: _data.totalCount,
        isTmdb: _data.isTmdb,
      );
    }

    if (isLoggedIn && !remoteOk && !_data.isTmdb) {
      await OfflineSyncService.instance.enqueueListEdit(
        mediaId: mediaId,
        type: _isManga ? 'manga' : 'anime',
        status: status,
        score: score,
        progress: progress,
        totalCount: _data.totalCount,
        title: _data.title,
      );
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _isInList = true;
      _userStatus = status;
    });
    _invalidateLists();

    if (closeAfter) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _openEditStatus() async {
    final mediaId = _data.mediaId;
    if (mediaId == null || mediaId <= 0) return;

    // En pantallas anchas, el panel lateral glass reemplaza al modal.
    if (MediaQuery.sizeOf(context).width >= _panelMinWidth) {
      HapticFeedback.lightImpact();
      setState(() {
        _editPanelOpen = !_editPanelOpen;
        _editPanelActive = _editPanelActive || _editPanelOpen;
      });
      return;
    }

    final updated = await EditEntryModal.show(
      context: context,
      mediaId: mediaId,
      title: _data.title,
      type: _isManga ? 'manga' : 'anime',
      initialStatus: _userStatus,
      initialScore: _data.userScore,
      initialProgress: _data.progress,
      totalCount: _data.totalCount,
      initialRepeat: _data.repeat,
      initialStartedAt: _data.startedAt,
      initialCompletedAt: _data.completedAt,
      isEntryInList: _isInList,
    );

    if (updated == true && mounted) {
      _invalidateLists();
      Navigator.of(context).maybePop();
    }
  }

  void _invalidateLists() {
    ref.invalidate(animeCollectionProvider);
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recommendationsProvider);
    ref.invalidate(mangaCollectionProvider);
    ref.invalidate(continueReadingMangaProvider);
    ref.invalidate(mangaRecommendationsProvider);
  }

  void _openDetails() {
    final onOpenDetails = widget.onOpenDetails;
    if (onOpenDetails == null) return;
    Navigator.of(context).pop();
    onOpenDetails();
  }
}

class _PreviewAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;

  const _PreviewAction({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (busy)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 19,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
