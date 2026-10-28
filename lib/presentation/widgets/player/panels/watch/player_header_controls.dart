import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Compact, web-style selector controls rendered on the page header line
/// (next to the title): playback source, audio tracks and subtitle tracks.
/// Each opens a plain Material dropdown that pops up above the button.
class PlayerHeaderControls extends ConsumerWidget {
  final bool showSource;
  final List<OnlinestreamVideoSource> sources;
  final OnlinestreamVideoSource? activeSource;
  final bool isResolvingSources;
  final String? providerName;
  final bool isDubbed;
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

  String _serverLabel(OnlinestreamVideoSource src) {
    var name = src.server;
    const tags = [
      '[Latino]', '(Latino)', '[Castellano]', '(Castellano)',
      '[English Dub]', '(English Dub)', '[Dub]', '[DUB]', '(Dub)',
      '[Sub (Multi)]', '[SUB]', '[Sub]', '(Sub)',
    ];
    for (final tag in tags) {
      name = name.replaceAll(tag, '');
    }
    name = name.trim();
    final label = name.isEmpty ? src.server : name;
    final quality = (src.quality.isNotEmpty && src.quality != 'auto')
        ? ' • ${src.quality}'
        : '';
    return '$label$quality';
  }

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
          : (active != null
              ? _serverLabel(active)
              : l10n.playbackSources);

      final providers = onSelectProvider == null
          ? const <OnlinestreamProvider>[]
          : ref.watch(onlinestreamProvidersProvider).maybeWhen(
                data: (p) => p,
                orElse: () => const <OnlinestreamProvider>[],
              );

      children.add(
        _HeaderMenu(
          icon: AppIcons.stream(iconPack),
          label: sourceLabel,
          tooltip: l10n.playbackSources,
          menuChildren: [
            if (providers.length > 1) ...[
              for (final p in providers)
                MenuItemButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onSelectProvider?.call(p.id);
                  },
                  leadingIcon: Icon(
                    _isProviderSelected(p) ? AppIcons.check(iconPack) : AppIcons.stream(iconPack),
                    size: 18,
                  ),
                  child: Text(p.name.isNotEmpty ? p.name : p.id),
                ),
              const Divider(height: 1),
            ],
            for (final src in sources)
              MenuItemButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (!_isActiveSource(src, active)) onSelectSource?.call(src);
                },
                leadingIcon: Icon(
                  _isActiveSource(src, active) ? AppIcons.check(iconPack) : AppIcons.stream(iconPack),
                  size: 18,
                  color: _isActiveSource(src, active) ? theme.colorScheme.primary : null,
                ),
                child: Text(_serverLabel(src)),
              ),
            if (onToggleDubbed != null) ...[
              const Divider(height: 1),
              MenuItemButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onToggleDubbed!();
                },
                leadingIcon: Icon(AppIcons.audio(iconPack), size: 18),
                child: Text(isDubbed ? l10n.audioDubbed : l10n.audioSubtitled),
              ),
            ],
            if (onReloadSources != null)
              MenuItemButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onReloadSources!();
                },
                leadingIcon: Icon(AppIcons.refresh(iconPack), size: 18),
                child: Text(l10n.reloadSourcesTooltip),
              ),
          ],
        ),
      );
    }

    if (onSubtitleTrackSelected != null && subtitleTracks.isNotEmpty) {
      children.add(
        _HeaderMenu(
          icon: AppIcons.subtitles(iconPack),
          label: '',
          tooltip: l10n.subtitleTracks,
          menuChildren: [
            MenuItemButton(
              onPressed: () => onSubtitleTrackSelected!(null),
              leadingIcon: Icon(
                selectedSubtitleTrackId == null ? AppIcons.check(iconPack) : Icons.block,
                size: 18,
              ),
              child: Text(l10n.disableSubtitles),
            ),
            for (final t in subtitleTracks)
              MenuItemButton(
                onPressed: () => onSubtitleTrackSelected!(t),
                leadingIcon: Icon(
                  t.id == selectedSubtitleTrackId ? AppIcons.check(iconPack) : AppIcons.subtitles(iconPack),
                  size: 18,
                ),
                child: Text(_trackLabel(t)),
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
          menuChildren: [
            for (final t in audioTracks)
              MenuItemButton(
                onPressed: () => onAudioTrackSelected!(t),
                leadingIcon: Icon(
                  t.id == selectedAudioTrackId ? AppIcons.check(iconPack) : AppIcons.audio(iconPack),
                  size: 18,
                ),
                child: Text(_trackLabel(t)),
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
  final List<Widget> menuChildren;

  const _HeaderMenu({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.menuChildren,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MenuAnchor(
      menuChildren: menuChildren,
      builder: (context, controller, child) {
        return Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
