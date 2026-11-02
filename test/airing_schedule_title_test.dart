import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';

void main() {
  test('AiringScheduleItem parses AniList media title correctly', () {
    final rawJson = {
      "id": 415245,
      "airingAt": 1793671200,
      "episode": 22,
      "media": {
        "id": 213188,
        "title": {
          "userPreferred": "Jueshi Zhan Hun 2",
          "romaji": "Jueshi Zhan Hun 2",
          "english": null,
          "native": "绝世战魂 第2季"
        },
        "coverImage": {
          "large": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/medium/bx213188-zwmmMVqqUjh8.png",
          "extraLarge": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx213188-zwmmMVqqUjh8.png",
          "medium": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/small/bx213188-zwmmMVqqUjh8.png"
        }
      }
    };

    final item = AiringScheduleItem.fromJson(rawJson);
    expect(item.media.displayTitle(TitleLanguage.romaji), equals('Jueshi Zhan Hun 2'));
    expect(item.media.displayTitle(TitleLanguage.english), equals('Jueshi Zhan Hun 2'));
    expect(item.media.title, equals('Jueshi Zhan Hun 2'));
  });
}
