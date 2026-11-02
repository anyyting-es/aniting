import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'desktop_cast_models.dart';

/// Center detailed info panel presenting character biography, attributes, and roles.
/// Features a fixed-slot layout that keeps character information calm and static without jumping.
class DesktopCastInfoPanel extends ConsumerWidget {
  final DesktopCastItem item;

  const DesktopCastInfoPanel({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final roleLabel = item.isMain
        ? l10n.mainRole.toUpperCase()
        : (item.role == 'ACTOR' ? l10n.cast.toUpperCase() : l10n.supportingRole.toUpperCase());

    final hasAttributes = item.gender != null ||
        item.age != null ||
        item.birthday != null ||
        item.bloodType != null;

    return SizedBox(
      height: 405,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Slot 1: Header (Role + Native name, Name, and Aliases) ─── Fixed height: 96px
          SizedBox(
            height: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top line: Role badge + Native Japanese Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.isMain
                            ? theme.colorScheme.primary.withValues(alpha: 0.16)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.isMain
                              ? theme.colorScheme.primary.withValues(alpha: 0.45)
                              : (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: item.isMain ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (item.nativeName != null && item.nativeName!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          item.nativeName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Character Name
                SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                // Alternative Names line
                SizedBox(
                  height: 18,
                  child: item.alternativeNames.isNotEmpty
                      ? Text(
                          item.alternativeNames.take(4).map((a) => '• $a').join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Slot 2: Attributes Row ─── Fixed height: 32px
          SizedBox(
            height: 32,
            child: hasAttributes
                ? _buildAttributesRow(theme, iconPack, isDark)
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // ─── Slot 3: Biography Container ───
          Expanded(
            child: GlassCard(
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    (item.bio != null && item.bio!.isNotEmpty)
                        ? item.bio!
                        : l10n.noDescriptionAvailable,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.82)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributesRow(ThemeData theme, AppIconPack iconPack, bool isDark) {
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      children: [
        if (item.gender != null && item.gender!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildPill(
              icon: AppIcons.profile(iconPack),
              text: item.gender!,
              theme: theme,
              isDark: isDark,
            ),
          ),
        if (item.age != null && item.age!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildPill(
              icon: AppIcons.info(iconPack),
              text: '${item.age} yrs',
              theme: theme,
              isDark: isDark,
            ),
          ),
        if (item.birthday != null && item.birthday!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildPill(
              icon: AppIcons.calendar(iconPack),
              text: item.birthday!,
              theme: theme,
              isDark: isDark,
            ),
          ),
        if (item.bloodType != null && item.bloodType!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildPill(
              icon: AppIcons.heart(iconPack),
              text: 'Type ${item.bloodType}',
              theme: theme,
              isDark: isDark,
            ),
          ),
      ],
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String text,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
