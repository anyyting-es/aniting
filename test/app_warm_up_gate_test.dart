import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/main_shell.dart';
import 'package:seanime_app/presentation/screens/startup/app_warm_up_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStoppedServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.stopped);
}

class MockRunningWarmServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
        status: ServerStatus(username: 'TestUser'),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppWarmUpGate Tests', () {
    testWidgets('Renders splash view with logo, title, and progress bar initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockStoppedServerNotifier.new),
            continueWatchingProvider.overrideWith((ref) => Future.value([])),
            downloadedAnimeProvider.overrideWith((ref) => Future.value([])),
            animeCollectionProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: GlassHost(
              richBackdrop: true,
              backdrop: Colors.black,
              child: AppWarmUpGate(),
            ),
          ),
        ),
      );

      // Verify startup splash elements are present on the first frame
      expect(find.byKey(const ValueKey('app_warmup_splash')), findsOneWidget);
      expect(find.text('Aniting'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);

      // Drain warmup timer and any mounted MainShell timers
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Transitions smoothly to MainShell after warm-up finishes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockRunningWarmServerNotifier.new),
            continueWatchingProvider.overrideWith((ref) => Future.value(<AnimeEntry>[])),
            downloadedAnimeProvider.overrideWith((ref) => Future.value(<AnimeEntry>[])),
            animeCollectionProvider.overrideWith((ref) => Future.value(<AnimeEntry>[])),
          ],
          child: const MaterialApp(
            home: GlassHost(
              richBackdrop: true,
              backdrop: Colors.black,
              child: AppWarmUpGate(),
            ),
          ),
        ),
      );

      // Initially on splash
      expect(find.byKey(const ValueKey('app_warmup_splash')), findsOneWidget);

      // Advance through min display duration (550ms) and fade transition (350ms)
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 450));

      // MainShell is now displayed
      expect(find.byType(MainShell), findsOneWidget);

      // Drain MainShell's auto-update delayed timer (1500ms)
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
