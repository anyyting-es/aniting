import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/server/lan_discovery_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';

/// Card widget that displays Aniting servers discovered on the local Wi-Fi,
/// with on-demand scanning to conserve battery and network resources.
class ServerDiscoveredListCard extends ConsumerStatefulWidget {
  final void Function(String ip, int port) onSelectServer;

  const ServerDiscoveredListCard({
    super.key,
    required this.onSelectServer,
  });

  @override
  ConsumerState<ServerDiscoveredListCard> createState() => _ServerDiscoveredListCardState();
}

class _ServerDiscoveredListCardState extends ConsumerState<ServerDiscoveredListCard> {
  bool _isScanning = false;
  Timer? _scanTimeout;
  StreamSubscription<List<DiscoveredServer>>? _sub;
  List<DiscoveredServer> _servers = [];

  @override
  void initState() {
    super.initState();
    // Iniciar un escaneo inicial breve de 4 segundos al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final service = ref.read(lanDiscoveryServiceProvider);
    service.startListening();

    _sub?.cancel();
    _sub = service.serversStream.listen((servers) {
      if (mounted) {
        setState(() => _servers = servers);
      }
    });

    // Detener el escaneo automáticamente a los 4 segundos
    _scanTimeout?.cancel();
    _scanTimeout = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
      service.stopListening();
    });
  }

  @override
  void dispose() {
    _scanTimeout?.cancel();
    _sub?.cancel();
    try {
      ref.read(lanDiscoveryServiceProvider).stopListening();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final serverManager = ref.watch(serverManagerProvider);
    final serverState = ref.watch(serverNotifierProvider);

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
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Icon(
                  Icons.radar_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.discoveredServers,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.discoveredServersDesc,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _startScan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l10n.searchServers, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),

          const SizedBox(height: 14),

          if (_isScanning && _servers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.searchingServers,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if (_servers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wifi_find_rounded,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.noServersFound,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.noServersFoundDesc,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: _startScan,
                      icon: const Icon(Icons.radar_rounded, size: 18),
                      label: Text(l10n.searchServers),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _servers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final server = _servers[index];
                final isCurrent = server.ip == serverManager.host &&
                    server.port == serverManager.port &&
                    serverState.isOnline;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        ),
                        child: Icon(
                          Icons.dns_rounded,
                          color: isCurrent ? const Color(0xFF22C55E) : theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${server.ip}:${server.port}${server.version.isNotEmpty ? ' • v${server.version}' : ''}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                l10n.connectedToServer,
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => widget.onSelectServer(server.ip, server.port),
                          child: Text(l10n.connectToServer),
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
