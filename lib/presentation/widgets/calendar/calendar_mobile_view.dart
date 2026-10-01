import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'calendar_day_tabs.dart';
import 'calendar_episode_card.dart';
import 'calendar_now_marker.dart';

class CalendarMobileView extends StatefulWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;
  final List<AiringScheduleItem> allSchedules;
  final TitleLanguage titleLang;
  final AppTranslations l10n;
  final bool isSpanish;
  final Future<void> Function() onRefresh;

  const CalendarMobileView({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.allSchedules,
    required this.titleLang,
    required this.l10n,
    required this.isSpanish,
    required this.onRefresh,
  });

  @override
  State<CalendarMobileView> createState() => _CalendarMobileViewState();
}

class _CalendarMobileViewState extends State<CalendarMobileView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant CalendarMobileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _pageController.hasClients &&
        _pageController.page?.round() != widget.selectedIndex) {
      _pageController.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<AiringScheduleItem> _getSchedulesForDay(DateTime day) {
    final start = day.millisecondsSinceEpoch ~/ 1000;
    final end = start + 86400;
    return widget.allSchedules.where((s) => s.airingAt >= start && s.airingAt < end).toList()
      ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return Column(
      children: [
        // Full-width Day Tabs Header with animated sliding line indicator
        CalendarDayTabs(
          days: widget.days,
          selectedIndex: widget.selectedIndex,
          onDaySelected: (idx) {
            widget.onDaySelected(idx);
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                idx,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            }
          },
          isSpanish: widget.isSpanish,
        ),

        // Day-by-Day PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.days.length,
            onPageChanged: (pageIndex) {
              widget.onDaySelected(pageIndex);
            },
            itemBuilder: (context, pageIndex) {
              final day = widget.days[pageIndex];
              final isToday = pageIndex == 0;
              final dayItems = _getSchedulesForDay(day);

              if (dayItems.isEmpty) {
                return RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 44,
                              color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.l10n.noAiringToday,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Build timeline items with NowMarker if today
              final columnWidgets = <Widget>[];
              bool markerInserted = false;

              for (int i = 0; i < dayItems.length; i++) {
                final item = dayItems[i];

                if (isToday && !markerInserted && item.airingAt > nowSeconds) {
                  columnWidgets.add(const CalendarNowMarker());
                  markerInserted = true;
                }

                columnWidgets.add(
                  CalendarEpisodeCard(
                    schedule: item,
                    titleLang: widget.titleLang,
                  ),
                );
              }

              if (isToday && !markerInserted) {
                columnWidgets.add(const CalendarNowMarker());
              }

              return RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 100),
                  itemCount: columnWidgets.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) => columnWidgets[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
