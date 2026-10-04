import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadHistoryItem serialization', () {
    test('toMap and fromMap roundtrip correctly', () {
      final now = DateTime.now();
      final item = DownloadHistoryItem(
        id: 'torrent_123',
        title: 'Sousou no Frieren - 01',
        subtitle: '1080p Web-DL',
        coverImage: 'https://example.com/cover.jpg',
        size: '1.2 GB',
        type: 'torrent',
        completedAt: now,
        filePath: '/downloads/frieren_01.mkv',
        mediaId: 154587,
      );

      final map = item.toMap();
      final fromMap = DownloadHistoryItem.fromMap(map);

      expect(fromMap.id, equals('torrent_123'));
      expect(fromMap.title, equals('Sousou no Frieren - 01'));
      expect(fromMap.subtitle, equals('1080p Web-DL'));
      expect(fromMap.size, equals('1.2 GB'));
      expect(fromMap.type, equals('torrent'));
      expect(fromMap.mediaId, equals(154587));
      expect(fromMap.filePath, equals('/downloads/frieren_01.mkv'));
    });

    test('toJson and fromJson roundtrip correctly', () {
      final now = DateTime.now();
      final item = DownloadHistoryItem(
        id: 'manga_456',
        title: 'Chainsaw Man',
        subtitle: 'Capítulo 150',
        size: '45 MB',
        type: 'manga',
        completedAt: now,
        mediaId: 98765,
      );

      final jsonStr = item.toJson();
      final fromJson = DownloadHistoryItem.fromJson(jsonStr);

      expect(fromJson.id, equals('manga_456'));
      expect(fromJson.title, equals('Chainsaw Man'));
      expect(fromJson.type, equals('manga'));
      expect(fromJson.mediaId, equals(98765));
    });
  });

  group('DownloadHistoryNotifier operations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with empty list and records completed downloads', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(downloadHistoryProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      final testItem = DownloadHistoryItem(
        id: 'test_1',
        title: 'Attack on Titan Final',
        size: '800 MB',
        type: 'torrent',
        completedAt: DateTime.now(),
      );

      await notifier.addItem(testItem);

      final state = container.read(downloadHistoryProvider);
      expect(state.length, equals(1));
      expect(state.first.title, equals('Attack on Titan Final'));

      // Remove single item
      await notifier.removeItem('test_1');
      expect(container.read(downloadHistoryProvider), isEmpty);

      // Add back and clear
      await notifier.addItem(testItem);
      expect(container.read(downloadHistoryProvider).length, equals(1));

      await notifier.clearHistory();
      expect(container.read(downloadHistoryProvider), isEmpty);
    });
  });
}
