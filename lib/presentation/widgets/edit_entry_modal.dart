import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/theme/app_theme_colors.dart';
import 'package:aniting/core/theme/theme_provider.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_action_button.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_date_picker.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_entry_actions.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_score_slider.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_status_select.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_stepper.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_values.dart';

/// Modal compacto estilo web para editar o eliminar una entrada de
/// AniList / local. Respeta fielmente la paleta y colores configurados en la app.
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

  /// Abre el modal responsivamente con una transición deslizante de arriba hacia abajo.
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
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
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

class _EditEntryModalState extends ConsumerState<EditEntryModal>
    with EditEntryValues {
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isAnime => widget.type == 'anime';

  @override
  void initState() {
    super.initState();
    initEditValues(
      initialStatus: widget.initialStatus,
      initialScore: widget.initialScore,
      initialProgress: widget.initialProgress,
      initialRepeat: widget.initialRepeat,
      initialStartedAt: widget.initialStartedAt,
      initialCompletedAt: widget.initialCompletedAt,
    );

    if (widget.isEntryInList &&
        (widget.initialStartedAt == null || widget.initialRepeat == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchLatestListData();
      });
    }
  }

  Future<void> _fetchLatestListData() async {
    setState(() => loadingInitialData = true);
    final repo = ref.read(repositoryProvider);
    final listData = await repo.getAnilistEntryListData(
      mediaId: widget.mediaId,
      type: widget.type,
    );

    if (mounted && listData != null) {
      setState(() {
        applyFetchedListData(listData);
        loadingInitialData = false;
      });
    } else if (mounted) {
      setState(() => loadingInitialData = false);
    }
  }

  Future<void> _handlePickDate(bool isStart) async {
    final initial = isStart
        ? (startDate ?? DateTime.now())
        : (completionDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2040),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          completionDate = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final remoteSuccess = await persistEditEntry(
      ref,
      mediaId: widget.mediaId,
      title: widget.title,
      type: widget.type,
      status: status,
      score: score,
      progress: progress,
      repeat: repeat,
      totalCount: widget.totalCount,
      startedAt: startDate,
      completedAt: completionDate,
    );

    if (!mounted) return;
    final isLoggedIn =
        ref.read(serverNotifierProvider).status?.isLoggedIn ?? false;

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
    final isLoggedIn =
        ref.read(serverNotifierProvider).status?.isLoggedIn ?? false;

    final confirmed = await showDeleteConfirmDialog(
      context,
      l10n: l10n,
      isLoggedIn: isLoggedIn,
      title: widget.title,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    await deleteEditEntry(
      ref,
      mediaId: widget.mediaId,
      type: widget.type,
    );

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
    final isOled = ref.watch(themeProvider).isOled;

    final modalBg = isOled
        ? Colors.black
        : (isDark ? colorScheme.surfaceContainer : colorScheme.surface);
    final modalBorder = isOled
        ? colors.border
        : colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45);
    final sectionDivider = colorScheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.3);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: modalBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: modalBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado compacto: chip de tipo + título + cerrar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _isAnime ? 'ANIME' : 'MANGA',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              letterSpacing: -0.3,
                              color: colorScheme.onSurface,
                            ) ??
                            TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CloseButton(
                      onTap: () => Navigator.of(context).pop(),
                      tooltip: l10n.close,
                    ),
                  ],
                ),

                if (loadingInitialData) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
                const SizedBox(height: 14),
                Container(height: 1, color: sectionDivider),
                const SizedBox(height: 13),

                // Estado + Progreso
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 18,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 13,
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.status,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          EditEntryStatusSelect(
                            status: status,
                            isAnime: _isAnime,
                            l10n: l10n,
                            onChanged: (newStatus) {
                              setState(() {
                                status = newStatus;
                                if (newStatus == 'COMPLETED' &&
                                    widget.totalCount != null &&
                                    widget.totalCount! > 0) {
                                  progress = widget.totalCount!;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EditEntryStepper(
                        label: l10n.progress,
                        value: progress,
                        totalCount: widget.totalCount,
                        icon: _isAnime ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                        l10n: l10n,
                        onChanged: (newProgress) => setState(() => progress = newProgress),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                // Fecha de inicio + Fecha de finalización
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditEntryDatePicker(
                        label: l10n.startDate,
                        dateLabel: formatDate(startDate),
                        l10n: l10n,
                        onPick: () => _handlePickDate(true),
                        onClear: () => setState(() => startDate = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EditEntryDatePicker(
                        label: l10n.completionDate,
                        dateLabel: formatDate(completionDate),
                        l10n: l10n,
                        onPick: () => _handlePickDate(false),
                        onClear: () => setState(() => completionDate = null),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                // Repeticiones + Puntaje
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EditEntryStepper(
                        label: _isAnime ? l10n.totalRewatches : l10n.totalRereads,
                        value: repeat,
                        icon: Icons.repeat_rounded,
                        l10n: l10n,
                        onChanged: (newRepeat) => setState(() => repeat = newRepeat),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EditEntryScoreSlider(
                        score: score,
                        l10n: l10n,
                        onChanged: (newScore) => setState(() => score = newScore),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Container(height: 1, color: sectionDivider),

                // Barra de acciones: eliminar | cancelar + guardar
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (widget.isEntryInList)
                        EditEntryActionButton(
                          label: l10n.delete,
                          variant: EditEntryActionVariant.ghost,
                          danger: true,
                          icon: Icons.delete_outline_rounded,
                          loading: _isDeleting,
                          onTap: (_isSaving || _isDeleting) ? null : _handleDelete,
                        ),
                      const Spacer(),
                      EditEntryActionButton(
                        label: l10n.cancel,
                        variant: EditEntryActionVariant.ghost,
                        onTap: (_isSaving || _isDeleting) ? null : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      EditEntryActionButton(
                        label: l10n.save,
                        variant: EditEntryActionVariant.primary,
                        icon: _isSaving ? null : Icons.check_rounded,
                        loading: _isSaving,
                        onTap: (_isSaving || _isDeleting) ? null : _handleSave,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de cerrar circular compacto con feedback de hover.
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  final String tooltip;

  const _CloseButton({required this.onTap, required this.tooltip});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? colorScheme.onSurface.withValues(alpha: 0.08)
                  : colorScheme.onSurface.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 15,
              color: _hovered
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
