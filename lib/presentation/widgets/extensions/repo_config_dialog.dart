import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class MarketplaceRepoConfigDialog extends ConsumerStatefulWidget {
  final String currentRepoUrl;
  final String defaultRepoUrl;
  final ValueChanged<String> onSaveRepoUrl;
  final Future<bool> Function(String manifestUri) onInstallManifest;

  const MarketplaceRepoConfigDialog({
    super.key,
    required this.currentRepoUrl,
    required this.defaultRepoUrl,
    required this.onSaveRepoUrl,
    required this.onInstallManifest,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentRepoUrl,
    required String defaultRepoUrl,
    required ValueChanged<String> onSaveRepoUrl,
    required Future<bool> Function(String manifestUri) onInstallManifest,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => MarketplaceRepoConfigDialog(
        currentRepoUrl: currentRepoUrl,
        defaultRepoUrl: defaultRepoUrl,
        onSaveRepoUrl: onSaveRepoUrl,
        onInstallManifest: onInstallManifest,
      ),
    );
  }

  @override
  ConsumerState<MarketplaceRepoConfigDialog> createState() => _MarketplaceRepoConfigDialogState();
}

class _MarketplaceRepoConfigDialogState extends ConsumerState<MarketplaceRepoConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _manifestController;
  bool _isInstallingManifest = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.currentRepoUrl);
    _manifestController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _manifestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassCard(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.gitBranch,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.repoConfigTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          l10n.marketplace,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Section 1: Repo URL
                      Text(
                        l10n.repoUrlLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: widget.defaultRepoUrl,
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                          prefixIcon: Icon(LucideIcons.globe, size: 16, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(LucideIcons.rotateCcw, size: 13),
                          label: Text(l10n.restoreDefaultRepo, style: const TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () => _urlController.text = widget.defaultRepoUrl,
                        ),
                      ),

                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        thickness: 0.8,
                        color: theme.dividerColor.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Manual Install Manifest
                      Text(
                        l10n.manualInstallManifest,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _manifestController,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'https://.../manifest.json',
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                          prefixIcon: Icon(LucideIcons.link, size: 16, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  if (_manifestController.text.trim().isNotEmpty) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isInstallingManifest
                          ? null
                          : () async {
                              final uri = _manifestController.text.trim();
                              if (uri.isNotEmpty) {
                                setState(() => _isInstallingManifest = true);
                                final ok = await widget.onInstallManifest(uri);
                                if (context.mounted) {
                                  setState(() => _isInstallingManifest = false);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? '${l10n.extensionInstalledSuccessfully}.'
                                          : '${l10n.extensionInstallFailed}.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      child: _isInstallingManifest
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.installManifest),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final newUrl = _urlController.text.trim();
                      if (newUrl.isNotEmpty) {
                        Navigator.pop(context);
                        widget.onSaveRepoUrl(newUrl);
                      }
                    },
                    child: Text(l10n.saveAndLoad),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
