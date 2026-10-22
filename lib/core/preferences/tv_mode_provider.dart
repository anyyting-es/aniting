import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TvModeNotifier extends Notifier<bool> {
  static const _prefKey = 'app_tv_mode_enabled';
  static const _channel = MethodChannel('com.anyyting.aniting/server');

  @override
  bool build() {
    _load();
    return false; // disabled by default
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
        return;
      }
      // Auto-detect TV on Android if not previously configured
      if (Platform.isAndroid) {
        final isTv = await _channel.invokeMethod<bool>('isTvDevice');
        if (isTv == true) {
          state = true;
          await prefs.setBool(_prefKey, true);
        }
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final tvModeProvider = NotifierProvider<TvModeNotifier, bool>(
  TvModeNotifier.new,
);
