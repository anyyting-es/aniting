import 'package:flutter/material.dart';

/// Mockup visual de teléfono estilo Pixel Wallpaper & Style (tamaño compacto fijo sin estiramiento)
class ThemeMockupPhone extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color bgColor;
  final Color cardColor;
  final Color line1Color;
  final Color line2Color;
  final Color accentColor;
  final bool isSplit;
  final VoidCallback onTap;

  const ThemeMockupPhone({
    super.key,
    required this.label,
    required this.isSelected,
    required this.bgColor,
    required this.cardColor,
    required this.line1Color,
    required this.line2Color,
    required this.accentColor,
    this.isSplit = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 125,
              width: 104,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSplit ? null : bgColor,
                gradient: isSplit
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.5, 0.5],
                        colors: [Color(0xFFF7F6FB), Color(0xFF1E1C24)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mini barra superior
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 5),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Líneas simuladas de contenido
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: line1Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 7,
                    margin: const EdgeInsets.only(right: 18),
                    decoration: BoxDecoration(
                      color: line2Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  // Mini barra de navegación inferior
                  Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 5,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
