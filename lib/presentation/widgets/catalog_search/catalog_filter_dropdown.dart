import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

class CatalogFilterDropdownItem<T> {
  final T value;
  final String label;

  const CatalogFilterDropdownItem({
    required this.value,
    required this.label,
  });
}

/// Selector estilizado como dropdown con vidrio líquido de `g1455` (GlassPopoverAnchor).
/// Respeta la paleta activa de la aplicación, recorta suavemente el scrollbar dentro de las esquinas
/// redondeadas (clipBehavior) y ofrece tipografía y controles de tamaño cómodo y legible.
class CatalogFilterDropdown<T> extends StatefulWidget {
  final IconData? icon;
  final String label;
  final T selectedValue;
  final List<CatalogFilterDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  const CatalogFilterDropdown({
    super.key,
    this.icon,
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
  });

  @override
  State<CatalogFilterDropdown<T>> createState() => _CatalogFilterDropdownState<T>();
}

class _CatalogFilterDropdownState<T> extends State<CatalogFilterDropdown<T>> {
  late final GlassMenuController _menuController;

  @override
  void initState() {
    super.initState();
    _menuController = GlassMenuController();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelectedFromDefault = widget.items.isNotEmpty && widget.selectedValue != widget.items.first.value;

    return GlassPopoverAnchor(
      controller: _menuController,
      width: 310,
      radius: 20,
      popoverBuilder: (context) {
        // Envolvemos con ClipRRect para que la barrita de scroll y los items
        // nunca se salgan de las esquinas redondeadas del popover.
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.items.map((item) {
                    final isCurrent = item.value == widget.selectedValue;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          widget.onChanged(item.value);
                          _menuController.close();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    color: isCurrent
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Icon(
                                  Icons.check_rounded,
                                  size: 19,
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
            ),
          ),
        );
      },
      builder: (context, controller) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: controller.open,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? (theme.colorScheme.surfaceContainerHighest.computeLuminance() < 0.05
                        ? const Color(0xFF16161C)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65))
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelectedFromDefault
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : (theme.brightness == Brightness.dark
                          ? const Color(0xFF2E2E38)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  width: isSelectedFromDefault ? 1.3 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 19,
                      color: isSelectedFromDefault
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: isSelectedFromDefault ? FontWeight.w600 : FontWeight.w500,
                        color: isSelectedFromDefault
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isSelectedFromDefault
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
