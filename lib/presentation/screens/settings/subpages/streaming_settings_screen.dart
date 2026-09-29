import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/streaming_preferences_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA: FUENTES Y ALMACENAMIENTO DE STREAMING
// ─────────────────────────────────────────────────────────────────────────────
class StreamingSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const StreamingSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<StreamingSettingsScreen> createState() =>
      _StreamingSettingsScreenState();
}

class _StreamingSettingsScreenState
    extends ConsumerState<StreamingSettingsScreen> {
  final TextEditingController _downloadDirController = TextEditingController();
  Map<String, dynamic>? _torrentSettings;
  bool _autoDeletePrevious = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTorrentstreamSettings();
  }

  @override
  void dispose() {
    _downloadDirController.dispose();
    super.dispose();
  }

  Future<void> _loadTorrentstreamSettings() async {
    try {
      final settings =
          await ref.read(repositoryProvider).getTorrentstreamSettings();
      if (mounted && settings != null) {
        setState(() {
          _torrentSettings = settings;
          _downloadDirController.text =
              (settings['downloadDir'] as String?) ?? '';
          _autoDeletePrevious =
              settings['autoDeletePreviousTorrents'] == true;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAutoDelete(bool value) async {
    setState(() => _autoDeletePrevious = value);
    final current = Map<String, dynamic>.from(_torrentSettings ?? {});
    current['autoDeletePreviousTorrents'] = value;
    final ok = await ref
        .read(repositoryProvider)
        .saveTorrentstreamSettings(current);
    if (ok && mounted) {
      _torrentSettings = current;
    }
  }

  Future<void> _saveDownloadDir([String? explicitPath]) async {
    setState(() => _isSaving = true);
    final path = (explicitPath ?? _downloadDirController.text).trim();
    final current = Map<String, dynamic>.from(_torrentSettings ?? {});
    current['downloadDir'] = path;

    final ok = await ref
        .read(repositoryProvider)
        .saveTorrentstreamSettings(current);

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (ok) {
          _torrentSettings = current;
          _downloadDirController.text = path;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? (path.isEmpty
                  ? 'Ruta restaurada a almacenamiento SSD predeterminado'
                  : 'Directorio de trabajo guardado correctamente')
              : 'Error al guardar el directorio de trabajo'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(streamingPreferencesProvider);
    final notifier = ref.read(streamingPreferencesProvider.notifier);
    final l10n = ref.watch(translationsProvider);

    return PixelSubpageScaffold(
      title: l10n.streamingSources,
      isEmbedded: widget.isEmbedded,
      children: [
        // ─── MÉTODOS DE REPRODUCCIÓN ──────────────────────────────────────────
        SettingsSectionHeader(title: l10n.playbackMethods),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.cloud_download_rounded,
              title: l10n.torrentStreaming,
              subtitle: l10n.torrentStreamingDesc,
              value: prefs.torrentStreamingEnabled,
              onChanged: (val) => notifier.setTorrentEnabled(val),
            ),
            const PixelTileDivider(),
            PixelSwitchTile(
              icon: Icons.public_rounded,
              title: l10n.onlineStreaming,
              subtitle: l10n.onlineStreamingDesc,
              value: prefs.onlineStreamingEnabled,
              onChanged: (val) => notifier.setOnlineEnabled(val),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ─── ALMACENAMIENTO Y CACHÉ DE TORRENTS ──────────────────────────────
        SettingsSectionHeader(title: l10n.torrentStorageSection),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.delete_sweep_rounded,
              title: l10n.autoDeletePreviousTitle,
              subtitle: l10n.autoDeletePreviousDesc,
              value: _autoDeletePrevious,
              onChanged: (val) {
                if (!_isLoading) _saveAutoDelete(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ─── DIRECTORIO DE TRABAJO (WORKING DIRECTORY) ────────────────────────
        PixelCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.workingDirectoryTitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.workingDirectoryDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _downloadDirController,
                decoration: InputDecoration(
                  hintText: l10n.defaultDirectoryHint,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _isSaving ? null : () => _saveDownloadDir(''),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(l10n.resetPath),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : () => _saveDownloadDir(),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(l10n.savePath),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        PixelInfoBanner(
          icon: Icons.info_outline_rounded,
          text: l10n.streamingSourcesNotice,
        ),
      ],
    );
  }
}
