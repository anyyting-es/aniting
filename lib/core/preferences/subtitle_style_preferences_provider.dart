import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubtitleBorderStyle {
  none,
  outline,
  dropShadow,
  raised,
  depressed;

  static SubtitleBorderStyle fromName(String? name) {
    return SubtitleBorderStyle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SubtitleBorderStyle.outline,
    );
  }
}

class SubtitleStylePrefs {
  final String fontFamily;
  final double fontSizeMultiplier;
  final bool bold;
  final bool italic;
  final int textColor;
  final int backgroundColor;
  final SubtitleBorderStyle borderStyle;
  final int borderColor;
  final double borderSize;
  final bool overrideAss;
  final double bottomOffset;

  const SubtitleStylePrefs({
    this.fontFamily = 'sans-serif',
    this.fontSizeMultiplier = 1.0,
    this.bold = true,
    this.italic = false,
    this.textColor = 0xFFFFFFFF,
    this.backgroundColor = 0x00000000,
    this.borderStyle = SubtitleBorderStyle.outline,
    this.borderColor = 0xFF000000,
    this.borderSize = 3.0,
    this.overrideAss = false,
    this.bottomOffset = 0.0,
  });

  static const defaultPrefs = SubtitleStylePrefs();

  SubtitleStylePrefs copyWith({
    String? fontFamily,
    double? fontSizeMultiplier,
    bool? bold,
    bool? italic,
    int? textColor,
    int? backgroundColor,
    SubtitleBorderStyle? borderStyle,
    int? borderColor,
    double? borderSize,
    bool? overrideAss,
    double? bottomOffset,
  }) {
    return SubtitleStylePrefs(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderStyle: borderStyle ?? this.borderStyle,
      borderColor: borderColor ?? this.borderColor,
      borderSize: borderSize ?? this.borderSize,
      overrideAss: overrideAss ?? this.overrideAss,
      bottomOffset: bottomOffset ?? this.bottomOffset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontFamily': fontFamily,
      'fontSizeMultiplier': fontSizeMultiplier,
      'bold': bold,
      'italic': italic,
      'textColor': textColor,
      'backgroundColor': backgroundColor,
      'borderStyle': borderStyle.name,
      'borderColor': borderColor,
      'borderSize': borderSize,
      'overrideAss': overrideAss,
      'bottomOffset': bottomOffset,
    };
  }

  factory SubtitleStylePrefs.fromMap(Map<String, dynamic> map) {
    return SubtitleStylePrefs(
      fontFamily: map['fontFamily'] as String? ?? 'sans-serif',
      fontSizeMultiplier: (map['fontSizeMultiplier'] as num?)?.toDouble() ?? 1.0,
      bold: map['bold'] as bool? ?? true,
      italic: map['italic'] as bool? ?? false,
      textColor: (map['textColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      backgroundColor: (map['backgroundColor'] as num?)?.toInt() ?? 0x00000000,
      borderStyle: SubtitleBorderStyle.fromName(map['borderStyle'] as String?),
      borderColor: (map['borderColor'] as num?)?.toInt() ?? 0xFF000000,
      borderSize: (map['borderSize'] as num?)?.toDouble() ?? 3.0,
      overrideAss: map['overrideAss'] as bool? ?? false,
      bottomOffset: (map['bottomOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SubtitleStylePrefs.fromJson(String source) {
    try {
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      return SubtitleStylePrefs.fromMap(decoded);
    } catch (_) {
      return defaultPrefs;
    }
  }

  /// Converts ARGB int to hex string '#AARRGGBB' for MPV
  static String toMpvHexColor(int argb) {
    final a = ((argb >> 24) & 0xFF).toRadixString(16).padLeft(2, '0');
    final r = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (argb & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b'.toUpperCase();
  }

  Color get textFlutterColor => Color(textColor);
  Color get bgFlutterColor => Color(backgroundColor);
  Color get borderFlutterColor => Color(borderColor);
}

class SubtitleStylePreferencesNotifier extends Notifier<SubtitleStylePrefs> {
  static const _prefKey = 'subtitle_style_prefs_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  SubtitleStylePrefs build() {
    final cached = _cachedPrefs;
    if (cached != null) {
      final raw = cached.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        return SubtitleStylePrefs.fromJson(raw);
      }
    }
    _load();
    return SubtitleStylePrefs.defaultPrefs;
  }

  Future<void> _load() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        state = SubtitleStylePrefs.fromJson(raw);
      }
    } catch (_) {}
  }

  Future<void> updateStyle(SubtitleStylePrefs Function(SubtitleStylePrefs current) updater) async {
    final newStyle = updater(state);
    state = newStyle;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setString(_prefKey, newStyle.toJson());
    } catch (_) {}
  }

  Future<void> setStyle(SubtitleStylePrefs newStyle) async {
    state = newStyle;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setString(_prefKey, newStyle.toJson());
    } catch (_) {}
  }

  Future<void> resetToDefaults() async {
    state = SubtitleStylePrefs.defaultPrefs;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.remove(_prefKey);
    } catch (_) {}
  }
}

final subtitleStylePreferencesProvider =
    NotifierProvider<SubtitleStylePreferencesNotifier, SubtitleStylePrefs>(
  SubtitleStylePreferencesNotifier.new,
);
