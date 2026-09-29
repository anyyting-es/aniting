import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

enum MobileNavStyle {
  classic('classic'),
  floating('floating');

  final String key;
  const MobileNavStyle(this.key);

  String localizedLabel(AppTranslations l10n) {
    switch (this) {
      case MobileNavStyle.classic:
        return l10n.mobileNavStyleClassic;
      case MobileNavStyle.floating:
        return l10n.mobileNavStyleFloating;
    }
  }

  static MobileNavStyle fromKey(String? key) {
    if (key == 'floating') return MobileNavStyle.floating;
    return MobileNavStyle.classic;
  }
}

class MobileNavStyleNotifier extends Notifier<MobileNavStyle> {
  static const _prefKey = 'mobile_nav_style';

  @override
  MobileNavStyle build() {
    _load();
    return MobileNavStyle.classic;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = MobileNavStyle.fromKey(saved);
      }
    } catch (_) {}
  }

  Future<void> setStyle(MobileNavStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, style.key);
    } catch (_) {}
  }

  Future<void> toggleStyle() async {
    final next = state == MobileNavStyle.classic
        ? MobileNavStyle.floating
        : MobileNavStyle.classic;
    await setStyle(next);
  }
}

final mobileNavStyleProvider =
    NotifierProvider<MobileNavStyleNotifier, MobileNavStyle>(MobileNavStyleNotifier.new);
