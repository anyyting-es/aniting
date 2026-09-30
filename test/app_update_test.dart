import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/app_update_models.dart';
import 'package:seanime_app/presentation/widgets/update/app_update_dialog.dart';

class _MaterialIconPackNotifier extends IconPackNotifier {
  @override
  AppIconPack build() => AppIconPack.material;
}

void main() {
  group('AppUpdateInfo Version Comparison Tests', () {
    test('Correctly identifies newer versions', () {
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.1', currentVersion: '1.0.0'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.1-beta', currentVersion: '1.0.0'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: 'v1.0.1-beta', currentVersion: '1.0.0'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: 'v1.0.1-beta', currentVersion: '1.0.0-beta'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.0', currentVersion: '1.0.0-beta'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.0-beta.2', currentVersion: '1.0.0-beta.1'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: 'v1.1.0', currentVersion: '1.0.0'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '2.0.0', currentVersion: '1.9.9'),
        isTrue,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.0+2', currentVersion: '1.0.0+1'),
        isTrue,
      );
    });

    test('Correctly identifies same or older versions', () {
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.0', currentVersion: '1.0.0'),
        isFalse,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: 'v1.0.0', currentVersion: '1.0.0'),
        isFalse,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: 'v1.0.1-beta', currentVersion: '1.0.1-beta'),
        isFalse,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '1.0.0-beta', currentVersion: '1.0.0'),
        isFalse,
      );
      expect(
        AppUpdateInfo.isVersionNewer(remoteVersion: '0.9.9', currentVersion: '1.0.0'),
        isFalse,
      );
    });

    test('Parses GitHub Release JSON correctly with APK asset', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': 'Aniting v1.0.1 - Novedades',
        'body': '• Corrección de errores\n• In-app updates integradas',
        'published_at': '2026-09-30T12:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/anyyting-es/aniting/releases/download/v1.0.1/app-release.apk',
            'size': 123456789,
          },
          {
            'name': 'other_file.txt',
            'browser_download_url': 'https://example.com/other.txt',
            'size': 100,
          }
        ],
      };

      final update = AppUpdateInfo.fromGitHubJson(
        json: json,
        currentVersion: '1.0.0',
      );

      expect(update.hasUpdate, isTrue);
      expect(update.version, '1.0.1');
      expect(update.tagName, 'v1.0.1');
      expect(update.apkFileName, 'app-release.apk');
      expect(
        update.apkDownloadUrl,
        'https://github.com/anyyting-es/aniting/releases/download/v1.0.1/app-release.apk',
      );
      expect(update.apkSizeBytes, 123456789);
      expect(update.formattedSize, '117.7 MB');
      expect(update.releaseNotes, contains('In-app updates integradas'));
    });
  });

  group('AppUpdateDialog Widget Tests', () {
    testWidgets('Renders update dialog with release notes and action buttons', (tester) async {
      const updateInfo = AppUpdateInfo(
        tagName: 'v1.0.1',
        version: '1.0.1',
        title: 'Aniting v1.0.1',
        releaseNotes: '• Nuevas funciones de actualización\n• Corrección de bugs',
        apkDownloadUrl: 'https://example.com/app-release.apk',
        apkFileName: 'app-release.apk',
        apkSizeBytes: 52428800, // 50 MB
        hasUpdate: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iconPackProvider.overrideWith(_MaterialIconPackNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AppUpdateDialog(updateInfo: updateInfo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nueva versión'), findsOneWidget);
      expect(find.text('v1.0.1'), findsOneWidget);
      expect(find.textContaining('Novedades y Cambios'), findsOneWidget);
      expect(find.textContaining('Nuevas funciones de actualización'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsOneWidget);
      expect(find.text('Más tarde'), findsOneWidget);
    });
  });
}
