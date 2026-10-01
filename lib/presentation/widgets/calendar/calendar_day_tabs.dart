import 'package:flutter/material.dart';

class CalendarDayTabs extends StatelessWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;
  final bool isSpanish;
  final double? columnWidth;
  final ScrollController? scrollController;

  const CalendarDayTabs({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.isSpanish,
    this.columnWidth,
    this.scrollController,
  });

  String _formatDayMonth(DateTime day) {
    return '${day.month}/${day.day}';
  }

  String _formatWeekday(DateTime day, int index) {
    if (index == 0) {
      return isSpanish ? 'Hoy' : 'Today';
    }
    const esDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = (day.weekday - 1).clamp(0, 6);
    final name = isSpanish ? esDays[idx] : enDays[idx];

    // In reference: later days of next week can show "Next Mon"
    if (index >= 4 && day.weekday == DateTime.monday) {
      return isSpanish ? 'Próx. $name' : 'Next $name';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // If columnWidth is specified (desktop multi-column sync), use it, otherwise distribute equally
        final tabWidth = columnWidth ?? (totalWidth > 0 ? (totalWidth / days.length) : 60.0);
        final tabCount = days.length;
        final contentWidth = columnWidth != null ? (columnWidth! * tabCount) : totalWidth;
        const indicatorWidth = 40.0;

        Widget tabsContent = SizedBox(
          width: contentWidth,
          height: 68,
          child: Stack(
            children: [
              // Bottom hairline divider
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),

              // Animated sliding line indicator ("dot tipo línea / pestaña")
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: (selectedIndex * tabWidth) + (tabWidth - indicatorWidth) / 2,
                bottom: 0,
                width: indicatorWidth,
                height: 3.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.5),
                        blurRadius: 5,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),

              // Day buttons
              Positioned.fill(
                child: Row(
                  children: List.generate(days.length, (index) {
                    final day = days[index];
                    final isSelected = index == selectedIndex;
                    final dateStr = _formatDayMonth(day);
                    final weekdayStr = _formatWeekday(day, index);

                    return SizedBox(
                      width: tabWidth,
                      height: 68,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onDaySelected(index),
                          splashColor: primaryColor.withValues(alpha: 0.12),
                          highlightColor: primaryColor.withValues(alpha: 0.06),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? Colors.white : primaryColor)
                                      : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                weekdayStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );

        if (columnWidth != null && scrollController != null) {
          return SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: tabsContent,
          );
        }

        return tabsContent;
      },
    );
  }
}
