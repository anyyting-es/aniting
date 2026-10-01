import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_day_tabs.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_desktop_view.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_episode_card.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_mobile_view.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_now_marker.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = List.generate(7, (i) => today.add(Duration(days: i)));
  const l10n = SpanishTranslations();

  final mockEntry1 = AnimeEntry(
    id: 101,
    mediaId: 101,
    title: 'Sousou no Frieren',
    romajiTitle: 'Sousou no Frieren',
    coverImage: 'https://example.com/cover1.jpg',
    progress: 0,
    status: 'RELEASING',
  );

  final mockEntry2 = AnimeEntry(
    id: 102,
    mediaId: 102,
    title: 'Dungeon Meshi',
    romajiTitle: 'Dungeon Meshi',
    coverImage: 'https://example.com/cover2.jpg',
    progress: 0,
    status: 'RELEASING',
  );

  final mockSchedules = [
    // Today: one episode in past (early morning) and one episode in future (night)
    AiringScheduleItem(
      id: 1,
      airingAt: (today.millisecondsSinceEpoch ~/ 1000) + 3600, // 01:00 AM
      episode: 1,
      media: mockEntry1,
    ),
    AiringScheduleItem(
      id: 2,
      airingAt: (today.millisecondsSinceEpoch ~/ 1000) + 80000, // late night
      episode: 2,
      media: mockEntry2,
    ),
    // Tomorrow: one episode
    AiringScheduleItem(
      id: 3,
      airingAt: (today.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000) + 7200,
      episode: 5,
      media: mockEntry1,
    ),
  ];

  group('CalendarDayTabs Tests', () {
    testWidgets('Renders all 7 days and sliding indicator moves on tap', (tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CalendarDayTabs(
                  days: days,
                  selectedIndex: selectedIdx,
                  onDaySelected: (idx) => setState(() => selectedIdx = idx),
                  isSpanish: true,
                );
              },
            ),
          ),
        ),
      );

      // Verify today and days are displayed
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.byType(AnimatedPositioned), findsOneWidget);

      // Tap on the 3rd tab (index 2)
      final thirdTabFinder = find.text('${days[2].month}/${days[2].day}');
      expect(thirdTabFinder, findsOneWidget);
      await tester.tap(thirdTabFinder);
      await tester.pumpAndSettle();

      expect(selectedIdx, 2);
    });
  });

  group('CalendarDesktopView Tests', () {
    testWidgets('Renders multi-column layout with NowMarker and episode cards', (tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1400,
                height: 900,
                child: CalendarDesktopView(
                  days: days,
                  selectedIndex: selectedIdx,
                  onDaySelected: (idx) => selectedIdx = idx,
                  allSchedules: mockSchedules,
                  titleLang: TitleLanguage.romaji,
                  l10n: l10n,
                  isSpanish: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify columns are rendered side by side
      expect(find.byType(CalendarEpisodeCard), findsNWidgets(3));
      expect(find.text('Sousou no Frieren'), findsWidgets);
      expect(find.text('Dungeon Meshi'), findsOneWidget);
      expect(find.byType(CalendarNowMarker), findsOneWidget);
    });
  });

  group('CalendarMobileView Tests', () {
    testWidgets('Renders single-day focused view and changes day on tab click', (tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return CalendarMobileView(
                      days: days,
                      selectedIndex: selectedIdx,
                      onDaySelected: (idx) => setState(() => selectedIdx = idx),
                      allSchedules: mockSchedules,
                      titleLang: TitleLanguage.romaji,
                      l10n: l10n,
                      isSpanish: true,
                      onRefresh: () async {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // On day 0 (today), shows the 2 episodes for today
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text('Dungeon Meshi'), findsOneWidget);

      // Select tomorrow (index 1)
      final tomorrowFinder = find.text('${days[1].month}/${days[1].day}');
      await tester.tap(tomorrowFinder);
      await tester.pumpAndSettle();

      expect(selectedIdx, 1);
      // Episode 5 of Sousou no Frieren is for tomorrow
      expect(find.text('Ep. 5'), findsOneWidget);
    });
  });
}
