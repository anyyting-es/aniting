import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/preferences/download_preferences_provider.dart';
import '../../../core/storage/app_storage_paths.dart';

class WelcomeStepDownloads extends ConsumerStatefulWidget {
  const WelcomeStepDownloads({super.key});

  @override
  ConsumerState<WelcomeStepDownloads> createState() =>
      _WelcomeStepDownloadsState();
}

class _WelcomeStepDownloadsState extends ConsumerState<WelcomeStepDownloads> {
  final TextEditingController _pathController = TextEditingController();
  bool _initialized = false;
  bool _unifiedFolder = true;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final downloadPrefs = ref.watch(downloadPreferencesProvider);
    final downloadNotifier = ref.read(downloadPreferencesProvider.notifier);

    if (!_initialized && !downloadPrefs.isLoading) {
      _pathController.text = downloadPrefs.resolvedBasePath;
      _initialized = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.hardDrive,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.welcomeStepDownloads,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.welcomeDownloadsPrompt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Unified Folder Toggle Glass Card
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unified Storage',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.welcomeDownloadsUnifiedDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  M3ESwitch(
                    value: _unifiedFolder,
                    onChanged: (val) => setState(() => _unifiedFolder = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Path Input & Actions Glass Card
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.folder,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Base Download Directory',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pathController,
                    onChanged: (val) {
                      downloadNotifier.setCustomBasePath(val);
                    },
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'e.g. /storage/emulated/0/Documents/Anime/aniting',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Reset to Default button
                      TextButton.icon(
                        onPressed: () async {
                          await downloadNotifier.resetToDefault();
                          final def =
                              await AppStoragePaths.getDefaultDownloadsBasePath();
                          setState(() => _pathController.text = def);
                        },
                        icon: const Icon(LucideIcons.rotateCcw, size: 14),
                        label: Text(
                          l10n.welcomeDownloadsDefault,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      // Open Folder if exists
                      IconButton.filledTonal(
                        tooltip: 'Open folder',
                        onPressed: () {
                          final p = _pathController.text.trim();
                          if (p.isNotEmpty) {
                            AppStoragePaths.openDirectoryInFileManager(p);
                          }
                        },
                        icon: const Icon(LucideIcons.folderOpen, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
