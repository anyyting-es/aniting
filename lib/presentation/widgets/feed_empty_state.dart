import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/presentation/providers/local_library_provider.dart';
import 'package:aniting/presentation/screens/settings/widgets/media_servers/jellyfin_login_dialog.dart';
import 'package:aniting/presentation/screens/settings/widgets/media_servers/plex_login_dialog.dart';
import 'package:aniting/presentation/widgets/anilist_auth_sheet.dart';

/// Compact empty state shown when the user is not logged in or has no items
/// in their anime/manga library. Offers exploring the catalog plus the
/// available account connections and a local library scan.
class FeedEmptyState extends ConsumerStatefulWidget {
  final bool isLoggedIn;
  final bool isManga;
  final bool isOffline;
  final VoidCallback? onRetry;
  final VoidCallback? onExplore;
  final VoidCallback? onLogin;
  final AppIconPack iconPack;

  const FeedEmptyState({
    super.key,
    required this.isLoggedIn,
    this.isManga = false,
    this.isOffline = false,
    this.onRetry,
    this.onExplore,
    this.onLogin,
    this.iconPack = AppIconPack.lucide,
  });

  @override
  ConsumerState<FeedEmptyState> createState() => _FeedEmptyStateState();
}

class _FeedEmptyStateState extends ConsumerState<FeedEmptyState> {
  static const _anilistColor = Color(0xFF02A9FF);
  static const _plexColor = Color(0xFFE5A00D);
  static const _jellyfinColor = Color(0xFF00A4DC);

  bool _isScanning = false;

  Future<void> _scanLocalLibrary() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    final l10n = ref.read(translationsProvider);

    try {
      final ok = await ref.read(localLibraryProvider.notifier).scanLibrary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.scanLocalFolder : l10n.error),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    final title = widget.isOffline
        ? l10n.noInternetConnection
        : (widget.isManga ? l10n.emptyMangaFeedTitle : l10n.emptyAnimeFeedTitle);

    final description = widget.isOffline
        ? l10n.noInternetConnectionDesc
        : (!widget.isLoggedIn
            ? (widget.isManga
                ? l10n.emptyMangaFeedConnectDesc
                : l10n.emptyFeedConnectDesc)
            : (widget.isManga
                ? l10n.emptyMangaFeedDesc
                : l10n.emptyAnimeFeedDesc));

    final mainIcon = widget.isOffline
        ? Icons.wifi_off_rounded
        : (!widget.isLoggedIn
            ? Icons.account_circle_outlined
            : (widget.isManga
                ? Icons.auto_stories_outlined
                : Icons.live_tv_rounded));

    final showServices = !widget.isLoggedIn && !widget.isManga;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Compact confused anime character illustration
              Image.asset(
                'assets/images/confused.png',
                height: 85,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      mainIcon,
                      size: 26,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2. Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),

              // 3. Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // 4. Actions
              if (widget.isOffline) ...[
                _primaryAction(
                  icon: Icons.refresh_rounded,
                  label: l10n.retry,
                  onTap: widget.onRetry,
                ),
                if (widget.onExplore != null) ...[
                  const SizedBox(height: 14),
                  _appsRow(
                    actions: [
                      _AppIconAction(
                        icon: Icons.explore_outlined,
                        accent: theme.colorScheme.primary,
                        tooltip: l10n.navExplore,
                        onTap: widget.onExplore!,
                      ),
                    ],
                  ),
                ],
              ] else if (!widget.isLoggedIn) ...[
                if (widget.onExplore != null)
                  _primaryAction(
                    icon: Icons.explore_rounded,
                    label: l10n.navExplore,
                    onTap: widget.onExplore,
                  ),
                const SizedBox(height: 16),
                _appsRow(
                  actions: [
                    _AppIconAction(
                      icon: Icons.sync_rounded,
                      assetLogo: 'assets/icons/AniList_logo.png',
                      accent: _anilistColor,
                      tooltip: l10n.serviceAniList,
                      onTap: () {
                        if (widget.onLogin != null) {
                          widget.onLogin!();
                        } else {
                          AnilistAuthSheet.show(context);
                        }
                      },
                    ),
                    if (showServices) ...[
                      _AppIconAction(
                        icon: Icons.tv_rounded,
                        assetLogo: 'assets/icons/plex_logo.png',
                        accent: _plexColor,
                        tooltip: l10n.servicePlex,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const PlexLoginDialog(),
                          );
                        },
                      ),
                      _AppIconAction(
                        icon: Icons.movie_filter_rounded,
                        assetLogo: 'assets/icons/jellyfin_logo.png',
                        accent: _jellyfinColor,
                        tooltip: l10n.serviceJellyfin,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const JellyfinLoginDialog(),
                          );
                        },
                      ),
                    ],
                    if (!widget.isManga)
                      _AppIconAction(
                        icon: Icons.folder_open_rounded,
                        accent: theme.colorScheme.primary,
                        tooltip: l10n.scanLocalFolder,
                        isBusy: _isScanning,
                        onTap: _scanLocalLibrary,
                      ),
                  ],
                ),
              ] else if (widget.onExplore != null) ...[
                _primaryAction(
                  icon: Icons.explore_rounded,
                  label: l10n.navExplore,
                  onTap: widget.onExplore,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        onPressed: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        icon: Icon(icon, size: 19),
        label: Text(label),
      ),
    );
  }

  Widget _appsRow({required List<Widget> actions}) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          actions[i],
        ],
      ],
    );
  }
}

/// Brand icon action used in the empty feed state.
class _AppIconAction extends StatefulWidget {
  final IconData icon;

  /// Optional brand asset (PNG) rendered instead of [icon].
  final String? assetLogo;
  final Color accent;
  final String tooltip;
  final VoidCallback onTap;
  final bool isBusy;

  const _AppIconAction({
    required this.icon,
    this.assetLogo,
    required this.accent,
    required this.tooltip,
    required this.onTap,
    this.isBusy = false,
  });

  @override
  State<_AppIconAction> createState() => _AppIconActionState();
}

class _AppIconActionState extends State<_AppIconAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.isBusy ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.isBusy
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isHovered && !widget.isBusy
                  ? widget.accent.withValues(alpha: isDark ? 0.18 : 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isHovered && !widget.isBusy
                    ? widget.accent.withValues(alpha: 0.45)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Center(
              child: widget.isBusy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accent,
                      ),
                    )
                  : widget.assetLogo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            widget.assetLogo!,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            // The shipped brand PNGs are huge (up to 3840px);
                            // decode only what the 28px tile needs.
                            cacheWidth: 112,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => Icon(
                              widget.icon,
                              size: 21,
                              color: widget.accent,
                            ),
                          ),
                        )
                      : Icon(widget.icon, size: 21, color: widget.accent),
            ),
          ),
        ),
      ),
    );
  }
}