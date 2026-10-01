import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'calendar_day_tabs.dart';
import 'calendar_episode_card.dart';
import 'calendar_now_marker.dart';

class CalendarDesktopView extends StatefulWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;
  final List<AiringScheduleItem> allSchedules;
  final TitleLanguage titleLang;
  final AppTranslations l10n;
  final bool isSpanish;

  const CalendarDesktopView({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.allSchedules,
    required this.titleLang,
    required this.l10n,
    required this.isSpanish,
  });

  @override
  State<CalendarDesktopView> createState() => _CalendarDesktopViewState();
}

class _CalendarDesktopViewState extends State<CalendarDesktopView> {
  late final ScrollController _horizontalController;
  late final ScrollController _headerScrollController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _horizontalController = SmoothTrackingScrollController();
    _headerScrollController = ScrollController();

    _horizontalController.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      if (_headerScrollController.hasClients &&
          _headerScrollController.offset != _horizontalController.offset) {
        _headerScrollController.jumpTo(
          _horizontalController.offset.clamp(0.0, _headerScrollController.position.maxScrollExtent),
        );
      }
      _isSyncing = false;
    });

    _headerScrollController.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      if (_horizontalController.hasClients &&
          _horizontalController.offset != _headerScrollController.offset) {
        _horizontalController.jumpTo(
          _headerScrollController.offset.clamp(0.0, _horizontalController.position.maxScrollExtent),
        );
      }
      _isSyncing = false;
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarDesktopView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelectedDay(widget.selectedIndex);
    }
  }

  double _calculateColWidth(double totalWidth) {
    // Generous minimum column width (290px) to prevent tiny text or cramped images
    return math.max(totalWidth / 4.5, 290.0);
  }

  void _scrollToSelectedDay(int index) {
    if (!_horizontalController.hasClients) return;
    final totalWidth = MediaQuery.of(context).size.width;
    final colWidth = _calculateColWidth(totalWidth);
    final targetOffset = index * colWidth;
    final maxScroll = _horizontalController.position.maxScrollExtent;
    final clamped = targetOffset.clamp(0.0, maxScroll);

    _horizontalController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Generous column width so elements are clearly visible without squinting
        final colWidth = _calculateColWidth(totalWidth);
        final contentWidth = colWidth * widget.days.length;

        return Column(
          children: [
            // Full-width Day Tabs Header with animated sliding line indicator
            CalendarDayTabs(
              days: widget.days,
              selectedIndex: widget.selectedIndex,
              onDaySelected: (idx) {
                widget.onDaySelected(idx);
                _scrollToSelectedDay(idx);
              },
              isSpanish: widget.isSpanish,
              columnWidth: colWidth,
              scrollController: _headerScrollController,
            ),

            // Multi-column Content Body
            Expanded(
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: contentWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(widget.days.length, (dayIdx) {
                      final day = widget.days[dayIdx];
                      final isToday = dayIdx == 0;
                      final isSelected = dayIdx == widget.selectedIndex;
                      final dayItems = _getSchedulesForDay(day);

                      // Build column list items including CalendarNowMarker if today
                      final columnWidgets = <Widget>[];

                      if (dayItems.isEmpty) {
                        columnWidgets.add(
                          Padding(
                            padding: const EdgeInsets.only(top: 48, left: 16, right: 16),
                            child: Center(
                              child: Text(
                                widget.l10n.noAiringToday,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white30 : theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        bool markerInserted = false;

                        for (int i = 0; i < dayItems.length; i++) {
                          final item = dayItems[i];

                          // Insert NowMarker before the first future episode if today
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

                        // If all episodes are in past and today, add marker at the end
                        if (isToday && !markerInserted) {
                          columnWidgets.add(const CalendarNowMarker());
                        }
                      }

                      return Container(
                        width: colWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? Colors.white.withValues(alpha: 0.015)
                                  : theme.colorScheme.primary.withValues(alpha: 0.02))
                              : Colors.transparent,
                          border: Border(
                            right: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          children: columnWidgets,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
