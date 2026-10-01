import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/data/models/app_update_models.dart';
import 'package:seanime_app/data/services/app_update_service.dart';

enum UpdateDownloadStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  downloading,
  downloaded,
  installing,
  error,
}

class AppUpdateState {
  final UpdateDownloadStatus status;
  final AppUpdateInfo? updateInfo;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadedFilePath;
  final String? errorMessage;

  const AppUpdateState({
    this.status = UpdateDownloadStatus.idle,
    this.updateInfo,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadedFilePath,
    this.errorMessage,
  });

  bool get isChecking => status == UpdateDownloadStatus.checking;
  bool get hasUpdate => status == UpdateDownloadStatus.updateAvailable && (updateInfo?.hasUpdate ?? false);
  bool get isDownloading => status == UpdateDownloadStatus.downloading;
  bool get isDownloaded => status == UpdateDownloadStatus.downloaded;
  bool get isInstalling => status == UpdateDownloadStatus.installing;

  AppUpdateState copyWith({
    UpdateDownloadStatus? status,
    AppUpdateInfo? updateInfo,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadedFilePath,
    String? errorMessage,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final installedAppVersionProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(appUpdateServiceProvider);
  return service.getInstalledAppVersion();
});

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  CancelToken? _cancelToken;

  @override
  AppUpdateState build() {
    return const AppUpdateState();
  }

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  /// Checks GitHub Releases for a new version.
  Future<AppUpdateInfo?> checkForUpdate({String? currentVersion}) async {
    state = state.copyWith(status: UpdateDownloadStatus.checking, errorMessage: null);
    try {
      final info = await _service.checkForUpdate(currentVersion: currentVersion);
      if (info != null && info.hasUpdate) {
        state = state.copyWith(
          status: UpdateDownloadStatus.updateAvailable,
          updateInfo: info,
        );
      } else {
        state = state.copyWith(
          status: UpdateDownloadStatus.upToDate,
          updateInfo: info,
        );
      }
      return info;
    } catch (e) {
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Downloads the APK and prepares it for installation.
  Future<void> downloadUpdate() async {
    final info = state.updateInfo;
    final url = info?.apkDownloadUrl;
    if (url == null || url.isEmpty) {
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: 'No se encontró archivo APK adjunto en esta versión.',
      );
      return;
    }

    final fileName = info?.apkFileName ?? 'aniting-${info?.tagName ?? "update"}.apk';

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(
      status: UpdateDownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: info?.apkSizeBytes ?? 0,
      errorMessage: null,
    );

    try {
      final file = await _service.downloadApk(
        downloadUrl: url,
        fileName: fileName,
        cancelToken: _cancelToken,
        onProgress: (received, total, progress) {
          state = state.copyWith(
            downloadProgress: progress,
            downloadedBytes: received,
            totalBytes: total,
          );
        },
      );

      state = state.copyWith(
        status: UpdateDownloadStatus.downloaded,
        downloadProgress: 1.0,
        downloadedFilePath: file.path,
      );

      // Automatically proceed to install on Android
      if (Platform.isAndroid) {
        await installUpdate();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state = state.copyWith(status: UpdateDownloadStatus.updateAvailable);
      } else {
        state = state.copyWith(
          status: UpdateDownloadStatus.error,
          errorMessage: 'Error en la descarga: ${e.message}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: 'Error al descargar la actualización: $e',
      );
    }
  }

  /// Requests package installation via native Android intent.
  Future<void> installUpdate() async {
    final filePath = state.downloadedFilePath;
    if (filePath == null || filePath.isEmpty) return;

    if (!Platform.isAndroid) {
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: 'La instalación directa solo está disponible en Android.',
      );
      return;
    }

    state = state.copyWith(status: UpdateDownloadStatus.installing);

    try {
      final canInstall = await _service.canRequestPackageInstalls();
      if (!canInstall) {
        await _service.openInstallPermissionSetting();
      }
      await _service.installApk(filePath);
      state = state.copyWith(status: UpdateDownloadStatus.downloaded);
    } catch (e) {
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: 'Error al abrir el instalador: $e',
      );
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(status: UpdateDownloadStatus.updateAvailable);
  }
}

final appUpdateNotifierProvider =
    NotifierProvider<AppUpdateNotifier, AppUpdateState>(AppUpdateNotifier.new);
