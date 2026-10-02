import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopEpisodePagination extends ConsumerWidget {
  final int currentPage;
  final int totalPages;
  final int startIndex;
  final int endIndex;
  final ValueChanged<int> onPageChanged;

  const DesktopEpisodePagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.startIndex,
    required this.endIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171B) : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          InkWell(
            onTap: currentPage > 0
                ? () => onPageChanged(currentPage - 1)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: currentPage > 0
                    ? (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentPage > 0
                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4))
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.transparent),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: currentPage > 0
                        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                        : (isDark ? Colors.white30 : theme.colorScheme.outline.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.previous,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: currentPage > 0
                          ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                          : (isDark ? Colors.white30 : theme.colorScheme.outline.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Page chips or indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalPages <= 7) ...[
                for (int p = 0; p < totalPages; p++) ...[
                  InkWell(
                    onTap: () => onPageChanged(p),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: currentPage == p
                            ? (isDark ? Colors.white.withValues(alpha: 0.16) : theme.colorScheme.primaryContainer)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: currentPage == p
                              ? (isDark ? Colors.white.withValues(alpha: 0.28) : theme.colorScheme.primary.withValues(alpha: 0.4))
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${p + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: currentPage == p ? FontWeight.w700 : FontWeight.w500,
                          color: currentPage == p
                              ? (isDark ? Colors.white : theme.colorScheme.primary)
                              : (isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  l10n.pageOf(currentPage + 1, totalPages),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EP ${startIndex + 1} - $endIndex',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          // Next button
          InkWell(
            onTap: currentPage < totalPages - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: currentPage < totalPages - 1
                    ? (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentPage < totalPages - 1
                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4))
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.transparent),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.next,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: currentPage < totalPages - 1
                          ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                          : (isDark ? Colors.white30 : theme.colorScheme.outline.withValues(alpha: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: currentPage < totalPages - 1
                        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                        : (isDark ? Colors.white30 : theme.colorScheme.outline.withValues(alpha: 0.5)),
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
