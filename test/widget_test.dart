import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/onboarding_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/main.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.stopped);
}

class MockOnboardingNotifier extends OnboardingNotifier {
  @override
  bool build() => true;
}

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
          onboardingProvider.overrideWith(MockOnboardingNotifier.new),
        ],
        child: const AnitingFlutterApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnitingFlutterApp), findsOneWidget);
  });

  testWidgets('AnimeCard renders in compact and desktop widths without overflow', (WidgetTester tester) async {
    final entry = AnimeEntry(
      id: 10,
      mediaId: 10,
      title: 'Sousou no Frieren',
      progress: 10,
      status: 'CURRENT',
      score: 93,
      airDate: '2023-09-29',
      format: 'TV',
    );

    // Compact mobile width (e.g. in 3-column grid)
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 115,
                child: AnimeCard(entry: entry),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sousou no Frieren'), findsOneWidget);
    expect(find.text('2023 • TV'), findsOneWidget);
  });

  testWidgets('MangaCard renders in compact and desktop widths without overflow', (WidgetTester tester) async {
    final entry = MangaEntry(
      id: 20,
      mediaId: 20,
      title: 'Berserk',
      progress: 364,
      status: 'RELEASING',
    );

    // Compact mobile width (e.g. in 3-column grid)
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 115,
                child: MangaCard(entry: entry),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Berserk'), findsOneWidget);
    expect(find.text('Ch. 364'), findsOneWidget);
  });

  testWidgets('AnimeCard respects fixed 2-line height container for short and long titles', (WidgetTester tester) async {
    final shortEntry = AnimeEntry(
      id: 11,
      mediaId: 11,
      title: 'Bleach',
      progress: 1,
      status: 'FINISHED',
      format: 'TV',
    );

    // Compact mobile width
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: AnimeCard(entry: shortEntry),
              ),
            ),
          ),
        ),
      ),
    );

    // Verify title text exists and is inside a Container of fixed height 30.0
    final textFinder = find.text('Bleach');
    expect(textFinder, findsOneWidget);
    final containerFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(Container),
    ).first;
    final Container containerWidget = tester.widget<Container>(containerFinder);
    expect(containerWidget.constraints?.maxHeight, 30.0);

    // Desktop width
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                child: AnimeCard(entry: shortEntry),
              ),
            ),
          ),
        ),
      ),
    );

    final desktopContainerFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(Container),
    ).first;
    final Container desktopContainerWidget = tester.widget<Container>(desktopContainerFinder);
    expect(desktopContainerWidget.constraints?.maxHeight, 34.0);
  });
}
