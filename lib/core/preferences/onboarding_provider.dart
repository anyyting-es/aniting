import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNotifier extends Notifier<bool> {
  static const String _key = 'has_completed_onboarding_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  bool build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getBool(_key) ?? false;
    }
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      state = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  Future<void> completeOnboarding() async {
    state = true;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setBool(_key, true);
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    state = false;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setBool(_key, false);
    } catch (_) {}
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
