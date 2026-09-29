import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';

class ExtensionCodeModal extends ConsumerWidget {
  final ExtensionItem extension;
  final SeanimeRepository repository;

  const ExtensionCodeModal({
    super.key,
    required this.extension,
    required this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required ExtensionItem extension,
    required SeanimeRepository repository,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ExtensionCodeModal(
        extension: extension,
        repository: repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return FutureBuilder<String?>(
      future: repository.getExtensionPayload(extension.id),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final code = snapshot.data;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Row(
            children: [
              Icon(Icons.code_rounded, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extension.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${extension.id} • v${extension.version} (${extension.language})',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (code != null && code.isNotEmpty)
                IconButton(
                  tooltip: l10n.copyCode,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.codeCopiedToClipboard),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 750,
            height: 500,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (code == null || code.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.code_off_rounded,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(l10n.sourceCodeNotLoaded),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            code,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
}
