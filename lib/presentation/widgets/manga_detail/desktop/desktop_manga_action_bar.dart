import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DesktopMangaActionBar extends ConsumerWidget {
  final int mediaId;
  final String title;
  final int progress;
  final int? idMal;
  final VoidCallback onContinueReading;
  final void Function(String title) onOpenEditEntryModal;
  final VoidCallback onBatchDownload;

  const DesktopMangaActionBar({
    super.key,
    required this.mediaId,
    required this.title,
    required this.progress,
    this.idMal,
    required this.onContinueReading,
    required this.onOpenEditEntryModal,
    required this.onBatchDownload,
  });

  Future<void> _launchAnilist(int mediaId) async {
    try {
      await launchUrlString(
        'https://anilist.co/manga/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _launchMal(int idMal) async {
    try {
      await launchUrlString(
        'https://myanimelist.net/manga/$idMal',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _shareManga(BuildContext context, String title, String message) {
    Clipboard.setData(ClipboardData(text: 'https://anilist.co/manga/$mediaId'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String newStatus,
  ) async {
    final repo = ref.read(repositoryProvider);
    final serverState = ref.read(serverNotifierProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;
    final l10n = ref.read(translationsProvider);

    if (isLoggedIn) {
      await repo.editAnilistListEntry(
        mediaId: mediaId,
        type: 'manga',
        status: newStatus,
        progress: progress,
      );
      ref.invalidate(mangaCollectionProvider);
      ref.invalidate(continueReadingMangaProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.formatStatus(newStatus)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (context.mounted) {
        onOpenEditEntryModal(title);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final label = progress > 0
        ? l10n.continueChapterNumbered(progress + 1)
        : l10n.startReading;

    return Row(
      children: [
        // Big M3E Read Button
        M3EButton.icon(
          style: M3EButtonStyle.filled,
          size: M3EButtonSize.sm,
          shape: M3EButtonShape.round,
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          onPressed: onContinueReading,
        ),
        const SizedBox(width: 10),

        // Bookmark / Status Button (GlassMenuAnchor with fluid detachment)
        GlassMenuAnchor(
          width: 210,
          items: [
            GlassMenuItem(
              label: l10n.statusWatching,
              icon: Icon(
                AppIcons.playCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFF10B981),
              ),
              onPressed: () => _updateStatus(context, ref, 'CURRENT'),
            ),
            GlassMenuItem(
              label: l10n.statusPlanning,
              icon: Icon(
                AppIcons.bookmarkAdded(iconPack),
                size: 18,
                color: const Color(0xFF3B82F6),
              ),
              onPressed: () => _updateStatus(context, ref, 'PLANNING'),
            ),
            GlassMenuItem(
              label: l10n.statusCompleted,
              icon: Icon(
                AppIcons.checkCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFF8B5CF6),
              ),
              onPressed: () => _updateStatus(context, ref, 'COMPLETED'),
            ),
            GlassMenuItem(
              label: l10n.statusPaused,
              icon: Icon(
                AppIcons.pauseCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFFF59E0B),
              ),
              onPressed: () => _updateStatus(context, ref, 'PAUSED'),
            ),
            GlassMenuItem(
              label: l10n.statusDropped,
              icon: Icon(
                AppIcons.cancel(iconPack),
                size: 18,
                color: const Color(0xFFEF4444),
              ),
              onPressed: () => _updateStatus(context, ref, 'DROPPED'),
            ),
            GlassMenuItem(
              label: l10n.editDetails,
              icon: Icon(
                AppIcons.edit(iconPack),
                size: 18,
              ),
              onPressed: () => onOpenEditEntryModal(title),
            ),
          ],
          builder: (context, controller) {
            return M3EIconButton(
              tooltip: l10n.editInAnilist,
              icon: Icon(AppIcons.edit(iconPack), size: 18),
              variant: M3EIconButtonVariant.tonal,
              size: M3EIconButtonSize.sm,
              onPressed: controller.open,
            );
          },
        ),
        const SizedBox(width: 8),

        // Batch Download Button
        M3EIconButton(
          tooltip: l10n.batchDownload,
          icon: const Icon(Icons.download_rounded, size: 18),
          variant: M3EIconButtonVariant.tonal,
          size: M3EIconButtonSize.sm,
          onPressed: onBatchDownload,
        ),
        const SizedBox(width: 8),

        // Share Button
        M3EIconButton(
          tooltip: l10n.share,
          icon: const Icon(Icons.share_rounded, size: 18),
          variant: M3EIconButtonVariant.tonal,
          size: M3EIconButtonSize.sm,
          onPressed: () => _shareManga(context, title, l10n.linkCopiedFor(title)),
        ),
        const SizedBox(width: 8),

        // AniList External Link
        M3EIconButton(
          tooltip: l10n.viewOnAnilist,
          icon: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/icons/AniList_logo.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            ),
          ),
          variant: M3EIconButtonVariant.tonal,
          size: M3EIconButtonSize.sm,
          onPressed: () => _launchAnilist(mediaId),
        ),
        const SizedBox(width: 8),

        // MAL External Link
        if (idMal != null) ...[
          M3EIconButton(
            tooltip: l10n.viewOnMal,
            icon: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/icons/MyAnimeList_Logo.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
            ),
            variant: M3EIconButtonVariant.tonal,
            size: M3EIconButtonSize.sm,
            onPressed: () => _launchMal(idMal!),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
