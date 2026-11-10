import 'dart:io' show Platform;

import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/player/renderer_info.dart';
import 'package:aniting/data/models/gpu_settings.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GPU section for the player settings.
///
/// Two facts drive this panel:
///
/// * On hybrid laptops (Intel/AMD iGPU + discrete GPU) **Windows** decides which
///   adapter a process gets. The per-app preference is the only reliable lever,
///   it lives in the registry, and it only applies on the next launch — hence the
///   explicit "restart required" notice instead of pretending it is instant.
/// * mpv's own `gpu-api` / `d3d11-adapter` cannot override that decision for the
///   window's device, so surfacing a misleading renderer dropdown is worse than
///   showing the truth.
class GpuSettingsCard extends ConsumerStatefulWidget {
  const GpuSettingsCard({super.key});

  @override
  ConsumerState<GpuSettingsCard> createState() => _GpuSettingsCardState();
}

class _GpuSettingsCardState extends ConsumerState<GpuSettingsCard> {
  GpuSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(repositoryProvider).getGpuSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _apply(String mode) async {
    if (_saving) return;
    final previous = _settings?.preference;
    setState(() => _saving = true);

    final updated = await ref.read(repositoryProvider).setGpuPreference(mode);

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (updated != null) {
        _settings = updated;
        _changed = previous != updated.preference;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Android/iOS expose a single SoC and macOS has no per-app preference, so a
    // GPU panel there would be noise.
    if (!Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final settings = _settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: l10n.gpuSectionTitle),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else if (settings == null || settings.gpus.isEmpty)
                Text(
                  l10n.gpuNoneDetected,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                ValueListenableBuilder<RendererInfo?>(
                  valueListenable: activeRenderer,
                  builder: (context, renderer, _) {
                    if (renderer == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.desktop_windows_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${l10n.gpuActive}: ${renderer.label}',
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Text(
                  l10n.gpuDetected,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 10),
                for (final gpu in settings.gpus)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          gpu.dedicated
                              ? AppIcons.video(iconPack)
                              : Icons.memory_rounded,
                          size: 17,
                          color: gpu.dedicated
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            gpu.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (gpu.dedicated
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            gpu.dedicated
                                ? l10n.gpuDedicated
                                : l10n.gpuIntegrated,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: gpu.dedicated
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              if (settings != null && settings.canSetPreference) ...[
                const SizedBox(height: 6),
                const Divider(height: 20),
                Text(
                  l10n.gpuPreferenceTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.gpuPreferenceDesc,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _modeChip(GpuPreference.auto, l10n.gpuPreferenceAuto),
                    _modeChip(GpuPreference.high, l10n.gpuPreferenceHigh),
                    _modeChip(GpuPreference.power, l10n.gpuPreferencePower),
                  ],
                ),
                if (_changed) ...[
                  const SizedBox(height: 12),
                  PixelInfoBanner(
                    icon: Icons.restart_alt_rounded,
                    text: l10n.gpuRestartRequired,
                  ),
                ],
              ] else if (settings?.note != null) ...[
                const SizedBox(height: 10),
                PixelInfoBanner(
                  icon: Icons.info_outline_rounded,
                  text: settings!.note!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String mode, String label) {
    final theme = Theme.of(context);
    final isSelected = _settings?.preference == mode;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: isSelected,
      onSelected: _saving ? null : (_) => _apply(mode),
      showCheckmark: false,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
