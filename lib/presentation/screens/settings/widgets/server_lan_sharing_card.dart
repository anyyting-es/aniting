import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/lan_sharing_provider.dart';
import 'package:seanime_app/core/server/lan_discovery_service.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';

/// Card widget to configure LAN server sharing and broadcasting.
class ServerLanSharingCard extends ConsumerStatefulWidget {
  const ServerLanSharingCard({super.key});

  @override
  ConsumerState<ServerLanSharingCard> createState() => _ServerLanSharingCardState();
}

class _ServerLanSharingCardState extends ConsumerState<ServerLanSharingCard> {
  late final TextEditingController _nameController;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(lanServerNameProvider));
    _resolveIp();
  }

  Future<void> _resolveIp() async {
    final ip = await LanDiscoveryService.getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isSharing = ref.watch(lanSharingProvider);
    final serverState = ref.watch(serverNotifierProvider);
    final serverManager = ref.read(serverManagerProvider);

    return PixelCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSharing
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: isSharing ? const Color(0xFF22C55E) : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lanSharing,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serverState.state == ServerState.remote
                          ? l10n.lanSharingRequiresLocal
                          : l10n.lanSharingDesc,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSharing && serverState.state != ServerState.remote,
                onChanged: serverState.state == ServerState.remote
                    ? null
                    : (val) async {
                        await ref.read(lanSharingProvider.notifier).setEnabled(val);
                        final discovery = ref.read(lanDiscoveryServiceProvider);

                        if (!val) {
                          discovery.stopBroadcasting();
                        }

                        // Si el servidor local está corriendo, reiniciarlo para aplicar el binding (0.0.0.0 o 127.0.0.1)
                        if (serverState.state == ServerState.running) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                content: Text(l10n.restartingServer),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                          final notifier = ref.read(serverNotifierProvider.notifier);
                          await notifier.stopServer();
                          await notifier.startLocal();
                        }
                      },
              ),
            ],
          ),

          if (isSharing && serverState.state != ServerState.remote) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Server display name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.serverName,
                hintText: l10n.serverNameHint,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                prefixIcon: const Icon(Icons.badge_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_rounded),
                  tooltip: l10n.save,
                  onPressed: () {
                    ref.read(lanServerNameProvider.notifier).setName(_nameController.text);
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              onSubmitted: (value) {
                ref.read(lanServerNameProvider.notifier).setName(value);
              },
            ),

            const SizedBox(height: 12),

            // Active sharing status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.sharingOnNetwork}: ${_localIp ?? '...'}:${serverManager.port}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.lanSharingActiveDesc,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
