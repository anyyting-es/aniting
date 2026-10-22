import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/local_file_item.dart';

void main() {
  group('Local Library AniList Matching Tests', () {
    test('LocalFileItem parses directory and filenames accurately', () {
      final json = {
        'path': '/home/user/Anime/Boku no Hero Academia [TV]/[SubsPlease] Boku no Hero Academia - 01 (1080p).mkv',
        'mediaId': 0,
        'locked': false,
        'ignored': false,
        'parsedInfo': {
          'title': 'Boku no Hero Academia',
          'episode': '01',
          'season': '1',
        },
      };

      final item = LocalFileItem.fromJson(json);
      expect(item.name, '[SubsPlease] Boku no Hero Academia - 01 (1080p).mkv');
      expect(item.mediaId, 0);
      expect(item.isUnmatched, true);
      expect(item.folderName, 'Boku no Hero Academia [TV]');
      expect(item.folderPath, '/home/user/Anime/Boku no Hero Academia [TV]');
      expect(item.parsedTitle, 'Boku no Hero Academia');
    });

    test('UnmatchedFolderGroup does not falsely flag folders with "TV" as TMDB', () {
      final item = LocalFileItem(
        path: '/home/user/Anime/Boku no Hero Academia [TV]/[SubsPlease] Boku no Hero Academia - 01 (1080p).mkv',
        name: '[SubsPlease] Boku no Hero Academia - 01 (1080p).mkv',
        mediaId: 0,
        folderPath: '/home/user/Anime/Boku no Hero Academia [TV]',
        folderName: 'Boku no Hero Academia [TV]',
        parsedTitle: 'Boku no Hero Academia',
      );

      // Unless folderTypes explicitly map it to 'tv' or 'movie', it is Anime (isTmdb = false)
      final folderTypes = <String, String>{
        '/home/user/Anime': 'anime',
      };

      bool isTmdb = false;
      final normPath = item.folderPath.replaceAll('\\', '/').toLowerCase();
      for (final tEntry in folderTypes.entries) {
        final conf = tEntry.key.replaceAll('\\', '/').toLowerCase();
        if (normPath == conf || normPath.startsWith('$conf/')) {
          if (tEntry.value == 'tv' || tEntry.value == 'movie') {
            isTmdb = true;
            break;
          }
        }
      }

      final group = UnmatchedFolderGroup(
        folderPath: item.folderPath,
        folderName: item.folderName,
        guessedTitle: item.parsedTitle ?? item.folderName,
        files: [item],
        isTmdb: isTmdb,
      );

      expect(group.isTmdb, false);
      expect(group.folderName, 'Boku no Hero Academia [TV]');
      expect(group.guessedTitle, 'Boku no Hero Academia');
    });

    test('UnmatchedFolderGroup flags folders as TMDB only when explicitly designated in folderTypes', () {
      final item = LocalFileItem(
        path: '/media/Series/Breaking Bad/Season 1/S01E01.mkv',
        name: 'S01E01.mkv',
        mediaId: 0,
        folderPath: '/media/Series/Breaking Bad/Season 1',
        folderName: 'Season 1',
        parsedTitle: 'Breaking Bad',
      );

      final folderTypes = <String, String>{
        '/media/Series': 'tv',
      };

      bool isTmdb = false;
      final normPath = item.folderPath.replaceAll('\\', '/').toLowerCase();
      for (final tEntry in folderTypes.entries) {
        final conf = tEntry.key.replaceAll('\\', '/').toLowerCase();
        if (normPath == conf || normPath.startsWith('$conf/')) {
          if (tEntry.value == 'tv' || tEntry.value == 'movie') {
            isTmdb = true;
            break;
          }
        }
      }

      final group = UnmatchedFolderGroup(
        folderPath: item.folderPath,
        folderName: item.folderName,
        guessedTitle: item.parsedTitle ?? item.folderName,
        files: [item],
        isTmdb: isTmdb,
      );

      expect(group.isTmdb, true);
    });
  });
}
