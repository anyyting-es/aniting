import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../../core/i18n/i18n_provider.dart';
import '../../../../core/preferences/lan_sharing_provider.dart';
import '../../../../core/server/server_manager.dart';
import '../../../providers/app_providers.dart';

enum TvPairingStep {
  startingServer,
  enablingSharing,
  sendingBeacon,
  completed,
  error,
}

class TvPairingSheet extends ConsumerStatefulWidget {
  final String tvIp;
  final int tvPort;

  const TvPairingSheet({
    super.key,
    required this.tvIp,
    this.tvPort = 43211,
  });

  static Future<void> show({
    required BuildContext context,
    required String tvIp,
    int tvPort = 43211,
  }) {
    return showGlassSheet<void>(
      context: context,
      builder: (ctx) => TvPairingSheet(tvIp: tvIp, tvPort: tvPort),
    );
  }

  @override
  ConsumerState<TvPairingSheet> createState() => _TvPairingSheetState();
}

class _TvPairingSheetState extends ConsumerState<TvPairingSheet> {
  TvPairingStep _step = TvPairingStep.startingServer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executePairing();
    });
  }

  Future<void> _executePairing() async {
    try {
      // 1. Activar preferencia de Compartir en LAN primero para forzar bind en 0.0.0.0
      setState(() => _step = TvPairingStep.startingServer);
      await ref.read(lanSharingProvider.notifier).setEnabled(true);

      // 2. Iniciar o reiniciar servidor local para asegurar binding en 0.0.0.0
      final serverNotifier = ref.read(serverNotifierProvider.notifier);
      final serverState = ref.read(serverNotifierProvider);

      if (serverState.state != ServerState.running) {
        await serverNotifier.startLocal();
      } else {
        // Si ya estaba corriendo, reiniciar para que tome el bind a 0.0.0.0
        await serverNotifier.stopServer();
        await serverNotifier.startLocal();
      }

      final updatedState = ref.read(serverNotifierProvider);
      if (updatedState.state != ServerState.running) {
        setState(() {
          _step = TvPairingStep.error;
          _errorMessage = updatedState.errorMessage ?? 'Error al iniciar servidor';
        });
        return;
      }

      // 3. Activar emisión UDP general
      setState(() => _step = TvPairingStep.enablingSharing);
      final serverName = ref.read(lanServerNameProvider);
      final serverManager = ref.read(serverManagerProvider);
      final discovery = ref.read(lanDiscoveryServiceProvider);
      final version = updatedState.status?.version ?? '1.0.6';

      discovery.startBroadcasting(
        serverName: serverName,
        serverPort: serverManager.port,
        version: version,
      );

      // 4. Enviar balizas directas dirigidas a la IP de la TV para vinculación inmediata
      setState(() => _step = TvPairingStep.sendingBeacon);
      await discovery.sendDirectBeacon(
        targetIp: widget.tvIp,
        serverName: serverName,
        serverPort: serverManager.port,
        version: version,
        pairedWith: widget.tvIp,
      );

      // Pequeña pausa para deleite visual de progreso
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() => _step = TvPairingStep.completed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = TvPairingStep.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Icon with responsive halo
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _step == TvPairingStep.completed
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  _step == TvPairingStep.completed
                      ? LucideIcons.tv2
                      : LucideIcons.tv,
                  color: _step == TvPairingStep.completed
                      ? const Color(0xFF22C55E)
                      : theme.colorScheme.primary,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              l10n.tvPairingTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.tvPairingSubtitle} (${widget.tvIp})',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),

            // Progress items card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    _buildStepRow(
                      context: context,
                      label: l10n.tvPairingStartingServer,
                      status: _getStepStatus(TvPairingStep.startingServer),
                    ),
                    const Divider(height: 18),
                    _buildStepRow(
                      context: context,
                      label: l10n.tvPairingEnablingSharing,
                      status: _getStepStatus(TvPairingStep.enablingSharing),
                    ),
                    const Divider(height: 18),
                    _buildStepRow(
                      context: context,
                      label: l10n.tvPairingSendingBeacon,
                      status: _getStepStatus(TvPairingStep.sendingBeacon),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Feedback banner / Success text
            if (_step == TvPairingStep.completed) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.circleCheck, color: Color(0xFF22C55E), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.tvPairingSuccess,
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ] else if (_step == TvPairingStep.error) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Error',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Action button
            M3EButton(
              style: _step == TvPairingStep.completed
                  ? M3EButtonStyle.filled
                  : M3EButtonStyle.tonal,
              size: M3EButtonSize.md,
              shape: M3EButtonShape.round,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.tvPairingClose),
            ),
          ],
        ),
      ),
    );
  }

  _RowStatus _getStepStatus(TvPairingStep targetStep) {
    if (_step == TvPairingStep.error) {
      return _RowStatus.error;
    }
    if (_step == TvPairingStep.completed) {
      return _RowStatus.done;
    }
    if (_step.index > targetStep.index) {
      return _RowStatus.done;
    }
    if (_step == targetStep) {
      return _RowStatus.inProgress;
    }
    return _RowStatus.pending;
  }

  Widget _buildStepRow({
    required BuildContext context,
    required String label,
    required _RowStatus status,
  }) {
    final theme = Theme.of(context);

    Widget statusIcon;
    switch (status) {
      case _RowStatus.done:
        statusIcon = const Icon(LucideIcons.check, size: 16, color: Color(0xFF22C55E));
        break;
      case _RowStatus.inProgress:
        statusIcon = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case _RowStatus.error:
        statusIcon = Icon(LucideIcons.x, size: 16, color: theme.colorScheme.error);
        break;
      case _RowStatus.pending:
        statusIcon = Icon(
          LucideIcons.circle,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
        );
        break;
    }

    return Row(
      children: [
        statusIcon,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: status == _RowStatus.inProgress ? FontWeight.bold : FontWeight.w500,
              color: status == _RowStatus.pending
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

enum _RowStatus {
  pending,
  inProgress,
  done,
  error,
}
