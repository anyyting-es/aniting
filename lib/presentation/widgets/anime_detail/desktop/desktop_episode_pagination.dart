import 'package:flutter/material.dart';

class DesktopEpisodePagination extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: currentPage > 0 ? 0.15 : 0.04),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: currentPage > 0 ? Colors.white : Colors.white30,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Anterior',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: currentPage > 0 ? Colors.white : Colors.white30,
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
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: currentPage == p
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${p + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: currentPage == p ? FontWeight.w700 : FontWeight.w500,
                          color: currentPage == p ? Colors.white : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  'Página ${currentPage + 1} de $totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EP ${startIndex + 1} - $endIndex',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
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
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: currentPage < totalPages - 1 ? 0.15 : 0.04),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Siguiente',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: currentPage < totalPages - 1 ? Colors.white : Colors.white30,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: currentPage < totalPages - 1 ? Colors.white : Colors.white30,
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
