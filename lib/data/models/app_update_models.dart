import 'dart:ffi';

/// Model representing a GitHub Release update for Aniting.
class AppUpdateInfo {
  final String tagName;
  final String version;
  final String title;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSizeBytes;
  final DateTime? publishedAt;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.releaseNotes,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSizeBytes,
    this.publishedAt,
    this.hasUpdate = false,
  });

  /// Formatted size in MB (e.g., '117.8 MB')
  String get formattedSize {
    if (apkSizeBytes == null || apkSizeBytes! <= 0) return '';
    final mb = apkSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory AppUpdateInfo.fromGitHubJson({
    required Map<String, dynamic> json,
    required String currentVersion,
  }) {
    final tag = (json['tag_name'] as String?)?.trim() ?? '';
    final cleanVersion = tag.replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final name = (json['name'] as String?)?.trim() ?? tag;
    final body = (json['body'] as String?)?.trim() ?? '';
    final publishedStr = json['published_at'] as String?;
    DateTime? publishedDate;
    if (publishedStr != null) {
      publishedDate = DateTime.tryParse(publishedStr);
    }

    // Look for .apk asset (prioritizing architecture match or universal)
    String? downloadUrl;
    String? fileName;
    int? sizeBytes;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      String targetAbiKeyword = '';
      try {
        final currentAbi = Abi.current();
        if (currentAbi == Abi.androidArm64) {
          targetAbiKeyword = 'arm64-v8a';
        } else if (currentAbi == Abi.androidArm) {
          targetAbiKeyword = 'armeabi-v7a';
        } else if (currentAbi == Abi.androidX64) {
          targetAbiKeyword = 'x86_64';
        }
      } catch (_) {}

      Map<String, dynamic>? selectedAsset;

      // 1. Try to find APK matching device ABI
      if (targetAbiKeyword.isNotEmpty) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final aName = ((asset['name'] as String?) ?? '').toLowerCase();
            if (aName.endsWith('.apk') && aName.contains(targetAbiKeyword)) {
              selectedAsset = asset;
              break;
            }
          }
        }
      }

      // 2. If not found, look for universal apk (app-release.apk or universal)
      if (selectedAsset == null) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final aName = ((asset['name'] as String?) ?? '').toLowerCase();
            if (aName.endsWith('.apk') &&
                (aName == 'app-release.apk' || aName.contains('universal'))) {
              selectedAsset = asset;
              break;
            }
          }
        }
      }

      // 3. Fallback to any .apk asset
      if (selectedAsset == null) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final aName = ((asset['name'] as String?) ?? '').toLowerCase();
            if (aName.endsWith('.apk')) {
              selectedAsset = asset;
              break;
            }
          }
        }
      }

      if (selectedAsset != null) {
        fileName = (selectedAsset['name'] as String?) ?? '';
        downloadUrl = selectedAsset['browser_download_url'] as String?;
        sizeBytes = (selectedAsset['size'] as num?)?.toInt();
      }
    }

    final isNewer = isVersionNewer(remoteVersion: cleanVersion, currentVersion: currentVersion);

    return AppUpdateInfo(
      tagName: tag,
      version: cleanVersion,
      title: name.isNotEmpty ? name : 'Aniting $tag',
      releaseNotes: body,
      apkDownloadUrl: downloadUrl,
      apkFileName: fileName,
      apkSizeBytes: sizeBytes,
      publishedAt: publishedDate,
      hasUpdate: isNewer,
    );
  }

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0, 1.0.1-beta > 1.0.0).
  static bool isVersionNewer({
    required String remoteVersion,
    required String currentVersion,
  }) {
    if (remoteVersion.isEmpty) return false;
    try {
      final remoteParts = _parseVersion(remoteVersion);
      final currentParts = _parseVersion(currentVersion);

      for (int i = 0; i < remoteParts.length && i < currentParts.length; i++) {
        final r = remoteParts[i];
        final c = currentParts[i];
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return remoteVersion != currentVersion;
    }
  }

  static List<int> _parseVersion(String version) {
    // 1. Strip leading 'v' or 'V' and trim
    String clean = version.trim().replaceFirst(RegExp(r'^[vV]'), '');

    // 2. Extract build number if present after '+' (e.g. 1.0.0+1)
    int buildNum = 0;
    if (clean.contains('+')) {
      final plusParts = clean.split('+');
      clean = plusParts[0];
      final bStr = plusParts[1].replaceAll(RegExp(r'\D'), '');
      if (bStr.isNotEmpty) {
        buildNum = int.tryParse(bStr) ?? 0;
      }
    }

    // 3. Extract pre-release tag if present after '-' (e.g. 1.0.1-beta, 1.0.0-beta.2, 1.0.0-rc1)
    int preReleaseNum = 0;
    bool hasPreRelease = false;
    if (clean.contains('-')) {
      hasPreRelease = true;
      final dashParts = clean.split('-');
      clean = dashParts[0];
      final preStr = dashParts.sublist(1).join('-');
      final preDigits = preStr.replaceAll(RegExp(r'\D'), '');
      if (preDigits.isNotEmpty) {
        preReleaseNum = int.tryParse(preDigits) ?? 0;
      }
    }

    // 4. Parse major.minor.patch
    final dotParts = clean.split('.');
    final major = dotParts.isNotEmpty ? (int.tryParse(dotParts[0].replaceAll(RegExp(r'\D'), '')) ?? 0) : 0;
    final minor = dotParts.length > 1 ? (int.tryParse(dotParts[1].replaceAll(RegExp(r'\D'), '')) ?? 0) : 0;
    final patch = dotParts.length > 2 ? (int.tryParse(dotParts[2].replaceAll(RegExp(r'\D'), '')) ?? 0) : 0;

    // Structure: [major, minor, patch, isStable, preReleaseNum, buildNum]
    // where isStable is 1 if NO pre-release suffix, or 0 if pre-release (e.g. -beta).
    // This correctly handles:
    // - 1.0.1-beta (patch 1) > 1.0.0 (patch 0) -> true
    // - 1.0.0 (stable, isStable 1) > 1.0.0-beta (isStable 0) -> true
    // - 1.0.0-beta.2 (preNum 2) > 1.0.0-beta.1 (preNum 1) -> true
    // - 1.0.0+2 (build 2) > 1.0.0+1 (build 1) -> true
    return [major, minor, patch, hasPreRelease ? 0 : 1, preReleaseNum, buildNum];
  }
}
