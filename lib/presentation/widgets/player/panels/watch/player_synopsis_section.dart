import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

/// Expandable synopsis block (3-line clamp + "more/less").
/// Shared between the desktop watch column and the mobile info panel.
class PlayerSynopsisSection extends ConsumerStatefulWidget {
  final String synopsis;

  const PlayerSynopsisSection({super.key, required this.synopsis});

  @override
  ConsumerState<PlayerSynopsisSection> createState() =>
      _PlayerSynopsisSectionState();
}

class _PlayerSynopsisSectionState extends ConsumerState<PlayerSynopsisSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    if (widget.synopsis.trim().isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.45,
            ) ??
            const TextStyle(fontSize: 12.5, height: 1.45);

        final textSpan = TextSpan(text: widget.synopsis, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);

        final bool canExpand = textPainter.didExceedMaxLines;

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: canExpand ? () => setState(() => _isExpanded = !_isExpanded) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.synopsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (canExpand)
                      Text(
                        _isExpanded ? l10n.synopsisLess : l10n.synopsisMore,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.synopsis,
                  maxLines: _isExpanded ? null : 3,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
