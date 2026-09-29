import 'package:seanime_app/data/models/anime_entry.dart';

class AiringScheduleItem {
  final int id;
  final int airingAt; // UNIX timestamp in seconds
  final int episode;
  final int? timeUntilAiring; // seconds
  final AnimeEntry media;

  AiringScheduleItem({
    required this.id,
    required this.airingAt,
    required this.episode,
    this.timeUntilAiring,
    required this.media,
  });

  DateTime get airingDateTime => DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);

  factory AiringScheduleItem.fromJson(Map<String, dynamic> json) {
    return AiringScheduleItem(
      id: json['id'] as int? ?? 0,
      airingAt: json['airingAt'] as int? ?? 0,
      episode: json['episode'] as int? ?? 0,
      timeUntilAiring: json['timeUntilAiring'] as int?,
      media: AnimeEntry.fromJson(json['media'] as Map<String, dynamic>? ?? {}),
    );
  }
}
