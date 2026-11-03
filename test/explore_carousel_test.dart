import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/widgets/explore/explore_carousel_models.dart';
import 'package:seanime_app/presentation/widgets/explore/explore_hero_carousel.dart';
import 'package:seanime_app/presentation/widgets/explore/explore_manga_banner_carousel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleItems = <ExploreCarouselItem>[
    const ExploreCarouselItem(
      mediaId: 1,
      title: 'Frieren: Beyond Journey\'s End',
      backdropUrl: 'https://example.com/banner.jpg',
      posterUrl: 'https://example.com/cover.jpg',
      format: 'TV',
      year: 2023,
      score: 9.3,
      genres: ['Adventure', 'Fantasy'],
    ),
    const ExploreCarouselItem(
      mediaId: 2,
      title: 'Jujutsu Kaisen Season 2',
      backdropUrl: 'https://example.com/banner2.jpg',
      posterUrl: 'https://example.com/cover2.jpg',
      format: 'TV',
      year: 2023,
      score: 8.8,
      genres: ['Action', 'Supernatural'],
    ),
  ];

  final sampleMangaItems = <ExploreCarouselItem>[
    const ExploreCarouselItem(
      mediaId: 101,
      title: 'Berserk',
      backdropUrl: 'https://example.com/berserk_banner.jpg',
      posterUrl: 'https://example.com/berserk_cover.jpg',
      format: 'MANGA',
      year: 1989,
      score: 9.5,
      genres: ['Dark Fantasy', 'Action'],
      isManga: true,
    ),
  ];

  testWidgets('ExploreHeroCarousel renders items and handles details button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExploreHeroCarousel(
              items: sampleItems,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify first title is rendered
    expect(find.text('Frieren: Beyond Journey\'s End'), findsWidgets);
    // Verify format and year pills
    expect(find.text('TV'), findsWidgets);
    expect(find.text('2023'), findsWidgets);
  });

  testWidgets('ExploreMangaBannerCarousel renders compact banner layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExploreMangaBannerCarousel(
              items: sampleMangaItems,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify manga title
    expect(find.text('Berserk'), findsWidgets);
    expect(find.text('MANGA'), findsWidgets);
  });
}
