import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/desktop_nav_style_provider.dart';
import 'package:seanime_app/core/preferences/mobile_nav_style_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
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
import 'package:seanime_app/presentation/providers/app_update_provider.dart';
import 'package:seanime_app/presentation/widgets/shell_animated_indexed_stack.dart';
import 'package:seanime_app/presentation/widgets/update/app_update_dialog.dart';
import 'package:seanime_app/data/services/explore_carousel_service.dart';

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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      RepaintBoundary(
        child: FeedScreen(
          onOpenSearch: () => setState(() => _activeSection = ShellSection.explore),
          onOpenSettings: _openSettings,
        ),
      ),
      RepaintBoundary(
        child: MangaFeedScreen(
          onOpenSearch: () => setState(() => _activeSection = ShellSection.explore),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
      ref.read(exploreCarouselNotifierProvider.notifier).syncOnStartup();
    });
  }

  static bool _hasCheckedForUpdatesOnStartup = false;

  Future<void> _checkAutoUpdate() async {
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
    _isResumeExpandedNotifier.dispose();
    super.dispose();
  }

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
    final desktopNavStyle = ref.watch(desktopNavStyleProvider);
    final iconPack = ref.watch(iconPackProvider);

    final serverState = ref.watch(serverNotifierProvider);
    final avatarUrl = serverState.status?.avatarUrl;

    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final showsEnabled = ref.watch(showsSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);

    final isHomeActive = animeEnabled || showsEnabled;

    final List<ShellSection> availableSections = [
      if (isHomeActive) ShellSection.anime,
      if (mangaEnabled) ShellSection.manga,
      ShellSection.explore,
      ShellSection.calendar,
      ShellSection.profile,
    ];

    if (!availableSections.contains(_activeSection)) {
      _activeSection = availableSections.first;
    }

    final activeIndex = availableSections.indexOf(_activeSection);

    final availablePages = availableSections.map<Widget>((s) {
      switch (s) {
        case ShellSection.anime:
          return _pages[0];
        case ShellSection.manga:
          return _pages[1];
        case ShellSection.explore:
          return _pages[2];
        case ShellSection.calendar:
          return _pages[3];
        case ShellSection.profile:
          return _pages[4];
      }
    }).toList();

    final sidebarItems = <DesktopSidebarItem>[];
    final desktopSidebarItems = <DesktopSidebarItem>[];

    for (int i = 0; i < availableSections.length; i++) {
      final s = availableSections[i];
      switch (s) {
        case ShellSection.anime:
          final String homeLabel;
          if (animeEnabled && !showsEnabled) {
            homeLabel = l10n.navHome;
          } else if (!animeEnabled && showsEnabled) {
            homeLabel = l10n.shows;
          } else {
            homeLabel = l10n.navHome;
          }

          final item = DesktopSidebarItem(
            icon: (!animeEnabled && showsEnabled) ? Icons.movie_filter_rounded : AppIcons.home(iconPack),
            selectedIcon: (!animeEnabled && showsEnabled) ? Icons.movie_filter_rounded : AppIcons.home(iconPack),
            label: homeLabel,
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
            body: Row(
              children: [
                // Vertical Desktop Sidebar Rail
                DesktopSidebar(
                  selectedIndex: activeIndex,
                  isSearchActive: _activeSection == ShellSection.explore,
                  onDestinationSelected: (idx) {
                    if (idx >= 0 && idx < availableSections.length) {
                      setState(() => _activeSection = availableSections[idx]);
                    }
                  },
                  onSearchPressed: () {
                    setState(() => _activeSection = ShellSection.explore);
                  },
                  onSettingsPressed: _openSettings,
                  items: desktopSidebarItems,
                ),

                // Full-width Main Content Area for Desktop & TV with Smooth Animation
                Expanded(
                  child: ShellAnimatedIndexedStack(
                    index: activeIndex,
                    children: availablePages,
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
              child: ShellAnimatedIndexedStack(
                index: activeIndex,
                children: availablePages,
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
                        setState(() => _activeSection = availableSections[idx]);
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
          body: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: ShellAnimatedIndexedStack(
              index: activeIndex,
              children: availablePages,
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
                      setState(() => _activeSection = availableSections[idx]);
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
                      setState(() => _activeSection = availableSections[idx]);
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
