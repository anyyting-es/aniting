import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

class SourceInfoView extends ConsumerWidget {
  final String? videoSource;
  final String? videoUrl;
  final bool isUsingExoPlayer;

  const SourceInfoView({
    super.key,
    required this.videoSource,
    required this.videoUrl,
    required this.isUsingExoPlayer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final sourceLabel = videoSource ?? l10n.unknown;
    final fullUrl = videoUrl ?? sourceLabel;
    final isLocal = fullUrl.startsWith('/') || sourceLabel.startsWith('Local');
    final isTorrent = sourceLabel.startsWith('Torrent');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  isTorrent
                      ? AppIcons.downloadOffline(iconPack)
                      : isLocal
                          ? AppIcons.folder(iconPack)
                          : AppIcons.stream(iconPack),
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTorrent
                          ? l10n.sourceTorrent
                          : isLocal
                              ? l10n.sourceFile
                              : l10n.sourceStream,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sourceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Engine row
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.playbackEngineLabel}:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUsingExoPlayer ? 'ExoPlayer' : 'libmpv',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // URL / Link title
          Text(
            isLocal ? '${l10n.filePathLabel}:' : '${l10n.sourceUrlLabel}:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // URL box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: SelectableText(
              fullUrl,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Copy button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: 0.18),
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: primaryColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
              ),
              icon: Icon(AppIcons.copy(iconPack), size: 16),
              label: Text(
                isLocal ? l10n.copyPath : l10n.copyLink,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fullUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isLocal ? l10n.pathCopied : l10n.linkCopied,
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
