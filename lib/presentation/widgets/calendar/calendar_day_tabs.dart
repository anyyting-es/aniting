import 'package:flutter/material.dart';

/// Horizontal day selector for the airing calendar.
///
/// Compact, quiet day cells keeping the header readable and unobtrusive.
class CalendarDayTabs extends StatelessWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;
  final bool isSpanish;
  final String todayLabel;
  final double? columnWidth;
  final ScrollController? scrollController;

  const CalendarDayTabs({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.isSpanish,
    required this.todayLabel,
    this.columnWidth,
    this.scrollController,
  });

  String _weekdayLabel(DateTime day, int index) {
    if (index == 0) return todayLabel.toUpperCase();
    const esDays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    const enDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final idx = (day.weekday - 1).clamp(0, 6);
    final name = isSpanish ? esDays[idx] : enDays[idx];

    if (index >= 4 && day.weekday == DateTime.monday) {
      return isSpanish ? 'PRÓX $name' : 'NEXT $name';
    }
    return name;
  }

  String _monthLabel(DateTime day) {
    const esMonths = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    const enMonths = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final idx = (day.month - 1).clamp(0, 11);
    return isSpanish ? esMonths[idx] : enMonths[idx];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final tabWidth =
            columnWidth ?? (totalWidth > 0 ? (totalWidth / days.length) : 56.0);
        final contentWidth =
            columnWidth != null ? (columnWidth! * days.length) : totalWidth;

        final tabsContent = SizedBox(
          width: contentWidth,
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: List.generate(days.length, (index) {
                final day = days[index];
                return SizedBox(
                  width: tabWidth,
                  child: _CalendarDayCell(
                    width: tabWidth,
                    dayNumber: day.day,
                    weekday: _weekdayLabel(day, index),
                    month: _monthLabel(day),
                    isSelected: index == selectedIndex,
                    isToday: index == 0,
                    onTap: () => onDaySelected(index),
                  ),
                );
              }),
            ),
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

class _CalendarDayCell extends StatefulWidget {
  final double width;
  final int dayNumber;
  final String weekday;
  final String month;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.width,
    required this.dayNumber,
    required this.weekday,
    required this.month,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final hoverFill = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    final dateColor = widget.isSelected
        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
        : (isDark ? Colors.white.withValues(alpha: 0.88) : theme.colorScheme.onSurface);
    final weekdayColor = widget.isSelected
        ? (isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface)
        : (isDark
            ? Colors.white.withValues(alpha: 0.44)
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7));
    final monthColor = widget.isSelected
        ? (isDark ? Colors.white.withValues(alpha: 0.6) : theme.colorScheme.onSurfaceVariant)
        : (isDark
            ? Colors.white.withValues(alpha: 0.34)
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? selectedFill
                  : (_isHovered ? hoverFill : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : theme.colorScheme.outlineVariant)
                    : (_isHovered
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.35))
                        : Colors.transparent),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.weekday,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: weekdayColor,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.width >= 56)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${widget.dayNumber}',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -0.4,
                          color: dateColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.month,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: monthColor,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${widget.dayNumber}',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.4,
                      color: dateColor,
                    ),
                  ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2.5,
                  width: widget.isSelected ? 16 : 0,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
