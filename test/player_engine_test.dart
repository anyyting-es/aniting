import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/preferences/player_engine_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerEngine Tests', () {
    test('Default player engine from key mapping works', () {
      expect(PlayerEngine.fromKey('exoplayer'), PlayerEngine.exoplayer);
      expect(PlayerEngine.fromKey('mpv'), PlayerEngine.mpv);
      expect(PlayerEngine.fromKey('unknown'), PlayerEngine.defaultEngine);
    });

    test('PlayerEngineNotifier loads and persists engine preference', () async {
      SharedPreferences.setMockInitialValues({'video_player_engine_pref': 'mpv'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger instantiation
      container.read(playerEngineProvider);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(playerEngineProvider), PlayerEngine.mpv);

      // Switch engine to exoplayer
      await container.read(playerEngineProvider.notifier).setEngine(PlayerEngine.exoplayer);
      expect(container.read(playerEngineProvider), PlayerEngine.exoplayer);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('video_player_engine_pref'), 'exoplayer');
    });
  });
}
