import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

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
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button (Icon-only)
              IconButton(
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                icon: Icon(AppIcons.chevronLeft(iconPack)),
                iconSize: 20,
                tooltip: l10n.previous,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.onSurface,
                  disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  backgroundColor: currentPage > 0
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.7)
                      : Colors.transparent,
                ),
              ),

              const SizedBox(width: 6),

              // Page chips or indicator
              if (totalPages <= 7) ...[
                for (int p = 0; p < totalPages; p++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => onPageChanged(p),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: currentPage == p
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: currentPage == p
                                ? Colors.transparent
                                : theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.3),
                          ),
                        ),
                        child: Text(
                          '${p + 1}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: currentPage == p ? FontWeight.w700 : FontWeight.w500,
                            color: currentPage == p
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    l10n.pageOf(currentPage + 1, totalPages),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 8),

              // Subtle Episode Range Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.2),
                  ),
                ),
                child: Text(
                  'EP ${startIndex + 1} - $endIndex',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Next button (Icon-only)
              IconButton(
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                icon: Icon(AppIcons.chevronRight(iconPack)),
                iconSize: 20,
                tooltip: l10n.next,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.onSurface,
                  disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  backgroundColor: currentPage < totalPages - 1
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.7)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
