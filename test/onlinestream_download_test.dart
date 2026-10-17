import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/downloads/online_stream_download_task.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/online_stream_download_provider.dart';

void main() {
  group('OnlineStreamDownloadTask Tests', () {
    test('serializes and deserializes properly from backend payload', () {
      final json = {
        'id': '101_1',
        'mediaId': 101,
        'episodeNumber': 1,
        'animeTitle': 'Sousou no Frieren',
        'episodeTitle': 'The Journey Begins',
        'thumbnail': 'https://example.com/thumb.jpg',
        'providerId': 'zoro',
        'providerName': 'Zoro Provider',
        'server': 'vidcloud',
        'quality': '1080p',
        'videoUrl': 'https://example.com/stream.m3u8',
        'headers': {'Referer': 'https://example.com'},
        'isHls': true,
        'savePath': '/library/Sousou no Frieren/Sousou no Frieren - 01.mp4',
        'status': 'downloading',
        'progress': 0.65,
        'downloadedBytes': 157286400,
        'speed': '3.2 MB/s',
        'subtitles': [
          {
            'url': 'https://example.com/sub.vtt',
            'language': 'Spanish',
            'isDefault': true,
          }
        ],
        'createdAt': '2026-10-17T18:00:00Z',
      };

      final task = OnlineStreamDownloadTask.fromJson(json);

      expect(task.id, '101_1');
      expect(task.mediaId, 101);
      expect(task.episodeNumber, 1);
      expect(task.animeTitle, 'Sousou no Frieren');
      expect(task.episodeTitle, 'The Journey Begins');
      expect(task.status, OnlineStreamDownloadStatus.downloading);
      expect(task.isActive, isTrue);
      expect(task.isDone, isFalse);
      expect(task.progress, 0.65);
      expect(task.speed, '3.2 MB/s');
      expect(task.downloadedBytes, 157286400);
      expect(task.subtitles.length, 1);
      expect(task.subtitles.first.language, 'Spanish');
      expect(task.subtitles.first.isDefault, isTrue);
    });

    test('OnlinestreamSubtitle toJson serializes properly', () {
      const sub = OnlinestreamSubtitle(
        id: 'es',
        url: 'https://example.com/sub_es.vtt',
        language: 'Spanish',
        isDefault: true,
      );

      final json = sub.toJson();
      expect(json['id'], 'es');
      expect(json['url'], 'https://example.com/sub_es.vtt');
      expect(json['language'], 'Spanish');
      expect(json['isDefault'], isTrue);
    });

    test('OnlineStreamDownloadState filters active, paused and visible tasks', () {
      final task1 = OnlineStreamDownloadTask(
        id: '1_1',
        mediaId: 1,
        episodeNumber: 1,
        animeTitle: 'Anime 1',
        episodeTitle: 'Ep 1',
        providerId: 'p',
        providerName: 'P',
        server: 's',
        quality: '1080p',
        videoUrl: 'u',
        savePath: 'p',
        status: OnlineStreamDownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      final task2 = OnlineStreamDownloadTask(
        id: '1_2',
        mediaId: 1,
        episodeNumber: 2,
        animeTitle: 'Anime 1',
        episodeTitle: 'Ep 2',
        providerId: 'p',
        providerName: 'P',
        server: 's',
        quality: '1080p',
        videoUrl: 'u',
        savePath: 'p',
        status: OnlineStreamDownloadStatus.completed,
        createdAt: DateTime.now(),
      );

      final task3 = OnlineStreamDownloadTask(
        id: '1_3',
        mediaId: 1,
        episodeNumber: 3,
        animeTitle: 'Anime 1',
        episodeTitle: 'Ep 3',
        providerId: 'p',
        providerName: 'P',
        server: 's',
        quality: '1080p',
        videoUrl: 'u',
        savePath: 'p',
        status: OnlineStreamDownloadStatus.failed,
        error: 'Network timeout',
        createdAt: DateTime.now(),
      );

      final state = OnlineStreamDownloadState({
        task1.id: task1,
        task2.id: task2,
        task3.id: task3,
      });

      expect(state.allTasks.length, 3);
      expect(state.activeTasks.length, 1);
      expect(state.activeTasks.first.id, '1_1');
      expect(state.isDownloading(1, 1), isTrue);
      expect(state.isDownloading(1, 2), isFalse);
      expect(state.visibleTasks.length, 2); // task1 (downloading) and task3 (failed)
    });
  });
}
