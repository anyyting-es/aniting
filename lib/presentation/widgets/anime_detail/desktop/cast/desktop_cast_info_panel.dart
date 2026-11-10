import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'desktop_cast_models.dart';

/// Center detailed info panel presenting character biography, attributes, and roles.
/// Features clean, frameless typography and tight, proportional spacing.
class DesktopCastInfoPanel extends ConsumerStatefulWidget {
  final DesktopCastItem item;

  const DesktopCastInfoPanel({
    super.key,
    required this.item,
  });

  @override
  ConsumerState<DesktopCastInfoPanel> createState() =>
      _DesktopCastInfoPanelState();
}

class _DesktopCastInfoPanelState extends ConsumerState<DesktopCastInfoPanel> {
  final ScrollController _bioScrollController = ScrollController();

  @override
  void dispose() {
    _bioScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
          // ─── Header: Role badge + Native Japanese Name ───
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

          const SizedBox(height: 8),

          // ─── Character Name ───
          Text(
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

          // ─── Alternative Names (only if present) ───
          if (item.alternativeNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.alternativeNames.take(4).map((a) => '• $a').join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ─── Attributes Row (Gender, Age, Birthday, Blood Type) ───
          if (hasAttributes) ...[
            SizedBox(
              height: 32,
              child: _buildAttributesRow(theme, iconPack, isDark),
            ),
            const SizedBox(height: 14),
          ],

          // ─── Biography Text (Frameless, clean typography) ───
          Expanded(
            child: Scrollbar(
              controller: _bioScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _bioScrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  (item.bio != null && item.bio!.isNotEmpty)
                      ? item.bio!
                      : l10n.noCharacterDescriptionAvailable,
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
        ],
      ),
    );
  }

  Widget _buildAttributesRow(ThemeData theme, AppIconPack iconPack, bool isDark) {
    final item = widget.item;
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
