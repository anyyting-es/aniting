import 'package:flutter/material.dart';
import 'package:aniting/core/theme/app_palette.dart';

/// Flutter ThemeExtension for custom Web / Media Center tokens.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderFocused;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final double borderRadius;

  /// True when the app runs on a pure black (OLED) background.
  ///
  /// Cards must not paint an elevated fill in that mode: the extra tone reads as
  /// a muddy purple-grey patch over black. Only the accent border should be
  /// visible.
  final bool isOled;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderFocused,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    this.borderRadius = 10.0,
    this.isOled = false,
  });

  BorderRadius get cardBorderRadius => BorderRadius.circular(borderRadius);
  Radius get radius => Radius.circular(borderRadius);

  /// Surface used by settings cards and grouped tiles.
  Color get cardSurface =>
      isOled ? Colors.transparent : surfaceElevated.withValues(alpha: 0.40);

  /// Border used by settings cards: the accent stays visible on OLED.
  Color cardBorder(ColorScheme colorScheme) => isOled
      ? colorScheme.primary.withValues(alpha: 0.20)
      : colorScheme.outlineVariant.withValues(alpha: 0.25);

  factory AppThemeColors.fromPalette(
    AppThemePalette palette, {
    double borderRadius = 10.0,
    bool isOled = false,
  }) {
    return AppThemeColors(
      background: palette.background,
      // Pure black in OLED: no elevated tones anywhere.
      surface: isOled ? Colors.black : palette.surface,
      surfaceElevated: isOled ? Colors.black : palette.surfaceElevated,
      border: palette.border,
      borderFocused: palette.borderFocused,
      accent: palette.accent,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      textMuted: palette.textMuted,
      borderRadius: borderRadius,
      isOled: isOled,
    );
  }

  factory AppThemeColors.fallback() {
    return AppThemeColors.fromPalette(AppPalettes.catppuccin);
  }

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderFocused,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    double? borderRadius,
    bool? isOled,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderFocused: borderFocused ?? this.borderFocused,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderRadius: borderRadius ?? this.borderRadius,
      isOled: isOled ?? this.isOled,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      border: Color.lerp(border, other.border, t) ?? border,
      borderFocused: Color.lerp(borderFocused, other.borderFocused, t) ?? borderFocused,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      borderRadius: (borderRadius + (other.borderRadius - borderRadius) * t),
      isOled: t < 0.5 ? isOled : other.isOled,
    );
  }
}

/// Extension on BuildContext for quick access: `context.themeColors`
extension ThemeColorsContextExtension on BuildContext {
  AppThemeColors get themeColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.fallback();
}
