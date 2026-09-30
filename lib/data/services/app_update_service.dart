import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seanime_app/data/models/app_update_models.dart';

/// Progress callback for APK download: (downloadedBytes, totalBytes, fraction 0.0 to 1.0)
typedef UpdateDownloadProgressCallback = void Function(int received, int total, double progress);

/// Service for checking updates from GitHub Releases, downloading APKs, and installing them on Android.
class AppUpdateService {
  static const String currentAppVersion = '1.0.0';
  static const String githubOwner = 'anyyting-es';
  static const String githubRepo = 'aniting';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static const MethodChannel _channel = MethodChannel('com.seanime.app/server');

  final Dio _dio;

  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'Aniting-App/$currentAppVersion',
    },
  ));

  /// Checks if a newer release exists on GitHub.
  Future<AppUpdateInfo?> checkForUpdate({String currentVersion = currentAppVersion}) async {
    try {
      final response = await _dio.get(latestReleaseUrl);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;
        return AppUpdateInfo.fromGitHubJson(
          json: json,
          currentVersion: currentVersion,
        );
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No releases published yet on this repo
        debugPrint('[AppUpdateService] No GitHub releases found (404).');
        return AppUpdateInfo(
          tagName: 'v$currentVersion',
          version: currentVersion,
          title: 'Aniting v$currentVersion',
          releaseNotes: 'Estás en la última versión.',
          hasUpdate: false,
        );
      }
      debugPrint('[AppUpdateService] Error checking for update: $e');
      rethrow;
    } catch (e) {
      debugPrint('[AppUpdateService] Unexpected error: $e');
      rethrow;
    }
  }

  /// Downloads the APK to the application cache directory.
  Future<File> downloadApk({
    required String downloadUrl,
    required String fileName,
    UpdateDownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/$fileName';
    final file = File(savePath);

    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }

    final downloadDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
    ));

    await downloadDio.download(
      downloadUrl,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          final progress = (received / total).clamp(0.0, 1.0);
          onProgress(received, total, progress);
        }
      },
    );

    return File(savePath);
  }

  /// Checks if the app has permission to install unknown apps (Android 8.0+).
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      final canInstall = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } catch (e) {
      debugPrint('[AppUpdateService] canRequestPackageInstalls failed: $e');
      return true;
    }
  }

  /// Opens the system settings screen to allow installing unknown apps.
  Future<bool> openInstallPermissionSetting() async {
    if (!Platform.isAndroid) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openInstallPermissionSetting');
      return opened ?? false;
    } catch (e) {
      debugPrint('[AppUpdateService] openInstallPermissionSetting failed: $e');
      return false;
    }
  }

  /// Launches the Android Package Installer for the specified APK file path.
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK installation is only supported on Android.');
    }
    try {
      final result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[AppUpdateService] installApk failed: $e');
      rethrow;
    }
  }
}
