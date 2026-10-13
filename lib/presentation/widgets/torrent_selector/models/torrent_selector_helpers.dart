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

class ParsedTorrentTags {
  final String? videoCodec;
  final bool is10Bit;
  final String? audioCodec;
  final bool isDualAudio;
  final bool isMultiSubs;
  final int? episode;

  const ParsedTorrentTags({
    this.videoCodec,
    this.is10Bit = false,
    this.audioCodec,
    this.isDualAudio = false,
    this.isMultiSubs = false,
    this.episode,
  });
}

enum TorrentSortField {
  none,
  seeders,
  size,
  date,
  resolution,
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

  /// Parses video, audio, and subtitle tags from torrent name
  static ParsedTorrentTags parseTags(TorrentItem item) {
    final name = item.name;
    final lower = name.toLowerCase();

    // 1. Video Codec
    String? videoCodec;
    if (RegExp(r'\b(?:h\.?264|x264|avc)\b', caseSensitive: false).hasMatch(name)) {
      if (lower.contains('avc')) {
        videoCodec = 'AVC';
      } else {
        videoCodec = 'H.264';
      }
    } else if (RegExp(r'\b(?:hevc|h\.?265|x265)\b', caseSensitive: false).hasMatch(name)) {
      videoCodec = 'HEVC';
    } else if (lower.contains('av1')) {
      videoCodec = 'AV1';
    }

    // 2. 10bit
    final is10Bit = RegExp(r'\b(?:10-?bit|hi10p)\b', caseSensitive: false).hasMatch(name);

    // 3. Audio Codec
    String? audioCodec;
    if (RegExp(r'\baac(?:2\.0|\s*2\.0)?\b', caseSensitive: false).hasMatch(name)) {
      audioCodec = 'AAC2.0';
    } else if (lower.contains('aac')) {
      audioCodec = 'AAC';
    } else if (lower.contains('flac')) {
      audioCodec = 'FLAC';
    } else if (lower.contains('opus')) {
      audioCodec = 'OPUS';
    } else if (lower.contains('e-ac-3') || lower.contains('eac3')) {
      audioCodec = 'E-AC-3';
    } else if (lower.contains('ac3') || lower.contains('ac-3')) {
      audioCodec = 'AC3';
    }

    // 4. Dual Audio / Dub
    final isDualAudio = RegExp(
      r'\b(?:dual[- ]audio|dual|original\s*\+\s*dub|multi[- ]audio|dubbed|dub)\b',
      caseSensitive: false,
    ).hasMatch(name);

    // 5. Multi Subs
    final isMultiSubs = RegExp(
      r'\b(?:multi[- ]?subs?|softsubs?)\b',
      caseSensitive: false,
    ).hasMatch(name);

    // 6. Episode number
    int? ep = item.episodeNumber;
    if (ep == null) {
      final epMatch = RegExp(r'(?:[-_ ]|s\d{1,2}e)(\d{1,3})(?:v\d+)?\b', caseSensitive: false).firstMatch(name);
      if (epMatch != null) {
        ep = int.tryParse(epMatch.group(1) ?? '');
      }
    }

    return ParsedTorrentTags(
      videoCodec: videoCodec,
      is10Bit: is10Bit,
      audioCodec: audioCodec,
      isDualAudio: isDualAudio,
      isMultiSubs: isMultiSubs,
      episode: ep,
    );
  }

  /// Formats raw date or ISO string into human-friendly relative format
  static String formatRelativeDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '';
    final trimmed = rawDate.trim();
    if (trimmed.contains('ago') || trimmed.contains('hace') || trimmed.contains('yesterday')) {
      return trimmed;
    }

    final dt = DateTime.tryParse(trimmed);
    if (dt == null) return trimmed;

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative) return 'recently';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
      return '$m min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 60) {
      return 'about a month ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'about $months months ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return 'about $years year${years > 1 ? 's' : ''} ago';
    }
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

List<TorrentItem> sortTorrents(
  List<TorrentItem> torrents,
  TorrentSortField field,
  bool ascending,
) {
  if (field == TorrentSortField.none) return torrents;
  final list = List<TorrentItem>.from(torrents);

  int resToScore(String? r) {
    if (r == null) return 0;
    final l = r.toLowerCase();
    if (l.contains('2160') || l.contains('4k')) return 4;
    if (l.contains('1080')) return 3;
    if (l.contains('720')) return 2;
    if (l.contains('480') || l.contains('540')) return 1;
    return 0;
  }

  list.sort((a, b) {
    int cmp = 0;
    switch (field) {
      case TorrentSortField.seeders:
        cmp = a.seeders.compareTo(b.seeders);
        break;
      case TorrentSortField.size:
        cmp = a.size.compareTo(b.size);
        break;
      case TorrentSortField.resolution:
        cmp = resToScore(a.resolution).compareTo(resToScore(b.resolution));
        break;
      case TorrentSortField.date:
        final da = DateTime.tryParse(a.date ?? '');
        final db = DateTime.tryParse(b.date ?? '');
        if (da != null && db != null) {
          cmp = da.compareTo(db);
        } else {
          cmp = (a.date ?? '').compareTo(b.date ?? '');
        }
        break;
      case TorrentSortField.none:
        break;
    }
    return ascending ? cmp : -cmp;
  });

  return list;
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
