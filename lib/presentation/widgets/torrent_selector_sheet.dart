import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/torrent_selector_dialog.dart';

export 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart'
    show TorrentStreamLaunchInfo;

class TorrentSelectorSheet extends StatelessWidget {
  final int mediaId;
  final int episodeNumber;
  final String episodeTitle;
  final AnimeDetails? animeDetails;
  final String? aniDBEpisode;
  final bool isSheet;
  final bool isDownloadMode;
  final List<int>? initialSelectedEpisodes;

  const TorrentSelectorSheet({
    super.key,
    required this.mediaId,
    required this.episodeNumber,
    required this.episodeTitle,
    this.animeDetails,
    this.aniDBEpisode,
    this.isSheet = false,
    this.isDownloadMode = false,
    this.initialSelectedEpisodes,
  });

  @override
  Widget build(BuildContext context) {
    return TorrentSelectorDialog(
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      animeDetails: animeDetails,
      aniDBEpisode: aniDBEpisode,
      isSheet: isSheet,
      isDownloadMode: isDownloadMode,
      initialSelectedEpisodes: initialSelectedEpisodes,
    );
  }
}
