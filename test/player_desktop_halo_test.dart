import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/player/layouts/player_desktop_layout.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';

void main() {
  group('PlayerDesktopLayout ambient halo', () {
    const haloKey = ValueKey('test-halo');
    const videoColor = Color(0xFF00FF00);
    const haloColor = Color(0xFFFF0000);

    Future<void> pumpLayout(
      WidgetTester tester, {
      required double pageWidth,
      required bool showRail,
      required bool withHalo,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: pageWidth,
              height: 900,
              child: PlayerDesktopLayout(
                layoutMode: PlayerLayoutMode.normal,
                pageHeader: const SizedBox(height: 40),
                viewport: const ColoredBox(color: videoColor),
                watchContent: const SizedBox(height: 200),
                episodesRail: const SizedBox.shrink(),
                showEpisodeRail: showRail,
                ambientHalo: withHalo
                    ? const ColoredBox(key: haloKey, color: haloColor)
                    : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Rect videoRectOf(WidgetTester tester) => tester.getRect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == videoColor),
    );

    testWidgets('the ambient halo is rendered behind the video', (
      tester,
    ) async {
      await pumpLayout(
        tester,
        pageWidth: 1600,
        showRail: true,
        withHalo: true,
      );

      expect(find.byKey(haloKey), findsOneWidget);
    });

    testWidgets('the halo is listed BEFORE the video so it paints below', (
      tester,
    ) async {
      await pumpLayout(
        tester,
        pageWidth: 1600,
        showRail: true,
        withHalo: true,
      );

      // A `Stack` paints its positioned children in list order, so the halo
      // must come first in the child list. If it came last, the blurred copy
      // would be smeared on top of the player.
      final stack = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(haloKey),
              matching: find.byType(Stack),
            )
            .first,
      );

      // The halo is the first positioned child; the video is the second.
      // Both are `Positioned`, so the paint order follows the list order.
      expect(stack.children.length, 2);
      expect(stack.children.first, isA<Positioned>());
      expect(stack.children.last, isA<Positioned>());

      // The first child must contain the halo.
      expect(
        find
            .descendant(
              of: find.byWidget(stack.children.first),
              matching: find.byKey(haloKey),
            )
            .evaluate(),
        isNotEmpty,
        reason: 'the halo must be the first (bottom) child of the stack',
      );

      // The last child must contain the video.
      expect(
        find
            .descendant(
              of: find.byWidget(stack.children.last),
              matching: find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == videoColor,
              ),
            )
            .evaluate(),
        isNotEmpty,
        reason: 'the video must be the last (top) child of the stack',
      );
    });

    testWidgets('halo bleeds symmetrically on all sides of the video', (
      tester,
    ) async {
      await pumpLayout(
        tester,
        pageWidth: 1600,
        showRail: true,
        withHalo: true,
      );

      final videoRect = videoRectOf(tester);
      final haloRect = tester.getRect(find.byKey(haloKey));

      expect(
        videoRect.left - haloRect.left,
        closeTo(haloRect.right - videoRect.right, 0.5),
        reason: 'halo must bleed symmetrically left/right',
      );
      expect(
        videoRect.top - haloRect.top,
        closeTo(haloRect.bottom - videoRect.bottom, 0.5),
        reason: 'halo must bleed symmetrically top/bottom',
      );
      expect(videoRect.left - haloRect.left, greaterThan(0));
    });

    testWidgets('the video keeps a 16:9 aspect ratio', (tester) async {
      await pumpLayout(
        tester,
        pageWidth: 1600,
        showRail: true,
        withHalo: true,
      );

      final videoRect = videoRectOf(tester);
      expect(videoRect.width / videoRect.height, closeTo(16 / 9, 0.01));
    });

    testWidgets('halo is never clipped by the page viewport', (tester) async {
      for (final width in [1280.0, 1600.0, 1920.0, 2560.0]) {
        for (final rail in [true, false]) {
          await pumpLayout(
            tester,
            pageWidth: width,
            showRail: rail,
            withHalo: true,
          );

          final haloRect = tester.getRect(find.byKey(haloKey));
          final pageRect = tester.getRect(find.byType(PlayerDesktopLayout));

          expect(
            haloRect.left,
            greaterThanOrEqualTo(pageRect.left - 0.5),
            reason: 'halo must stay inside the viewport on the left '
                '(w=$width rail=$rail)',
          );
          expect(
            haloRect.right,
            lessThanOrEqualTo(pageRect.right + 0.5),
            reason: 'halo must stay inside the viewport on the right '
                '(w=$width rail=$rail)',
          );
        }
      }
    });

    testWidgets('the halo room is reserved before the halo exists', (
      tester,
    ) async {
      await pumpLayout(
        tester,
        pageWidth: 1600,
        showRail: true,
        withHalo: false,
      );

      final videoRect = videoRectOf(tester);
      final pageRect = tester.getRect(find.byType(PlayerDesktopLayout));

      // The player is laid out exactly like the halo-enabled page: the bleed
      // room is reserved from the very first frame, so the video does not
      // shrink/slide once playback starts and the halo is built.
      expect(
        videoRect.left - pageRect.left,
        closeTo(
          PlayerDesktopLayout.haloBleed + 24,
          1.0,
        ),
      );
    });

    testWidgets('hiding the rail keeps the video size and centers it', (
      tester,
    ) async {
      await pumpLayout(
        tester,
        pageWidth: 1920,
        showRail: true,
        withHalo: false,
      );
      final withRail = videoRectOf(tester);

      await pumpLayout(
        tester,
        pageWidth: 1920,
        showRail: false,
        withHalo: false,
      );
      final withoutRail = videoRectOf(tester);
      final pageRect = tester.getRect(find.byType(PlayerDesktopLayout));

      expect(withoutRail.width, closeTo(withRail.width, 0.5));
      expect(withoutRail.height, closeTo(withRail.height, 0.5));
      expect(
        withoutRail.center.dx,
        closeTo(pageRect.center.dx, 0.5),
        reason: 'the video must stay centered when the rail is hidden',
      );
    });

    testWidgets('the video keeps its exact rect when the halo appears', (
      tester,
    ) async {
      // 1100 px sits right around the rail breakpoint once the bleed room is
      // reserved, so it also catches the rail collapsing when playback starts.
      for (final width in [1100.0, 1280.0, 1600.0, 1920.0]) {
        await pumpLayout(
          tester,
          pageWidth: width,
          showRail: true,
          withHalo: false,
        );
        final before = videoRectOf(tester);

        await pumpLayout(
          tester,
          pageWidth: width,
          showRail: true,
          withHalo: true,
        );
        final after = videoRectOf(tester);

        expect(after.left, closeTo(before.left, 0.5), reason: 'w=$width');
        expect(after.top, closeTo(before.top, 0.5), reason: 'w=$width');
        expect(after.width, closeTo(before.width, 0.5), reason: 'w=$width');
        expect(after.height, closeTo(before.height, 0.5), reason: 'w=$width');
      }
    });
  });
}
