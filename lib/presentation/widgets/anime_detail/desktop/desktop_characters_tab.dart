import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopCharactersTab extends ConsumerWidget {
  final List characters;
  final bool isLoading;

  const DesktopCharactersTab({
    super.key,
    required this.characters,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);

    if (isLoading && characters.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 10);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.52,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) => _buildSkeletonCard(),
          );
        },
      );
    }

    if (characters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, color: Colors.white38, size: 32),
              const SizedBox(height: 10),
              Text(
                l10n.noCharactersAvailable,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 10);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: characters.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.52,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final edge = characters[index] as Map<String, dynamic>?;
            return _DesktopCharacterCard(edge: edge, l10n: l10n);
          },
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 0.70,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D23),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 10,
          width: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF22262E),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          width: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF22262E),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _DesktopCharacterCard extends StatefulWidget {
  final Map<String, dynamic>? edge;
  final AppTranslations l10n;

  const _DesktopCharacterCard({
    required this.edge,
    required this.l10n,
  });

  @override
  State<_DesktopCharacterCard> createState() => _DesktopCharacterCardState();
}

class _DesktopCharacterCardState extends State<_DesktopCharacterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.edge?['role'] as String? ?? 'SUPPORTING';
    final node = widget.edge?['node'] as Map<String, dynamic>?;
    final nameMap = node?['name'] as Map<String, dynamic>?;
    final charName = nameMap?['userPreferred'] ?? nameMap?['full'] ?? widget.l10n.character;
    final imageMap = node?['image'] as Map<String, dynamic>?;
    final imgUrl = imageMap?['large'] ?? imageMap?['medium'];
    final isMain = role.toUpperCase() == 'MAIN';

    final roleLabel = isMain
        ? widget.l10n.mainRole.toUpperCase()
        : widget.l10n.supportingRole.toUpperCase();

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Entire Poster Card expands and contracts on hover
          AspectRatio(
            aspectRatio: 0.70,
            child: AnimatedScale(
              scale: _isHovered ? 1.025 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171B) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isHovered
                        ? Colors.white.withValues(alpha: 0.30)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.20),
                      blurRadius: _isHovered ? 10 : 6,
                      offset: Offset(0, _isHovered ? 3 : 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: imgUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imgUrl as String,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2228)),
                      )
                    : Container(color: const Color(0xFF1E2228)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Role Label outside container
          Text(
            roleLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isMain ? theme.colorScheme.primary : Colors.white60,
            ),
          ),
          const SizedBox(height: 2),

          // 3. Character Name outside container
          Text(
            charName as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _isHovered ? theme.colorScheme.primary : Colors.white,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
