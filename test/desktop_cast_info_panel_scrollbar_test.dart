import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/cast/desktop_cast_info_panel.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/cast/desktop_cast_models.dart';

void main() {
  testWidgets('DesktopCastInfoPanel scrollbar has a valid scroll position',
      (tester) async {
    final item = DesktopCastItem(
      id: 1,
      name: 'Yuji Itadori',
      role: 'MAIN',
      bio: List.filled(
        40,
        'A first-year student at Jujutsu High with an unusually strong body.',
      ).join(' '),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 500,
                child: DesktopCastInfoPanel(item: item),
              ),
            ),
          ),
        ),
      ),
    );

    // Let the scrollbar schedule and run its post-frame validity check.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsOneWidget);
  });
}
