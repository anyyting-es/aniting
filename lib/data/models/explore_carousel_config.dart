class ExploreFeaturedItem {
  final int mediaId;
  final String title;
  final String? horizontalBackground;
  final String? verticalBackground;
  final String? logo;
  final String? description;
  final int? year;
  final String? format;
  final double? score;
  final List<String> genres;

  const ExploreFeaturedItem({
    required this.mediaId,
    required this.title,
    this.horizontalBackground,
    this.verticalBackground,
    this.logo,
    this.description,
    this.year,
    this.format,
    this.score,
    this.genres = const [],
  });

  factory ExploreFeaturedItem.fromJson(Map<String, dynamic> json) {
    return ExploreFeaturedItem(
      mediaId: json['media_id'] as int? ?? json['mediaId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      horizontalBackground: json['horizontal_background'] as String? ?? json['horizontalBackground'] as String?,
      verticalBackground: json['vertical_background'] as String? ?? json['verticalBackground'] as String?,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      year: json['year'] as int?,
      format: json['format'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'media_id': mediaId,
    'title': title,
    if (horizontalBackground != null) 'horizontal_background': horizontalBackground,
    if (verticalBackground != null) 'vertical_background': verticalBackground,
    if (logo != null) 'logo': logo,
    if (description != null) 'description': description,
    if (year != null) 'year': year,
    if (format != null) 'format': format,
    if (score != null) 'score': score,
    'genres': genres,
  };
}

class ExploreCarouselConfig {
  final int version;
  final String? updatedAt;
  final List<ExploreFeaturedItem> items;

  const ExploreCarouselConfig({
    required this.version,
    this.updatedAt,
    this.items = const [],
  });

  factory ExploreCarouselConfig.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ExploreCarouselConfig(
      version: json['version'] as int? ?? 1,
      updatedAt: json['updated_at'] as String? ?? json['updatedAt'] as String?,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => ExploreFeaturedItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    if (updatedAt != null) 'updated_at': updatedAt,
    'items': items.map((e) => e.toJson()).toList(),
  };

  static const ExploreCarouselConfig empty = ExploreCarouselConfig(version: 0, items: []);
}
