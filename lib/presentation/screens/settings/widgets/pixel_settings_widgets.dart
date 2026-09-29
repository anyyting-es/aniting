import 'package:flutter/material.dart';

/// Encabezado de sección con estilo Android 16
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Contenedor de grupo de ajustes abierto (sin cajas envolventes ni bordes)
class PixelSettingsGroupCard extends StatelessWidget {
  final List<Widget> children;
  const PixelSettingsGroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Contenedor abierto para componentes internos (sin cajas ni bordes)
class PixelCardContainer extends StatelessWidget {
  final Widget child;
  const PixelCardContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

/// Divisor tenue interior para elementos
class PixelTileDivider extends StatelessWidget {
  const PixelTileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      indent: 48,
      endIndent: 16,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
    );
  }
}

/// Posición de un SettingsTile dentro de su grupo/sección (mantenido para compatibilidad)
enum SettingsTilePosition {
  single,
  top,
  middle,
  bottom,
}

/// Fila de ajuste suelta (sin cajón envolvente) con resaltado sutil en selección.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final SettingsTilePosition position;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.isSelected = false,
    this.position = SettingsTilePosition.single,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de ajuste con Switch integrado estilo Pixel
class PixelSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PixelSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      secondary: Icon(
        icon,
        color: value ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Banner de información tonal estilo Pixel
class PixelInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const PixelInfoBanner({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estilo común para SegmentedButtons estilo Pixel Pill
ButtonStyle pixelSegmentedButtonStyle(ThemeData theme) {
  return ButtonStyle(
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

/// Botón píldora seleccionable con animación Android 16 (gap individual y esquinas redondeadas en activo)
class PixelSelectablePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const PixelSelectablePill({
    super.key,
    required this.label,
    this.icon,
    this.subtitle,
    required this.isSelected,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(isSelected ? 24 : 12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 16 : 18,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: compact ? 6 : 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: compact ? 16 : 18,
              height: compact ? 16 : 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: isSelected ? 0 : 1.2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: compact ? 10 : 12,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

