import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';

/// Top page header for the desktop player watch page, providing
/// back button and media title.
class PlayerDesktopHeader extends ConsumerWidget {
  final String title;
  final VoidCallback onBack;

  const PlayerDesktopHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Row(
        children: [
          IconButton(
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.all(8),
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              highlightColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            icon: Icon(AppIcons.arrowLeft(iconPack), size: 20),
            tooltip: l10n.back,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
