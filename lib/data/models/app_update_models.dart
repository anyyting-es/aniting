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

    // Look for .apk asset
    String? downloadUrl;
    String? fileName;
    int? sizeBytes;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final aName = (asset['name'] as String?) ?? '';
          if (aName.toLowerCase().endsWith('.apk')) {
            fileName = aName;
            downloadUrl = asset['browser_download_url'] as String?;
            sizeBytes = (asset['size'] as num?)?.toInt();
            break;
          }
        }
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

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0).
  static bool isVersionNewer({
    required String remoteVersion,
    required String currentVersion,
  }) {
    if (remoteVersion.isEmpty) return false;
    try {
      final remoteParts = _parseVersion(remoteVersion);
      final currentParts = _parseVersion(currentVersion);

      for (int i = 0; i < 3; i++) {
        final r = remoteParts[i];
        final c = currentParts[i];
        if (r > c) return true;
        if (r < c) return false;
      }
      // If major.minor.patch are equal, check build number if present
      if (remoteParts.length > 3 && currentParts.length > 3) {
        return remoteParts[3] > currentParts[3];
      }
      return false;
    } catch (_) {
      return remoteVersion != currentVersion;
    }
  }

  static List<int> _parseVersion(String version) {
    // Strip leading 'v' and extract major.minor.patch+build
    final clean = version.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final mainAndBuild = clean.split('+');
    final dotParts = mainAndBuild[0].split('.');

    final major = dotParts.isNotEmpty ? (int.tryParse(dotParts[0]) ?? 0) : 0;
    final minor = dotParts.length > 1 ? (int.tryParse(dotParts[1]) ?? 0) : 0;
    final patch = dotParts.length > 2 ? (int.tryParse(dotParts[2]) ?? 0) : 0;

    final parts = [major, minor, patch];
    if (mainAndBuild.length > 1) {
      final build = int.tryParse(mainAndBuild[1]) ?? 0;
      parts.add(build);
    }
    return parts;
  }
}
