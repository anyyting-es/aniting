import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/i18n/translations/es.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/data/models/airing_schedule.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/presentation/widgets/calendar/calendar_month_view.dart';

void main() {
  final now = DateTime.now();

  final entry = AnimeEntry(
    id: 101,
    mediaId: 101,
    title: 'Sousou no Frieren',
    romajiTitle: 'Sousou no Frieren',
    coverImage: 'https://example.com/cover1.jpg',
    progress: 0,
    status: 'RELEASING',
  );
  final airingAt =
      (DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000) +
          3600;
  final schedule = AiringScheduleItem(
    id: 1,
    airingAt: airingAt,
    episode: 1,
    media: entry,
  );

  Finder posterImage() => find.byWidgetPredicate(
    (w) => w is CachedNetworkImage && w.memCacheHeight == 720,
  );

  Widget buildCalendar({GlobalKey<NavigatorState>? navigatorKey}) {
    return ProviderScope(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 900,
            child: CalendarMonthView(
              currentMonth: DateTime(now.year, now.month, 1),
              onMonthChanged: (_) {},
              allSchedules: [schedule],
              titleLang: TitleLanguage.romaji,
              l10n: const SpanishTranslations(),
              isSpanish: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> hoverTitle(WidgetTester tester, TestGesture gesture) async {
    final title = find.text('Sousou no Frieren').first;
    await gesture.moveTo(tester.getCenter(title));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('month view keeps loose titles with time and a large hover cover',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildCalendar());
    await tester.pump();

    final airedAt = DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);
    final expectedTime =
        '${airedAt.hour.toString().padLeft(2, '0')}:${airedAt.minute.toString().padLeft(2, '0')}';
    expect(find.text(expectedTime), findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await hoverTitle(tester, gesture);

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    final size = tester.getSize(find.byType(CachedNetworkImage));
    expect(size.width, 158);
    expect(size.height, 238);

    await gesture.moveTo(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('hover cover lives inside the calendar, not the root overlay',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildCalendar(navigatorKey: navigatorKey));
    await tester.pump();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await hoverTitle(tester, gesture);
    expect(posterImage(), findsOneWidget);

    // The poster is part of the month view subtree. It used to be an entry in
    // the root overlay, which kept it floating above every route.
    expect(
      find.descendant(
        of: find.byType(CalendarMonthView),
        matching: posterImage(),
      ),
      findsOneWidget,
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('OTHER PAGE'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OTHER PAGE'), findsOneWidget);
    // Opening another route dismisses the poster (it can no longer float on
    // top of the new page).
    expect(posterImage(), findsNothing);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('OTHER PAGE'), findsNothing);
  });

  testWidgets('opening a day hides the hover cover', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildCalendar());
    await tester.pump();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await hoverTitle(tester, gesture);
    expect(posterImage(), findsOneWidget);

    // Pick a day a few columns away so neither the poster nor the hovered
    // title absorbs the tap.
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final targetDay = now.day + 3 <= daysInMonth ? now.day + 3 : now.day - 3;
    await tester.tap(find.text('$targetDay').first);
    await tester.pumpAndSettle();

    // The day modal is open and the poster is gone.
    expect(posterImage(), findsNothing);
  });
}
