import 'package:flutter/material.dart';

class ExtensionItem {
  final String id;
  final String name;
  final String version;
  final String manifestUri;
  final String payloadUri;
  final String language;
  final String type;
  final String description;
  final String author;
  final String? icon;
  final String lang;
  final bool disabled;
  final bool hasUpdate;
  final bool isBuiltin;
  final int stars;
  /// Capability declared by marketplace metadata / provider settings:
  /// `anime`, `tmdb` or `both`. Null when the source does not declare it.
  final String? providerType;

  const ExtensionItem({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.manifestUri = '',
    this.payloadUri = '',
    this.language = 'javascript',
    required this.type,
    this.description = '',
    this.author = 'Desconocido',
    this.icon,
    this.lang = 'multi',
    this.disabled = false,
    this.hasUpdate = false,
    this.isBuiltin = false,
    this.stars = 0,
    this.providerType,
  });

  factory ExtensionItem.fromJson(Map<String, dynamic> json, {bool disabled = false, bool hasUpdate = false}) {
    final manifestUri = json['manifestURI'] as String? ?? json['manifestUri'] as String? ?? '';
    final payloadUri = json['payloadURI'] as String? ?? json['payloadUri'] as String? ?? '';
    final stars = json['stars'] is int ? json['stars'] as int : 0;
    return ExtensionItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      version: json['version'] as String? ?? '1.0.0',
      manifestUri: manifestUri,
      payloadUri: payloadUri,
      language: json['language'] as String? ?? 'javascript',
      type: json['type'] as String? ?? 'plugin',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? 'Desconocido',
      icon: json['icon'] as String?,
      lang: json['lang'] as String? ?? 'multi',
      disabled: disabled,
      hasUpdate: hasUpdate,
      isBuiltin: manifestUri == 'builtin',
      stars: stars,
      providerType: json['providerType']?.toString(),
    );
  }

  /// Whether this extension is an online streaming provider that only resolves
  /// TMDB movies/series (VidSrc, Torrentio, ...).
  ///
  /// It prefers the declared `providerType`; for repositories that do not
  /// declare it, the TMDB capability is inferred from the metadata text.
  bool get isTmdbOnlyProvider {
    if (type.toLowerCase() != 'onlinestream-provider') return false;
    final declared = providerType?.trim().toLowerCase();
    if (declared == 'tmdb') return true;
    if (declared == 'anime' || declared == 'both') return false;
    final haystack = '$id $name $description'.toLowerCase();
    return haystack.contains('tmdb');
  }

  String get typeLabel {
    switch (type) {
      case 'anime-torrent-provider':
        return 'Anime Torrents';
      case 'onlinestream-provider':
        return 'Online Streaming';
      case 'manga-provider':
        return 'Manga';
      case 'plugin':
        return 'Plugins';
      default:
        return type;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'anime-torrent-provider':
        return Icons.cloud_download_rounded;
      case 'onlinestream-provider':
        return Icons.play_circle_filled_rounded;
      case 'manga-provider':
        return Icons.menu_book_rounded;
      case 'plugin':
        return Icons.extension_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'anime-torrent-provider':
        return const Color(0xFF38BDF8); // Sky blue
      case 'onlinestream-provider':
        return const Color(0xFFA855F7); // Purple
      case 'manga-provider':
        return const Color(0xFFF97316); // Orange
      case 'plugin':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF6B7280);
    }
  }
}
