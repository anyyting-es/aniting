import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/models/onlinestream_models.dart';
import '../../../screens/extensions_marketplace_screen.dart';

/// Full modal sheet for advanced options (Sub/Dub audio toggle, manual linking, cache reload, extensions).
class AnimeDetailAdvancedSheet extends StatefulWidget {
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final ValueChanged<bool> onToggleDubbed;
  final VoidCallback? onOpenManualMapping;
  final VoidCallback? onRefreshCache;

  const AnimeDetailAdvancedSheet({
    super.key,
    required this.selectedProvider,
    required this.isDubbed,
    required this.onToggleDubbed,
    this.onOpenManualMapping,
    this.onRefreshCache,
  });

  @override
  State<AnimeDetailAdvancedSheet> createState() => _AnimeDetailAdvancedSheetState();
}

class _AnimeDetailAdvancedSheetState extends State<AnimeDetailAdvancedSheet> {
  late bool _dubbed;

  @override
  void initState() {
    super.initState();
    _dubbed = widget.isDubbed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final sheetBg = isDark ? const Color(0xFF1E1E24) : theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset + safeBottom + 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // M3 Handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Opciones Avanzadas',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Audio Mode (Sub / Dub)
              if (widget.selectedProvider?.supportsDub ?? true) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Text(
                    'AUDIO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(Icons.subtitles_rounded,
                              size: 16,
                              color: !_dubbed
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant),
                          label: const Text('Subtitulado'),
                          selected: !_dubbed,
                          onSelected: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _dubbed = false);
                            widget.onToggleDubbed(false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(Icons.record_voice_over_rounded,
                              size: 16,
                              color: _dubbed
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant),
                          label: const Text('Doblado (Dub)'),
                          selected: _dubbed,
                          onSelected: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _dubbed = true);
                            widget.onToggleDubbed(true);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Actions: Manual Link & Cache Reload
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    if (widget.onOpenManualMapping != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onOpenManualMapping?.call();
                          },
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: const Text('Vincular'),
                        ),
                      ),
                    if (widget.onOpenManualMapping != null && widget.onRefreshCache != null)
                      const SizedBox(width: 10),
                    if (widget.onRefreshCache != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            widget.onRefreshCache?.call();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Recargar'),
                        ),
                      ),
                  ],
                ),
              ),

              // Marketplace link
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExtensionsMarketplaceScreen()),
                    );
                  },
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('Explorar más extensiones en la tienda'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
