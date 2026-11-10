import 'dart:async';

import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/data/models/trailer_streams.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/trailer/trailer_media_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desktop trailer dialog.
///
/// The embedded YouTube iFrame player is not available on Linux/Windows, so the
/// trailer is resolved by the companion server into directly playable URLs and
/// played with media_kit. Resolution is the slow part (6–8 s the first time, then
/// cached server-side), which is why the dialog opens immediately with a spinner
/// instead of blocking the tap.
class TrailerMediaDialog extends ConsumerStatefulWidget {
  final String trailerId;
  final String? title;

  /// Invoked when the stream could not be resolved, so the caller can fall back
  /// to the external player.
  final VoidCallback onResolveFailed;

  const TrailerMediaDialog({
    super.key,
    required this.trailerId,
    required this.onResolveFailed,
    this.title,
  });

  @override
  ConsumerState<TrailerMediaDialog> createState() => _TrailerMediaDialogState();
}

class _TrailerMediaDialogState extends ConsumerState<TrailerMediaDialog> {
  TrailerStreams? _streams;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final streams = await ref
        .read(repositoryProvider)
        .resolveTrailer(widget.trailerId);

    if (!mounted) return;

    if (streams == null) {
      setState(() => _failed = true);
      // Nothing to show inline: hand over to the platform player.
      widget.onResolveFailed();
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _streams = streams);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final rawTitle = widget.title?.trim() ?? '';
    final title = rawTitle.isNotEmpty ? rawTitle : l10n.officialTrailer;
    final streams = _streams;

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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (streams != null)
                      TrailerMediaPlayer(
                        streams: streams,
                        onReady: () {
                          if (mounted && !_playing) {
                            setState(() => _playing = true);
                          }
                        },
                      ),
                    if (!_playing && !_failed)
                      const Center(
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
