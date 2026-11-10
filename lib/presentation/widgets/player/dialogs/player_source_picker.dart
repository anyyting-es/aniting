import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/data/models/onlinestream_models.dart';

/// In-player source picker.
///
/// It is shown right after entering a TMDB episode/movie. The installed
/// providers are listed at the top; selecting one loads its sources (e.g.
/// Torrentio torrents, or the servers of an HTTP streaming extension) and
/// choosing a source starts playback.
Future<void> showPlayerSourcePicker(
  BuildContext context, {
  required String title,
  required String episodeTitle,
  String? imageUrl,
  required List<OnlinestreamProvider> providers,
  required String? initialProviderId,
  required Future<List<OnlinestreamVideoSource>> Function(String providerId)
      loadSources,
  required void Function(
    OnlinestreamProvider provider,
    OnlinestreamVideoSource source,
  ) onSourceSelected,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => PlayerSourcePickerDialog(
      title: title,
      episodeTitle: episodeTitle,
      imageUrl: imageUrl,
      providers: providers,
      initialProviderId: initialProviderId,
      loadSources: loadSources,
      onSourceSelected: onSourceSelected,
    ),
  );
}

class PlayerSourcePickerDialog extends ConsumerStatefulWidget {
  final String title;
  final String episodeTitle;
  final String? imageUrl;
  final List<OnlinestreamProvider> providers;
  final String? initialProviderId;
  final Future<List<OnlinestreamVideoSource>> Function(String providerId)
      loadSources;
  final void Function(
    OnlinestreamProvider provider,
    OnlinestreamVideoSource source,
  ) onSourceSelected;

  const PlayerSourcePickerDialog({
    super.key,
    required this.title,
    required this.episodeTitle,
    this.imageUrl,
    required this.providers,
    required this.initialProviderId,
    required this.loadSources,
    required this.onSourceSelected,
  });

  @override
  ConsumerState<PlayerSourcePickerDialog> createState() =>
      _PlayerSourcePickerDialogState();
}

class _PlayerSourcePickerDialogState
    extends ConsumerState<PlayerSourcePickerDialog> {
  late String? _providerId;
  List<OnlinestreamVideoSource> _sources = const [];
  bool _isLoading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _providerId = widget.providers.any((p) => p.id == widget.initialProviderId)
        ? widget.initialProviderId
        : (widget.providers.isNotEmpty ? widget.providers.first.id : null);
    _loadSources();
  }

  OnlinestreamProvider? get _selectedProvider {
    for (final provider in widget.providers) {
      if (provider.id == _providerId) return provider;
    }
    return null;
  }

  Future<void> _loadSources({String? providerId}) async {
    final id = providerId ?? _providerId;
    if (id == null) return;

    final requestId = ++_requestId;
    setState(() {
      _providerId = id;
      _isLoading = true;
      _sources = const [];
    });

    final sources = await widget.loadSources(id);
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _sources = sources;
      _isLoading = false;
    });
  }

  void _select(OnlinestreamVideoSource source) {
    final provider = _selectedProvider;
    if (provider == null) return;
    Navigator.of(context).pop();
    widget.onSourceSelected(provider, source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.28),
              width: 1.2,
            ),
          ),
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, l10n, iconPack, isDark),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.selectSource,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.black54,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                _buildProviders(l10n, iconPack, theme, isDark),
                const SizedBox(height: 14),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildSources(context, l10n, iconPack, theme, isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppTranslations l10n,
    AppIconPack iconPack,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 110,
              height: 62,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
          )
        else
          Container(
            width: 110,
            height: 62,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                AppIcons.play(iconPack),
                size: 24,
                color: Colors.white54,
              ),
            ),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.episodeTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(AppIcons.close(iconPack), size: 20),
          color: isDark ? Colors.white70 : Colors.black54,
          tooltip: l10n.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildProviders(
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    bool isDark,
  ) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.providers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final provider = widget.providers[index];
          final isSelected = provider.id == _providerId;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isSelected ? null : () => _loadSources(providerId: provider.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.globe(iconPack),
                      size: 15,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark
                                ? Colors.white70
                                : theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      provider.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark
                                  ? Colors.white70
                                  : theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSources(
    BuildContext context,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    bool isDark,
  ) {
    if (_isLoading) {
      return SizedBox(
        key: const ValueKey('sources_loading'),
        height: 132,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.searchingSources,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_sources.isEmpty) {
      return Container(
        key: const ValueKey('sources_empty'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.searchOff(iconPack),
              size: 30,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noSourcesFoundForEpisode,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: ValueKey('sources_${_providerId}_${_sources.length}'),
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _sources.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.6,
          indent: 14,
          endIndent: 14,
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        itemBuilder: (context, index) {
          final source = _sources[index];
          return _SourceRow(
            source: source,
            iconPack: iconPack,
            isDark: isDark,
            onTap: () => _select(source),
          );
        },
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final OnlinestreamVideoSource source;
  final AppIconPack iconPack;
  final bool isDark;
  final VoidCallback onTap;

  const _SourceRow({
    required this.source,
    required this.iconPack,
    required this.isDark,
    required this.onTap,
  });

  String get _title {
    if (source.isTorrent) {
      final quality = source.quality.trim();
      return quality.isNotEmpty && quality != 'auto' ? quality : 'Torrent';
    }
    if (source.server.trim().isNotEmpty) return source.server;
    final quality = source.quality.trim();
    return quality.isNotEmpty && quality != 'auto' ? quality : 'Source';
  }

  String? get _nameLine {
    final label = source.label?.trim();
    if (label != null && label.isNotEmpty) return label;
    final release = source.releaseName?.trim();
    if (release != null && release.isNotEmpty) return release;
    return null;
  }

  String? get _metaLine {
    final parts = <String>[];

    if (source.isTorrent) {
      final size = source.sizeFormatted?.trim();
      if (size != null && size.isNotEmpty) parts.add(size);
      final indexer = source.indexer?.trim();
      if (indexer != null && indexer.isNotEmpty) parts.add(indexer);
      if (source.languages.isNotEmpty) {
        parts.add(source.languages.join(' / '));
      }
    } else {
      final quality = source.quality.trim();
      if (quality.isNotEmpty &&
          quality != 'auto' &&
          quality.toLowerCase() != _title.toLowerCase()) {
        parts.add(quality);
      }
      final label = source.label?.trim();
      if (label != null && label.isNotEmpty && label != _nameLine) {
        parts.add(label);
      }
    }

    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? get _codec {
    final codec = source.codec?.trim();
    return codec != null && codec.isNotEmpty ? codec : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = isDark ? Colors.white : theme.colorScheme.onSurface;
    final secondary = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : theme.colorScheme.onSurfaceVariant;
    final meta = _metaLine;
    final name = _nameLine;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  source.isTorrent
                      ? AppIcons.cloudDownload(iconPack)
                      : AppIcons.play(iconPack),
                  size: 17,
                  color: isDark ? Colors.white70 : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                        ),
                        if (source.isTorrent) ...[
                          const SizedBox(width: 7),
                          _Badge(
                            label: 'TORRENT',
                            background: theme.colorScheme.primary
                                .withValues(alpha: isDark ? 0.22 : 0.12),
                            foreground: isDark
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                        ],
                        if (_codec != null) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: _codec!,
                            background: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.06),
                            foreground: secondary,
                          ),
                        ],
                        const Spacer(),
                        if (source.isTorrent &&
                            source.seeders != null &&
                            source.seeders! > 0) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: '👤 ${source.seeders}',
                            background: const Color(0xFF22C55E)
                                .withValues(alpha: isDark ? 0.22 : 0.12),
                            foreground: const Color(0xFF22C55E),
                          ),
                        ],
                      ],
                    ),
                    if (name != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: secondary,
                        ),
                      ),
                    ],
                    if (meta != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                AppIcons.chevronRight(iconPack),
                size: 18,
                color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: foreground,
        ),
      ),
    );
  }
}
