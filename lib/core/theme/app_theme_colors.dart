import 'package:flutter/material.dart';
import 'package:seanime_app/core/theme/app_palette.dart';

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
  });

  BorderRadius get cardBorderRadius => BorderRadius.circular(borderRadius);
  Radius get radius => Radius.circular(borderRadius);

  factory AppThemeColors.fromPalette(AppThemePalette palette, {double borderRadius = 10.0}) {
    return AppThemeColors(
      background: palette.background,
      surface: palette.surface,
      surfaceElevated: palette.surfaceElevated,
      border: palette.border,
      borderFocused: palette.borderFocused,
      accent: palette.accent,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      textMuted: palette.textMuted,
      borderRadius: borderRadius,
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
    );
  }
}

/// Extension on BuildContext for quick access: `context.themeColors`
extension ThemeColorsContextExtension on BuildContext {
  AppThemeColors get themeColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.fallback();
}
