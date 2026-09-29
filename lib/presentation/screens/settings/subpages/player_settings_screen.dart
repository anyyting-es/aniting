import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/player_engine_provider.dart';
import 'package:seanime_app/core/preferences/volume_boost_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA: REPRODUCTOR DE VIDEO (ESTILO ANDROID 16)
// ─────────────────────────────────────────────────────────────────────────────
class PlayerSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;
  const PlayerSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerEngine = ref.watch(playerEngineProvider);
    final playerEngineNotifier = ref.read(playerEngineProvider.notifier);
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return PixelSubpageScaffold(
      title: l10n.videoPlayer,
      isEmbedded: isEmbedded,
      children: [
        // ─── MOTOR DE REPRODUCCIÓN ──────────────────────────────
        SettingsSectionHeader(title: l10n.playbackEngine),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.defaultEngine,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.defaultEngineDesc,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PlayerEngine>(
                  style: pixelSegmentedButtonStyle(theme),
                  segments: const [
                    ButtonSegment(
                      value: PlayerEngine.exoplayer,
                      label: Text('ExoPlayer (Media3)'),
                      icon: Icon(Icons.rocket_launch_rounded),
                    ),
                    ButtonSegment(
                      value: PlayerEngine.mpv,
                      label: Text('libmpv'),
                      icon: Icon(Icons.play_circle_outline_rounded),
                    ),
                  ],
                  selected: {playerEngine},
                  onSelectionChanged: (newSelection) {
                    playerEngineNotifier.setEngine(newSelection.first);
                  },
                ),
              ),
              const SizedBox(height: 14),
              PixelInfoBanner(
                icon: Icons.info_outline_rounded,
                text: playerEngine.localizedDescription(l10n),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── AUDIO Y CONTROLES ─────────────────────────────────
        SettingsSectionHeader(title: l10n.audioAndGestures),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.volume_up_rounded,
              title: l10n.volumeBoost,
              subtitle: l10n.volumeBoostDesc,
              value: ref.watch(volumeBoostProvider),
              onChanged: (val) =>
                  ref.read(volumeBoostProvider.notifier).setEnabled(val),
            ),
          ],
        ),
      ],
    );
  }
}
