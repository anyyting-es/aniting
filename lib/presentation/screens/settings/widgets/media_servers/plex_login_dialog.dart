import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/i18n/i18n_provider.dart';
import '../../../../../core/media_servers/providers/media_servers_provider.dart';
import '../../../../../core/media_servers/services/plex_auth_service.dart';

class PlexLoginDialog extends ConsumerStatefulWidget {
  const PlexLoginDialog({super.key});

  @override
  ConsumerState<PlexLoginDialog> createState() => _PlexLoginDialogState();
}

class _PlexLoginDialogState extends ConsumerState<PlexLoginDialog> {
  final _authService = PlexAuthService();
  Timer? _pollTimer;

  bool _isLoading = true;
  String? _errorMessage;
  String? _pinCode;
  dynamic _pinId;
  String? _authUrl;

  List<PlexServerCandidate> _servers = [];
  bool _selectingServer = false;

  @override
  void initState() {
    super.initState();
    _startPinAuth();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPinAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pinData = await _authService.createPin();
      if (!mounted) return;

      setState(() {
        _pinCode = pinData['code'] as String?;
        _pinId = pinData['id'];
        _authUrl = pinData['authUrl'] as String?;
        _isLoading = false;
      });

      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPin());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pollPin() async {
    if (_pinId == null) return;
    try {
      final token = await _authService.checkPin(_pinId);
      if (token != null && token.isNotEmpty) {
        _pollTimer?.cancel();
        _onPinClaimed(token);
      }
    } catch (_) {}
  }

  Future<void> _onPinClaimed(String token) async {
    setState(() => _isLoading = true);
    try {
      final servers = await _authService.getServers(token);
      if (!mounted) return;

      if (servers.isEmpty) {
        setState(() {
          _errorMessage = 'No se encontraron servidores asociados a esta cuenta de Plex';
          _isLoading = false;
        });
        return;
      }

      if (servers.length == 1) {
        await _connectCandidate(servers.first);
      } else {
        setState(() {
          _servers = servers;
          _selectingServer = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _connectCandidate(PlexServerCandidate candidate) async {
    setState(() => _isLoading = true);
    final workingUrl = await _authService.findWorkingUrl(
      candidate.candidateUrls,
      candidate.accessToken,
    );

    if (workingUrl == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo conectar a los endpoints del servidor Plex';
        _isLoading = false;
      });
      return;
    }

    final config = _authService.buildConfig(
      candidate: candidate,
      activeUrl: workingUrl,
    );

    await ref.read(mediaServersProvider.notifier).addServer(config);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.tv, color: Color(0xFFE5A00D), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _selectingServer ? l10n.plexSelectServer : l10n.plexLoginTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  M3EIconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
                Center(
                  child: Text(
                    l10n.plexWaitingAuth,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                M3EButton(
                  label: Text(l10n.retry),
                  onPressed: _startPinAuth,
                ),
              ] else if (_selectingServer) ...[
                ..._servers.map((candidate) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        leading: const Icon(LucideIcons.server, color: Color(0xFFE5A00D)),
                        title: Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${candidate.candidateUrls.length} endpoints'),
                        onTap: () => _connectCandidate(candidate),
                      ),
                    )),
              ] else ...[
                Text(
                  l10n.plexLoginDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5A00D), width: 1.5),
                    ),
                    child: Text(
                      _pinCode ?? '----',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: Color(0xFFE5A00D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_authUrl != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _authUrl!,
                        version: QrVersions.auto,
                        size: 150,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                M3EButton(
                  label: Text(l10n.plexOpenBrowser),
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  onPressed: () {
                    if (_authUrl != null) {
                      launchUrl(Uri.parse(_authUrl!), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
