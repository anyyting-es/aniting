import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/preferences/onboarding_provider.dart';
import 'package:aniting/core/server/server_manager.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/main.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/anime_card.dart';
import 'package:aniting/presentation/widgets/manga_card.dart';

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
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
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
      year: 2023,
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
                child: AnimeCard(entry: entry, showMetadata: true),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sousou no Frieren'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
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

  testWidgets('AnimeCard respects fixed 2-line title display for short and long titles', (WidgetTester tester) async {
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

    // Verify title text exists and has maxLines: 2 with ellipsis
    final textFinder = find.text('Bleach');
    expect(textFinder, findsOneWidget);
    final Text textWidget = tester.widget<Text>(textFinder);
    expect(textWidget.maxLines, 2);
    expect(textWidget.overflow, TextOverflow.ellipsis);

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

    final desktopTextFinder = find.text('Bleach');
    expect(desktopTextFinder, findsOneWidget);
    final Text desktopTextWidget = tester.widget<Text>(desktopTextFinder);
    expect(desktopTextWidget.maxLines, 2);
    expect(desktopTextWidget.overflow, TextOverflow.ellipsis);
  });
}
