import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_date_picker.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_score_slider.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_status_dropdown.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_stepper.dart';
import 'package:seanime_app/presentation/widgets/edit_entry_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Edit Entry Subwidgets Tests', () {
    testWidgets('EditEntryScoreSlider renders and increments/decrements value', (tester) async {
      double score = 7.5;
      await tester.pumpWidget(
        buildTestWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return Consumer(
                builder: (context, ref, _) {
                  final l10n = ref.watch(translationsProvider);
                  return EditEntryScoreSlider(
                    score: score,
                    onChanged: (val) => setState(() => score = val),
                    l10n: l10n,
                  );
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7.5 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(score, 8.0);
      expect(find.text('8 / 10'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(score, 7.5);
      expect(find.text('7.5 / 10'), findsOneWidget);
    });

    testWidgets('EditEntryStepper renders progress with max episodes/chapters', (tester) async {
      int progress = 5;
      await tester.pumpWidget(
        buildTestWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return EditEntryStepper(
                label: 'Episodios vistos',
                value: progress,
                totalCount: 12,
                onChanged: (val) => setState(() => progress = val),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Episodios vistos'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('/ 12'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(progress, 6);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('EditEntryDatePicker renders date and clear icon when date is set', (tester) async {
      DateTime? selectedDate = DateTime(2024, 5, 15);
      await tester.pumpWidget(
        buildTestWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return Consumer(
                builder: (context, ref, _) {
                  final l10n = ref.watch(translationsProvider);
                  return EditEntryDatePicker(
                    label: 'Fecha de inicio',
                    date: selectedDate,
                    onPick: () {},
                    onClear: () => setState(() => selectedDate = null),
                    l10n: l10n,
                  );
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fecha de inicio'), findsOneWidget);
      expect(find.text('2024-05-15'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(selectedDate, isNull);
      expect(find.text('2024-05-15'), findsNothing);
    });

    testWidgets('EditEntryStatusDropdown renders current status label', (tester) async {
      String status = 'CURRENT';
      await tester.pumpWidget(
        buildTestWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return Consumer(
                builder: (context, ref, _) {
                  final l10n = ref.watch(translationsProvider);
                  return EditEntryStatusDropdown(
                    status: status,
                    isAnime: true,
                    onChanged: (s) => setState(() => status = s),
                    l10n: l10n,
                  );
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viendo'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });
  });

  group('EditEntryModal Presentation Tests', () {
    testWidgets('EditEntryModal renders title, ANIME tag, and action buttons', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const EditEntryModal(
            mediaId: 101,
            title: 'Frieren: Beyond Journey\'s End',
            type: 'anime',
            initialStatus: 'CURRENT',
            initialScore: 9.5,
            initialProgress: 14,
            totalCount: 28,
            isEntryInList: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
      expect(find.text('ANIME'), findsOneWidget);
      expect(find.text('9.5 / 10'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('/ 28'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
