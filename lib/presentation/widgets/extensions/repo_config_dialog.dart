import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final l10n = ref.watch(translationsProvider);

    return AlertDialog(
      title: Text(l10n.repoConfigTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.repoUrlLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: widget.defaultRepoUrl,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: Text(l10n.restoreDefaultRepo),
                onPressed: () => _urlController.text = widget.defaultRepoUrl,
              ),
              const Divider(height: 24),
              Text(
                l10n.manualInstallManifest,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _manifestController,
                decoration: InputDecoration(
                  hintText: 'https://.../manifest.json',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (_manifestController.text.trim().isNotEmpty)
          OutlinedButton(
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
                            content: Text(ok ? '${l10n.extensionInstalledSuccessfully}.' : '${l10n.extensionInstallFailed}.'),
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
        FilledButton(
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
    );
  }
}
