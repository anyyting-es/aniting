import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/i18n_provider.dart';
import '../../../../core/server/lan_discovery_service.dart';
import '../../../../data/services/default_extensions_service.dart';
import '../../../providers/app_providers.dart';
import 'tv_audio_feedback.dart';
import 'welcome_tv_focus_tile.dart';
import 'welcome_tv_manual_ip_card.dart';

/// TV Step 2: Server connection with clean QR pairing, local auto-discovery,
/// and manual IP fallback. Controlled via DPAD and controller back key.
class WelcomeTvStepServer extends ConsumerStatefulWidget {
  final VoidCallback onFinished;

  const WelcomeTvStepServer({
    super.key,
    required this.onFinished,
  });

  @override
  ConsumerState<WelcomeTvStepServer> createState() => _WelcomeTvStepServerState();
}

class _WelcomeTvStepServerState extends ConsumerState<WelcomeTvStepServer> {
  String? _tvIp;
  String? _connectingServerAddress;
  bool _hasAutoConnected = false;
  bool _isStartingLocal = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceIp();
  }

  Future<void> _loadDeviceIp() async {
    final ip = await LanDiscoveryService.getLocalIpAddress();
    if (mounted) {
      setState(() => _tvIp = ip);
    }
  }

  Future<void> _startAndUseLocalServer() async {
    final l10n = ref.read(translationsProvider);
    setState(() => _isStartingLocal = true);
    try {
      final notifier = ref.read(serverNotifierProvider.notifier);
      await notifier.startLocal();

      // Poll until online or timeout
      for (int i = 0; i < 20; i++) {
        final current = ref.read(serverNotifierProvider);
        if (current.isOnline) break;
        await Future.delayed(const Duration(milliseconds: 400));
      }

      final finalState = ref.read(serverNotifierProvider);
      if (finalState.isOnline) {
        // Auto-install recommended extensions so streaming works immediately
        final repo = ref.read(repositoryProvider);
        final lang = ref.read(appLanguageProvider);
        await DefaultExtensionsService.installRecommended(repo, language: lang);

        TvAudioFeedback.playSuccess();
        widget.onFinished();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(finalState.errorMessage ?? l10n.welcomeTvConnectionFailed),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingLocal = false);
      }
    }
  }

  Future<void> _connectToServer(DiscoveredServer server) async {
    setState(() => _connectingServerAddress = server.address);
    try {
      final notifier = ref.read(serverNotifierProvider.notifier);
      await notifier.checkConnection(host: server.ip, port: server.port);
      final state = ref.read(serverNotifierProvider);

      if (state.isOnline) {
        TvAudioFeedback.playSuccess();
        widget.onFinished();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Error al conectar al servidor'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _connectingServerAddress = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final serverState = ref.watch(serverNotifierProvider);

    final discoveredAsync = ref.watch(discoveredServersProvider);
    final discoveredList = discoveredAsync.value ?? [];

    ref.listen<AsyncValue<List<DiscoveredServer>>>(discoveredServersProvider, (prev, next) {
      if (_hasAutoConnected || _connectingServerAddress != null) return;
      final list = next.value ?? [];
      for (final server in list) {
        if (server.pairedWith != null && (_tvIp == null || server.pairedWith == _tvIp)) {
          _hasAutoConnected = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.tvPairingAutoConnecting} (${server.name})'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          _connectToServer(server);
          break;
        }
      }
    });

    final ipString = _tvIp ?? '127.0.0.1';
    final qrData = 'aniting://pair?action=serve_tv&ip=$ipString&port=${AppConstants.defaultPort}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ─── LEFT: CLEAN QR CODE PAIRING ─────────────────────────────
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(left: 48, right: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcomeTvScanQrTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.welcomeTvScanQrDesc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Pure White QR Box (Zero glowing colored shadows)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 150.0,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 14),

                // Neutral IP indicator
                Text(
                  '${l10n.welcomeTvDeviceIp}: $ipString',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── RIGHT: AUTO-DISCOVERY & MANUAL CONNECTION ───────────────
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(right: 48),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Local Embedded Server Option ───────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: WelcomeTvFocusTile(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: const Icon(LucideIcons.cpu, size: 20, color: Colors.white),
                      title: Text(l10n.welcomeTvUseLocalServer),
                      subtitle: Text(
                        serverState.isOnline
                            ? l10n.welcomeTvLocalServerActive
                            : l10n.welcomeTvUseLocalServerDesc,
                      ),
                      trailing: _isStartingLocal
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                serverState.isOnline ? l10n.welcomeNext : l10n.startServer,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                      onTap: _startAndUseLocalServer,
                    ),
                  ),

                  // Discovered local servers header
                  Row(
                    children: [
                      const Icon(LucideIcons.radio, size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        l10n.welcomeTvDiscoveredServers,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (discoveredList.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${discoveredList.length})',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (discoveredList.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.welcomeTvSearchingServers,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...discoveredList.map((server) {
                      final isThisConnecting = _connectingServerAddress == server.address;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: WelcomeTvFocusTile(
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          leading: const Icon(LucideIcons.server, size: 20, color: Colors.white70),
                          title: Text(server.name),
                          subtitle: Text(
                            '${server.ip}:${server.port}${server.version.isNotEmpty ? '  •  v${server.version}' : ''}',
                          ),
                          trailing: isThisConnecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    l10n.welcomeTvConnect,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                          onTap: () => _connectToServer(server),
                        ),
                      );
                    }),

                  const SizedBox(height: 12),

                  // Manual IP Entry Card
                  WelcomeTvManualIpCard(onSuccess: widget.onFinished),

                  const SizedBox(height: 12),

                  // Skip option
                  WelcomeTvFocusTile(
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: const Icon(LucideIcons.skipForward, size: 18, color: Colors.white38),
                    title: Text(
                      l10n.welcomeTvSkipServer,
                      style: const TextStyle(fontSize: 13.5, color: Colors.white54),
                    ),
                    onTap: () {
                      TvAudioFeedback.playSelect();
                      widget.onFinished();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
