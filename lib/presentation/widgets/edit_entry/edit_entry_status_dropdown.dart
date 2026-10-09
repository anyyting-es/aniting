import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

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

/// Selector de estado de entrada estilizado con Liquid Glass y Popover flotante de `g1455`.
class EditEntryStatusDropdown extends StatefulWidget {
  final String status;
  final bool isAnime;
  final ValueChanged<String> onChanged;
  final AppTranslations l10n;
  final BorderRadius borderRadius;

  const EditEntryStatusDropdown({
    super.key,
    required this.status,
    required this.isAnime,
    required this.onChanged,
    required this.l10n,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<EditEntryStatusDropdown> createState() => _EditEntryStatusDropdownState();
}

class _EditEntryStatusDropdownState extends State<EditEntryStatusDropdown> {
  late final GlassMenuController _menuController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _menuController = GlassMenuController();
  }

  List<EditEntryStatusItem> _buildItems() {
    final l10n = widget.l10n;
    return [
      EditEntryStatusItem(
        key: 'CURRENT',
        label: widget.isAnime ? l10n.statusWatching : l10n.startReading,
        icon: Icons.play_circle_fill_rounded,
        color: const Color(0xFF10B981), // Emerald
      ),
      EditEntryStatusItem(
        key: 'PLANNING',
        label: l10n.statusPlanning,
        icon: Icons.bookmark_added_rounded,
        color: const Color(0xFF3B82F6), // Blue
      ),
      EditEntryStatusItem(
        key: 'COMPLETED',
        label: l10n.statusCompleted,
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF8B5CF6), // Purple
      ),
      EditEntryStatusItem(
        key: 'REPEATING',
        label: widget.isAnime ? l10n.rewatch : l10n.totalRereads,
        icon: Icons.repeat_rounded,
        color: const Color(0xFF06B6D4), // Cyan
      ),
      EditEntryStatusItem(
        key: 'PAUSED',
        label: l10n.statusPaused,
        icon: Icons.pause_circle_filled_rounded,
        color: const Color(0xFFF59E0B), // Amber
      ),
      EditEntryStatusItem(
        key: 'DROPPED',
        label: l10n.statusDropped,
        icon: Icons.cancel_rounded,
        color: const Color(0xFFEF4444), // Red
      ),
    ];
  }

  EditEntryStatusItem _getCurrentItem(List<EditEntryStatusItem> items) {
    return items.firstWhere(
      (item) => item.key == widget.status,
      orElse: () => items.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = _buildItems();
    final current = _getCurrentItem(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.l10n.status,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 7),
        GlassPopoverAnchor(
          controller: _menuController,
          width: 260,
          radius: 18,
          popoverBuilder: (context) {
            final defaultColor = DefaultTextStyle.of(context).style.color ??
                (isDark ? Colors.white : Colors.black87);
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((item) {
                    final isSelected = item.key == widget.status;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onChanged(item.key);
                          _menuController.close();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : defaultColor,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
          builder: (context, controller) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              controller.open();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      current.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ],
);
  }
}
