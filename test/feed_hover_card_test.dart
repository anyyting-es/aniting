import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_preview_data.dart';
import 'package:aniting/presentation/widgets/feed/feed_hover_card.dart';

const _sample = ShowPreviewData(
  title: 'Sousou no Frieren',
  subtitle: 'Frieren: Beyond Journey\'s End',
  description:
      'Tras derrotar al Rey Demonio, la maga elfa Frieren emprende un viaje '
      'para comprender a los humanos y el paso del tiempo.',
  genres: ['Aventura', 'Drama', 'Fantasía'],
  progress: 12,
  totalCount: 28,
  meta: [
    ShowPreviewMeta('2023', Icons.calendar_today_rounded),
    ShowPreviewMeta('TV', Icons.movie_filter_rounded),
    ShowPreviewMeta('9.1', Icons.star_rounded),
  ],
);

Widget _buildHarness({
  required VoidCallback onOpenDetails,
  ShowPreviewData Function()? dataBuilder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 40, top: 120),
          child: SizedBox(
            width: 140,
            height: 210,
            child: FeedHoverCard(
              dataBuilder: dataBuilder ?? () => _sample,
              onOpenDetails: onOpenDetails,
              child: const ColoredBox(
                key: ValueKey('anchor'),
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _hoverAnchor(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('anchor'))));
  // Rest on the card past the hover delay, then let the growth finish.
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  testWidgets('hover opens the expand card with details', (tester) async {
    await tester.pumpWidget(_buildHarness(onOpenDetails: () {}));

    expect(find.text('Sousou no Frieren'), findsNothing);

    await _hoverAnchor(tester);

    expect(find.text('Sousou no Frieren'), findsOneWidget);
    expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
    expect(find.textContaining('Aventura'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
    expect(find.text('12/28'), findsOneWidget);
    expect(find.textContaining('Rey Demonio'), findsOneWidget);
  });

  testWidgets('tapping the card opens the details', (tester) async {
    var opened = false;
    await tester.pumpWidget(_buildHarness(onOpenDetails: () => opened = true));

    await _hoverAnchor(tester);
    await tester.tap(find.text('Sousou no Frieren'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });

  testWidgets('does not expand before the hover delay', (tester) async {
    await tester.pumpWidget(_buildHarness(onOpenDetails: () {}));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('anchor'))),
    );

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Sousou no Frieren'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Sousou no Frieren'), findsOneWidget);
  });

  testWidgets('leaving the card closes the expand card', (tester) async {
    await tester.pumpWidget(_buildHarness(onOpenDetails: () {}));

    final gesture = await _hoverAnchor(tester);
    expect(find.text('Sousou no Frieren'), findsOneWidget);

    await gesture.moveTo(const Offset(760, 40));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Sousou no Frieren'), findsNothing);
  });

  testWidgets('renders without a cover and without a synopsis', (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        onOpenDetails: () {},
        dataBuilder: () => const ShowPreviewData(title: 'Sin datos'),
      ),
    );

    await _hoverAnchor(tester);

    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.textContaining('Rey Demonio'), findsNothing);
  });
}
