import 'package:flutter/material.dart';

import 'package:aniting/core/i18n/translations/translations.dart';

/// Botón de acción compacto estilo web (sin `FilledButton`/`TextButton` de
/// Material): contenedor con animación de hover/press, spinner opcional y
/// variantes primaria, fantasma y de peligro.
class EditEntryActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final EditEntryActionVariant variant;
  final IconData? icon;
  final bool loading;
  final bool danger;

  /// Acento opcional para la variante primaria (p. ej. el color de la serie
  /// en el panel del preview inmersivo).
  final Color? accent;

  /// Cuando es `true`, las variantes fantasma usan colores glass translúcidos.
  final bool glass;

  const EditEntryActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = EditEntryActionVariant.primary,
    this.icon,
    this.loading = false,
    this.danger = false,
    this.accent,
    this.glass = false,
  });

  @override
  State<EditEntryActionButton> createState() => _EditEntryActionButtonState();
}

enum EditEntryActionVariant { primary, ghost }

/// Blanco u oscuro según la luminancia del acento, para asegurar contraste.
Color _onAccentOf(Color accent) {
  return accent.computeLuminance() > 0.55 ? const Color(0xFF16181D) : Colors.white;
}

/// Versión clara del color de error para privilegiar contraste sobre glass.
Color _lightError(Color error) {
  return error.computeLuminance() < 0.4
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.35), error)
      : error;
}

class _EditEntryActionButtonState extends State<EditEntryActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = widget.onTap != null && !widget.loading;

    final accent = widget.danger
        ? colorScheme.error
        : (widget.accent ?? colorScheme.primary);
    final isPrimary = widget.variant == EditEntryActionVariant.primary;

    Color bg;
    Color fg;
    Color border;
    if (isPrimary) {
      bg = enabled
          ? (widget.danger ? colorScheme.error : accent)
          : accent.withValues(alpha: 0.45);
      fg = widget.danger ? colorScheme.onError : _onAccentOf(accent);
      border = Colors.transparent;
      if (_hovered && widget.danger) bg = colorScheme.error.withValues(alpha: 0.9);
    } else if (widget.glass) {
      bg = widget.danger
          ? (_hovered ? colorScheme.error.withValues(alpha: 0.22) : colorScheme.error.withValues(alpha: 0.10))
          : (_hovered ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05));
      fg = widget.danger ? _lightError(colorScheme.error) : Colors.white.withValues(alpha: 0.9);
      border = widget.danger
          ? colorScheme.error.withValues(alpha: _hovered ? 0.55 : 0.35)
          : Colors.white.withValues(alpha: _hovered ? 0.28 : 0.16);
      if (!enabled) fg = fg.withValues(alpha: 0.4);
    } else {
      bg = widget.danger
          ? (_hovered ? colorScheme.error.withValues(alpha: 0.12) : Colors.transparent)
          : (_hovered
              ? colorScheme.onSurface.withValues(alpha: 0.07)
              : Colors.transparent);
      fg = widget.danger ? colorScheme.error : colorScheme.onSurfaceVariant;
      border = widget.danger
          ? colorScheme.error.withValues(alpha: _hovered ? 0.45 : 0.25)
          : colorScheme.outlineVariant.withValues(alpha: _hovered ? 0.6 : 0.35);
      if (!enabled) fg = fg.withValues(alpha: 0.4);
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => enabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
              boxShadow: isPrimary && enabled && _hovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: widget.loading
                      ? Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(fg),
                            ),
                          ),
                        )
                      : widget.icon != null
                          ? Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(widget.icon, size: 15, color: fg),
                            )
                          : const SizedBox.shrink(),
                ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: fg,
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

/// Diálogo de confirmación de borrado alineado con el estilo del modal.
/// Reemplaza al `AlertDialog` con botones Material por acciones compactas.
Future<bool?> showDeleteConfirmDialog(
  BuildContext context, {
  required AppTranslations l10n,
  required bool isLoggedIn,
  required String title,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isLoggedIn ? l10n.deleteFromAnilist : l10n.deleteFromList,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isLoggedIn
                    ? l10n.deleteAnilistConfirm(title)
                    : l10n.deleteLocalConfirm(title),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  EditEntryActionButton(
                    label: l10n.cancel,
                    variant: EditEntryActionVariant.ghost,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                  const SizedBox(width: 8),
                  EditEntryActionButton(
                    label: l10n.delete,
                    variant: EditEntryActionVariant.primary,
                    danger: true,
                    icon: Icons.delete_outline_rounded,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
