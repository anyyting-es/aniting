import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../../../../../core/i18n/i18n_provider.dart';
import '../../../../../core/media_servers/models/media_server_type.dart';
import '../../../../../core/media_servers/providers/media_servers_provider.dart';
import 'jellyfin_login_dialog.dart';
import 'plex_login_dialog.dart';

class MediaServersSettingsCard extends ConsumerWidget {
  const MediaServersSettingsCard({super.key});

  void _showAddServerOptions(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addMediaServer,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFE5A00D).withValues(alpha: 0.12),
              leading: const Icon(LucideIcons.tv, color: Color(0xFFE5A00D)),
              title: const Text('Plex Media Server', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('PIN OAuth & Direct Play'),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () {
                Navigator.of(ctx).pop();
                showDialog(context: context, builder: (_) => const PlexLoginDialog());
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFF00A4DC).withValues(alpha: 0.12),
              leading: const Icon(LucideIcons.film, color: Color(0xFF00A4DC)),
              title: const Text('Jellyfin / Emby', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Servidor personal local o remoto'),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () {
                Navigator.of(ctx).pop();
                showDialog(context: context, builder: (_) => const JellyfinLoginDialog());
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final serversState = ref.watch(mediaServersProvider);

    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.hardDrive, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mediaServersTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      l10n.mediaServersDesc,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              M3EButton(
                label: Text(l10n.addMediaServer),
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => _showAddServerOptions(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (serversState.servers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.serverOff, size: 36, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(
                    l10n.noMediaServersConnected,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: serversState.servers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final server = serversState.servers[index];
                final isSelected = server.id == serversState.activeServerId;
                final isPlex = server.type == MediaServerType.plex;
                final brandColor = isPlex ? const Color(0xFFE5A00D) : const Color(0xFF00A4DC);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? brandColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPlex ? LucideIcons.tv : LucideIcons.film,
                          color: brandColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  server.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: brandColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      l10n.activeServerLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: brandColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: server.isOnline ? Colors.greenAccent : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  server.isOnline ? l10n.mediaServerOnline : l10n.mediaServerOffline,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  server.url,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isSelected)
                        M3EButton(
                          label: const Text('Usar'),
                          onPressed: () => ref.read(mediaServersProvider.notifier).setActiveServer(server.id),
                        ),
                      const SizedBox(width: 6),
                      M3EIconButton(
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        onPressed: () => ref.read(mediaServersProvider.notifier).removeServer(server.id),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
