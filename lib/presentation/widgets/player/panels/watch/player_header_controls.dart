import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/player/stream_server_label.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/providers/torrent_stream_provider.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';

/// Compact, web-style selector controls rendered on the page header line
/// (next to the title): the online provider (installed extension), the server
/// of that provider, audio tracks and subtitle tracks. Each opens a liquid
/// glass dropdown (g1455) that pops up over the button.
class PlayerHeaderControls extends ConsumerWidget {
  final bool showSource;
  final List<OnlinestreamVideoSource> sources;
  final OnlinestreamVideoSource? activeSource;
  final bool isResolvingSources;
  final String? providerName;
  final bool isDubbed;
  final bool isTorrentStream;
  final VoidCallback? onToggleDubbed;
  final VoidCallback? onReloadSources;
  final ValueChanged<OnlinestreamVideoSource>? onSelectSource;
  final ValueChanged<String>? onSelectProvider;

  final List<UiTrack> audioTracks;
  final List<UiTrack> subtitleTracks;
  final String? selectedAudioTrackId;
  final String? selectedSubtitleTrackId;
  final ValueChanged<UiTrack>? onAudioTrackSelected;
  final ValueChanged<UiTrack?>? onSubtitleTrackSelected;

  const PlayerHeaderControls({
    super.key,
    this.showSource = false,
    this.sources = const [],
    this.activeSource,
    this.isResolvingSources = false,
    this.providerName,
    this.isDubbed = false,
    this.isTorrentStream = false,
    this.onToggleDubbed,
    this.onReloadSources,
    this.onSelectSource,
    this.onSelectProvider,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioTrackId,
    this.selectedSubtitleTrackId,
    this.onAudioTrackSelected,
    this.onSubtitleTrackSelected,
  });

  String _serverLabel(OnlinestreamVideoSource src) => formatStreamServerLabel(
    src.server,
    quality: src.quality,
    includeQuality: true,
  );

  bool _isActiveSource(
    OnlinestreamVideoSource src,
    OnlinestreamVideoSource? active,
  ) {
    if (active == null) return false;
    return active.url == src.url ||
        (active.server == src.server && active.quality == src.quality);
  }

  String _trackLabel(UiTrack t) {
    final parts = <String>[];
    if (t.title.trim().isNotEmpty) parts.add(t.title.trim());
    final lang = t.language.trim();
    if (lang.isNotEmpty && lang.toLowerCase() != 'und') parts.add(lang);
    return parts.isEmpty ? '${t.index + 1}' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final children = <Widget>[];

    if (showSource) {
      final active = activeSource;
      final sourceLabel = isResolvingSources
          ? l10n.searchingSources
          : (active != null ? _serverLabel(active) : l10n.playbackSources);

      final providers = onSelectProvider == null
          ? const <OnlinestreamProvider>[]
          : ref
                .watch(onlinestreamProvidersProvider)
                .maybeWhen(
                  data: (p) => p,
                  orElse: () => const <OnlinestreamProvider>[],
                );

      // Provider (installed extension) and server are independent choices, so
      // they get separate dropdowns instead of one mixed list. Provider-level
      // actions (reload, dub toggle) live here, keeping the server list clean.
      if (onSelectProvider != null &&
          (providers.isNotEmpty ||
              onReloadSources != null ||
              onToggleDubbed != null)) {
        final selected = providers.where(_isProviderSelected).firstOrNull;
        final providerLabel = selected != null
            ? (selected.name.isNotEmpty ? selected.name : selected.id)
            : (providerName?.isNotEmpty == true
                  ? providerName!
                  : l10n.onlineProvider);

        children.add(
          _HeaderMenu(
            icon: AppIcons.extension(iconPack),
            label: providerLabel,
            tooltip: l10n.changeProvider,
            items: [
              for (final p in providers)
                GlassMenuItem(
                  label: p.name.isNotEmpty ? p.name : p.id,
                  icon: Icon(
                    _isProviderSelected(p)
                        ? AppIcons.check(iconPack)
                        : AppIcons.globe(iconPack),
                    size: 18,
                    color: _isProviderSelected(p)
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (!_isProviderSelected(p)) onSelectProvider!.call(p.id);
                  },
                ),
              if (onReloadSources != null)
                GlassMenuItem(
                  label: l10n.reloadSourcesTooltip,
                  icon: Icon(AppIcons.refresh(iconPack), size: 18),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onReloadSources!();
                  },
                ),
              if (onToggleDubbed != null)
                GlassMenuItem(
                  label: isDubbed ? l10n.audioDubbed : l10n.audioSubtitled,
                  icon: Icon(AppIcons.audio(iconPack), size: 18),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onToggleDubbed!();
                  },
                ),
            ],
          ),
        );
      }

      children.add(
        _HeaderMenu(
          icon: AppIcons.server(iconPack),
          label: sourceLabel,
          tooltip: l10n.selectServerQuality,
          items: [
            for (final src in sources)
              GlassMenuItem(
                label: _serverLabel(src),
                icon: Icon(
                  _isActiveSource(src, active)
                      ? AppIcons.check(iconPack)
                      : AppIcons.stream(iconPack),
                  size: 18,
                  color: _isActiveSource(src, active)
                      ? theme.colorScheme.primary
                      : null,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (!_isActiveSource(src, active)) onSelectSource?.call(src);
                },
              ),
          ],
        ),
      );
    }

    // Torrent telemetry lives next to the source selectors, but it must still
    // show if the source selector itself is not switchable.
    if (isTorrentStream) children.add(const _TorrentStatsTile());

    if (onSubtitleTrackSelected != null && subtitleTracks.isNotEmpty) {
      children.add(
        _HeaderMenu(
          icon: AppIcons.subtitles(iconPack),
          label: '',
          tooltip: l10n.subtitleTracks,
          items: [
            GlassMenuItem(
              label: l10n.disableSubtitles,
              icon: Icon(
                selectedSubtitleTrackId == null
                    ? AppIcons.check(iconPack)
                    : Icons.block,
                size: 18,
              ),
              onPressed: () => onSubtitleTrackSelected!(null),
            ),
            for (final t in subtitleTracks)
              GlassMenuItem(
                label: _trackLabel(t),
                icon: Icon(
                  t.id == selectedSubtitleTrackId
                      ? AppIcons.check(iconPack)
                      : AppIcons.subtitles(iconPack),
                  size: 18,
                ),
                onPressed: () => onSubtitleTrackSelected!(t),
              ),
          ],
        ),
      );
    }

    if (onAudioTrackSelected != null && audioTracks.isNotEmpty) {
      children.add(
        _HeaderMenu(
          icon: AppIcons.audio(iconPack),
          label: '',
          tooltip: l10n.audioTracks,
          items: [
            for (final t in audioTracks)
              GlassMenuItem(
                label: _trackLabel(t),
                icon: Icon(
                  t.id == selectedAudioTrackId
                      ? AppIcons.check(iconPack)
                      : AppIcons.audio(iconPack),
                  size: 18,
                ),
                onPressed: () => onAudioTrackSelected!(t),
              ),
          ],
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    );
  }

  bool _isProviderSelected(OnlinestreamProvider p) {
    final current = providerName?.toLowerCase();
    if (current == null) return false;
    return current == p.id.toLowerCase() || current == p.name.toLowerCase();
  }
}

class _HeaderMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final List<GlassMenuItem> items;

  const _HeaderMenu({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canOpen = items.isNotEmpty;

    return _CompactMenuAnchor(
      width: 220,
      tooltip: tooltip,
      items: items,
      builder: (context, controller) {
        return Tooltip(
          message: canOpen ? tooltip : label,
          child: GlassButton(
            // An empty menu must not open into a blank glass panel.
            onPressed: canOpen ? controller.open : null,
            minSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isDark ? Colors.white : theme.colorScheme.primary,
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
                if (canOpen) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// g1455's `GlassMenuAnchor` hard-codes 42 px rows with a 17 px label
/// (`kGlassMenuRowHeight`), which feels oversized next to the compact header
/// buttons. This popover keeps the same glass surface but renders denser rows.
class _CompactMenuAnchor extends StatefulWidget {
  final double width;
  final String tooltip;
  final List<GlassMenuItem> items;
  final Widget Function(BuildContext, GlassMenuController) builder;

  const _CompactMenuAnchor({
    required this.width,
    required this.tooltip,
    required this.items,
    required this.builder,
  });

  @override
  State<_CompactMenuAnchor> createState() => _CompactMenuAnchorState();
}

class _CompactMenuAnchorState extends State<_CompactMenuAnchor> {
  final GlassMenuController _controller = GlassMenuController();

  @override
  Widget build(BuildContext context) {
    return GlassPopoverAnchor(
      width: widget.width,
      radius: 16,
      controller: _controller,
      barrierLabel: widget.tooltip,
      popoverBuilder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in widget.items)
              _CompactMenuItem(
                item: item,
                onSelected: () {
                  _controller.close();
                  item.onPressed?.call();
                },
              ),
          ],
        ),
      ),
      builder: widget.builder,
    );
  }
}

class _CompactMenuItem extends StatefulWidget {
  final GlassMenuItem item;
  final VoidCallback onSelected;

  const _CompactMenuItem({required this.item, required this.onSelected});

  @override
  State<_CompactMenuItem> createState() => _CompactMenuItemState();
}

class _CompactMenuItemState extends State<_CompactMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.item.onPressed != null;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.35)
        : widget.item.isDestructive
        ? const Color(0xFFFF3B30)
        : scheme.onSurface;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onSelected : null,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: _hovered && enabled
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: widget.item.icon == null
                    ? null
                    : IconTheme.merge(
                        data: IconThemeData(color: color, size: 16),
                        child: widget.item.icon!,
                      ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact live torrent telemetry shown next to the source selectors.
///
/// Only rendered while a torrent stream is active: download speed, upload
/// speed and seeders, on the same glass surface as the header buttons.
class _TorrentStatsTile extends ConsumerWidget {
  const _TorrentStatsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final status = ref.watch(torrentStreamStatusProvider);
    final isDark = theme.brightness == Brightness.dark;
    final label = isDark ? Colors.white : theme.colorScheme.onSurface;
    final dim = label.withValues(alpha: 0.65);

    Widget metric(IconData icon, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: dim),
          const SizedBox(width: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 74),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: label,
              ),
            ),
          ),
        ],
      );
    }

    Widget separator() => Container(
      width: 1,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: dim.withValues(alpha: 0.28),
    );

    // The backend sends an empty string when the counter did not move. Show
    // `0 B/s` so a stalled/seedless torrent is visibly zero, not missing data.
    final down = status == null
        ? '--'
        : (status.downloadSpeed.isNotEmpty ? status.downloadSpeed : '0 B/s');
    final up = status == null
        ? '--'
        : (status.uploadSpeed.isNotEmpty ? status.uploadSpeed : '0 B/s');
    final seeders = '${status?.seeders ?? 0}';

    return Tooltip(
      message:
          '${l10n.downloadSpeed}: $down\n'
          '${l10n.uploadSpeed}: $up\n'
          '${l10n.seedersPeers}: $seeders',
      child: GlassCard(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: SizedBox(
          height: 22,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              metric(AppIcons.arrowDown(iconPack), down),
              separator(),
              metric(AppIcons.arrowUp(iconPack), up),
              separator(),
              metric(AppIcons.users(iconPack), seeders),
            ],
          ),
        ),
      ),
    );
  }
}
