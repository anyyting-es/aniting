import 'dart:io';
import 'package:flutter/material.dart';
import '../i18n/translations/translations.dart';

/// Semantic colors for modern Web / Media Center UI.
class AppThemePalette {
  final String id;
  final String name;
  final String description;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderFocused;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final bool isDark;
  final String category;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.description,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderFocused,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    this.isDark = true,
    this.category = 'dark',
  });

  AppThemePalette copyWith({
    String? id,
    String? name,
    String? description,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderFocused,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    bool? isDark,
    String? category,
  }) {
    return AppThemePalette(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderFocused: borderFocused ?? this.borderFocused,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      isDark: isDark ?? this.isDark,
      category: category ?? this.category,
    );
  }

  /// Returns the localized name of the palette if available, or the raw name.
  String localizedName(AppTranslations l10n) {
    switch (id) {
      case AppPalettes.materialPurpleId:
        return l10n.materialPurpleName;
      case AppPalettes.materialBlueId:
        return l10n.materialBlueName;
      case AppPalettes.materialGreenId:
        return l10n.materialGreenName;
      case AppPalettes.materialOrangeId:
        return l10n.materialOrangeName;
      case AppPalettes.materialCrimsonId:
        return l10n.materialCrimsonName;
      case AppPalettes.materialTealId:
        return l10n.materialTealName;
      case AppPalettes.systemId:
        return l10n.paletteSystem;
      default:
        return name;
    }
  }

  /// Builds a matching Flutter ColorScheme so standard widgets remain cohesive.
  ColorScheme toColorScheme({bool? isDarkOverride}) {
    final effectiveDark = isDarkOverride ?? isDark;
    final brightness = effectiveDark ? Brightness.dark : Brightness.light;
    return ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: effectiveDark ? const Color(0xFF100F15) : Colors.white,
      primaryContainer: accent.withValues(alpha: 0.20),
      onPrimaryContainer: effectiveDark ? Colors.white : accent,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accent.withValues(alpha: 0.15),
      onSecondaryContainer: effectiveDark ? Colors.white : accent,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.5),
      error: const Color(0xFFFF5370),
      onError: Colors.white,
    );
  }
}

/// Helper to parse hex colors safely.
Color? tryParseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return null;
}

class MaterialPaletteInfo {
  final String id;
  final String name;
  final String description;
  final Color seed;
  const MaterialPaletteInfo(this.id, this.name, this.description, this.seed);
}

/// Community and system palettes.
class AppPalettes {
  AppPalettes._();

  static const String systemId = 'system';

  // Dark palette IDs
  static const String catppuccinId = 'catppuccin';
  static const String tokyoNightId = 'tokyo_night';
  static const String draculaId = 'dracula';
  static const String nordId = 'nord';
  static const String oledBlackId = 'oled_black';
  static const String cyberpunkId = 'cyberpunk';
  static const String midnightId = 'midnight';
  static const String gruvboxDarkId = 'gruvbox_dark';
  static const String rosePineId = 'rose_pine';

  // Light palette IDs
  static const String catppuccinLatteId = 'catppuccin_latte';
  static const String tokyoDayId = 'tokyo_day';
  static const String nordSnowId = 'nord_snow';
  static const String draculaLightId = 'dracula_light';
  static const String sakuraId = 'sakura';
  static const String solarizedLightId = 'solarized_light';
  static const String cleanSlateId = 'clean_slate';

  // Material Design 3 palette IDs
  static const String materialPurpleId = 'material_purple';
  static const String materialBlueId = 'material_blue';
  static const String materialGreenId = 'material_green';
  static const String materialOrangeId = 'material_orange';
  static const String materialCrimsonId = 'material_crimson';
  static const String materialTealId = 'material_teal';

  // ─── TEMAS OSCUROS (DARK) ──────────────────────────────────────────────────

  /// Catppuccin Mocha
  static const AppThemePalette catppuccin = AppThemePalette(
    id: catppuccinId,
    name: 'Catppuccin Mocha',
    description: 'Estética relajante con fondos carbón y acento malva pastel',
    background: Color(0xFF1E1E2E),
    surface: Color(0xFF181825),
    surfaceElevated: Color(0xFF313244),
    border: Color(0xFF45475A),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFFCBA6F7),
    textPrimary: Color(0xFFCDD6F4),
    textSecondary: Color(0xFFA6ADC8),
    textMuted: Color(0xFF6C7086),
    isDark: true,
    category: 'dark',
  );

  /// Tokyo Night
  static const AppThemePalette tokyoNight = AppThemePalette(
    id: tokyoNightId,
    name: 'Tokyo Night',
    description: 'Noche con azul profundo y cian equilibrado',
    background: Color(0xFF1A1B26),
    surface: Color(0xFF16161E),
    surfaceElevated: Color(0xFF24283B),
    border: Color(0xFF292E42),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFF7AA2F7),
    textPrimary: Color(0xFFC0CAF5),
    textSecondary: Color(0xFF9AA5CE),
    textMuted: Color(0xFF565F89),
    isDark: true,
    category: 'dark',
  );

  /// Dracula
  static const AppThemePalette dracula = AppThemePalette(
    id: draculaId,
    name: 'Dracula',
    description: 'El clásico oscuro con violeta elegante',
    background: Color(0xFF282A36),
    surface: Color(0xFF21222C),
    surfaceElevated: Color(0xFF343746),
    border: Color(0xFF44475A),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFFBD93F9),
    textPrimary: Color(0xFFF8F8F2),
    textSecondary: Color(0xFFBFBFBF),
    textMuted: Color(0xFF6272A4),
    isDark: true,
    category: 'dark',
  );

  /// Nord
  static const AppThemePalette nord = AppThemePalette(
    id: nordId,
    name: 'Nord',
    description: 'Colores árticos y minimalistas con acento azul escarchado',
    background: Color(0xFF2E3440),
    surface: Color(0xFF242933),
    surfaceElevated: Color(0xFF3B4252),
    border: Color(0xFF434C5E),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFF88C0D0),
    textPrimary: Color(0xFFECEFF4),
    textSecondary: Color(0xFFD8DEE9),
    textMuted: Color(0xFF4C566A),
    isDark: true,
    category: 'dark',
  );

  /// OLED True Black
  static const AppThemePalette oledBlack = AppThemePalette(
    id: oledBlackId,
    name: 'OLED Pure Black',
    description: 'Negro absoluto #000000 para máximo contraste y ahorro de energía',
    background: Color(0xFF000000),
    surface: Color(0xFF0C0C0F),
    surfaceElevated: Color(0xFF16161B),
    border: Color(0xFF24242C),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFFD0BCFE),
    textPrimary: Color(0xFFEDEDF0),
    textSecondary: Color(0xFFA8A8B0),
    textMuted: Color(0xFF60606A),
    isDark: true,
    category: 'dark',
  );

  /// Cyberpunk
  static const AppThemePalette cyberpunk = AppThemePalette(
    id: cyberpunkId,
    name: 'Cyberpunk',
    description: 'Alto contraste y paleta moderna',
    background: Color(0xFF0B0E14),
    surface: Color(0xFF131722),
    surfaceElevated: Color(0xFF1D2233),
    border: Color(0xFF2E344E),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFFF0C674),
    textPrimary: Color(0xFFF0F4FC),
    textSecondary: Color(0xFFAAB2C8),
    textMuted: Color(0xFF586280),
    isDark: true,
    category: 'dark',
  );

  /// Midnight Navy
  static const AppThemePalette midnight = AppThemePalette(
    id: midnightId,
    name: 'Midnight Navy',
    description: 'Azul medianoche refinado para visualización cinematográfica',
    background: Color(0xFF0B132B),
    surface: Color(0xFF1C2541),
    surfaceElevated: Color(0xFF243356),
    border: Color(0xFF3A506B),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFF48CAE4),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCCD6F6),
    textMuted: Color(0xFF8892B0),
    isDark: true,
    category: 'dark',
  );

  /// Gruvbox Dark
  static const AppThemePalette gruvboxDark = AppThemePalette(
    id: gruvboxDarkId,
    name: 'Gruvbox Dark',
    description: 'Tonos cálidos retro nostálgicos con acento ámbar dorado',
    background: Color(0xFF282828),
    surface: Color(0xFF1D2021),
    surfaceElevated: Color(0xFF3C3836),
    border: Color(0xFF504945),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFFFABD2F),
    textPrimary: Color(0xFFEBDBB2),
    textSecondary: Color(0xFFBDAE93),
    textMuted: Color(0xFF928374),
    isDark: true,
    category: 'dark',
  );

  /// Rosé Pine
  static const AppThemePalette rosePine = AppThemePalette(
    id: rosePineId,
    name: 'Rosé Pine',
    description: 'Atmósfera elegante y misteriosa con tonos rosa y pino sutiles',
    background: Color(0xFF191724),
    surface: Color(0xFF1F1D2E),
    surfaceElevated: Color(0xFF26233A),
    border: Color(0xFF403D52),
    borderFocused: Color(0xFFFFFFFF),
    accent: Color(0xFFEBBCBA),
    textPrimary: Color(0xFFE0DEF4),
    textSecondary: Color(0xFF908CAA),
    textMuted: Color(0xFF6E6A86),
    isDark: true,
    category: 'dark',
  );

  // ─── TEMAS CLAROS (LIGHT) ──────────────────────────────────────────────────

  /// Catppuccin Latte
  static const AppThemePalette catppuccinLatte = AppThemePalette(
    id: catppuccinLatteId,
    name: 'Catppuccin Latte',
    description: 'Suave y relajante con base marfil pastel y acento malva',
    background: Color(0xFFEFF1F5),
    surface: Color(0xFFE6E9EF),
    surfaceElevated: Color(0xFFDCE0E8),
    border: Color(0xFFCCD0DA),
    borderFocused: Color(0xFF8839EF),
    accent: Color(0xFF8839EF),
    textPrimary: Color(0xFF4C4F69),
    textSecondary: Color(0xFF5C5F77),
    textMuted: Color(0xFF9CA0B0),
    isDark: false,
    category: 'light',
  );

  /// Tokyo Day
  static const AppThemePalette tokyoDay = AppThemePalette(
    id: tokyoDayId,
    name: 'Tokyo Night Day',
    description: 'Estética clara japonesa inspirada en el día de Tokio',
    background: Color(0xFFE1E2E7),
    surface: Color(0xFFD5D6DB),
    surfaceElevated: Color(0xFFC8C9CE),
    border: Color(0xFFB4B5B9),
    borderFocused: Color(0xFF34548A),
    accent: Color(0xFF34548A),
    textPrimary: Color(0xFF3760BF),
    textSecondary: Color(0xFF6172B0),
    textMuted: Color(0xFF8990B3),
    isDark: false,
    category: 'light',
  );

  /// Nord Snow Storm
  static const AppThemePalette nordSnow = AppThemePalette(
    id: nordSnowId,
    name: 'Nord Snow Storm',
    description: 'Paleta ártica luminosa y escandinava con acento azul polar',
    background: Color(0xFFECEFF4),
    surface: Color(0xFFE5E9F0),
    surfaceElevated: Color(0xFFD8DEE9),
    border: Color(0xFFC4C9D4),
    borderFocused: Color(0xFF5E81AC),
    accent: Color(0xFF5E81AC),
    textPrimary: Color(0xFF2E3440),
    textSecondary: Color(0xFF434C5E),
    textMuted: Color(0xFF7B88A1),
    isDark: false,
    category: 'light',
  );

  /// Dracula Alucard
  static const AppThemePalette draculaLight = AppThemePalette(
    id: draculaLightId,
    name: 'Dracula Alucard',
    description: 'Versión clara con base pergamino suave y acento violeta',
    background: Color(0xFFF8F8F2),
    surface: Color(0xFFEDECE6),
    surfaceElevated: Color(0xFFE2E1DA),
    border: Color(0xFFD0CEC4),
    borderFocused: Color(0xFF9554F7),
    accent: Color(0xFF9554F7),
    textPrimary: Color(0xFF282A36),
    textSecondary: Color(0xFF44475A),
    textMuted: Color(0xFF6272A4),
    isDark: false,
    category: 'light',
  );

  /// Sakura Pastel
  static const AppThemePalette sakura = AppThemePalette(
    id: sakuraId,
    name: 'Sakura Pastel',
    description: 'Estética anime dulce y fresca con tonos flor de cerezo',
    background: Color(0xFFFFF7F8),
    surface: Color(0xFFFFEEF2),
    surfaceElevated: Color(0xFFFFDFE7),
    border: Color(0xFFFFCCD8),
    borderFocused: Color(0xFFE05A88),
    accent: Color(0xFFE05A88),
    textPrimary: Color(0xFF4A2E35),
    textSecondary: Color(0xFF8A606A),
    textMuted: Color(0xFFB58E97),
    isDark: false,
    category: 'light',
  );

  /// Solarized Light
  static const AppThemePalette solarizedLight = AppThemePalette(
    id: solarizedLightId,
    name: 'Solarized Light',
    description: 'Contraste de precisión técnica sobre crema cálido',
    background: Color(0xFFFDF6E3),
    surface: Color(0xFFEEE8D5),
    surfaceElevated: Color(0xFFE0D8C3),
    border: Color(0xFFD3C8B0),
    borderFocused: Color(0xFF268BD2),
    accent: Color(0xFF268BD2),
    textPrimary: Color(0xFF073642),
    textSecondary: Color(0xFF586E75),
    textMuted: Color(0xFF93A1A1),
    isDark: false,
    category: 'light',
  );

  /// Clean Slate Minimalist
  static const AppThemePalette cleanSlate = AppThemePalette(
    id: cleanSlateId,
    name: 'Clean Slate Minimalist',
    description: 'Blanco moderno puro y minimalista con azul contemporáneo',
    background: Color(0xFFFAFAFB),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F3F5),
    border: Color(0xFFE2E5E9),
    borderFocused: Color(0xFF2563EB),
    accent: Color(0xFF2563EB),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    isDark: false,
    category: 'light',
  );

  // ─── MATERIAL DESIGN 3 (ADAPTABLES CLARO / OSCURO) ──────────────────────────

  static const List<MaterialPaletteInfo> materialPalettesInfo = [
    MaterialPaletteInfo(
      materialPurpleId,
      'Material You Violeta',
      'Diseño Material 3 con violeta dinámico y armónico',
      Color(0xFF6750A4),
    ),
    MaterialPaletteInfo(
      materialBlueId,
      'Material You Océano',
      'Diseño Material 3 con azul pacífico y elegante',
      Color(0xFF0061A4),
    ),
    MaterialPaletteInfo(
      materialGreenId,
      'Material You Bosque',
      'Diseño Material 3 con verde esmeralda y menta fresco',
      Color(0xFF006E1C),
    ),
    MaterialPaletteInfo(
      materialOrangeId,
      'Material You Atardecer',
      'Diseño Material 3 con cálido ámbar dorado',
      Color(0xFF8B5000),
    ),
    MaterialPaletteInfo(
      materialCrimsonId,
      'Material You Frambuesa',
      'Diseño Material 3 con rosa carmesí refinado',
      Color(0xFF9C4146),
    ),
    MaterialPaletteInfo(
      materialTealId,
      'Material You Turquesa',
      'Diseño Material 3 con turquesa equilibrado',
      Color(0xFF006A6A),
    ),
  ];

  static AppThemePalette createMaterialPalette({
    required String id,
    required String name,
    required String description,
    required Color seedColor,
    required bool isDark,
  }) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    return AppThemePalette(
      id: id,
      name: name,
      description: description,
      background: isDark ? const Color(0xFF141218) : const Color(0xFFFEF7FF),
      surface: isDark ? const Color(0xFF1D1B20) : const Color(0xFFF7F2FA),
      surfaceElevated: isDark ? const Color(0xFF2B2930) : const Color(0xFFECE6F0),
      border: isDark ? const Color(0xFF49454F) : const Color(0xFFCAC4D0),
      borderFocused: scheme.primary,
      accent: scheme.primary,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textMuted: scheme.outline,
      isDark: isDark,
      category: 'material',
    );
  }

  /// Detects Dank Material Shell / Matugen colors on Linux, or returns null.
  static AppThemePalette? detectSystemPalette() {
    if (!Platform.isLinux) return null;
    try {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return null;

      final gtkCssPath = '$home/.config/gtk-3.0/dank-colors.css';
      final file = File(gtkCssPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();

        final winMatch = RegExp(r'@define-color\s+window_bg_color\s+(#[0-9a-fA-F]{6})').firstMatch(content);
        final cardMatch = RegExp(r'@define-color\s+card_bg_color\s+(#[0-9a-fA-F]{6})').firstMatch(content);
        final accentMatch = RegExp(r'@define-color\s+accent_bg_color\s+(#[0-9a-fA-F]{6})').firstMatch(content);
        final fgMatch = RegExp(r'@define-color\s+window_fg_color\s+(#[0-9a-fA-F]{6})').firstMatch(content);

        final bg = tryParseHex(winMatch?.group(1)) ?? const Color(0xFF141218);
        final surf = tryParseHex(cardMatch?.group(1)) ?? const Color(0xFF211F24);
        final acc = tryParseHex(accentMatch?.group(1)) ?? const Color(0xFFD0BCFE);
        final fg = tryParseHex(fgMatch?.group(1)) ?? const Color(0xFFE6E0E9);

        return AppThemePalette(
          id: systemId,
          name: 'Sistema (Dank Shell / Matugen)',
          description: 'Sincronizado en tiempo real con tu escritorio Linux',
          background: bg,
          surface: surf,
          surfaceElevated: Color.lerp(surf, Colors.white, 0.08) ?? surf,
          border: Color.lerp(surf, fg, 0.15) ?? const Color(0xFF35333B),
          borderFocused: const Color(0xFFFFFFFF),
          accent: acc,
          textPrimary: fg,
          textSecondary: fg.withValues(alpha: 0.70),
          textMuted: fg.withValues(alpha: 0.45),
          isDark: true,
          category: 'dark',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Preset lists per category
  static List<AppThemePalette> getDarkPresets() {
    final systemDms = detectSystemPalette();
    return [
      ?systemDms,
      catppuccin,
      tokyoNight,
      dracula,
      nord,
      oledBlack,
      cyberpunk,
      midnight,
      gruvboxDark,
      rosePine,
    ];
  }

  static List<AppThemePalette> getLightPresets() {
    return const [
      catppuccinLatte,
      tokyoDay,
      nordSnow,
      draculaLight,
      sakura,
      solarizedLight,
      cleanSlate,
    ];
  }

  static List<AppThemePalette> getMaterialPresets({bool isDark = true}) {
    return materialPalettesInfo.map((info) => createMaterialPalette(
      id: info.id,
      name: info.name,
      description: info.description,
      seedColor: info.seed,
      isDark: isDark,
    )).toList();
  }

  /// Default list of selectable community presets
  static List<AppThemePalette> getPresets({bool isDark = true}) {
    final dark = getDarkPresets();
    final light = getLightPresets();
    final material = getMaterialPresets(isDark: isDark);
    return isDark ? [...dark, ...material, ...light] : [...light, ...material, ...dark];
  }

  static AppThemePalette getById(String id, {bool isDark = true}) {
    for (final info in materialPalettesInfo) {
      if (info.id == id) {
        return createMaterialPalette(
          id: info.id,
          name: info.name,
          description: info.description,
          seedColor: info.seed,
          isDark: isDark,
        );
      }
    }

    if (id == systemId) {
      final detected = detectSystemPalette();
      if (detected != null) return detected;
      return isDark ? catppuccin : catppuccinLatte;
    }

    for (final p in getLightPresets()) {
      if (p.id == id) return p;
    }
    for (final p in getDarkPresets()) {
      if (p.id == id) return p;
    }

    return isDark ? catppuccin : catppuccinLatte;
  }

  static String getMatchingVariant(String id, bool toDark) {
    if (materialPalettesInfo.any((m) => m.id == id)) return id;
    if (id == systemId) return id;

    if (toDark) {
      switch (id) {
        case catppuccinLatteId: return catppuccinId;
        case tokyoDayId: return tokyoNightId;
        case nordSnowId: return nordId;
        case draculaLightId: return draculaId;
        case sakuraId: return cyberpunkId;
        case solarizedLightId: return midnightId;
        case cleanSlateId: return oledBlackId;
        default: return id;
      }
    } else {
      switch (id) {
        case catppuccinId: return catppuccinLatteId;
        case tokyoNightId: return tokyoDayId;
        case nordId: return nordSnowId;
        case draculaId: return draculaLightId;
        case cyberpunkId: return sakuraId;
        case midnightId: return solarizedLightId;
        case oledBlackId: return cleanSlateId;
        case gruvboxDarkId: return solarizedLightId;
        case rosePineId: return sakuraId;
        default: return id;
      }
    }
  }
}
