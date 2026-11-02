import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../../../../core/i18n/i18n_provider.dart';
import '../../../../core/media_servers/providers/media_servers_provider.dart';
import '../../media_servers/media_server_browser_screen.dart';
import '../widgets/media_servers/media_servers_settings_card.dart';
import '../widgets/pixel_subpage_scaffold.dart';

class MediaServersSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;

  const MediaServersSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final activeServer = ref.watch(activeMediaServerProvider);

    return PixelSubpageScaffold(
      title: l10n.mediaServersTitle,
      isEmbedded: isEmbedded,
      children: [
        const MediaServersSettingsCard(),
        if (activeServer != null) ...[
          const SizedBox(height: 16),
          M3EButton(
            label: Text('Explorar contenido de ${activeServer.name}'),
            icon: const Icon(LucideIcons.playCircle, size: 18),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MediaServerBrowserScreen(),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
