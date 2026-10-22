import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/i18n_provider.dart';
import '../../../providers/app_providers.dart';
import 'tv_audio_feedback.dart';
import 'welcome_tv_focus_tile.dart';

/// TV Card for entering server IP and port manually. Clean and minimal.
class WelcomeTvManualIpCard extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const WelcomeTvManualIpCard({
    super.key,
    required this.onSuccess,
  });

  @override
  ConsumerState<WelcomeTvManualIpCard> createState() => _WelcomeTvManualIpCardState();
}

class _WelcomeTvManualIpCardState extends ConsumerState<WelcomeTvManualIpCard> {
  bool _isExpanded = false;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  final FocusNode _hostFocusNode = FocusNode();
  final FocusNode _portFocusNode = FocusNode();
  bool _isHostEditing = false;
  bool _isPortEditing = false;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: '192.168.1.');
    _portController = TextEditingController(text: '${AppConstants.defaultPort}');

    _hostFocusNode.addListener(() {
      if (!_hostFocusNode.hasFocus && _isHostEditing) {
        setState(() => _isHostEditing = false);
      }
    });

    _portFocusNode.addListener(() {
      if (!_portFocusNode.hasFocus && _isPortEditing) {
        setState(() => _isPortEditing = false);
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final port = int.tryParse(portStr) ?? AppConstants.defaultPort;

    if (host.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(serverNotifierProvider.notifier);
      await notifier.checkConnection(host: host, port: port);
      final serverState = ref.read(serverNotifierProvider);

      if (serverState.isOnline) {
        TvAudioFeedback.playSuccess();
        widget.onSuccess();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = serverState.errorMessage ?? 'Error de conexión';
            _isConnecting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    if (!_isExpanded) {
      return WelcomeTvFocusTile(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: const Icon(LucideIcons.keyboard, size: 20, color: Colors.white70),
        title: Text(l10n.welcomeTvManualIp),
        subtitle: Text(l10n.welcomeTvManualIpDesc),
        trailing: const Icon(Icons.expand_more_rounded, size: 20, color: Colors.white38),
        onTap: () => setState(() => _isExpanded = true),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.keyboard, size: 18, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.welcomeTvManualIp,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                onPressed: () => setState(() => _isExpanded = false),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      final key = event.logicalKey;
                      if ((key == LogicalKeyboardKey.select ||
                              key == LogicalKeyboardKey.enter ||
                              key == LogicalKeyboardKey.numpadEnter ||
                              key == LogicalKeyboardKey.gameButtonA) &&
                          !_isHostEditing) {
                        setState(() => _isHostEditing = true);
                        _hostFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      } else if (key == LogicalKeyboardKey.escape && _isHostEditing) {
                        setState(() => _isHostEditing = false);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _hostController,
                    focusNode: _hostFocusNode,
                    readOnly: !_isHostEditing,
                    showCursor: _isHostEditing,
                    onTap: () {
                      if (!_isHostEditing) {
                        setState(() => _isHostEditing = true);
                      }
                    },
                    onSubmitted: (_) {
                      setState(() => _isHostEditing = false);
                    },
                    style: const TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.white),
                    decoration: InputDecoration(
                      labelText: l10n.welcomeTvServerHost,
                      hintText: '192.168.1.50',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      final key = event.logicalKey;
                      if ((key == LogicalKeyboardKey.select ||
                              key == LogicalKeyboardKey.enter ||
                              key == LogicalKeyboardKey.numpadEnter ||
                              key == LogicalKeyboardKey.gameButtonA) &&
                          !_isPortEditing) {
                        setState(() => _isPortEditing = true);
                        _portFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      } else if (key == LogicalKeyboardKey.escape && _isPortEditing) {
                        setState(() => _isPortEditing = false);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _portController,
                    focusNode: _portFocusNode,
                    readOnly: !_isPortEditing,
                    showCursor: _isPortEditing,
                    keyboardType: TextInputType.number,
                    onTap: () {
                      if (!_isPortEditing) {
                        setState(() => _isPortEditing = true);
                      }
                    },
                    onSubmitted: (_) {
                      setState(() => _isPortEditing = false);
                    },
                    style: const TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.white),
                    decoration: InputDecoration(
                      labelText: l10n.welcomeTvServerPort,
                      hintText: '${AppConstants.defaultPort}',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isConnecting ? null : _handleConnect,
              child: _isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      l10n.welcomeTvConnect,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
