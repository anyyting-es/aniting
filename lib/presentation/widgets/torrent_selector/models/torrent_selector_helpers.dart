import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:seanime_app/data/models/torrent_models.dart';

class TorrentStreamLaunchInfo {
  final int mediaId;
  final String videoUrl;
  final String title;
  final String episodeTitle;
  final int episodeNumber;
  final String videoSource;
  final VoidCallback onDispose;

  const TorrentStreamLaunchInfo({
    required this.mediaId,
    required this.videoUrl,
    required this.title,
    required this.episodeTitle,
    required this.episodeNumber,
    required this.videoSource,
    required this.onDispose,
  });
}

enum TorrentHealthLevel {
  excellent,
  good,
  medium,
  poor,
  dead,
}

class TorrentHealthInfo {
  final TorrentHealthLevel level;
  final Color color;
  final String label;

  const TorrentHealthInfo({
    required this.level,
    required this.color,
    required this.label,
  });

  static TorrentHealthInfo resolve(int seeders, AppTranslations l10n) {
    if (seeders >= 40) {
      return TorrentHealthInfo(
        level: TorrentHealthLevel.excellent,
        color: const Color(0xFF10B981), // Emerald
        label: l10n.torrentHealthExcellent,
      );
    } else if (seeders >= 15) {
      return TorrentHealthInfo(
        level: TorrentHealthLevel.good,
        color: const Color(0xFF34D399), // Mint green
        label: l10n.torrentHealthGood,
      );
    } else if (seeders >= 5) {
      return TorrentHealthInfo(
        level: TorrentHealthLevel.medium,
        color: const Color(0xFFFBBF24), // Amber
        label: l10n.torrentHealthMedium,
      );
    } else if (seeders >= 1) {
      return TorrentHealthInfo(
        level: TorrentHealthLevel.poor,
        color: const Color(0xFFFB923C), // Orange
        label: l10n.torrentHealthPoor,
      );
    } else {
      return TorrentHealthInfo(
        level: TorrentHealthLevel.dead,
        color: const Color(0xFFEF4444), // Rose red
        label: l10n.torrentHealthDead,
      );
    }
  }
}

class TorrentNameParser {
  /// Extracts the release group name (e.g. "SubsPlease", "Erai-raws", "Judas")
  static String? extractReleaseGroup(TorrentItem item) {
    if (item.releaseGroup != null && item.releaseGroup!.trim().isNotEmpty) {
      return item.releaseGroup!.trim();
    }
    final match = RegExp(r'^\s*\[([^\]]+)\]').firstMatch(item.name);
    if (match != null) {
      final grp = match.group(1)?.trim();
      if (grp != null && grp.isNotEmpty && !grp.toLowerCase().contains('batch')) {
        return grp;
      }
    }
    return null;
  }

  /// Cleans redundant hashes (e.g. [9A1B2C3D]) and file extensions (.mkv, .mp4)
  static String cleanDisplayTitle(String rawName) {
    var clean = rawName
        .replaceAll(RegExp(r'\.mkv|\.mp4|\.avi', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[[a-fA-F0-9]{8}\]'), '')
        .trim();

    // Strip leading group if bracketed at start: [SubsPlease] Title -> Title
    final groupMatch = RegExp(r'^\s*\[[^\]]+\]\s*').firstMatch(clean);
    if (groupMatch != null) {
      clean = clean.substring(groupMatch.end).trim();
    }

    return clean.isNotEmpty ? clean : rawName;
  }
}

bool isBatchTorrent(TorrentItem torrent) {
  final name = torrent.name.toLowerCase();

  // 1. Explicit batch / complete release keywords
  if (RegExp(
    r'\b(?:batch|complete\s*series?|completa|completo|temporada\s+completa|serie\s+completa|all\s+episodes|entire\s+series)\b',
  ).hasMatch(name)) {
    return true;
  }

  // 2. Explicit single episode patterns: e.g. "S3-04", "S03E04", "S1 - 04", "Ep 04"
  final singleEpPatterns = [
    RegExp(r'\b[sS]\d{1,2}\s*[-_eE]\s*\d{1,3}\b'),
    RegExp(r'\b(?:ep|eps|e|cap|capitulo|cap[ií]tulo|episodio)\.?\s*0*(\d{1,4})\b', caseSensitive: false),
    RegExp(r'\s+-\s+0*(\d{1,3})(?:v\d+)?\b'),
  ];

  bool hasSingleEp = false;
  for (final pattern in singleEpPatterns) {
    if (pattern.hasMatch(torrent.name)) {
      hasSingleEp = true;
      break;
    }
  }

  // 3. Multi-season ranges (e.g. "S01-S03", "Season 1-3")
  final isMultiSeason = RegExp(
    r'\b[sS]\d{1,2}\s*[-~]\s*[sS]\d{1,2}\b|\b(?:season|temporada)\s*\d{1,2}\s*[-~]\s*(?:season|temporada)?\s*\d{1,2}\b|\b(?:seasons|temporadas)\s*\d{1,2}\s*[-~]\s*\d{1,2}\b',
    caseSensitive: false,
  ).hasMatch(name);

  if (isMultiSeason) return true;

  // 4. Bracketed or explicit episode ranges
  final bracketedRange = RegExp(
    r'[\[\(]\s*(?:ep|eps|e)?\s*(\d{1,3})\s*[-~]\s*(?:ep|eps|e)?\s*(\d{1,3})\s*[\]\)]',
  ).firstMatch(name);
  if (bracketedRange != null) {
    final start = int.tryParse(bracketedRange.group(1) ?? '');
    final end = int.tryParse(bracketedRange.group(2) ?? '');
    if (start != null && end != null && end > start) return true;
  }

  final epRange = RegExp(
    r'\b(?:ep|eps|e)\s*(\d{1,3})\s*[-~]\s*(?:ep|eps|e)?\s*(\d{1,3})\b',
  ).firstMatch(name);
  if (epRange != null) {
    final start = int.tryParse(epRange.group(1) ?? '');
    final end = int.tryParse(epRange.group(2) ?? '');
    if (start != null && end != null && end > start) return true;
  }

  if (hasSingleEp) return false;

  return torrent.isBatch;
}

List<TorrentItem> filterTorrentsList(
  List<TorrentItem> torrents, {
  required String quality,
  required bool showOnlyBatches,
}) {
  var list = torrents;
  if (showOnlyBatches) {
    list = list.where((t) => isBatchTorrent(t)).toList();
  }
  if (quality == 'Todos') {
    return list;
  }
  return list.where((t) {
    final res = (t.resolution ?? '').toLowerCase();
    final name = t.name.toLowerCase();
    switch (quality) {
      case '1080p':
        return res.contains('1080') || name.contains('1080');
      case '720p':
        return res.contains('720') || name.contains('720');
      case '2160p / 4K':
        return res.contains('2160') || res.contains('4k') || name.contains('2160') || name.contains('4k');
      case '480p':
        return res.contains('480') || res.contains('540') || name.contains('480');
      default:
        return true;
    }
  }).toList();
}
