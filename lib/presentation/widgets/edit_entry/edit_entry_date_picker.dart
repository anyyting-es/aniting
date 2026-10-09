import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

/// Selector de fecha con estética Liquid Glass para fechas de inicio y finalización.
class EditEntryDatePicker extends StatefulWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final AppTranslations l10n;
  final BorderRadius borderRadius;

  const EditEntryDatePicker({
    super.key,
    required this.label,
    required this.date,
    required this.onPick,
    required this.onClear,
    required this.l10n,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<EditEntryDatePicker> createState() => _EditEntryDatePickerState();
}

class _EditEntryDatePickerState extends State<EditEntryDatePicker> {
  bool _isHovered = false;

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasDate = widget.date != null;
    final displayStr = hasDate ? _formatDate(widget.date!) : widget.l10n.selectDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 7),
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: _isHovered ? 0.45 : 0.30)
                    : (_isHovered ? Colors.white : Colors.white.withValues(alpha: 0.95)),
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: _isHovered ? 0.22 : 0.12)
                      : (_isHovered ? theme.colorScheme.primary.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.10)),
                  width: 1.0,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: hasDate ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      displayStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                        color: hasDate ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  if (hasDate)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: widget.onClear,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
