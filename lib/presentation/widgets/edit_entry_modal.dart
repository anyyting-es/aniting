import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_date_picker.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_score_slider.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_status_dropdown.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_stepper.dart';

/// Modal dialog moderno con estética Liquid Glass para editar o eliminar una entrada de AniList / local.
/// Se despliega con una suave animación de arriba hacia abajo (slide-down) como una ventana translúcida.
class EditEntryModal extends ConsumerStatefulWidget {
  final int mediaId;
  final String title;
  final String type; // 'anime' | 'manga'
  final String? initialStatus;
  final double? initialScore;
  final int? initialProgress;
  final int? totalCount; // totalEpisodes or totalChapters
  final int? initialRepeat;
  final String? initialStartedAt;
  final String? initialCompletedAt;
  final bool isEntryInList;

  const EditEntryModal({
    super.key,
    required this.mediaId,
    required this.title,
    required this.type,
    this.initialStatus,
    this.initialScore,
    this.initialProgress,
    this.totalCount,
    this.initialRepeat,
    this.initialStartedAt,
    this.initialCompletedAt,
    this.isEntryInList = true,
  });

  /// Abre el modal responsivamente con una transición de ventana deslizante de arriba hacia abajo.
  static Future<bool?> show({
    required BuildContext context,
    required int mediaId,
    required String title,
    required String type, // 'anime' | 'manga'
    String? initialStatus,
    double? initialScore,
    int? initialProgress,
    int? totalCount,
    int? initialRepeat,
    String? initialStartedAt,
    String? initialCompletedAt,
    bool isEntryInList = true,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.16),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (ctx, anim, secAnim) => EditEntryModal(
        mediaId: mediaId,
        title: title,
        type: type,
        initialStatus: initialStatus,
        initialScore: initialScore,
        initialProgress: initialProgress,
        totalCount: totalCount,
        initialRepeat: initialRepeat,
        initialStartedAt: initialStartedAt,
        initialCompletedAt: initialCompletedAt,
        isEntryInList: isEntryInList,
      ),
    );
  }

  @override
  ConsumerState<EditEntryModal> createState() => _EditEntryModalState();
}

class _EditEntryModalState extends ConsumerState<EditEntryModal> {
  late String _status;
  late double _score;
  late int _progress;
  late int _repeat;

  DateTime? _startDate;
  DateTime? _completionDate;

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoadingInitialData = false;

  bool get _isAnime => widget.type == 'anime';

  @override
  void initState() {
    super.initState();
    _status = _normalizeStatus(widget.initialStatus);

    // Score: 0.0 to 10.0 scale
    final initialScoreVal = widget.initialScore;
    if (initialScoreVal != null && initialScoreVal > 0) {
      _score = (initialScoreVal > 10.0 ? initialScoreVal / 10.0 : initialScoreVal).clamp(0.0, 10.0);
    } else {
      _score = 0.0;
    }

    _progress = widget.initialProgress ?? 0;
    _repeat = widget.initialRepeat ?? 0;

    _startDate = _parseDate(widget.initialStartedAt);
    _completionDate = _parseDate(widget.initialCompletedAt);

    if (widget.isEntryInList && (widget.initialStartedAt == null || widget.initialRepeat == null)) {
      _fetchLatestListData();
    }
  }

  Future<void> _fetchLatestListData() async {
    setState(() => _isLoadingInitialData = true);
    final repo = ref.read(repositoryProvider);
    final listData = await repo.getAnilistEntryListData(
      mediaId: widget.mediaId,
      type: widget.type,
    );

    if (mounted && listData != null) {
      setState(() {
        if (listData['status'] is String) {
          _status = _normalizeStatus(listData['status'] as String);
        }
        if (listData['progress'] is num) {
          _progress = (listData['progress'] as num).toInt();
        }
        if (listData['score'] is num) {
          final s = (listData['score'] as num).toDouble();
          _score = (s > 10.0 ? s / 10.0 : s).clamp(0.0, 10.0);
        }
        if (listData['repeat'] is num) {
          _repeat = (listData['repeat'] as num).toInt();
        }
        if (listData['startedAt'] is Map) {
          _startDate = _parseDateFromMap(listData['startedAt'] as Map);
        }
        if (listData['completedAt'] is Map) {
          _completionDate = _parseDateFromMap(listData['completedAt'] as Map);
        }
        _isLoadingInitialData = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingInitialData = false);
    }
  }

  String _normalizeStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'CURRENT';
    final upper = raw.toUpperCase().trim();
    const valid = ['CURRENT', 'PLANNING', 'COMPLETED', 'REPEATING', 'PAUSED', 'DROPPED'];
    if (valid.contains(upper)) return upper;
    if (upper == 'WATCHING' || upper == 'READING') return 'CURRENT';
    return 'CURRENT';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateFromMap(Map data) {
    try {
      final y = data['year'] as int?;
      final m = data['month'] as int?;
      final d = data['day'] as int?;
      if (y != null && y > 0 && m != null && m > 0 && d != null && d > 0) {
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handlePickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_completionDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2040),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _completionDate = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final repo = ref.read(repositoryProvider);
    final scoreInput = _score;
    final scoreRaw = scoreInput > 0 ? (scoreInput <= 10.0 ? scoreInput * 10.0 : scoreInput) : null;
    final progress = _progress;
    final repeat = _repeat;

    Map<String, int>? startedAtMap;
    if (_startDate != null) {
      startedAtMap = {
        'year': _startDate!.year,
        'month': _startDate!.month,
        'day': _startDate!.day,
      };
    }

    Map<String, int>? completedAtMap;
    if (_completionDate != null) {
      completedAtMap = {
        'year': _completionDate!.year,
        'month': _completionDate!.month,
        'day': _completionDate!.day,
      };
    }

    final serverState = ref.read(serverNotifierProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;

    bool remoteSuccess = false;
    if (isLoggedIn) {
      remoteSuccess = await repo.editAnilistListEntry(
        mediaId: widget.mediaId,
        type: widget.type,
        status: _status,
        score: scoreRaw?.round(),
        progress: progress,
        startedAt: startedAtMap,
        completedAt: completedAtMap,
      );

      if (_isAnime && repeat >= 0) {
        await repo.updateAnimeRepeat(
          mediaId: widget.mediaId,
          repeat: repeat,
        );
      }
    }

    if (_isAnime) {
      await OfflineLibraryService.instance.saveAnimeEntryFromEdit(
        mediaId: widget.mediaId,
        title: widget.title,
        status: _status,
        score: scoreInput,
        progress: progress,
        totalCount: widget.totalCount,
        repeat: repeat,
      );
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(recommendationsProvider);
    } else {
      await OfflineLibraryService.instance.saveMangaEntryFromEdit(
        mediaId: widget.mediaId,
        title: widget.title,
        status: _status,
        score: scoreInput,
        progress: progress,
        totalCount: widget.totalCount,
      );
      ref.invalidate(mangaCollectionProvider);
      ref.invalidate(continueReadingMangaProvider);
      ref.invalidate(mangaRecommendationsProvider);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.of(context).pop(true);
    final message = isLoggedIn
        ? (remoteSuccess ? 'Guardado en AniList' : 'Guardado en tus listas locales')
        : 'Guardado en tus listas locales';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final l10n = ref.read(translationsProvider);
    final serverState = ref.read(serverNotifierProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxTheme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: ctxTheme.colorScheme.surfaceContainer,
          title: Text(
            isLoggedIn ? l10n.deleteFromAnilist : l10n.deleteFromList,
            style: TextStyle(color: ctxTheme.colorScheme.onSurface),
          ),
          content: Text(
            isLoggedIn
                ? l10n.deleteAnilistConfirm(widget.title)
                : l10n.deleteLocalConfirm(widget.title),
            style: TextStyle(color: ctxTheme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: ctxTheme.colorScheme.onSurfaceVariant),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ctxTheme.colorScheme.error,
                foregroundColor: ctxTheme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final repo = ref.read(repositoryProvider);
    if (isLoggedIn) {
      await repo.deleteAnilistListEntry(
        mediaId: widget.mediaId,
        type: widget.type,
      );
    }

    if (_isAnime) {
      await OfflineLibraryService.instance.deleteAnimeEntry(widget.mediaId);
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(recommendationsProvider);
    } else {
      await OfflineLibraryService.instance.deleteMangaEntry(widget.mediaId);
      ref.invalidate(mangaCollectionProvider);
      ref.invalidate(continueReadingMangaProvider);
      ref.invalidate(mangaRecommendationsProvider);
    }

    if (!mounted) return;
    setState(() => _isDeleting = false);

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.removedFromList),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final colors = context.themeColors;
    final glassEnabled = ref.watch(glassEffectsEnabledProvider);

    final cardRadius = BorderRadius.circular((colors.borderRadius * 1.1).clamp(18.0, 26.0));
    final fieldRadius = BorderRadius.circular((colors.borderRadius * 0.8).clamp(12.0, 16.0));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: cardRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              if (glassEnabled)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardRadius,
            child: GlassCard(
              borderRadius: cardRadius,
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: glassEnabled
                      ? (isDark
                          ? colorScheme.surfaceContainer.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.45))
                      : (isDark ? colorScheme.surfaceContainer : Colors.white),
                  borderRadius: cardRadius,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: glassEnabled ? 0.22 : 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Window Header: Badge, Title & Close Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isAnime ? 'ANIME' : 'MANGA',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                      color: colorScheme.onSurface,
                                    ) ??
                                    TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Close Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                                        : Colors.black.withValues(alpha: 0.05),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: isDark ? colorScheme.onSurfaceVariant : Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_isLoadingInitialData) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: Colors.transparent,
                            color: colorScheme.primary,
                          ),
                        ],

                        const SizedBox(height: 18),

                        // Form Section 1: Status & Score Slider
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: EditEntryStatusDropdown(
                                status: _status,
                                isAnime: _isAnime,
                                l10n: l10n,
                                borderRadius: fieldRadius,
                                onChanged: (newStatus) {
                                  setState(() {
                                    _status = newStatus;
                                    if (newStatus == 'COMPLETED' &&
                                        widget.totalCount != null &&
                                        widget.totalCount! > 0) {
                                      _progress = widget.totalCount!;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 6,
                              child: EditEntryScoreSlider(
                                score: _score,
                                l10n: l10n,
                                borderRadius: fieldRadius,
                                onChanged: (newScore) => setState(() => _score = newScore),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Form Section 2: Progress Stepper & Repeats Stepper
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: EditEntryStepper(
                                label: l10n.progress,
                                value: _progress,
                                totalCount: widget.totalCount,
                                icon: _isAnime ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                                borderRadius: fieldRadius,
                                onChanged: (newProgress) => setState(() => _progress = newProgress),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: EditEntryStepper(
                                label: _isAnime ? l10n.totalRewatches : l10n.totalRereads,
                                value: _repeat,
                                icon: Icons.repeat_rounded,
                                borderRadius: fieldRadius,
                                onChanged: (newRepeat) => setState(() => _repeat = newRepeat),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Form Section 3: Start Date & Completion Date
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: EditEntryDatePicker(
                                label: l10n.startDate,
                                date: _startDate,
                                l10n: l10n,
                                borderRadius: fieldRadius,
                                onPick: () => _handlePickDate(true),
                                onClear: () => setState(() => _startDate = null),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: EditEntryDatePicker(
                                label: l10n.completionDate,
                                date: _completionDate,
                                l10n: l10n,
                                borderRadius: fieldRadius,
                                onPick: () => _handlePickDate(false),
                                onClear: () => setState(() => _completionDate = null),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Bottom Action Bar: Delete (Left) & Cancel / Save (Right)
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runAlignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            // Delete Button
                            if (widget.isEntryInList)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (_isSaving || _isDeleting) ? null : _handleDelete,
                                  borderRadius: fieldRadius,
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer.withValues(alpha: isDark ? 0.30 : 0.20),
                                      borderRadius: fieldRadius,
                                      border: Border.all(
                                        color: colorScheme.error.withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isDeleting)
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.error,
                                            ),
                                          )
                                        else ...[
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            color: colorScheme.error,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            l10n.delete,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.error,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            // Save & Cancel Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: (_isSaving || _isDeleting) ? null : () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  ),
                                  child: Text(
                                    l10n.cancel,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: (_isSaving || _isDeleting) ? null : _handleSave,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: fieldRadius,
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isSaving
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_rounded, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.saveChanges,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }
}
