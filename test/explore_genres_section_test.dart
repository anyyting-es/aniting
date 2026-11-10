import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/presentation/screens/genres_screen.dart';
import 'package:aniting/presentation/widgets/explore/explore_genres_section.dart';

Widget _harness({bool isTv = false}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ExploreGenresSection(isDesktop: true, isTv: isTv),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the genres section with a name per card', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 300));

    final l10n = ProviderScope.containerOf(
      tester.element(find.byType(ExploreGenresSection)),
    ).read(translationsProvider);
    expect(find.text(l10n.genresTitle), findsOneWidget);
    expect(find.text(l10n.seeMore), findsOneWidget);

    final first = kAppGenres.first;
    final bySpanish = find.text(first.nameEs);
    final byEnglish = find.text(first.nameEn);
    expect(
      bySpanish.evaluate().isNotEmpty || byEnglish.evaluate().isNotEmpty,
      isTrue,
      reason: 'The first genre name must be painted on top of its card',
    );
  });

  testWidgets('renders on TV layout too', (tester) async {
    await tester.pumpWidget(_harness(isTv: true));
    await tester.pump(const Duration(milliseconds: 300));

    final first = kAppGenres.first;
    expect(
      find.text(first.nameEs).evaluate().isNotEmpty ||
          find.text(first.nameEn).evaluate().isNotEmpty,
      isTrue,
    );
  });
}
