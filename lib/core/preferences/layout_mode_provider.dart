import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LayoutMode {
  auto('auto', 'Automático'),
  desktop('desktop', 'Escritorio (PC)'),
  mobile('mobile', 'Móvil'),
  tv('tv', 'Modo TV (10ft)');

  final String key;
  final String label;
  const LayoutMode(this.key, this.label);

  String localizedLabel(AppTranslations l10n) {
    switch (this) {
      case LayoutMode.auto:
        return l10n.interfaceModeAuto;
      case LayoutMode.desktop:
        return l10n.interfaceModeDesktop;
      case LayoutMode.mobile:
        return l10n.interfaceModeMobile;
      case LayoutMode.tv:
        return l10n.interfaceModeTv;
    }
  }

  String localizedDescription(AppTranslations l10n) {
    switch (this) {
      case LayoutMode.auto:
        return l10n.interfaceModeAutoDesc;
      case LayoutMode.desktop:
        return l10n.interfaceModeDesktopDesc;
      case LayoutMode.mobile:
        return l10n.interfaceModeMobileDesc;
      case LayoutMode.tv:
        return l10n.interfaceModeTvDesc;
    }
  }

  static LayoutMode fromKey(String? key) {
    switch (key) {
      case 'desktop':
        return LayoutMode.desktop;
      case 'mobile':
        return LayoutMode.mobile;
      case 'tv':
        return LayoutMode.tv;
      default:
        return LayoutMode.auto;
    }
  }
}

class LayoutModeNotifier extends Notifier<LayoutMode> {
  static const _prefKey = 'app_layout_mode';

  @override
  LayoutMode build() {
    _load();
    return LayoutMode.auto;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = LayoutMode.fromKey(saved);
      }
    } catch (_) {}
  }

  Future<void> setMode(LayoutMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.key);
    } catch (_) {}
  }

  /// Resolves the actual layout to render given the context and screen dimensions
  static LayoutMode resolve(BuildContext context, LayoutMode mode) {
    if (mode != LayoutMode.auto) return mode;
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) {
      return LayoutMode.desktop;
    }
    return LayoutMode.mobile;
  }
}

final layoutModeProvider = NotifierProvider<LayoutModeNotifier, LayoutMode>(
  () => LayoutModeNotifier(),
);
