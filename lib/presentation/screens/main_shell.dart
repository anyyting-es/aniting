import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/mobile_nav_style_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/airing_calendar_screen.dart';
import 'package:seanime_app/presentation/screens/feed_screen.dart';
import 'package:seanime_app/presentation/screens/library_screen.dart';
import 'package:seanime_app/presentation/screens/manga_feed_screen.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/screens/settings_screen.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';
import 'package:seanime_app/presentation/widgets/floating_resume_bar.dart';
import 'package:seanime_app/presentation/widgets/mobile_floating_nav.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _isResumeExpandedNotifier = ValueNotifier<bool>(true);
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      RepaintBoundary(
        child: FeedScreen(
          onOpenSearch: () => setState(() => _currentIndex = 2),
          onOpenSettings: _openSettings,
        ),
      ),
      RepaintBoundary(
        child: MangaFeedScreen(
          onOpenSearch: () => setState(() => _currentIndex = 2),
          onOpenSettings: _openSettings,
        ),
      ),
      const RepaintBoundary(child: SearchScreen()),
      const RepaintBoundary(child: AiringCalendarScreen()),
      RepaintBoundary(
        child: LibraryScreen(
          onOpenSettings: _openSettings,
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _isResumeExpandedNotifier.dispose();
    super.dispose();
  }

  void _onDesktopDestinationSelected(int desktopIndex) {
    setState(() => _currentIndex = desktopIndex);
  }

  int get _desktopSelectedIndex => _currentIndex;

  void _openSettings() {
    Navigator.push(
      context,
      SlideRightToLeftPageRoute(child: const SettingsScreen()),
    );
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
    final iconPack = ref.watch(iconPackProvider);

    final serverState = ref.watch(serverNotifierProvider);
    final avatarUrl = serverState.status?.avatarUrl;

    final sidebarItems = [
      DesktopSidebarItem(
        icon: AppIcons.home(iconPack),
        selectedIcon: AppIcons.home(iconPack),
        label: l10n.navHome,
      ),
      DesktopSidebarItem(
        icon: AppIcons.manga(iconPack),
        selectedIcon: AppIcons.manga(iconPack),
        label: l10n.manga,
      ),
      DesktopSidebarItem(
        icon: AppIcons.explore(iconPack),
        selectedIcon: AppIcons.explore(iconPack),
        label: l10n.navExplore,
      ),
      DesktopSidebarItem(
        icon: AppIcons.calendar(iconPack),
        selectedIcon: AppIcons.calendar(iconPack),
        label: l10n.navCalendar,
      ),
      DesktopSidebarItem(
        icon: AppIcons.profile(iconPack),
        selectedIcon: AppIcons.profile(iconPack),
        label: l10n.navProfile,
        avatarUrl: avatarUrl,
      ),
    ];

    final desktopSidebarItems = [
      DesktopSidebarItem(
        icon: AppIcons.home(iconPack),
        selectedIcon: AppIcons.home(iconPack),
        label: l10n.navHome,
        targetIndex: 0,
      ),
      DesktopSidebarItem(
        icon: AppIcons.manga(iconPack),
        selectedIcon: AppIcons.manga(iconPack),
        label: l10n.manga,
        targetIndex: 1,
      ),
      DesktopSidebarItem(
        icon: AppIcons.calendar(iconPack),
        selectedIcon: AppIcons.calendar(iconPack),
        label: l10n.navCalendar,
        targetIndex: 3,
      ),
      DesktopSidebarItem(
        icon: AppIcons.profile(iconPack),
        selectedIcon: AppIcons.profile(iconPack),
        label: l10n.navProfile,
        targetIndex: 4,
        avatarUrl: avatarUrl,
      ),
    ];

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

    if (isDesktop) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            // Vertical Desktop Sidebar Rail
            DesktopSidebar(
              selectedIndex: _desktopSelectedIndex,
              isSearchActive: _currentIndex == 2,
              onDestinationSelected: _onDesktopDestinationSelected,
              onSearchPressed: () {
                setState(() => _currentIndex = 2);
              },
              onSettingsPressed: _openSettings,
              items: desktopSidebarItems,
            ),

            // Full-width Main Content Area for Desktop & TV
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    TickerMode(
                      enabled: _currentIndex == i,
                      child: _pages[i],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (mobileNavStyle == MobileNavStyle.floating) {
      // Mobile layout: Floating iOS-style bottom pill navigation dock with animated hero resume companion
      return Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: IndexedStack(
            index: _currentIndex,
            children: [
              for (int i = 0; i < _pages.length; i++)
                TickerMode(
                  enabled: _currentIndex == i,
                  child: _pages[i],
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          bottom: true,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isResumeExpandedNotifier,
            builder: (context, isResumeExpanded, _) {
              return MobileFloatingNav(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  _isResumeExpandedNotifier.value = true;
                },
                items: sidebarItems,
                isResumeExpanded: isResumeExpanded,
              );
            },
          ),
        ),
      );
    }

    // Mobile layout: Classic fixed NavigationBar
    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (int i = 0; i < _pages.length; i++)
            TickerMode(
              enabled: _currentIndex == i,
              child: _pages[i],
            ),
        ],
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
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) => setState(() => _currentIndex = index),
                backgroundColor: theme.colorScheme.surfaceContainer,
                indicatorColor: theme.colorScheme.primaryContainer,
                elevation: 0,
                height: 65,
                destinations: [
                  NavigationDestination(
                    icon: Icon(AppIcons.home(iconPack), color: theme.colorScheme.onSurfaceVariant),
                    selectedIcon: Icon(AppIcons.home(iconPack), color: theme.colorScheme.onPrimaryContainer),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.manga(iconPack), color: theme.colorScheme.onSurfaceVariant),
                    selectedIcon: Icon(AppIcons.manga(iconPack), color: theme.colorScheme.onPrimaryContainer),
                    label: l10n.manga,
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.explore(iconPack), color: theme.colorScheme.onSurfaceVariant),
                    selectedIcon: Icon(AppIcons.explore(iconPack), color: theme.colorScheme.onPrimaryContainer),
                    label: l10n.navExplore,
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.calendar(iconPack), color: theme.colorScheme.onSurfaceVariant),
                    selectedIcon: Icon(AppIcons.calendar(iconPack), color: theme.colorScheme.onPrimaryContainer),
                    label: l10n.navCalendar,
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.profile(iconPack), color: theme.colorScheme.onSurfaceVariant),
                    selectedIcon: Icon(AppIcons.profile(iconPack), color: theme.colorScheme.onPrimaryContainer),
                    label: l10n.navProfile,
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
