import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

/// Modal dialog to edit or delete an AniList entry for Anime or Manga.
/// Matches the design from the Seanime web UI with Status, Score, Progress,
/// Start date, Completion date, Total rewatches/rereads, Delete and Save.
/// Fully dynamic with the application's Material 3 theme and palette.
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

  /// Displays the modal dialog responsively.
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
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditEntryModal(
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
  late TextEditingController _scoreController;
  late TextEditingController _progressController;
  late TextEditingController _repeatController;

  DateTime? _startDate;
  DateTime? _completionDate;

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoadingInitialData = false;

  bool get _isAnime => widget.type == 'anime';

  @override
  void initState() {
    super.initState();
    // Normalize status: AniList statuses are uppercase strings
    _status = _normalizeStatus(widget.initialStatus);

    // Score controller: format as integer or 1-decimal float
    final initialScoreVal = widget.initialScore;
    String scoreText = '';
    if (initialScoreVal != null && initialScoreVal > 0) {
      final displayScore = initialScoreVal > 10.0 ? initialScoreVal / 10.0 : initialScoreVal;
      if (displayScore % 1 == 0) {
        scoreText = displayScore.toInt().toString();
      } else {
        scoreText = displayScore.toStringAsFixed(1);
      }
    }
    _scoreController = TextEditingController(text: scoreText);

    // Progress controller
    _progressController = TextEditingController(
      text: (widget.initialProgress ?? 0).toString(),
    );

    // Repeat controller
    _repeatController = TextEditingController(
      text: (widget.initialRepeat ?? 0).toString(),
    );

    // Dates
    _startDate = _parseDate(widget.initialStartedAt);
    _completionDate = _parseDate(widget.initialCompletedAt);

    // If dates or repeat are missing and entry is in list, attempt a fast background fetch
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
          _progressController.text = (listData['progress'] as num).toInt().toString();
        }
        if (listData['score'] is num) {
          final s = (listData['score'] as num).toDouble();
          if (s > 0) {
            final displayScore = s > 10.0 ? s / 10.0 : s;
            _scoreController.text = displayScore % 1 == 0 ? displayScore.toInt().toString() : displayScore.toStringAsFixed(1);
          } else {
            _scoreController.text = '';
          }
        }
        if (listData['repeat'] is num) {
          _repeatController.text = (listData['repeat'] as num).toInt().toString();
        }
        if (listData['startedAt'] is String) {
          _startDate = _parseDate(listData['startedAt'] as String);
        }
        if (listData['completedAt'] is String) {
          _completionDate = _parseDate(listData['completedAt'] as String);
        }
        _isLoadingInitialData = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingInitialData = false);
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _progressController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  String _normalizeStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'CURRENT';
    final upper = raw.toUpperCase();
    switch (upper) {
      case 'WATCHING':
      case 'READING':
      case 'CURRENT':
        return 'CURRENT';
      case 'PLANNING':
      case 'PLAN_TO_WATCH':
      case 'PLAN_TO_READ':
        return 'PLANNING';
      case 'COMPLETED':
        return 'COMPLETED';
      case 'REPEATING':
      case 'REWATCHING':
      case 'REREADING':
        return 'REPEATING';
      case 'PAUSED':
      case 'ON_HOLD':
        return 'PAUSED';
      case 'DROPPED':
        return 'DROPPED';
      default:
        return 'CURRENT';
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    return DateTime.tryParse(dateStr.trim());
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _getStatusLabel(String status, AppTranslations l10n) {
    switch (status) {
      case 'CURRENT':
        return _isAnime ? 'Watching' : 'Reading';
      case 'PLANNING':
        return 'Planning';
      case 'COMPLETED':
        return 'Completed';
      case 'REPEATING':
        return _isAnime ? 'Rewatching' : 'Rereading';
      case 'PAUSED':
        return 'Paused';
      case 'DROPPED':
        return 'Dropped';
      default:
        return status;
    }
  }

  Future<void> _handlePickDate(bool isStart) async {
    final theme = Theme.of(context);
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_completionDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          child: child!,
        );
      },
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

  void _stepProgress(int delta) {
    final cur = int.tryParse(_progressController.text) ?? 0;
    final next = (cur + delta).clamp(0, widget.totalCount ?? 99999);
    _progressController.text = next.toString();

    // Auto-update status to COMPLETED if max reached
    if (widget.totalCount != null && next >= widget.totalCount! && _status != 'COMPLETED') {
      setState(() => _status = 'COMPLETED');
    }
  }

  void _stepRepeat(int delta) {
    final cur = int.tryParse(_repeatController.text) ?? 0;
    final next = (cur + delta).clamp(0, 9999);
    _repeatController.text = next.toString();
  }

  void _stepScore(double delta) {
    final cur = double.tryParse(_scoreController.text) ?? 0.0;
    final next = (cur + delta).clamp(0.0, 100.0);
    if (next % 1 == 0) {
      _scoreController.text = next.toInt().toString();
    } else {
      _scoreController.text = next.toStringAsFixed(1);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);

    // Parse values
    final progress = int.tryParse(_progressController.text.trim()) ?? 0;
    final repeat = int.tryParse(_repeatController.text.trim()) ?? 0;

    int scoreRaw = 0;
    final scoreInput = double.tryParse(_scoreController.text.trim());
    if (scoreInput != null && scoreInput > 0) {
      if (scoreInput <= 10.0) {
        scoreRaw = (scoreInput * 10).round();
      } else {
        scoreRaw = scoreInput.round();
      }
    }

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

    final success = await repo.editAnilistListEntry(
      mediaId: widget.mediaId,
      type: widget.type,
      status: _status,
      score: scoreRaw,
      progress: progress,
      startedAt: startedAtMap,
      completedAt: completedAtMap,
    );

    // If anime and repeat was specified/changed, update repeat as well
    if (_isAnime && repeat >= 0) {
      await repo.updateAnimeRepeat(
        mediaId: widget.mediaId,
        repeat: repeat,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      // Invalidate relevant providers to update all screens
      if (_isAnime) {
        ref.invalidate(animeCollectionProvider);
        ref.invalidate(continueWatchingProvider);
      } else {
        ref.invalidate(mangaCollectionProvider);
        ref.invalidate(continueReadingMangaProvider);
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardado en AniList'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al actualizar en AniList',
            style: TextStyle(color: theme.colorScheme.onError),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxTheme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: ctxTheme.colorScheme.surfaceContainer,
          title: Text(
            'Eliminar de AniList',
            style: TextStyle(color: ctxTheme.colorScheme.onSurface),
          ),
          content: Text(
            '¿Seguro que deseas eliminar "${widget.title}" de tu lista de AniList?',
            style: TextStyle(color: ctxTheme.colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: ctxTheme.colorScheme.onSurfaceVariant),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ctxTheme.colorScheme.error,
                foregroundColor: ctxTheme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final repo = ref.read(repositoryProvider);
    final success = await repo.deleteAnilistListEntry(
      mediaId: widget.mediaId,
      type: widget.type,
    );

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (success) {
      if (_isAnime) {
        ref.invalidate(animeCollectionProvider);
        ref.invalidate(continueWatchingProvider);
      } else {
        ref.invalidate(mangaCollectionProvider);
        ref.invalidate(continueReadingMangaProvider);
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminado de tu lista'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al eliminar de AniList',
            style: TextStyle(color: theme.colorScheme.onError),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final colors = context.themeColors;
    final cardRadius = BorderRadius.circular((colors.borderRadius * 0.9).clamp(12.0, 20.0));
    final fieldRadius = BorderRadius.circular((colors.borderRadius * 0.7).clamp(8.0, 12.0));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: cardRadius,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header: Media Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
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
                if (_isLoadingInitialData) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Responsive Grid Form (3 columns on wide screens, wraps on compact)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 460;
                    if (isCompact) {
                      return Column(
                        children: [
                          _buildStatusField(theme, l10n, fieldRadius),
                          const SizedBox(height: 14),
                          _buildScoreField(theme, fieldRadius),
                          const SizedBox(height: 14),
                          _buildProgressField(theme, fieldRadius),
                          const SizedBox(height: 14),
                          _buildDateField(theme, 'Start date', _startDate, fieldRadius, () => _handlePickDate(true), () => setState(() => _startDate = null)),
                          const SizedBox(height: 14),
                          _buildDateField(theme, 'Completion date', _completionDate, fieldRadius, () => _handlePickDate(false), () => setState(() => _completionDate = null)),
                          const SizedBox(height: 14),
                          _buildRepeatField(theme, fieldRadius),
                        ],
                      );
                    }

                    // 3-Column 2-Row layout matching user screenshot
                    return Column(
                      children: [
                        // Row 1: Status | Score | Progress
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildStatusField(theme, l10n, fieldRadius)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildScoreField(theme, fieldRadius)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildProgressField(theme, fieldRadius)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Row 2: Start date | Completion date | Total rewatches
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDateField(theme, 'Start date', _startDate, fieldRadius, () => _handlePickDate(true), () => setState(() => _startDate = null))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDateField(theme, 'Completion date', _completionDate, fieldRadius, () => _handlePickDate(false), () => setState(() => _completionDate = null))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildRepeatField(theme, fieldRadius)),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Bottom Action Bar: Delete (Left) & Save (Right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Delete Button
                    if (widget.isEntryInList)
                      InkWell(
                        onTap: (_isSaving || _isDeleting) ? null : _handleDelete,
                        borderRadius: fieldRadius,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(alpha: isDark ? 0.35 : 0.25),
                            borderRadius: fieldRadius,
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: _isDeleting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.error,
                                    ),
                                  )
                                : Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Save Button
                    FilledButton(
                      onPressed: (_isSaving || _isDeleting) ? null : _handleSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: fieldRadius,
                        ),
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
                          : Text(
                              'Save',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Field Builders ---

  BoxDecoration _fieldBoxDecoration(ThemeData theme, BorderRadius radius) {
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.55 : 0.4),
      borderRadius: radius,
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
      ),
    );
  }

  Widget _buildFieldWrapper({
    required ThemeData theme,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  Widget _buildStatusField(ThemeData theme, AppTranslations l10n, BorderRadius radius) {
    const statuses = ['CURRENT', 'PLANNING', 'COMPLETED', 'REPEATING', 'PAUSED', 'DROPPED'];
    final colorScheme = theme.colorScheme;

    return _buildFieldWrapper(
      theme: theme,
      label: 'Status',
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: _fieldBoxDecoration(theme, radius),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _status,
            isExpanded: true,
            dropdownColor: colorScheme.surfaceContainerHigh,
            borderRadius: radius,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            items: statuses.map((st) {
              return DropdownMenuItem<String>(
                value: st,
                child: Text(
                  _getStatusLabel(st, l10n),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              );
            }).toList(),
            onChanged: (newVal) {
              if (newVal != null && mounted) {
                setState(() {
                  _status = newVal;
                  // If status changed to COMPLETED and total count is known, fill progress
                  if (newVal == 'COMPLETED' && widget.totalCount != null && widget.totalCount! > 0) {
                    _progressController.text = widget.totalCount.toString();
                  }
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScoreField(ThemeData theme, BorderRadius radius) {
    final colorScheme = theme.colorScheme;

    return _buildFieldWrapper(
      theme: theme,
      label: 'Score',
      child: Container(
        height: 46,
        decoration: _fieldBoxDecoration(theme, radius),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _scoreController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            _buildStepperChevrons(
              theme: theme,
              onUp: () => _stepScore(1.0),
              onDown: () => _stepScore(-1.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressField(ThemeData theme, BorderRadius radius) {
    final colorScheme = theme.colorScheme;

    return _buildFieldWrapper(
      theme: theme,
      label: 'Progress',
      child: Container(
        height: 46,
        decoration: _fieldBoxDecoration(theme, radius),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _progressController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            _buildStepperChevrons(
              theme: theme,
              onUp: () => _stepProgress(1),
              onDown: () => _stepProgress(-1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
    ThemeData theme,
    String label,
    DateTime? date,
    BorderRadius radius,
    VoidCallback onPick,
    VoidCallback onClear,
  ) {
    final colorScheme = theme.colorScheme;
    final hasDate = date != null;
    final dateStr = hasDate ? _formatDate(date) : 'Select a date';

    return _buildFieldWrapper(
      theme: theme,
      label: label,
      child: InkWell(
        onTap: onPick,
        borderRadius: radius,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _fieldBoxDecoration(theme, radius),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: TextStyle(
                    color: hasDate
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (hasDate)
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              Icon(
                Icons.calendar_today_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatField(ThemeData theme, BorderRadius radius) {
    final colorScheme = theme.colorScheme;

    return _buildFieldWrapper(
      theme: theme,
      label: _isAnime ? 'Total rewatches' : 'Total rereads',
      child: Container(
        height: 46,
        decoration: _fieldBoxDecoration(theme, radius),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _repeatController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            _buildStepperChevrons(
              theme: theme,
              onUp: () => _stepRepeat(1),
              onDown: () => _stepRepeat(-1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperChevrons({
    required ThemeData theme,
    required VoidCallback onUp,
    required VoidCallback onDown,
  }) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: onUp,
            borderRadius: BorderRadius.circular(4),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ),
          InkWell(
            onTap: onDown,
            borderRadius: BorderRadius.circular(4),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
