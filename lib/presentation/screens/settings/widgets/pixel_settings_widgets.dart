import 'package:flutter/material.dart';

import 'settings_dpad_focus.dart';

/// Encabezado de sección con estilo Material 3 Expressive
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

/// Contenedor de grupo de ajustes encapsulado estilo Material 3 Expressive
class PixelSettingsGroupCard extends StatelessWidget {
  final List<Widget> children;
  const PixelSettingsGroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Contenedor encapsulado para componentes internos estilo Material 3 Expressive
class PixelCardContainer extends StatelessWidget {
  final Widget child;
  const PixelCardContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Divisor tenue interior para elementos dentro de un PixelSettingsGroupCard
class PixelTileDivider extends StatelessWidget {
  const PixelTileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      endIndent: 16,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.12),
    );
  }
}

/// Posición de un SettingsTile dentro de su grupo/sección (mantenido para compatibilidad)
enum SettingsTilePosition { single, top, middle, bottom }

/// Fila de ajuste encapsulada dentro de grupo con insignia redondeada estilo dotfiles.
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
    final effectiveRadius = switch (position) {
      SettingsTilePosition.top =>
        const BorderRadius.vertical(top: Radius.circular(18)),
      SettingsTilePosition.bottom =>
        const BorderRadius.vertical(bottom: Radius.circular(18)),
      SettingsTilePosition.middle => BorderRadius.zero,
      SettingsTilePosition.single => BorderRadius.circular(18),
    };

    return SettingsDpadFocus(
      borderRadius: effectiveRadius,
      onActivate: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: effectiveRadius,
          onTap: onTap,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14.5,
                          color: isSelected
                              ? theme.colorScheme.primary
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
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
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

/// Fila de ajuste con Switch integrado estilo Material 3 Expressive
class PixelSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final BorderRadius? borderRadius;
  final SettingsTilePosition position;

  const PixelSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.borderRadius,
    this.position = SettingsTilePosition.single,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRadius = borderRadius ??
        switch (position) {
          SettingsTilePosition.top =>
            const BorderRadius.vertical(top: Radius.circular(18)),
          SettingsTilePosition.bottom =>
            const BorderRadius.vertical(bottom: Radius.circular(18)),
          SettingsTilePosition.middle => BorderRadius.zero,
          SettingsTilePosition.single => BorderRadius.circular(18),
        };

    return SettingsDpadFocus(
      borderRadius: effectiveRadius,
      onActivate: () => onChanged(!value),
      child: Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 19,
            ),
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
        ),
      ),
    );
  }
}

/// Banner de información tonal estilo Pixel
class PixelInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const PixelInfoBanner({super.key, required this.icon, required this.text});

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

    final pill = InkWell(
      canRequestFocus: false,
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
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
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
                            ? theme.colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.75,
                              )
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
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
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

    return SettingsDpadFocus(
      borderRadius: BorderRadius.circular(24),
      onActivate: onTap,
      child: pill,
    );
  }
}

/// Tappable card used to open a selection dialog (language, font, nav style…).
///
/// Consistent look across the appearance settings and, unlike a bare [InkWell],
/// it participates in D-pad navigation with the shared focus ring.
class SettingsDropdownCard extends StatelessWidget {
  final IconData icon;
  final String description;
  final String value;
  final TextStyle? valueStyle;
  final VoidCallback onTap;

  const SettingsDropdownCard({
    super.key,
    required this.icon,
    required this.description,
    required this.value,
    this.valueStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsDpadFocus(
      borderRadius: BorderRadius.circular(18),
      onActivate: onTap,
      child: PixelCardContainer(
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style:
                          valueStyle ??
                          TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
