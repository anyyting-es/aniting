import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/desktop_nav_style_provider.dart';
import 'package:aniting/core/preferences/mobile_nav_style_provider.dart';
import 'package:aniting/core/preferences/resume_bar_preferences_provider.dart';
import 'package:aniting/core/preferences/section_visibility_provider.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/airing_calendar_screen.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/screens/feed_screen.dart';
import 'package:aniting/presentation/screens/library_screen.dart';
import 'package:aniting/presentation/screens/manga_detail_screen.dart';
import 'package:aniting/presentation/screens/manga_feed_screen.dart';
import 'package:aniting/presentation/screens/search_screen.dart';
import 'package:aniting/presentation/screens/settings_screen.dart';
import 'package:aniting/presentation/widgets/desktop_sidebar.dart';
import 'package:aniting/presentation/widgets/floating_resume_bar.dart';
import 'package:aniting/presentation/widgets/mobile_floating_nav.dart';
import 'package:aniting/presentation/providers/app_update_provider.dart';
import 'package:aniting/presentation/widgets/quick_search/feed_quick_search.dart';
import 'package:aniting/presentation/widgets/shell_animated_indexed_stack.dart';
import 'package:aniting/presentation/widgets/update/app_update_dialog.dart';

enum ShellSection {
  anime,
  manga,
  explore,
  calendar,
  profile,
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  ShellSection _activeSection = ShellSection.anime;
  final ValueNotifier<bool> _isResumeExpandedNotifier = ValueNotifier<bool>(true);

  /// Tabs whose page has actually been built at least once.
  ///
  /// An [IndexedStack] builds *every* child, so mounting the whole shell on the
  /// first frame used to start all five screens — and all five families of
  /// providers and image decodes — in the same frame the splash handed over.
  /// That burst was the startup stutter. Inactive tabs now mount on demand (and
  /// then stay mounted, so their scroll position and state are preserved).
  final Set<ShellSection> _mountedSections = <ShellSection>{
    ShellSection.anime,
  };

  /// One built widget per section, kept stable across rebuilds: an identical
  /// widget instance makes the parent [Element] skip rebuilding that subtree.
  final Map<ShellSection, Widget> _pageCache = <ShellSection, Widget>{};

  final List<Timer> _deferredMountTimers = <Timer>[];

  /// Guards the command-palette shortcut while its dialog is on screen.
  bool _isQuickSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _activeSection = ShellSection.anime;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });

    _scheduleDeferredTabMounts();

    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
  }

  /// Mounts the remaining tabs one at a time, after the first paint.
  ///
  /// Switching to a tab for the first time then costs nothing visible, while the
  /// startup burst is spread over seconds instead of landing on the handover
  /// frame. Heaviest screens (Explore) go last.
  void _scheduleDeferredTabMounts() {
    // Widget tests have no real network/disk and pump large chunks of fake time
    // in one go; waking up every tab there only spawns failing requests.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    const order = <ShellSection>[
      ShellSection.manga,
      ShellSection.calendar,
      ShellSection.profile,
      ShellSection.explore,
    ];

    for (var i = 0; i < order.length; i++) {
      _deferredMountTimers.add(
        Timer(Duration(milliseconds: 1200 + (i * 1200)), () {
          final section = order[i];
          if (!mounted || _mountedSections.contains(section)) return;
          setState(() => _mountedSections.add(section));
        }),
      );
    }
  }

  void _selectSection(ShellSection section) {
    if (_activeSection == section && _mountedSections.contains(section)) {
      return;
    }
    setState(() {
      _activeSection = section;
      _mountedSections.add(section);
    });
  }

  Widget _pageFor(ShellSection section) {
    return _pageCache.putIfAbsent(section, () {
      switch (section) {
        case ShellSection.anime:
          return RepaintBoundary(
            child: FeedScreen(
              onOpenSearch: () {
                ref.read(searchViewActiveProvider.notifier).state = true;
                _selectSection(ShellSection.explore);
              },
              onOpenSettings: _openSettings,
            ),
          );
        case ShellSection.manga:
          return RepaintBoundary(
            child: MangaFeedScreen(
              onOpenSearch: () {
                ref.read(searchViewActiveProvider.notifier).state = true;
                _selectSection(ShellSection.explore);
              },
              onOpenSettings: _openSettings,
            ),
          );
        case ShellSection.explore:
          return const RepaintBoundary(child: SearchScreen());
        case ShellSection.calendar:
          return const RepaintBoundary(child: AiringCalendarScreen());
        case ShellSection.profile:
          return RepaintBoundary(
            child: LibraryScreen(onOpenSettings: _openSettings),
          );
      }
    });
  }

  static bool _hasCheckedForUpdatesOnStartup = false;

  Future<void> _checkAutoUpdate() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (_hasCheckedForUpdatesOnStartup) return;
    _hasCheckedForUpdatesOnStartup = true;

    // Small delay to allow the shell layout and feed warm-up to finish smoothly
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    try {
      final info = await ref.read(appUpdateNotifierProvider.notifier).checkForUpdate();
      if (mounted && info != null && info.hasUpdate) {
        AppUpdateDialog.show(context, info);
      }
    } catch (_) {
      // Silently ignore network or offline issues on startup
    }
  }

  @override
  void dispose() {
    for (final timer in _deferredMountTimers) {
      timer.cancel();
    }
    _deferredMountTimers.clear();
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    _isResumeExpandedNotifier.dispose();
    super.dispose();
  }

  /// Ctrl/Cmd + K opens the floating quick search from the anime and manga
  /// feeds. Only the visible shell route reacts, so a pushed detail screen or
  /// an open dialog keeps the shortcut to itself.
  bool _handleGlobalShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;

    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;

    if (_isQuickSearchOpen || _isSettingsOpen) return false;

    final section = _activeSection;
    if (section != ShellSection.anime && section != ShellSection.manga) {
      return false;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    unawaited(_openQuickSearch());
    return true;
  }

  Future<void> _openQuickSearch() async {
    if (_isQuickSearchOpen) return;
    _isQuickSearchOpen = true;
    try {
      final selected = await showFeedQuickSearch(
        context: context,
        isManga: _activeSection == ShellSection.manga,
      );
      if (!mounted || selected == null) return;

      if (selected is AnimeEntry) {
        await AnimeDetailScreen.navigate(
          context,
          mediaId: selected.mediaId,
          initialEntry: selected,
        );
      } else if (selected is MangaEntry) {
        await MangaDetailScreen.navigate(
          context,
          mediaId: selected.mediaId,
          initialEntry: selected,
        );
      }
    } finally {
      _isQuickSearchOpen = false;
    }
  }

  bool _isSettingsOpen = false;

  void _openSettings() async {
    setState(() => _isSettingsOpen = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) {
      setState(() => _isSettingsOpen = false);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      final pixels = notification.metrics.pixels;

      if (pixels <= 20) {
        if (!_isResumeExpandedNotifier.value) {
          _isResumeExpandedNotifier.value = true;
        }
      } else if (delta > 8 && pixels > 40) {
        if (_isResumeExpandedNotifier.value) {
          _isResumeExpandedNotifier.value = false;
        }
      } else if (delta < -8) {
        if (!_isResumeExpandedNotifier.value) {
          _isResumeExpandedNotifier.value = true;
        }
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.forward) {
        if (!_isResumeExpandedNotifier.value) {
          _isResumeExpandedNotifier.value = true;
        }
      } else if (notification.direction == ScrollDirection.reverse &&
          notification.metrics.pixels > 40) {
        if (_isResumeExpandedNotifier.value) {
          _isResumeExpandedNotifier.value = false;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final l10n = ref.watch(translationsProvider);
    final mobileNavStyle = ref.watch(mobileNavStyleProvider);
    final desktopNavStyle = ref.watch(desktopNavStyleProvider);
    final iconPack = ref.watch(iconPackProvider);

    final avatarUrl = ref.watch(serverNotifierProvider.select((s) => s.status?.avatarUrl));

    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);

    final List<ShellSection> availableSections = [
      ShellSection.anime,
      if (mangaEnabled) ShellSection.manga,
      ShellSection.explore,
      ShellSection.calendar,
      ShellSection.profile,
    ];

    if (!availableSections.contains(_activeSection)) {
      _activeSection = availableSections.first;
      _mountedSections.add(_activeSection);
    }

    final activeIndex = availableSections.indexOf(_activeSection);

    final isSidebarActive = isDesktop && desktopNavStyle == DesktopNavStyle.sidebar;

    final availablePages = availableSections.map<Widget>((s) {
      final page = _mountedSections.contains(s)
          ? _pageFor(s)
          : const SizedBox.shrink();
      if (isSidebarActive && s != ShellSection.explore) {
        return Padding(
          padding: const EdgeInsets.only(left: 72),
          child: page,
        );
      }
      return page;
    }).toList();

    final sidebarItems = <DesktopSidebarItem>[];
    final desktopSidebarItems = <DesktopSidebarItem>[];

    for (int i = 0; i < availableSections.length; i++) {
      final s = availableSections[i];
      switch (s) {
        case ShellSection.anime:
          final item = DesktopSidebarItem(
            icon: AppIcons.home(iconPack),
            selectedIcon: AppIcons.home(iconPack),
            label: l10n.navHome,
            targetIndex: i,
          );
          sidebarItems.add(item);
          desktopSidebarItems.add(item);
          break;
        case ShellSection.manga:
          final item = DesktopSidebarItem(
            icon: AppIcons.manga(iconPack),
            selectedIcon: AppIcons.manga(iconPack),
            label: l10n.manga,
            targetIndex: i,
          );
          sidebarItems.add(item);
          desktopSidebarItems.add(item);
          break;
        case ShellSection.explore:
          final item = DesktopSidebarItem(
            icon: AppIcons.explore(iconPack),
            selectedIcon: AppIcons.explore(iconPack),
            label: l10n.navExplore,
            targetIndex: i,
          );
          sidebarItems.add(item);
          break;
        case ShellSection.calendar:
          final item = DesktopSidebarItem(
            icon: AppIcons.calendar(iconPack),
            selectedIcon: AppIcons.calendar(iconPack),
            label: l10n.navCalendar,
            targetIndex: i,
          );
          sidebarItems.add(item);
          desktopSidebarItems.add(item);
          break;
        case ShellSection.profile:
          final item = DesktopSidebarItem(
            icon: AppIcons.profile(iconPack),
            selectedIcon: AppIcons.profile(iconPack),
            label: l10n.navProfile,
            targetIndex: i,
            avatarUrl: avatarUrl,
          );
          sidebarItems.add(item);
          desktopSidebarItems.add(item);
          break;
      }
    }

    ref.listen<LastSessionItem?>(lastSessionProvider, (prev, next) {
      if (next != null &&
          (prev == null ||
              prev.mediaId != next.mediaId ||
              prev.episodeNumber != next.episodeNumber ||
              prev.chapterNumber != next.chapterNumber)) {
        if (!_isResumeExpandedNotifier.value) {
          _isResumeExpandedNotifier.value = true;
        }
      }
    });

    final isDark = theme.brightness == Brightness.dark;
    final shellOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    Widget wrapWithSystemOverlay(Widget scaffoldChild) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: shellOverlayStyle,
        child: scaffoldChild,
      );
    }

    if (isDesktop) {
      if (desktopNavStyle == DesktopNavStyle.sidebar) {
        return wrapWithSystemOverlay(
          Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Stack(
              children: [
                // Full-width Main Content Area for Desktop & TV with Smooth Animation
                Positioned.fill(
                  child: Theme(
                    data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
                    child: Visibility(
                      visible: !_isSettingsOpen,
                      maintainState: true,
                      child: ShellAnimatedIndexedStack(
                        index: activeIndex,
                        children: availablePages,
                      ),
                    ),
                  ),
                ),

                // Floating Vertical Desktop Sidebar Rail (Transparent, Overlaying Canvas)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: DesktopSidebar(
                    selectedIndex: activeIndex,
                    isSearchActive: _activeSection == ShellSection.explore,
                    onDestinationSelected: (idx) {
                      if (idx >= 0 && idx < availableSections.length) {
                        final section = availableSections[idx];
                        if (section == ShellSection.explore) {
                          ref.read(searchViewActiveProvider.notifier).state = false;
                        }
                        _selectSection(section);
                      }
                    },
                    onSearchPressed: () {
                      ref.read(searchViewActiveProvider.notifier).state = false;
                      _selectSection(ShellSection.explore);
                    },
                    onSettingsPressed: _openSettings,
                    items: desktopSidebarItems,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Desktop Floating Navigation Mode: Full-bleed canvas with bottom centered floating dock
        return wrapWithSystemOverlay(
          Scaffold(
            extendBody: true,
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: Theme(
                data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
                child: Visibility(
                  visible: !_isSettingsOpen,
                  maintainState: true,
                  child: ShellAnimatedIndexedStack(
                    index: activeIndex,
                    children: availablePages,
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              bottom: true,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isResumeExpandedNotifier,
                builder: (context, isResumeExpanded, _) {
                  return MobileFloatingNav(
                    selectedIndex: activeIndex,
                    onDestinationSelected: (idx) {
                      if (idx >= 0 && idx < availableSections.length) {
                        _selectSection(availableSections[idx]);
                      }
                      _isResumeExpandedNotifier.value = true;
                    },
                    items: sidebarItems,
                    isResumeExpanded: isResumeExpanded,
                  );
                },
              ),
            ),
          ),
        );
      }
    }

    if (mobileNavStyle == MobileNavStyle.floating) {
      // Mobile layout: Floating iOS-style bottom pill navigation dock with animated hero resume companion
      return wrapWithSystemOverlay(
        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: Theme(
              data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
              child: Visibility(
                visible: !_isSettingsOpen,
                maintainState: true,
                child: ShellAnimatedIndexedStack(
                  index: activeIndex,
                  children: availablePages,
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            bottom: true,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isResumeExpandedNotifier,
              builder: (context, isResumeExpanded, _) {
                return MobileFloatingNav(
                  selectedIndex: activeIndex,
                  onDestinationSelected: (idx) {
                    if (idx >= 0 && idx < availableSections.length) {
                      _selectSection(availableSections[idx]);
                    }
                    _isResumeExpandedNotifier.value = true;
                  },
                  items: sidebarItems,
                  isResumeExpanded: isResumeExpanded,
                );
              },
            ),
          ),
        ),
      );
    }

    // Mobile layout: Classic fixed NavigationBar
    return wrapWithSystemOverlay(
      Scaffold(
        extendBody: false,
        body: ShellAnimatedIndexedStack(
          index: activeIndex,
          children: availablePages,
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FloatingResumeBar(),
            Container(
              color: theme.colorScheme.surfaceContainer,
              child: SafeArea(
                top: false,
                bottom: true,
                child: NavigationBar(
                  selectedIndex: activeIndex,
                  onDestinationSelected: (idx) {
                    if (idx >= 0 && idx < availableSections.length) {
                      _selectSection(availableSections[idx]);
                    }
                  },
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  indicatorColor: theme.colorScheme.primaryContainer,
                  elevation: 0,
                  height: 65,
                  destinations: sidebarItems.map((item) {
                    final isProfile = item.label == l10n.navProfile;
                    final hasAvatar = item.avatarUrl != null && item.avatarUrl!.isNotEmpty;
                    Widget iconWidget = Icon(item.icon, color: theme.colorScheme.onSurfaceVariant);
                    Widget selectedIconWidget = Icon(item.selectedIcon, color: theme.colorScheme.onPrimaryContainer);

                    if (isProfile && hasAvatar) {
                      final avatarWidget = Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: item.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
                          errorWidget: (context, url, error) => Icon(item.icon, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      );
                      iconWidget = avatarWidget;
                      selectedIconWidget = Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.onPrimaryContainer,
                            width: 1.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: item.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
                          errorWidget: (context, url, error) => Icon(item.icon, color: theme.colorScheme.onPrimaryContainer),
                        ),
                      );
                    }

                    return NavigationDestination(
                      icon: iconWidget,
                      selectedIcon: selectedIconWidget,
                      label: item.label,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
