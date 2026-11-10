import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'desktop_cast_models.dart';

/// Prominent vertical showcase card for the Seiyuu (voice actor).
/// Displays a large vertical portrait photo on top, and detailed actor information underneath.
class DesktopCastSeiyuuCard extends ConsumerWidget {
  final DesktopCastItem item;
  final bool isLoadingVa;
  final double width;
  final double height;

  const DesktopCastSeiyuuCard({
    super.key,
    required this.item,
    this.isLoadingVa = false,
    this.width = 235,
    this.height = 405,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasVa = item.vaName != null && item.vaName!.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey('va_card_${item.id}_${item.vaName}'),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Large Vertical Portrait Image (Top position, no overlay) ──
              Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isLoadingVa
                        ? Container(
                            color: isDark ? const Color(0xFF191C22) : Colors.black12,
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          )
                        : (hasVa && item.vaImageUrl != null && item.vaImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.vaImageUrl!,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                memCacheWidth: 480,
                                fadeInDuration: const Duration(milliseconds: 180),
                                errorWidget: (_, _, _) => _buildPlaceholder(iconPack, theme, isDark),
                              )
                            : _buildPlaceholder(iconPack, theme, isDark)),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 3. Information Underneath the Image ──
                SizedBox(
                  height: 64,
                  child: isLoadingVa
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 130,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.black12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 90,
                              height: 11,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        )
                      : (hasVa
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.vaName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (item.vaNativeName != null && item.vaNativeName!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.vaNativeName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.vaLanguage ?? l10n.japaneseVoice,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.noVoiceActorInfo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            )),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(AppIconPack iconPack, ThemeData theme, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF16191F) : Colors.black12,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.mic(iconPack),
              size: 42,
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Seiyuu',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
