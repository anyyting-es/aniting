import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart';
import 'package:seanime_app/presentation/widgets/anizip_episode_list.dart';
import 'package:seanime_app/presentation/widgets/online_stream_view.dart';

class AnimeDetailTvLayout extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeEntry? initialEntry;
  final AnimeDetails? details;
  final AniZipData? aniZipData;
  final bool isLoading;
  final bool isLoadingAniZip;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final AnimeDetailTab currentTab;

  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final void Function(String title) onOpenEditEntryModal;
  final Future<void> Function() onRetryAniZip;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  }) onOpenTorrentSelector;
  final VoidCallback onOpenDetailsModal;

  const AnimeDetailTvLayout({
    super.key,
    required this.mediaId,
    this.initialEntry,
    required this.details,
    required this.aniZipData,
    required this.isLoading,
    required this.isLoadingAniZip,
    required this.isLocalMode,
    required this.hasLocalFiles,
    required this.currentTab,
    required this.onToggleLocalMode,
    required this.onTabChanged,
    required this.onOpenEditEntryModal,
    required this.onRetryAniZip,
    required this.onOpenTorrentSelector,
    required this.onOpenDetailsModal,
  });

  @override
  ConsumerState<AnimeDetailTvLayout> createState() => _AnimeDetailTvLayoutState();
}

class _AnimeDetailTvLayoutState extends ConsumerState<AnimeDetailTvLayout> {
  final FocusNode _playButtonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the primary play button on TV
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playButtonFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _playButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);

    final title = widget.details?.displayTitle(titleLang) ??
        widget.initialEntry?.displayTitle(titleLang) ??
        widget.details?.title ??
        l10n.loading;

    final bannerUrl = widget.details?.bannerImage ??
        widget.initialEntry?.bannerImage ??
        widget.details?.coverImage;

    final liveCollectionEntry = ref.watch(animeCollectionProvider).whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
    final progress = liveCollectionEntry?.progress ??
        widget.details?.progress ??
        widget.initialEntry?.progress ??
        0;
    final totalEps = widget.details?.totalEpisodes ?? widget.initialEntry?.totalEpisodes;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen ambient backdrop
          if (bannerUrl != null)
            CachedNetworkImage(
              imageUrl: bannerUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),

          // Deep gradient overlay for 10-foot readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.4),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // TV Safe Area Navigation
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),

                  // Anime Title (Large 10-foot scale)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metadata subtitle
                  Text(
                    '${widget.details?.format ?? "TV"} • ${progress > 0 ? "Progreso: Ep $progress/$totalEps" : "${totalEps ?? "?"} Episodios"} • ${widget.details?.status ?? ""}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Big Focusable Buttons (DPAD friendly)
                  Row(
                    children: [
                      Focus(
                        focusNode: _playButtonFocus,
                        child: Builder(
                          builder: (ctx) {
                            final hasFocus = Focus.of(ctx).hasFocus;
                            return FilledButton.icon(
                              onPressed: () async {
                                final nextEp = progress + 1;
                                try {
                                  final repo = ref.read(repositoryProvider);
                                  final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
                                  final localEp = entry?.episodes.cast<LibraryEpisode?>().firstWhere(
                                    (e) => e?.episodeNumber == nextEp,
                                    orElse: () => null,
                                  );
                                  if (localEp != null) {
                                    if (!ctx.mounted) return;
                                    final serverManager = ref.read(serverManagerProvider);
                                    final l10n = ref.read(translationsProvider);
                                    final titleLang = ref.read(titleLanguageProvider);
                                    final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
                                    final streamUrl = localEp.localFilePath != null && localEp.localFilePath!.isNotEmpty
                                        ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
                                        : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${localEp.episodeNumber}';
                                    final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;

                                    Navigator.of(ctx, rootNavigator: true).push(
                                      VideoPlayerScreen.route(
                                        mediaId: widget.mediaId,
                                        videoUrl: streamUrl,
                                        title: animeTitle,
                                        episodeTitle: localEp.displayTitle.isNotEmpty ? localEp.displayTitle : 'Episodio $nextEp',
                                        episodeNumber: nextEp,
                                        videoSource: fileName != null ? 'Local • $fileName' : l10n.localLibrary,
                                        isLocalFile: true,
                                        animeDetails: widget.details,
                                        aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
                                      ),
                                    );
                                    return;
                                  }
                                } catch (_) {}

                                if (widget.currentTab == AnimeDetailTab.torrent) {
                                  widget.onOpenTorrentSelector(
                                    episodeNumber: nextEp,
                                    episodeTitle: 'Episodio $nextEp',
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: hasFocus ? Colors.white : theme.colorScheme.primary,
                                foregroundColor: hasFocus ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: hasFocus
                                      ? const BorderSide(color: Colors.white, width: 3)
                                      : BorderSide.none,
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 28),
                              label: Text(
                                progress > 0 ? 'Continuar (Ep ${progress + 1})' : 'Empezar a ver',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // More details button
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenDetailsModal,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 24),
                        label: const Text(
                          'Detalles',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Episodes rail / container
                  Expanded(
                    flex: 2,
                    child: widget.currentTab == AnimeDetailTab.torrent
                        ? AniZipEpisodeListView(
                            aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
                            fallbackEpisodes: widget.details?.episodes ?? const [],
                            animeDetails: widget.details,
                            isLoading: widget.isLoading || widget.isLoadingAniZip,
                            progress: progress,
                            onRetry: widget.onRetryAniZip,
                            onPlayEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                          )
                        : OnlineStreamView(
                            mediaId: widget.mediaId,
                            animeDetails: widget.details,
                            progress: progress,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
