import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aniting/core/i18n/translations/translations.dart';

/// Un estado del listado con su ícono y color característico.
class EditEntryStatusItem {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const EditEntryStatusItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Select de estado estilo web: trigger compacto + menú desplegable que se
/// comporta como extensión del mismo recuadro (mismo ancho, esquinas
/// inferiores redondeadas continuando el borde del trigger).
/// La opción activa no se repite en el menú: ya se ve en el trigger.
class EditEntryStatusSelect extends StatefulWidget {
  final String status;
  final bool isAnime;
  final AppTranslations l10n;
  final ValueChanged<String> onChanged;

  /// Cuando es `true`, el trigger y el menú usan colores glass translúcidos
  /// (blancos alfa) que se adaptan al fondo del preview inmersivo.
  final bool glass;

  const EditEntryStatusSelect({
    super.key,
    required this.status,
    required this.isAnime,
    required this.l10n,
    required this.onChanged,
    this.glass = false,
  });

  @override
  State<EditEntryStatusSelect> createState() => _EditEntryStatusSelectState();
}

class _EditEntryStatusSelectState extends State<EditEntryStatusSelect>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late final AnimationController _anim;

  bool _isHovered = false;
  bool _isOpen = false;

  static const _triggerHeight = 40.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 130),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _anim.dispose();
    super.dispose();
  }

  List<EditEntryStatusItem> _buildItems() {
    final l10n = widget.l10n;
    return [
      EditEntryStatusItem(
        key: 'CURRENT',
        label: widget.isAnime ? l10n.statusWatching : l10n.startReading,
        icon: Icons.play_circle_fill_rounded,
        color: const Color(0xFF10B981),
      ),
      EditEntryStatusItem(
        key: 'PLANNING',
        label: l10n.statusPlanning,
        icon: Icons.bookmark_added_rounded,
        color: const Color(0xFF3B82F6),
      ),
      EditEntryStatusItem(
        key: 'COMPLETED',
        label: l10n.statusCompleted,
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      EditEntryStatusItem(
        key: 'REPEATING',
        label: widget.isAnime ? l10n.rewatch : l10n.totalRereads,
        icon: Icons.repeat_rounded,
        color: const Color(0xFF06B6D4),
      ),
      EditEntryStatusItem(
        key: 'PAUSED',
        label: l10n.statusPaused,
        icon: Icons.pause_circle_filled_rounded,
        color: const Color(0xFFF59E0B),
      ),
      EditEntryStatusItem(
        key: 'DROPPED',
        label: l10n.statusDropped,
        icon: Icons.cancel_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];
  }

  EditEntryStatusItem get _currentItem {
    final items = _buildItems();
    return items.firstWhere(
      (item) => item.key == widget.status,
      orElse: () => items.first,
    );
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    if (_isOpen) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final theme = Theme.of(context);
    final glass = widget.glass;

    // Ancho del menú = ancho exacto del trigger: extensión del recuadro.
    final triggerWidth = _triggerKey.currentContext?.size?.width ?? 260.0;
    final items =
        _buildItems().where((item) => item.key != widget.status).toList();

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Barrera invisible para capturar taps fuera del menú.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset.zero,
              showWhenUnlinked: false,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (ctx, child) {
                  final t = Curves.easeOutCubic.transform(_anim.value);
                  final fade = Curves.easeOut.transform(_anim.value.clamp(0.0, 1.0));
                  return Opacity(
                    opacity: fade,
                    child: Transform.translate(
                      offset: Offset(0, -8 * (1 - t)),
                      child: child,
                    ),
                  );
                },
                child: Material(
                  type: MaterialType.transparency,
                  child: ClipRRect(
                    // Continúa el radio del recuadro: solo esquinas inferiores.
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                    child: glass
                        ? BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                            child: _menuBody(
                              bgColor: Colors.black.withValues(alpha: 0.34),
                              borderColor: Colors.white.withValues(alpha: 0.14),
                              menuWidth: triggerWidth,
                              items: items,
                            ),
                          )
                        : _menuBody(
                            bgColor: theme.brightness == Brightness.dark
                                ? theme.colorScheme.surfaceContainerHigh
                                : theme.colorScheme.surfaceContainerHighest,
                            borderColor:
                                theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            menuWidth: triggerWidth,
                            items: items,
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _isOpen = true;
    _anim.forward(from: 0);
    setState(() {});
  }

  void _close() {
    if (!_isOpen) return;
    _isOpen = false;
    _anim.reverse().whenComplete(() => _removeOverlay());
    if (mounted) setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final glass = widget.glass;
    final current = _currentItem;
    final focused = _isOpen;

    // Colores neutros: el acento de foco es blanco (glass) o el primario del
    // tema, no el color vivo del estado.
    final idleColor = glass
        ? Colors.white.withValues(alpha: _isHovered ? 0.24 : 0.16)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
    final focusColor = (focused || _isHovered)
        ? (glass
            ? Colors.white.withValues(alpha: focused ? 0.35 : 0.24)
            : theme.colorScheme.primary.withValues(alpha: focused ? 0.55 : 0.35))
        : idleColor;
    final sideWidth = focused ? 1.3 : 1.0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: AnimatedContainer(
            key: _triggerKey,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: _triggerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: glass
                  ? Colors.white.withValues(alpha: (focused || _isHovered) ? 0.10 : 0.06)
                  : dark
                      ? theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: focused ? 0.95 : 0.55)
                      : theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: focused ? 1.0 : 0.65),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: focused ? Radius.zero : const Radius.circular(10),
              ),
              border: Border(
                left: BorderSide(color: focusColor, width: sideWidth),
                top: BorderSide(color: focusColor, width: sideWidth),
                right: BorderSide(color: focusColor, width: sideWidth),
                // Al abrirse, el borde inferior lo aporta el menú aledaño.
                bottom: focused
                    ? BorderSide.none
                    : BorderSide(color: idleColor, width: sideWidth),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current.color,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    current.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: glass
                          ? Colors.white.withValues(alpha: 0.95)
                          : theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: glass
                        ? Colors.white.withValues(alpha: 0.55)
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuBody({
    required Color bgColor,
    required Color borderColor,
    required double menuWidth,
    required List<EditEntryStatusItem> items,
  }) {
    return Container(
      width: menuWidth,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
          // Continúa el borde del trigger; la esquina superior queda abierta.
          bottom: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _MenuItem(
              item: items[i],
              anim: _anim,
              index: i,
              glass: widget.glass,
              onTap: () {
                HapticFeedback.selectionClick();
                _close();
                widget.onChanged(items[i].key);
              },
            ),
        ],
      ),
    );
  }
}

/// Ítem neutro del menú: punto discreto del color del estado, texto en color
/// de superficie y marca de selección blanca. Sin tintes vivos por ítem.
class _MenuItem extends StatefulWidget {
  final EditEntryStatusItem item;
  final Animation<double> anim;
  final int index;
  final bool glass;
  final VoidCallback onTap;

  const _MenuItem({
    required this.item,
    required this.anim,
    required this.index,
    required this.glass,
    required this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = widget.glass;
    final labelColor = glass
        ? Colors.white.withValues(alpha: 0.92)
        : theme.colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: widget.anim,
          builder: (ctx, child) {
            // Entrada escalonada: cada ítem aparece levemente después del anterior.
            final start = (widget.index * 0.035).clamp(0.0, 0.5);
            final t = ((widget.anim.value - start) / (1 - start)).clamp(0.0, 1.0);
            final eased = Curves.easeOutCubic.transform(t);
            return Opacity(
              opacity: eased,
              child: Transform.translate(
                offset: Offset(-4 * (1 - eased), 0),
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            height: 38.0,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: _hovered
                  ? (glass
                      ? Colors.white.withValues(alpha: 0.09)
                      : theme.colorScheme.onSurface.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.07 : 0.05))
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // Punto discreto del color del estado (identificación).
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.item.color.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      color: labelColor,
                    ),
                  ),
                ),
                // Marca sutil al pasar el cursor.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hovered ? 1 : 0,
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 13,
                    color: glass
                        ? Colors.white.withValues(alpha: 0.5)
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
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
