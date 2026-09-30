import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seanime_app/core/theme/app_palette.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,
  light,
  dark,
}

class AppAccentColor {
  final String name;
  final Color color;

  const AppAccentColor({required this.name, required this.color});
}

const List<AppAccentColor> kMaterialAccents = [
  AppAccentColor(name: 'Violeta / Lavanda', color: Color(0xFFCBA6F7)),
  AppAccentColor(name: 'Azul Calmo', color: Color(0xFF7AA2F7)),
  AppAccentColor(name: 'Cian / Menta', color: Color(0xFF88C0D0)),
  AppAccentColor(name: 'Rosa', color: Color(0xFFBD93F9)),
  AppAccentColor(name: 'Ámbar', color: Color(0xFFF0C674)),
  AppAccentColor(name: 'Esmeralda', color: Color(0xFF50FA7B)),
  AppAccentColor(name: 'Cereza', color: Color(0xFFFF5555)),
  AppAccentColor(name: 'Pizarra', color: Color(0xFF395886)),
];

class AppFontOption {
  final String id;
  final String displayName;
  final String description;
  final TextTheme Function(TextTheme? textTheme)? textThemeBuilder;
  final TextStyle Function({TextStyle? textStyle})? textStyleBuilder;

  const AppFontOption({
    required this.id,
    required this.displayName,
    required this.description,
    this.textThemeBuilder,
    this.textStyleBuilder,
  });
}

/// Fallback fonts for CJK (Japanese / Kanji / Hiragana / Katakana) glyphs.
/// Ensures CJK characters render with proper font weights (w600/w700) and sharp contrast.
const List<String> kJapaneseFontFallbacks = [
  'Noto Sans JP',
  'Noto Sans CJK JP',
  'Hiragino Sans',
  'Hiragino Kaku Gothic ProN',
  'Yu Gothic',
  'Meiryo',
  'Droid Sans Fallback',
  'sans-serif',
];

final List<AppFontOption> kAvailableFonts = [
  const AppFontOption(
    id: 'system',
    displayName: 'Sistema',
    description: 'Tipografía predeterminada del dispositivo',
  ),
  AppFontOption(
    id: 'inter',
    displayName: 'Inter',
    description: 'Moderna, limpia y de máxima legibilidad web/desktop',
    textThemeBuilder: (t) => GoogleFonts.interTextTheme(t),
    textStyleBuilder: GoogleFonts.inter,
  ),
  AppFontOption(
    id: 'poppins',
    displayName: 'Poppins',
    description: 'Geométrica, estilizada y moderna',
    textThemeBuilder: (t) => GoogleFonts.poppinsTextTheme(t),
    textStyleBuilder: GoogleFonts.poppins,
  ),
  AppFontOption(
    id: 'outfit',
    displayName: 'Outfit',
    description: 'Contemporánea, refinada y minimalista',
    textThemeBuilder: (t) => GoogleFonts.outfitTextTheme(t),
    textStyleBuilder: GoogleFonts.outfit,
  ),
  AppFontOption(
    id: 'rubik',
    displayName: 'Rubik',
    description: 'Bordes ligeramente suaves y amigables',
    textThemeBuilder: (t) => GoogleFonts.rubikTextTheme(t),
    textStyleBuilder: GoogleFonts.rubik,
  ),
  AppFontOption(
    id: 'nunito',
    displayName: 'Nunito',
    description: 'Redondeada, cálida y estética anime',
    textThemeBuilder: (t) => GoogleFonts.nunitoTextTheme(t),
    textStyleBuilder: GoogleFonts.nunito,
  ),
  AppFontOption(
    id: 'jetbrains_mono',
    displayName: 'JetBrains Mono',
    description: 'Monoespaciada técnica y gamer',
    textThemeBuilder: (t) => GoogleFonts.jetBrainsMonoTextTheme(t),
    textStyleBuilder: GoogleFonts.jetBrainsMono,
  ),
];

Color? parseHexColor(String? hexString) => tryParseHex(hexString);

class ThemeSettings {
  final AppThemeMode themeMode;
  final bool isOled;
  /// If null, no custom accent override is active, so the current palette's natural accent color is used.
  /// If set (>= 0 and < kMaterialAccents.length), it explicitly overrides the palette's accent color.
  final int? customAccentIndex;
  final String fontId;
  final bool animeDynamicTheme;
  final String paletteId;
  final double borderRadius;

  const ThemeSettings({
    this.themeMode = AppThemeMode.dark,
    this.isOled = true,
    this.customAccentIndex,
    this.fontId = 'system',
    this.animeDynamicTheme = true,
    this.paletteId = AppPalettes.oledBlackId,
    this.borderRadius = 10.0,
  });

  /// Custom accent color if user explicitly picked one, or null to use the theme's natural accent.
  Color? get customAccent =>
      customAccentIndex != null &&
              customAccentIndex! >= 0 &&
              customAccentIndex! < kMaterialAccents.length
          ? kMaterialAccents[customAccentIndex!].color
          : null;

  AppAccentColor? get currentAccent =>
      customAccentIndex != null &&
              customAccentIndex! >= 0 &&
              customAccentIndex! < kMaterialAccents.length
          ? kMaterialAccents[customAccentIndex!]
          : null;

  AppFontOption get currentFont =>
      kAvailableFonts.firstWhere((f) => f.id == fontId, orElse: () => kAvailableFonts.first);

  AppThemePalette get currentPalette {
    if (isOled) return AppPalettes.oledBlack;
    final isDark = themeMode != AppThemeMode.light;
    return AppPalettes.getById(paletteId, isDark: isDark);
  }

  ThemeSettings copyWith({
    AppThemeMode? themeMode,
    bool? isOled,
    int? customAccentIndex,
    bool clearCustomAccent = false,
    String? fontId,
    bool? animeDynamicTheme,
    String? paletteId,
    double? borderRadius,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      isOled: isOled ?? this.isOled,
      customAccentIndex: clearCustomAccent ? null : (customAccentIndex ?? this.customAccentIndex),
      fontId: fontId ?? this.fontId,
      animeDynamicTheme: animeDynamicTheme ?? this.animeDynamicTheme,
      paletteId: paletteId ?? this.paletteId,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeSettings> {
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyIsOled = 'app_theme_oled';
  static const String _keyAccentIndex = 'app_theme_accent';
  static const String _keyFontId = 'app_theme_font';
  static const String _keyAnimeDynamicTheme = 'app_theme_anime_dynamic';
  static const String _keyPaletteId = 'app_theme_palette_id';
  static const String _keyBorderRadius = 'app_theme_border_radius';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  static String _defaultPaletteId() {
    return AppPalettes.oledBlackId;
  }

  @override
  ThemeSettings build() {
    final cached = _cachedPrefs;
    if (cached != null) {
      final modeIndex = cached.getInt(_keyThemeMode) ?? 2;
      var isOled = cached.getBool(_keyIsOled) ?? true;
      var mode = AppThemeMode.dark;
      if (modeIndex == 3) {
        mode = AppThemeMode.dark;
        isOled = true;
      } else if (modeIndex >= 0 && modeIndex < AppThemeMode.values.length) {
        mode = AppThemeMode.values[modeIndex];
      }
      final rawAccent = cached.getInt(_keyAccentIndex);
      final customAccent = (rawAccent != null && rawAccent >= 0 && rawAccent < kMaterialAccents.length)
          ? rawAccent
          : null;
      final font = cached.getString(_keyFontId) ?? 'system';
      final animeDynamic = cached.getBool(_keyAnimeDynamicTheme) ?? true;
      final palette = cached.getString(_keyPaletteId) ?? _defaultPaletteId();
      final radius = cached.getDouble(_keyBorderRadius) ?? 10.0;

      return ThemeSettings(
        themeMode: mode,
        isOled: isOled,
        customAccentIndex: customAccent,
        fontId: font,
        animeDynamicTheme: animeDynamic,
        paletteId: palette,
        borderRadius: radius,
      );
    }

    _loadFromPrefs();
    return ThemeSettings(
      isOled: true,
      paletteId: _defaultPaletteId(),
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final modeIndex = prefs.getInt(_keyThemeMode) ?? 2;
    var isOled = prefs.getBool(_keyIsOled) ?? true;
    var mode = AppThemeMode.dark;
    if (modeIndex == 3) {
      mode = AppThemeMode.dark;
      isOled = true;
    } else if (modeIndex >= 0 && modeIndex < AppThemeMode.values.length) {
      mode = AppThemeMode.values[modeIndex];
    }
    final rawAccent = prefs.getInt(_keyAccentIndex);
    final customAccent = (rawAccent != null && rawAccent >= 0 && rawAccent < kMaterialAccents.length)
        ? rawAccent
        : null;
    final font = prefs.getString(_keyFontId) ?? 'system';
    final animeDynamic = prefs.getBool(_keyAnimeDynamicTheme) ?? true;
    final palette = prefs.getString(_keyPaletteId) ?? _defaultPaletteId();
    final radius = prefs.getDouble(_keyBorderRadius) ?? 10.0;

    state = ThemeSettings(
      themeMode: mode,
      isOled: isOled,
      customAccentIndex: customAccent,
      fontId: font,
      animeDynamicTheme: animeDynamic,
      paletteId: palette,
      borderRadius: radius,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setOled(bool isOled) async {
    state = state.copyWith(isOled: isOled);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setBool(_keyIsOled, isOled);
  }

  Future<void> setAccentColor(int? index) async {
    if (index == null || index < 0) {
      state = state.copyWith(clearCustomAccent: true);
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setInt(_keyAccentIndex, -1);
    } else {
      final clamped = index.clamp(0, kMaterialAccents.length - 1);
      state = state.copyWith(customAccentIndex: clamped);
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setInt(_keyAccentIndex, clamped);
    }
  }

  Future<void> setPaletteId(String paletteId, {bool resetCustomAccent = true}) async {
    final willBeOled = paletteId == AppPalettes.oledBlackId;
    state = state.copyWith(
      paletteId: paletteId,
      isOled: willBeOled,
      clearCustomAccent: resetCustomAccent,
    );
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setString(_keyPaletteId, paletteId);
    await prefs.setBool(_keyIsOled, willBeOled);
    if (resetCustomAccent) {
      await prefs.setInt(_keyAccentIndex, -1);
    }
  }

  Future<void> setFontFamily(String fontId) async {
    state = state.copyWith(fontId: fontId);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setString(_keyFontId, fontId);
  }

  Future<void> setAnimeDynamicTheme(bool enabled) async {
    state = state.copyWith(animeDynamicTheme: enabled);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setBool(_keyAnimeDynamicTheme, enabled);
  }

  /// Sets border radius in state immediately for real-time visual feedback without writing to disk.
  void setPreviewBorderRadius(double radius) {
    final clamped = radius.clamp(0.0, 24.0);
    if ((state.borderRadius - clamped).abs() > 0.001) {
      state = state.copyWith(borderRadius: clamped);
    }
  }

  /// Sets border radius and persists to SharedPreferences.
  Future<void> setBorderRadius(double radius) async {
    final clamped = radius.clamp(0.0, 24.0);
    if ((state.borderRadius - clamped).abs() > 0.001) {
      state = state.copyWith(borderRadius: clamped);
    }
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setDouble(_keyBorderRadius, clamped);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(ThemeNotifier.new);

class AppThemeBuilder {
  static ThemeData buildTheme({
    AppThemePalette? palette,
    Color? seedColor,
    required bool isDark,
    bool isOled = false,
    String fontId = 'system',
    Color? customAccent,
    double borderRadius = 10.0,
  }) {
    var basePalette = palette ??
        (seedColor != null
            ? (isDark
                ? AppPalettes.catppuccin.copyWith(accent: seedColor, borderFocused: const Color(0xFFFFFFFF))
                : AppPalettes.catppuccinLatte.copyWith(accent: seedColor, borderFocused: seedColor))
            : (isDark ? AppPalettes.catppuccin : AppPalettes.catppuccinLatte));

    // If light mode is requested but the palette is dark, resolve to counterpart
    if (!isDark && basePalette.isDark) {
      final matchingId = AppPalettes.getMatchingVariant(basePalette.id, false);
      basePalette = AppPalettes.getById(matchingId, isDark: false);
    } else if (isDark && !basePalette.isDark && basePalette.category != 'material') {
      final matchingId = AppPalettes.getMatchingVariant(basePalette.id, true);
      basePalette = AppPalettes.getById(matchingId, isDark: true);
    }

    final effectiveAccent = customAccent ?? seedColor ?? basePalette.accent;
    final effectivePalette = isOled
        ? AppPalettes.oledBlack.copyWith(accent: effectiveAccent, borderFocused: const Color(0xFFFFFFFF))
        : basePalette.copyWith(
            accent: effectiveAccent,
            borderFocused: isDark ? const Color(0xFFFFFFFF) : effectiveAccent,
          );

    final brightness = isDark ? Brightness.dark : Brightness.light;
    final scheme = effectivePalette.toColorScheme(isDarkOverride: isDark);

    final fontOption = kAvailableFonts.firstWhere(
      (f) => f.id == fontId,
      orElse: () => kAvailableFonts.first,
    );

    TextTheme? textTheme;
    if (fontOption.textThemeBuilder != null) {
      final base = brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme;
      textTheme = fontOption.textThemeBuilder!(base);
    }

    if (textTheme != null) {
      textTheme = textTheme.apply(
        fontFamilyFallback: kJapaneseFontFallbacks,
      );
    } else {
      final base = brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme;
      textTheme = base.apply(
        fontFamilyFallback: kJapaneseFontFallbacks,
      );
    }

    final fontFamily = fontOption.textStyleBuilder != null
        ? fontOption.textStyleBuilder!().fontFamily
        : null;

    final themeColors = AppThemeColors.fromPalette(effectivePalette, borderRadius: borderRadius);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: effectivePalette.background,
      fontFamily: fontFamily,
      fontFamilyFallback: kJapaneseFontFallbacks,
      textTheme: textTheme,
      extensions: [themeColors],
      appBarTheme: AppBarTheme(
        backgroundColor: effectivePalette.background,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: effectivePalette.textPrimary, size: 20),
        titleTextStyle: TextStyle(
          color: effectivePalette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: effectivePalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: effectivePalette.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: effectivePalette.surface,
        indicatorColor: effectiveAccent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: effectiveAccent, size: 22),
        unselectedIconTheme: IconThemeData(color: effectivePalette.textMuted, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: effectiveAccent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: effectivePalette.textMuted,
          fontSize: 11,
          fontFamily: fontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: effectivePalette.surface,
        indicatorColor: effectiveAccent.withValues(alpha: 0.18),
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: effectivePalette.border,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: effectivePalette.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: effectivePalette.border, width: 1),
        ),
        textStyle: TextStyle(
          color: effectivePalette.textPrimary,
          fontSize: 12,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: WebPageTransitionsBuilder(),
          TargetPlatform.iOS: WebPageTransitionsBuilder(),
          TargetPlatform.linux: WebPageTransitionsBuilder(),
          TargetPlatform.macOS: WebPageTransitionsBuilder(),
          TargetPlatform.windows: WebPageTransitionsBuilder(),
          TargetPlatform.fuchsia: WebPageTransitionsBuilder(),
        },
      ),
    );
  }
}
