import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

class AnilistAuthSheet extends ConsumerStatefulWidget {
  const AnilistAuthSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AnilistAuthSheet(),
    );
  }

  @override
  ConsumerState<AnilistAuthSheet> createState() => _AnilistAuthSheetState();
}

class _AnilistAuthSheetState extends ConsumerState<AnilistAuthSheet> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tokenController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _openAnilistInBrowser() async {
    final l10n = ref.read(translationsProvider);
    final serverState = ref.read(serverNotifierProvider);
    final clientId = serverState.status?.anilistClientId;
    final cid = (clientId != null && clientId.isNotEmpty) ? clientId : '13985';

    final uri = Uri.parse(
      'https://anilist.co/api/v2/oauth/authorize?client_id=$cid&response_type=token',
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotOpenBrowser),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorOpeningBrowser} $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final l10n = ref.read(translationsProvider);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _tokenController.text = text;
        _errorMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tokenPasted),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.clipboardEmpty),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitToken() async {
    final l10n = ref.read(translationsProvider);
    final rawInput = _tokenController.text.trim();
    if (rawInput.isEmpty) {
      setState(() {
        _errorMessage = l10n.pasteTokenOrUrlPrompt;
      });
      return;
    }

    final tokenPreview = rawInput.contains('access_token=')
        ? (RegExp(r'access_token=([^&#\s]+)').firstMatch(rawInput)?.group(1) ?? rawInput)
        : rawInput.replaceAll(RegExp(r'\s+'), '');

    if (tokenPreview.length < 100) {
      setState(() {
        _errorMessage = l10n.tokenIncompletePrompt;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(serverNotifierProvider.notifier).loginWithAnilist(rawInput);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.loginSuccessAnilist),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
        } else {
          setState(() {
            _errorMessage = l10n.failedToLinkAccount;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        var msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.substring(11);
        }
        final upper = msg.toUpperCase();
        if (upper.contains('RATE_LIMIT') || upper.contains('RATE LIMIT') || upper.contains('LÍMITE TEMPORAL')) {
          msg = l10n.anilistRateLimitError;
        } else if (upper.contains('TIMEOUT') || upper.contains('TARDA')) {
          msg = l10n.anilistTimeoutError;
        } else if (upper.contains('INVALID_TOKEN') || upper.contains('INVALID TOKEN') || upper.contains('UNAUTHORIZED') || upper.contains('NO ES VÁLIDO') || upper.contains('EXPIRADO')) {
          msg = l10n.anilistInvalidTokenError;
        } else if (upper.contains('NETWORK_ERROR') || upper.contains('NO SE PUDO CONECTAR') || upper.contains('COULD NOT CONNECT')) {
          msg = l10n.anilistConnectionError;
        }
        setState(() {
          _errorMessage = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: Text(l10n.disconnectAccount),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(serverNotifierProvider.notifier).logoutAnilist();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sessionLoggedOut),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final serverState = ref.watch(serverNotifierProvider);
    final status = serverState.status;
    final isLoggedIn = status?.isLoggedIn ?? false;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // Absorb taps inside the sheet content
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 500 : double.infinity,
            ),
            child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: isDesktop
                  ? Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Clean Drag Handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      margin: const EdgeInsets.only(top: 2, bottom: 18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                if (isLoggedIn) ...[
                  // ─── USUARIO YA CONECTADO ─────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                  width: 2.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                backgroundImage: status?.avatarUrl != null
                                    ? NetworkImage(status!.avatarUrl!)
                                    : null,
                                child: status?.avatarUrl == null
                                    ? Icon(Icons.person, size: 48, color: theme.colorScheme.primary)
                                    : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/icons/3840px-AniList_logo.svg.png',
                                  cacheWidth: 44,
                                  cacheHeight: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          status?.username ?? l10n.anilistUser,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                              const SizedBox(width: 5),
                              Text(
                                l10n.accountSynced,
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (status?.username != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        final uri = Uri.parse('https://anilist.co/user/${status!.username}/');
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.viewProfileOnAnilist),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(l10n.disconnectAccount),
                  ),
                ] else ...[
                  // ─── LOGIN FORM (MODERNO Y PULIDO) ────────────────────
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/icons/3840px-AniList_logo.svg.png',
                                cacheWidth: 64,
                                cacheHeight: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.anilistLoginTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.anilistLoginDesc,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Botón para abrir AniList en el navegador (sin azul estridente)
                  OutlinedButton.icon(
                    onPressed: _openAnilistInBrowser,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      foregroundColor: theme.colorScheme.onSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(
                      Icons.open_in_browser_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      l10n.openInBrowser,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divisor sutil
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          l10n.pasteTokenDivider,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Input Box estilizado
                  TextField(
                    controller: _tokenController,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'Consolas'),
                    decoration: InputDecoration(
                      hintText: l10n.tokenPlaceholder,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      prefixIcon: Icon(
                        Icons.key_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_tokenController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              tooltip: l10n.clear,
                              onPressed: () => _tokenController.clear(),
                            ),
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded, size: 20),
                            tooltip: l10n.tokenPasted,
                            onPressed: _pasteFromClipboard,
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error, fontSize: 11.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Botón de Conexión
                  FilledButton(
                    onPressed: _isLoading ? null : _submitToken,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n.linkAccountBtn,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                  ),
                ],
              ],
              ),
            ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
