import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

enum DesktopNavStyle {
  sidebar('sidebar'),
  floating('floating');

  final String key;
  const DesktopNavStyle(this.key);

  String localizedLabel(AppTranslations l10n) {
    switch (this) {
      case DesktopNavStyle.sidebar:
        return l10n.desktopNavStyleSidebar;
      case DesktopNavStyle.floating:
        return l10n.desktopNavStyleFloating;
    }
  }

  static DesktopNavStyle fromKey(String? key) {
    if (key == 'floating') return DesktopNavStyle.floating;
    return DesktopNavStyle.sidebar;
  }
}

class DesktopNavStyleNotifier extends Notifier<DesktopNavStyle> {
  static const _prefKey = 'desktop_nav_style_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  DesktopNavStyle build() {
    if (_cachedPrefs != null) {
      final saved = _cachedPrefs!.getString(_prefKey);
      return DesktopNavStyle.fromKey(saved);
    }
    _load();
    return DesktopNavStyle.sidebar;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = DesktopNavStyle.fromKey(saved);
      }
    } catch (_) {}
  }

  Future<void> setStyle(DesktopNavStyle style) async {
    state = style;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, style.key);
    } catch (_) {}
  }

  Future<void> toggleStyle() async {
    final next = state == DesktopNavStyle.sidebar
        ? DesktopNavStyle.floating
        : DesktopNavStyle.sidebar;
    await setStyle(next);
  }
}

final desktopNavStyleProvider =
    NotifierProvider<DesktopNavStyleNotifier, DesktopNavStyle>(
  DesktopNavStyleNotifier.new,
);
