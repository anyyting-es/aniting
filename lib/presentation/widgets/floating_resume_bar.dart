import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_reader_screen.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';

class FloatingResumeBar extends ConsumerWidget {
  const FloatingResumeBar({super.key});

  static Future<void> resumePlayback(BuildContext context, WidgetRef ref, LastSessionItem session) async {
    HapticFeedback.mediumImpact();
    final l10n = ref.read(translationsProvider);

    if (session.isAnime) {
      final repo = ref.read(repositoryProvider);
      final serverManager = ref.read(serverManagerProvider);
      final epNum = session.episodeNumber ?? 1;

      // 1. FAST-PATH: If file exists in PC local library, stream directly from disk (0ms)
      try {
        final entry = await repo.getAnimeLibraryEntry(session.mediaId);
        final localEp = entry?.episodes.cast<LibraryEpisode?>().firstWhere(
          (e) => e?.episodeNumber == epNum,
          orElse: () => null,
        );
        if (localEp != null) {
          final streamUrl = localEp.localFilePath != null && localEp.localFilePath!.isNotEmpty
              ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
              : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${session.mediaId}&episodeNumber=${localEp.episodeNumber}';
          final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;
          if (context.mounted) {
            Navigator.of(context).push(
              VideoPlayerScreen.route(
                mediaId: session.mediaId,
                videoUrl: streamUrl,
                title: session.title,
                episodeTitle: localEp.displayTitle.isNotEmpty ? localEp.displayTitle : session.episodeTitle,
                episodeNumber: epNum,
                startPosition: session.positionMs != null
                    ? Duration(milliseconds: session.positionMs!)
                    : null,
                videoSource: fileName != null ? 'Local • $fileName' : l10n.localLibrary,
                isLocalFile: true,
              ),
            );
            return;
          }
        }
      } catch (_) {}

      // 2. TORRENT STREAM RESUME: Torrent stream on server was stopped on player exit, restart it
      final isTorrent = (session.videoUrl?.contains('torrentstream') ?? false) ||
          (session.videoSource?.toLowerCase().contains('torrent') ?? false);

      if (isTorrent) {
        final success = await repo.startTorrentStream(
          mediaId: session.mediaId,
          episodeNumber: epNum,
          autoSelect: true,
        );
        if (success && context.mounted) {
          final streamUrl =
              'http://${serverManager.host}:${serverManager.port}/api/v1/torrentstream/stream/video.mkv';
          Navigator.of(context).push(
            VideoPlayerScreen.route(
              mediaId: session.mediaId,
              videoUrl: streamUrl,
              title: session.title,
              episodeTitle: session.episodeTitle,
              episodeNumber: session.episodeNumber,
              startPosition: session.positionMs != null
                  ? Duration(milliseconds: session.positionMs!)
                  : null,
              videoSource: session.videoSource ?? 'Torrent',
              onDispose: () => repo.stopTorrentStream(),
            ),
          );
          return;
        } else if (context.mounted) {
          AnimeDetailScreen.navigate(context, mediaId: session.mediaId);
          return;
        }
      }

      if (!context.mounted) return;

      if (session.videoUrl != null && session.videoUrl!.isNotEmpty) {
        Navigator.of(context).push(
          VideoPlayerScreen.route(
            mediaId: session.mediaId,
            videoUrl: session.videoUrl!,
            title: session.title,
            episodeTitle: session.episodeTitle,
            episodeNumber: session.episodeNumber,
            startPosition: session.positionMs != null
                ? Duration(milliseconds: session.positionMs!)
                : null,
            headers: session.headers,
            mimeType: session.mimeType,
            videoSource: session.videoSource,
          ),
        );
      } else {
        AnimeDetailScreen.navigate(
          context,
          mediaId: session.mediaId,
        );
      }
    } else {
      if (session.chapterId != null && session.mangaProvider != null) {
        final chNumStr = session.chapterNumber != null
            ? (session.chapterNumber! % 1 == 0
                ? session.chapterNumber!.toInt().toString()
                : session.chapterNumber!.toString())
            : '1';
        final chapter = MangaChapter(
          id: session.chapterId!,
          url: session.chapterId!,
          title: session.subtitle ?? '${l10n.chapter} $chNumStr',
          chapter: chNumStr,
          index: (session.chapterNumber?.toInt() ?? 1) - 1,
        );
        MangaReaderScreen.navigate(
          context,
          mediaId: session.mediaId,
          mangaTitle: session.title,
          provider: session.mangaProvider!,
          chapter: chapter,
          allChapters: [chapter],
          initialPage: session.page ?? 1,
        );
      } else {
        MangaDetailScreen.navigate(
          context,
          mediaId: session.mediaId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(resumeBarEnabledProvider);
    final session = ref.watch(lastSessionProvider);

    if (!enabled || session == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    // Prefer MC (Main Character) image, then coverImage, or auto-resolve from repository
    final resolvedImage = session.displayImage ??
        (session.mediaId > 0
            ? ref
                .watch(sessionMcImageProvider(
                    (mediaId: session.mediaId, isAnime: session.isAnime)))
                .value
            : null);

    if (session.displayImage == null && resolvedImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = ref.read(lastSessionProvider);
        if (current != null &&
            current.mediaId == session.mediaId &&
            current.displayImage == null) {
          ref.read(lastSessionProvider.notifier).saveSession(
                current.copyWith(characterImage: resolvedImage),
              );
        }
      });
    }

    // Format subtitle
    String displaySubtitle = '';
    if (session.isAnime) {
      final epText = session.episodeNumber != null ? '${l10n.episode} ${session.episodeNumber}' : '';
      if (session.positionMs != null && session.durationMs != null && session.durationMs! > 0) {
        final posMin = (session.positionMs! ~/ 60000);
        final posSec = ((session.positionMs! % 60000) ~/ 1000).toString().padLeft(2, '0');
        displaySubtitle = epText.isNotEmpty ? '$epText • $posMin:$posSec' : '$posMin:$posSec';
      } else {
        displaySubtitle = epText.isNotEmpty ? epText : (session.subtitle ?? '');
      }
    } else {
      if (session.chapterNumber != null) {
        final chNum = session.chapterNumber! % 1 == 0
            ? session.chapterNumber!.toInt().toString()
            : session.chapterNumber!.toString();
        final pageText = session.page != null && session.page! > 0 ? ' • ${l10n.page} ${session.page}' : '';
        displaySubtitle = '${l10n.chapter} $chNum$pageText';
      } else {
        displaySubtitle = session.subtitle ?? '';
      }
    }

    final isDark = theme.brightness == Brightness.dark;
    const cardBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(22),
      topRight: Radius.circular(22),
      bottomLeft: Radius.circular(6),
      bottomRight: Radius.circular(6),
    );

    return RepaintBoundary(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -250) {
              // Swiped UP -> Resume
              resumePlayback(context, ref, session);
            } else if (details.primaryVelocity! > 250) {
              // Swiped DOWN -> Dismiss
              HapticFeedback.lightImpact();
              ref.read(lastSessionProvider.notifier).clearSession();
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 3),
          height: 62,
          decoration: BoxDecoration(
            borderRadius: cardBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardBorderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surface.withValues(alpha: 0.90)
                      : theme.colorScheme.surface.withValues(alpha: 0.95),
                  borderRadius: cardBorderRadius,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.40),
                    width: 1.0,
                  ),
                ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => resumePlayback(context, ref, session),
                  borderRadius: cardBorderRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      children: [
                        // Left: Cover Artwork with progress ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            if (session.progressRatio > 0.0)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  value: session.progressRatio,
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                  backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: resolvedImage != null && resolvedImage.isNotEmpty
                                  ? CachedNetworkImage(
                                      memCacheWidth: 110, memCacheHeight: 110, maxWidthDiskCache: 176, maxHeightDiskCache: 176,
                                      imageUrl: resolvedImage,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Icon(
                                        session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      errorWidget: (_, _, _) => Icon(
                                        session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Icon(
                                      session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // Center: Title & Subtitle
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    session.isAnime ? Icons.play_arrow_rounded : Icons.auto_stories_rounded,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      displaySubtitle,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Right: Circular Play Action Button
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(38, 38),
                          ),
                          icon: Icon(
                            session.isAnime ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                            size: 22,
                          ),
                          onPressed: () => resumePlayback(context, ref, session),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
