import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Lightweight, centered trailer popup.
///
/// Plays YouTube trailers inline with the official iFrame player where the
/// platform supports an embedded WebView (Android, iOS, macOS, Web). On
/// Linux/Windows — or for non-YouTube sources such as Dailymotion — it falls
/// back to opening the platform's own player.
class TrailerPlayerDialog extends ConsumerStatefulWidget {
  final String trailerId;
  final String? title;

  const TrailerPlayerDialog({
    super.key,
    required this.trailerId,
    this.title,
  });

  /// Whether an inline WebView-backed player can be embedded on this platform.
  static bool get canEmbedInline {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Opens a centered trailer popup, or the external player when inline
  /// playback is unavailable.
  static Future<void> show(
    BuildContext context, {
    required String? trailerId,
    String? trailerSite,
    String? title,
  }) async {
    if (trailerId == null || trailerId.isEmpty) return;

    final site = trailerSite?.toLowerCase();
    final isYouTube = site == null || site == 'youtube';
    if (!canEmbedInline || !isYouTube) {
      await openExternal(trailerId, trailerSite);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => TrailerPlayerDialog(trailerId: trailerId, title: title),
    );
  }

  /// Opens the trailer in the platform's own player (YouTube app, browser…).
  static Future<void> openExternal(
    String trailerId,
    String? trailerSite,
  ) async {
    final site = trailerSite?.toLowerCase();
    final url = site == 'dailymotion'
        ? 'https://www.dailymotion.com/video/$trailerId'
        : 'https://www.youtube.com/watch?v=$trailerId';
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  ConsumerState<TrailerPlayerDialog> createState() =>
      _TrailerPlayerDialogState();
}

class _TrailerPlayerDialogState extends ConsumerState<TrailerPlayerDialog> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.trailerId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final rawTitle = widget.title?.trim() ?? '';
    final title = rawTitle.isNotEmpty ? rawTitle : l10n.officialTrailer;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
              child: Row(
                children: [
                  Icon(
                    AppIcons.video(iconPack),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(AppIcons.close(iconPack), size: 20),
                    tooltip: l10n.close,
                  ),
                ],
              ),
            ),
            Flexible(
              child: YoutubePlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
