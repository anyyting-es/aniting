import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/constants/app_constants.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/server_lan_sharing_card.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/server_discovered_list_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA: SERVIDOR Y RED
// ─────────────────────────────────────────────────────────────────────────────
class ServerSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ServerSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _isBatteryOptIgnored = true;
  bool _isManageStorageGranted = true;

  @override
  void initState() {
    super.initState();
    final manager = ref.read(serverManagerProvider);
    _hostController = TextEditingController(text: manager.host);
    _portController = TextEditingController(text: manager.port.toString());
    _loadAndroidStatus();
  }

  Future<void> _loadAndroidStatus() async {
    if (!Platform.isAndroid) return;
    final manager = ref.read(serverManagerProvider);
    final bat = await manager.isBatteryOptimizationIgnored();
    final stor = await manager.isManageStorageGranted();
    if (mounted) {
      setState(() {
        _isBatteryOptIgnored = bat;
        _isManageStorageGranted = stor;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serverState = ref.watch(serverNotifierProvider);
    final serverNotifier = ref.read(serverNotifierProvider.notifier);
    final l10n = ref.watch(translationsProvider);

    return PixelSubpageScaffold(
      title: l10n.serverAndNetwork,
      isEmbedded: widget.isEmbedded,
      children: [
        // ─── ESTADO DEL SERVIDOR ────────────────────────────────────
        SettingsSectionHeader(
          title: serverState.state == ServerState.remote
              ? l10n.serverAndNetwork
              : l10n.localServer,
        ),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: serverState.state == ServerState.remote
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
                          : serverState.isOnline
                              ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                              : theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      serverState.state == ServerState.remote
                          ? Icons.lan_rounded
                          : serverState.isOnline
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                      color: serverState.state == ServerState.remote
                          ? theme.colorScheme.primary
                          : serverState.isOnline
                              ? const Color(0xFF22C55E)
                              : theme.colorScheme.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serverState.state == ServerState.remote
                              ? l10n.serverActiveRemote
                              : serverState.isOnline
                                  ? l10n.serverActiveLocal
                                  : l10n.serverOffline,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serverState.state == ServerState.remote
                              ? '${ref.watch(serverManagerProvider).host}:${ref.watch(serverManagerProvider).port}${serverState.status?.version != null ? ' • v${serverState.status!.version}' : ''}'
                              : serverState.isOnline
                                  ? '127.0.0.1:${ref.watch(serverManagerProvider).port}${serverState.status?.version != null ? ' • ${l10n.coreVersion}: ${serverState.status!.version}' : ''}'
                                  : '127.0.0.1:${ref.watch(serverManagerProvider).port}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (serverState.state == ServerState.remote) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.connectedToRemoteDesc,
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (serverState.errorMessage != null && !serverState.isOnline) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    serverState.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (serverState.state == ServerState.remote)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () async {
                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            content: Text(l10n.serverStarting),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                      await serverNotifier.switchToLocal();
                      final mgr = ref.read(serverManagerProvider);
                      _hostController.text = mgr.host;
                      _portController.text = mgr.port.toString();
                    },
                    icon: const Icon(Icons.phonelink_setup_rounded),
                    label: Text(l10n.useLocalServer),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: serverState.state == ServerState.starting
                            ? null
                            : () => serverNotifier.startLocal(),
                        icon: serverState.state == ServerState.starting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          serverState.state == ServerState.starting
                              ? l10n.serverStarting
                              : l10n.startLocal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: (serverState.isOnline || serverState.state == ServerState.starting)
                            ? () => serverNotifier.stopServer()
                            : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(l10n.stopServer),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── COMPARTIR SERVIDOR EN RED LOCAL ───────────────────────
        SettingsSectionHeader(title: l10n.lanSharing),
        const SizedBox(height: 10),
        const ServerLanSharingCard(),

        const SizedBox(height: 24),

        // ─── SERVIDORES DESCUBIERTOS EN RED ────────────────────────
        SettingsSectionHeader(title: l10n.discoveredServers),
        const SizedBox(height: 10),
        ServerDiscoveredListCard(
          onSelectServer: (ip, port) async {
            _hostController.text = ip;
            _portController.text = port.toString();
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Text(l10n.testingConnection),
                duration: const Duration(seconds: 1),
              ),
            );
            await serverNotifier.checkConnection(host: ip, port: port);
            if (!context.mounted) return;
            final currentState = ref.read(serverNotifierProvider);
            messenger.hideCurrentSnackBar();
            if (currentState.isOnline) {
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: Text(l10n.connectedToServer),
                  backgroundColor: const Color(0xFF22C55E),
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: Text(currentState.errorMessage ?? l10n.serverOffline),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        ),

        const SizedBox(height: 24),

        // ─── CONEXIÓN REMOTA ───────────────────────────────────────
        SettingsSectionHeader(title: l10n.remoteConnection),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: Column(
            children: [
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: l10n.hostIp,
                  hintText: l10n.hostHint,
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
                  prefixIcon: const Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.port,
                  hintText: '43211',
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
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () async {
                    final host = _hostController.text.trim();
                    final port = int.tryParse(_portController.text.trim()) ?? AppConstants.defaultPort;
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        content: Text(l10n.testingConnection),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    await serverNotifier.checkConnection(host: host, port: port);
                    if (!context.mounted) return;
                    final currentState = ref.read(serverNotifierProvider);
                    messenger.hideCurrentSnackBar();
                    if (currentState.isOnline) {
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          content: Text(l10n.connectedToServer),
                          backgroundColor: const Color(0xFF22C55E),
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          content: Text(currentState.errorMessage ?? l10n.serverOffline),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.wifi_find_rounded),
                  label: Text(l10n.testAndSave),
                ),
              ),
            ],
          ),
        ),

        if (Platform.isAndroid) ...[
          const SizedBox(height: 24),
          SettingsSectionHeader(title: l10n.androidPerfAndPerms),
          const SizedBox(height: 10),
          PixelCardContainer(
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
                        color: _isBatteryOptIgnored
                            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        _isBatteryOptIgnored
                            ? Icons.battery_charging_full_rounded
                            : Icons.battery_alert_rounded,
                        color: _isBatteryOptIgnored
                            ? const Color(0xFF22C55E)
                            : Colors.amber[800],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.batteryOpt,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isBatteryOptIgnored
                                ? l10n.batteryOptDisabled
                                : l10n.batteryOptEnabled,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isBatteryOptIgnored) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        await ref.read(serverManagerProvider).requestIgnoreBatteryOptimization();
                        await Future.delayed(const Duration(seconds: 1));
                        _loadAndroidStatus();
                      },
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text(l10n.disableOptimization),
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isManageStorageGranted
                            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        _isManageStorageGranted
                            ? Icons.folder_special_rounded
                            : Icons.folder_off_rounded,
                        color: _isManageStorageGranted
                            ? const Color(0xFF22C55E)
                            : Colors.amber[800],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.storageAccess,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isManageStorageGranted
                                ? l10n.storageAccessGranted
                                : l10n.storageAccessDenied,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isManageStorageGranted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        await ref.read(serverManagerProvider).requestManageStorage();
                        await Future.delayed(const Duration(seconds: 1));
                        _loadAndroidStatus();
                      },
                      icon: const Icon(Icons.security_rounded),
                      label: Text(l10n.grantStorageAccess),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
