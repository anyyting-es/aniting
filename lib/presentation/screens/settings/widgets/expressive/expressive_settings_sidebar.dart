import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

import '../../settings_screen.dart';
import 'expressive_settings_category_tile.dart';

class SettingsCategoryItem {
  final SettingsCategory category;
  final IconData Function(AppIconPack pack) iconBuilder;
  final String Function(AppTranslations l10n) titleBuilder;
  final String Function(AppTranslations l10n) subtitleBuilder;

  const SettingsCategoryItem({
    required this.category,
    required this.iconBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
  });
}

class SettingsCategoryGroup {
  final String Function(AppTranslations l10n) titleBuilder;
  final List<SettingsCategoryItem> items;

  const SettingsCategoryGroup({
    required this.titleBuilder,
    required this.items,
  });
}

final List<SettingsCategoryGroup> kSettingsCategoryGroups = [
  SettingsCategoryGroup(
    titleBuilder: (l) => l.settingsGroupAppearance,
    items: [
      SettingsCategoryItem(
        category: SettingsCategory.theme,
        iconBuilder: (p) => AppIcons.palette(p),
        titleBuilder: (l) => l.themeAndColors,
        subtitleBuilder: (l) => l.settingsSubtitleTheme,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.appearance,
        iconBuilder: (p) => AppIcons.appearance(p),
        titleBuilder: (l) => l.appearanceAndDisplay,
        subtitleBuilder: (l) => l.settingsSubtitleAppearance,
      ),
    ],
  ),
  SettingsCategoryGroup(
    titleBuilder: (l) => l.settingsGroupPlayback,
    items: [
      SettingsCategoryItem(
        category: SettingsCategory.player,
        iconBuilder: (p) => AppIcons.playCircle(p),
        titleBuilder: (l) => l.videoPlayer,
        subtitleBuilder: (l) => l.settingsSubtitlePlayer,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.manga,
        iconBuilder: (p) => AppIcons.manga(p),
        titleBuilder: (l) => l.mangaReader,
        subtitleBuilder: (l) => l.settingsSubtitleManga,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.streaming,
        iconBuilder: (p) => AppIcons.stream(p),
        titleBuilder: (l) => l.streamingSources,
        subtitleBuilder: (l) => l.settingsSubtitleStreaming,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.debrid,
        iconBuilder: (_) => Icons.bolt_rounded,
        titleBuilder: (l) => l.debridSettings,
        subtitleBuilder: (l) => l.settingsSubtitleDebrid,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.extensions,
        iconBuilder: (p) => AppIcons.extension(p),
        titleBuilder: (l) => l.extensionsTitle,
        subtitleBuilder: (l) => l.settingsSubtitleExtensions,
      ),
    ],
  ),
  SettingsCategoryGroup(
    titleBuilder: (l) => l.settingsGroupLibrary,
    items: [
      SettingsCategoryItem(
        category: SettingsCategory.localLibrary,
        iconBuilder: (_) => Icons.folder_copy_outlined,
        titleBuilder: (l) => l.localLibrarySettingsTitle,
        subtitleBuilder: (l) => l.settingsSubtitleLocalLibrary,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.downloadManager,
        iconBuilder: (_) => Icons.manage_history_rounded,
        titleBuilder: (l) => l.downloadManager,
        subtitleBuilder: (l) => l.settingsSubtitleDownloadManager,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.downloads,
        iconBuilder: (p) => AppIcons.downloadOffline(p),
        titleBuilder: (l) => l.downloads,
        subtitleBuilder: (l) => l.settingsSubtitleDownloads,
      ),
    ],
  ),
  SettingsCategoryGroup(
    titleBuilder: (l) => l.settingsGroupSystem,
    items: [
      SettingsCategoryItem(
        category: SettingsCategory.server,
        iconBuilder: (p) => AppIcons.server(p),
        titleBuilder: (l) => l.serverAndNetwork,
        subtitleBuilder: (l) => l.settingsSubtitleServer,
      ),
      SettingsCategoryItem(
        category: SettingsCategory.about,
        iconBuilder: (p) => AppIcons.info(p),
        titleBuilder: (l) => l.aboutApp,
        subtitleBuilder: (l) => l.settingsSubtitleAbout,
      ),
    ],
  ),
];

/// Floating settings navigation with grouped section labels.
///
/// All rows are built eagerly so D-Pad / keyboard navigation always has a
/// target, and arrow keys are handled explicitly:
/// * Up / Down move between rows with a smooth centered scroll.
/// * At the edges focus falls back to the reading order, so Down on the last
///   row lands inside the options panel instead of getting stuck.
class ExpressiveSettingsSidebar extends ConsumerStatefulWidget {
  final SettingsCategory selectedCategory;
  final ValueChanged<SettingsCategory> onSelectCategory;

  /// Focus scope of the options panel on the right. When provided, pressing
  /// Right on a row moves the focus inside that panel.
  final FocusScopeNode? detailFocusScope;

  const ExpressiveSettingsSidebar({
    super.key,
    required this.selectedCategory,
    required this.onSelectCategory,
    this.detailFocusScope,
  });

  @override
  ConsumerState<ExpressiveSettingsSidebar> createState() =>
      ExpressiveSettingsSidebarState();
}

/// Public so the screen can send the focus back to the selected row when the
/// user presses Left inside the options panel.
class ExpressiveSettingsSidebarState
    extends ConsumerState<ExpressiveSettingsSidebar> {
  static const _scrollDuration = Duration(milliseconds: 220);

  late final List<FocusNode> _focusNodes;
  late final List<GlobalKey> _itemKeys;
  final ScrollController _scrollController = ScrollController();
  int _focusedIndex = -1;

  int get _itemCount => kSettingsCategoryGroups.fold(
    0,
    (total, group) => total + group.items.length,
  );

  @override
  void initState() {
    super.initState();
    final count = _itemCount;
    _focusNodes = List.generate(
      count,
      (index) => FocusNode(debugLabel: 'settings-nav-$index'),
    );
    _itemKeys = List.generate(count, (index) => GlobalKey());
    for (var i = 0; i < count; i++) {
      _focusNodes[i].addListener(() => _onFocusChanged(i));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Focuses the row that matches the currently selected category.
  void focusSelectedRow() {
    final index = _indexOf(widget.selectedCategory);
    if (index < 0 || index >= _focusNodes.length) {
      return;
    }
    _focusNodes[index].requestFocus();
    _reveal(index);
  }

  int _indexOf(SettingsCategory category) {
    var index = 0;
    for (final group in kSettingsCategoryGroups) {
      for (final item in group.items) {
        if (item.category == category) {
          return index;
        }
        index++;
      }
    }
    return -1;
  }

  void _onFocusChanged(int index) {
    if (!_focusNodes[index].hasFocus) {
      return;
    }
    _focusedIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index));
  }

  /// Keeps the focused row vertically centered while there is content left,
  /// clamped naturally at the scroll extents.
  void _reveal(int index) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final itemContext = _itemKeys[index].currentContext;
    final renderObject = itemContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      return;
    }

    final position = _scrollController.position;
    final target = viewport
        .getOffsetToReveal(renderObject, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((target - position.pixels).abs() < 0.5) {
      return;
    }

    _scrollController.animateTo(
      target,
      duration: _scrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Right arrow: jump straight into the options panel.
    if (key == LogicalKeyboardKey.arrowRight) {
      return _focusDetailOptions()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    final isDown = key == LogicalKeyboardKey.arrowDown;
    final isUp = key == LogicalKeyboardKey.arrowUp;
    if (!isDown && !isUp) {
      return KeyEventResult.ignored;
    }

    final current = _focusedIndex;
    if (current < 0 || current >= _focusNodes.length) {
      return KeyEventResult.ignored;
    }

    final next = isDown ? current + 1 : current - 1;
    if (next >= 0 && next < _focusNodes.length) {
      _focusNodes[next].requestFocus();
      return KeyEventResult.handled;
    }

    // Edge reached: continue through the reading order so focus can enter the
    // options panel instead of staying trapped on the first/last row.
    final policy = FocusTraversalGroup.of(context);
    final moved = isDown
        ? policy.next(_focusNodes[current])
        : policy.previous(_focusNodes[current]);

    if (!moved && isUp) {
      policy.next(_focusNodes.last);
    }
    return KeyEventResult.handled;
  }

  /// Moves the focus to the first control inside the detail panel, resuming
  /// from the last focused one when possible.
  bool _focusDetailOptions() {
    final scope = widget.detailFocusScope;
    if (scope == null || scope.context == null) {
      return false;
    }

    FocusNode? target = scope.focusedChild;
    if (target != null &&
        (target.context == null ||
            target is FocusScopeNode ||
            !target.canRequestFocus)) {
      target = null;
    }

    if (target == null) {
      for (final candidate in scope.traversalDescendants) {
        if (candidate is! FocusScopeNode &&
            candidate.context != null &&
            candidate.canRequestFocus) {
          target = candidate;
          break;
        }
      }
    }

    if (target == null) {
      return false;
    }

    target.requestFocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final children = <Widget>[];
    var index = 0;
    for (final group in kSettingsCategoryGroups) {
      children.add(_SidebarSectionLabel(text: group.titleBuilder(l10n)));
      children.add(const SizedBox(height: 6));

      for (var i = 0; i < group.items.length; i++) {
        final item = group.items[i];
        final itemIndex = index++;
        children.add(
          ExpressiveSettingsCategoryTile(
            key: _itemKeys[itemIndex],
            focusNode: _focusNodes[itemIndex],
            icon: item.iconBuilder(iconPack),
            title: item.titleBuilder(l10n),
            subtitle: item.subtitleBuilder(l10n),
            isSelected: widget.selectedCategory == item.category,
            isFirst: i == 0,
            isLast: i == group.items.length - 1,
            onTap: () => widget.onSelectCategory(item.category),
          ),
        );
      }

      children.add(const SizedBox(height: 8));
    }

    return M3ETheme(
      data: theme.brightness == Brightness.dark
          ? M3EThemeData.dark(seedColor: colorScheme.primary)
          : M3EThemeData.light(seedColor: colorScheme.primary),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String text;

  const _SidebarSectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}
