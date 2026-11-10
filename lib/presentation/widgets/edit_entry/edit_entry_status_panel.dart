import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_action_button.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_date_picker.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_entry_actions.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_score_slider.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_status_select.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_stepper.dart';
import 'package:aniting/presentation/widgets/edit_entry/edit_entry_values.dart';

/// Panel glass de edición de estado que se despliega junto al preview
/// inmersivo (PC). Se adapta al fondo del preview — igual que sus botones —
/// mediante superficies translúcidas blancas-alfa y desenfoque de fondo.
class EditEntryStatusPanel extends ConsumerStatefulWidget {
  final int mediaId;
  final String title;
  final String type; // 'anime' | 'manga'
  final Color accent;
  final String? initialStatus;
  final double? initialScore;
  final int? initialProgress;
  final int? totalCount;
  final int? initialRepeat;
  final String? initialStartedAt;
  final String? initialCompletedAt;
  final bool isEntryInList;

  /// Se invoca al guardar o eliminar con éxito.
  final VoidCallback onFinished;

  const EditEntryStatusPanel({
    super.key,
    required this.mediaId,
    required this.title,
    required this.type,
    required this.accent,
    this.initialStatus,
    this.initialScore,
    this.initialProgress,
    this.totalCount,
    this.initialRepeat,
    this.initialStartedAt,
    this.initialCompletedAt,
    required this.isEntryInList,
    required this.onFinished,
  });

  @override
  ConsumerState<EditEntryStatusPanel> createState() =>
      _EditEntryStatusPanelState();
}

class _EditEntryStatusPanelState extends ConsumerState<EditEntryStatusPanel>
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

    await persistEditEntry(
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
    setState(() => _isSaving = false);
    widget.onFinished();
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
    await deleteEditEntry(ref, mediaId: widget.mediaId, type: widget.type);

    if (!mounted) return;
    setState(() => _isDeleting = false);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    // Los campos glass consumen `colorScheme.primary` como acento:
    // reintroducimos el acento de la serie dentro del subárbol del panel.
    final panelTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(primary: widget.accent),
      textTheme: theme.textTheme.apply(bodyColor: Colors.white),
    );

    return Theme(
      data: panelTheme,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 340,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: _panelBody(l10n),
          ),
        ),
      ),
    );
  }

  Widget _panelBody(AppTranslations l10n) {
    final dividerColor = Colors.white.withValues(alpha: 0.10);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado compacto
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _isAnime ? 'ANIME' : 'MANGA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),

          if (loadingInitialData) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: widget.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 1, color: dividerColor),
          const SizedBox(height: 12),

          // Estado
          _glassLabel(l10n.status, Icons.bookmark_border_rounded),
          const SizedBox(height: 6),
          EditEntryStatusSelect(
            status: status,
            isAnime: _isAnime,
            l10n: l10n,
            glass: true,
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

          const SizedBox(height: 12),

          // Progreso
          EditEntryStepper(
            label: l10n.progress,
            value: progress,
            totalCount: widget.totalCount,
            icon: _isAnime ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
            l10n: l10n,
            glass: true,
            onChanged: (v) => setState(() => progress = v),
          ),

          const SizedBox(height: 12),

          // Puntaje
          EditEntryScoreSlider(
            score: score,
            l10n: l10n,
            glass: true,
            onChanged: (v) => setState(() => score = v),
          ),

          const SizedBox(height: 12),

          // Repeticiones
          EditEntryStepper(
            label: _isAnime ? l10n.totalRewatches : l10n.totalRereads,
            value: repeat,
            icon: Icons.repeat_rounded,
            l10n: l10n,
            glass: true,
            onChanged: (v) => setState(() => repeat = v),
          ),

          const SizedBox(height: 12),

          // Fechas (compactas, lado a lado)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EditEntryDatePicker(
                  label: l10n.startDate,
                  dateLabel: formatDate(startDate),
                  l10n: l10n,
                  glass: true,
                  onPick: () => _handlePickDate(true),
                  onClear: () => setState(() => startDate = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EditEntryDatePicker(
                  label: l10n.completionDate,
                  dateLabel: formatDate(completionDate),
                  l10n: l10n,
                  glass: true,
                  onPick: () => _handlePickDate(false),
                  onClear: () => setState(() => completionDate = null),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Container(height: 1, color: dividerColor),
          const SizedBox(height: 12),

          // Acciones
          Row(
            children: [
              if (widget.isEntryInList)
                EditEntryActionButton(
                  label: l10n.delete,
                  variant: EditEntryActionVariant.ghost,
                  danger: true,
                  glass: true,
                  icon: Icons.delete_outline_rounded,
                  loading: _isDeleting,
                  onTap: (_isSaving || _isDeleting) ? null : _handleDelete,
                ),
              const Spacer(),
              EditEntryActionButton(
                label: l10n.save,
                variant: EditEntryActionVariant.primary,
                accent: widget.accent,
                icon: _isSaving ? null : Icons.check_rounded,
                loading: _isSaving,
                onTap: (_isSaving || _isDeleting) ? null : _handleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassLabel(String label, IconData icon) {
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.62)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
