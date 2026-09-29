import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

class ServerStatusBanner extends ConsumerWidget {
  final VoidCallback onOpenSettings;

  const ServerStatusBanner({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverNotifierProvider);
    final l10n = ref.watch(translationsProvider);

    Color bg;
    IconData icon;
    String text;

    switch (serverState.state) {
      case ServerState.running:
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        icon = Icons.check_circle_outline;
        text = '${l10n.serverActiveLocal} ${serverState.status?.username != null ? "• ${serverState.status!.username}" : ""}';
        break;
      case ServerState.remote:
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
        icon = Icons.cloud_done_outlined;
        text = '${l10n.serverActiveRemote} ${serverState.status?.username != null ? "• ${serverState.status!.username}" : ""}';
        break;
      case ServerState.starting:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        icon = Icons.sync;
        text = l10n.serverStarting;
        break;
      case ServerState.error:
      case ServerState.stopped:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        icon = Icons.cloud_off_outlined;
        text = l10n.serverDisconnected;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: serverState.isOnline
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: serverState.isOnline
                ? const Color(0xFF10B981)
                : (serverState.state == ServerState.starting
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444)),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.settingsTitle, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
