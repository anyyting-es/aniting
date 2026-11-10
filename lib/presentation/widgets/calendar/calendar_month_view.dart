import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/core/theme/app_theme_colors.dart';
import 'package:aniting/data/models/airing_schedule.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_preview_data.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_quick_view_detector.dart';

import 'calendar_episode_card.dart';

class CalendarMonthView extends StatefulWidget {
  final DateTime currentMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final List<AiringScheduleItem> allSchedules;
  final TitleLanguage titleLang;
  final AppTranslations l10n;
  final bool isSpanish;

  const CalendarMonthView({
    super.key,
    required this.currentMonth,
    required this.onMonthChanged,
    required this.allSchedules,
    required this.titleLang,
    required this.l10n,
    required this.isSpanish,
  });

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.year == widget.currentMonth.year &&
        now.month == widget.currentMonth.month) {
      _selectedDay = DateTime(now.year, now.month, now.day);
    } else {
      _selectedDay = DateTime(
        widget.currentMonth.year,
        widget.currentMonth.month,
        1,
      );
    }
  }

  /// Anchor for the hover cover preview. The preview is rendered inside this
  /// stack (not in the root overlay) so it can never survive the calendar page
  /// or float above other routes.
  final GlobalKey _previewStackKey = GlobalKey();

  @override
  void dispose() {
    // The poster is rendered inside this page, but its hide timer is global.
    // Clear both so nothing lingers after the calendar is gone.
    _CalendarCoverPreview.hide();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Offstage tabs keep their state (IndexedStack + TickerMode). Clear the
    // hovered poster so it does not reappear stale when the tab comes back.
    if (!TickerMode.of(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _CalendarCoverPreview.hide();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMonth.year != widget.currentMonth.year ||
        oldWidget.currentMonth.month != widget.currentMonth.month) {
      final now = DateTime.now();
      if (now.year == widget.currentMonth.year &&
          now.month == widget.currentMonth.month) {
        _selectedDay = DateTime(now.year, now.month, now.day);
      } else {
        _selectedDay = DateTime(
          widget.currentMonth.year,
          widget.currentMonth.month,
          1,
        );
      }
    }
  }

  String _formatMonthYear(DateTime date) {
    const esMonths = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    const enMonths = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final monthName = widget.isSpanish
        ? esMonths[date.month - 1]
        : enMonths[date.month - 1];
    return '$monthName ${date.year}';
  }

  String _formatFullDate(DateTime date, {bool includeYear = false}) {
    const esWeekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const enWeekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const esMonths = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    const enMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekdayName = widget.isSpanish
        ? esWeekdays[date.weekday - 1]
        : enWeekdays[date.weekday - 1];
    final monthName = widget.isSpanish
        ? esMonths[date.month - 1]
        : enMonths[date.month - 1];

    if (widget.isSpanish) {
      return includeYear
          ? '$weekdayName, ${date.day} de $monthName de ${date.year}'
          : '$weekdayName, ${date.day} de $monthName';
    } else {
      return includeYear
          ? '$weekdayName, $monthName ${date.day}, ${date.year}'
          : '$weekdayName, $monthName ${date.day}';
    }
  }

  void _previousMonth() {
    final prev = DateTime(
      widget.currentMonth.year,
      widget.currentMonth.month - 1,
      1,
    );
    widget.onMonthChanged(prev);
  }

  void _nextMonth() {
    final next = DateTime(
      widget.currentMonth.year,
      widget.currentMonth.month + 1,
      1,
    );
    widget.onMonthChanged(next);
  }

  void _goToToday() {
    final now = DateTime.now();
    widget.onMonthChanged(DateTime(now.year, now.month, 1));
    setState(() => _selectedDay = DateTime(now.year, now.month, now.day));
  }

  List<AiringScheduleItem> _getSchedulesForDay(DateTime day) {
    final start =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 1000;
    final end = start + 86400;
    return widget.allSchedules
        .where((s) => s.airingAt >= start && s.airingAt < end)
        .toList()
      ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
  }

  String _resolveTitle(AiringScheduleItem item) {
    final anime = item.media;
    final raw = anime.displayTitle(widget.titleLang);
    if (raw.isNotEmpty && raw != 'Sin título' && raw != 'No title') return raw;
    if (anime.title.isNotEmpty &&
        anime.title != 'Sin título' &&
        anime.title != 'No title') {
      return anime.title;
    }
    if (anime.romajiTitle != null && anime.romajiTitle!.trim().isNotEmpty) {
      return anime.romajiTitle!.trim();
    }
    if (anime.englishTitle != null && anime.englishTitle!.trim().isNotEmpty) {
      return anime.englishTitle!.trim();
    }
    if (anime.nativeTitle != null && anime.nativeTitle!.trim().isNotEmpty) {
      return anime.nativeTitle!.trim();
    }
    return 'Anime #${anime.mediaId}';
  }

  void _openDayModal(
    BuildContext context,
    DateTime cellDate,
    List<AiringScheduleItem> daySchedules,
  ) {
    // A title preview may be open while the user clicks the day cell. It lives
    // in the root overlay and would otherwise stay above the day route and
    // never come back down.
    _CalendarCoverPreview.hide();
    final colors = context.themeColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOled =
        colors.background == Colors.black ||
        (isDark && theme.scaffoldBackgroundColor == Colors.black);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final modalHeight = math.min(screenHeight * 0.82, 620.0);
    final modalWidth = math.min(screenWidth - 32, 540.0);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: isOled ? 0.88 : 0.65),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Center(
            child: SizedBox(
              width: modalWidth,
              height: modalHeight,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    color: isOled ? Colors.black : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOled
                          ? const Color(0xFF282832)
                          : colors.border.withValues(alpha: 0.85),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isOled ? 0.95 : 0.55,
                        ),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOled
                                      ? const Color(0xFF141418)
                                      : colors.accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOled
                                        ? const Color(0xFF282832)
                                        : colors.accent.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${cellDate.day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isOled
                                        ? Colors.white
                                        : colors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatFullDate(
                                        cellDate,
                                        includeYear: true,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${daySchedules.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isOled
                                                ? Colors.white70
                                                : colors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          ' ${widget.l10n.anime}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: widget.l10n.close,
                                color: colors.textSecondary,
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: isOled
                              ? const Color(0xFF202026)
                              : colors.border.withValues(alpha: 0.5),
                        ),

                        // Episode list
                        Expanded(
                          child: daySchedules.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.l10n.noAiringToday,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  itemCount: daySchedules.length,
                                  itemBuilder: (ctx, idx) {
                                    final item = daySchedules[idx];
                                    return CalendarEpisodeCard(
                                      schedule: item,
                                      titleLang: widget.titleLang,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOled =
        colors.background == Colors.black ||
        (isDark && theme.scaffoldBackgroundColor == Colors.black);
    final now = DateTime.now();
    final isCurrentMonth =
        now.year == widget.currentMonth.year &&
        now.month == widget.currentMonth.month;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        return Stack(
          key: _previewStackKey,
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Month Navigation Toolbar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: widget.l10n.previousMonth,
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          visualDensity: VisualDensity.compact,
                          color: colors.textSecondary,
                          onPressed: _previousMonth,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatMonthYear(widget.currentMonth),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: widget.l10n.nextMonth,
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          visualDensity: VisualDensity.compact,
                          color: colors.textSecondary,
                          onPressed: _nextMonth,
                        ),
                        const Spacer(),
                        if (!isCurrentMonth)
                          TextButton.icon(
                            onPressed: _goToToday,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.today_rounded, size: 15),
                            label: Text(
                              widget.l10n.today,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Weekday Headers
                  _buildWeekdayHeaders(theme, isDark, isOled),

                  // Calendar Grid Body
                  Expanded(
                    child: isDesktop
                        ? _buildDesktopGrid(context, theme, isDark, isOled)
                        : _buildMobileView(context, theme, isDark, isOled),
                  ),
                ],
              ),
            ),
            _buildCoverPreview(context),
          ],
        );
      },
    );
  }

  /// Renders the poster for the hovered month title, positioned inside this
  /// page's own stack.
  Widget _buildCoverPreview(BuildContext context) {
    return ValueListenableBuilder<_CalendarCoverPreviewData?>(
      valueListenable: _CalendarCoverPreview.notifier,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();

        final colors = context.themeColors;
        final theme = Theme.of(context);
        final isOled =
            data.isOled ||
            (theme.brightness == Brightness.dark &&
                theme.scaffoldBackgroundColor == Colors.black);

        final stackBox =
            _previewStackKey.currentContext?.findRenderObject() as RenderBox?;
        if (stackBox == null || !stackBox.attached || !stackBox.hasSize) {
          return const SizedBox.shrink();
        }

        final anchorTopLeft = stackBox.globalToLocal(data.anchor.topLeft);
        final anchorSize = data.anchor.size;
        final stackSize = stackBox.size;

        final previewWidth = _CalendarCoverPreview.width;
        final previewHeight = _CalendarCoverPreview.height;

        var left =
            anchorTopLeft.dx + (anchorSize.width - previewWidth) / 2;
        left = left.clamp(
          8.0,
          math.max(8.0, stackSize.width - previewWidth - 8),
        );

        var top = anchorTopLeft.dy - previewHeight - _CalendarCoverPreview.gap;
        if (top < 8) {
          top = anchorTopLeft.dy + (anchorSize.height - previewHeight) / 2;
        }
        top = top.clamp(
          8.0,
          math.max(8.0, stackSize.height - previewHeight - 8),
        );

        return Positioned(
          left: left,
          top: top,
          child: MouseRegion(
            // Moving the pointer from the title onto the poster keeps it
            // alive so it can be clicked; leaving both dismisses it.
            onEnter: (_) => _CalendarCoverPreview.cancelHide(),
            onExit: (_) => _CalendarCoverPreview.hideAfterDelay(data.owner),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _CalendarCoverPreview.hide();
                data.onOpen();
              },
              child: Material(
                type: MaterialType.transparency,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 130),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 5),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: previewWidth,
                    height: previewHeight,
                    decoration: BoxDecoration(
                      color: isOled ? Colors.black : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOled
                            ? const Color(0xFF2E2E38)
                            : colors.border.withValues(alpha: 0.85),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isOled ? 0.95 : 0.45,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: data.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: data.coverUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 480,
                              memCacheHeight: 720,
                              errorWidget: (_, _, _) => ColoredBox(
                                color: isOled
                                    ? const Color(0xFF101014)
                                    : colors.surfaceElevated,
                              ),
                            )
                          : ColoredBox(
                              color: isOled
                                  ? const Color(0xFF101014)
                                  : colors.surfaceElevated,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme, bool isDark, bool isOled) {
    final colors = context.themeColors;
    const esDays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    const enDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final labels = widget.isSpanish ? esDays : enDays;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isOled
                ? const Color(0xFF202026)
                : colors.border.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isOled ? Colors.white60 : colors.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDesktopGrid(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isOled,
  ) {
    final colors = context.themeColors;
    final year = widget.currentMonth.year;
    final month = widget.currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Monday
    final leadingBlanks = firstWeekday - 1;
    final totalCells = math.max(
      35,
      ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7,
    );
    final rowCount = totalCells ~/ 7;
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, gridConstraints) {
        const double horizontalPadding = 8.0;
        const double verticalPadding = 8.0;
        const double spacing = 4.0;
        final totalSpacingH = (7 - 1) * spacing;
        final totalSpacingV = (rowCount - 1) * spacing;

        final availableW =
            gridConstraints.maxWidth - horizontalPadding - totalSpacingH;
        final availableH =
            gridConstraints.maxHeight - verticalPadding - totalSpacingV;

        final cellWidth = availableW / 7;
        final cellHeight = math.max(68.0, availableH / rowCount);
        final computedAspectRatio = cellWidth / cellHeight;

        return GridView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: computedAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return Container(
                decoration: BoxDecoration(
                  color: isOled
                      ? Colors.black
                      : colors.surface.withValues(alpha: isDark ? 0.2 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOled
                        ? const Color(0xFF18181E)
                        : colors.border.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
              );
            }

            final cellDate = DateTime(year, month, dayNumber);
            final isToday =
                now.year == year && now.month == month && now.day == dayNumber;
            final daySchedules = _getSchedulesForDay(cellDate);

            return Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _openDayModal(context, cellDate, daySchedules),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isOled
                        ? Colors.black
                        : (isToday
                              ? colors.accent.withValues(alpha: 0.10)
                              : colors.surface.withValues(
                                  alpha: isDark ? 0.35 : 0.15,
                                )),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? colors.accent
                          : (isOled
                                ? const Color(0xFF26262E)
                                : colors.border.withValues(alpha: 0.65)),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Day number and count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: isToday
                                ? const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  )
                                : EdgeInsets.zero,
                            decoration: isToday
                                ? BoxDecoration(
                                    color: isOled
                                        ? const Color(0xFF141418)
                                        : colors.accent.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(4),
                                    border: isOled
                                        ? Border.all(
                                            color: colors.accent,
                                            width: 0.8,
                                          )
                                        : null,
                                  )
                                : null,
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: isToday
                                    ? colors.accent
                                    : (isOled
                                          ? Colors.white
                                          : colors.textPrimary),
                              ),
                            ),
                          ),
                          if (daySchedules.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isOled
                                    ? const Color(0xFF141418)
                                    : (isToday
                                          ? colors.accent.withValues(
                                              alpha: 0.18,
                                            )
                                          : colors.surfaceElevated.withValues(
                                              alpha: 0.75,
                                            )),
                                borderRadius: BorderRadius.circular(6),
                                border: isOled
                                    ? Border.all(
                                        color: const Color(0xFF22222A),
                                        width: 0.8,
                                      )
                                    : null,
                              ),
                              child: Text(
                                '${daySchedules.length}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isToday
                                      ? colors.accent
                                      : (isOled
                                            ? Colors.white70
                                            : colors.textSecondary),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Anime Title Items with Hero
                      Expanded(
                        child: daySchedules.isEmpty
                            ? const SizedBox.shrink()
                            : LayoutBuilder(
                                builder: (context, boxConstraints) {
                                  const itemHeight = 22.0;
                                  const itemGap = 2.0;
                                  const badgeHeight = 16.0;

                                  int maxVisible =
                                      (boxConstraints.maxHeight /
                                              (itemHeight + itemGap))
                                          .floor();
                                  if (daySchedules.length > maxVisible) {
                                    maxVisible =
                                        ((boxConstraints.maxHeight -
                                                    badgeHeight) /
                                                (itemHeight + itemGap))
                                            .floor();
                                  }
                                  maxVisible = math.max(0, maxVisible);
                                  final visibleItems = daySchedules
                                      .take(maxVisible)
                                      .toList();
                                  final remaining =
                                      daySchedules.length - visibleItems.length;

                                  return ClipRect(
                                    child: SingleChildScrollView(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final item in visibleItems) ...[
                                            _AiringTitleHoverItem(
                                              item: item,
                                              title: _resolveTitle(item),
                                              titleLang: widget.titleLang,
                                              isOled: isOled,
                                              onOpenDayModal: () =>
                                                  _openDayModal(
                                                    context,
                                                    cellDate,
                                                    daySchedules,
                                                  ),
                                            ),
                                            const SizedBox(height: itemGap),
                                          ],
                                          if (remaining > 0)
                                            InkWell(
                                              onTap: () => _openDayModal(
                                                context,
                                                cellDate,
                                                daySchedules,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 1,
                                                  left: 2,
                                                ),
                                                child: Text(
                                                  '+$remaining ${widget.l10n.anime}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isOled
                                                        ? Colors.white60
                                                        : colors.accent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isOled,
  ) {
    final colors = context.themeColors;
    final year = widget.currentMonth.year;
    final month = widget.currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;
    final totalCells = math.max(
      35,
      ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7,
    );
    final now = DateTime.now();

    final selectedDaySchedules = _getSchedulesForDay(_selectedDay);

    return Column(
      children: [
        // Compact calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.35,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox();
            }

            final cellDate = DateTime(year, month, dayNumber);
            final isToday =
                now.year == year && now.month == month && now.day == dayNumber;
            final isSelected =
                _selectedDay.year == year &&
                _selectedDay.month == month &&
                _selectedDay.day == dayNumber;
            final daySchedules = _getSchedulesForDay(cellDate);

            return InkWell(
              onTap: () => setState(() => _selectedDay = cellDate),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isOled
                            ? const Color(0xFF141418)
                            : colors.accent.withValues(alpha: 0.18))
                      : (isToday
                            ? (isOled
                                  ? Colors.black
                                  : colors.accent.withValues(alpha: 0.10))
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? colors.accent
                        : (isToday
                              ? colors.accent
                              : (isOled
                                    ? const Color(0xFF26262E)
                                    : colors.border.withValues(alpha: 0.5))),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected || isToday
                            ? colors.accent
                            : (isOled ? Colors.white : colors.textPrimary),
                      ),
                    ),
                    if (daySchedules.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected || isToday
                              ? colors.accent.withValues(alpha: 0.20)
                              : (isOled
                                    ? const Color(0xFF141418)
                                    : colors.surfaceElevated),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${daySchedules.length}',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected || isToday
                                ? colors.accent
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        Divider(
          height: 8,
          color: isOled
              ? const Color(0xFF202026)
              : colors.border.withValues(alpha: 0.5),
        ),

        // Selected day episodes header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Text(
                _formatFullDate(_selectedDay),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${selectedDaySchedules.length} ${widget.l10n.anime}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Selected day episodes list with full titles
        Expanded(
          child: selectedDaySchedules.isEmpty
              ? Center(
                  child: Text(
                    widget.l10n.noAiringToday,
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  itemCount: selectedDaySchedules.length,
                  itemBuilder: (context, index) {
                    final item = selectedDaySchedules[index];
                    return CalendarEpisodeCard(
                      schedule: item,
                      titleLang: widget.titleLang,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Snapshot of the poster drawn while a month title is hovered.
class _CalendarCoverPreviewData {
  final Object owner;

  /// Global rect of the hovered title, used to anchor the poster.
  final Rect anchor;
  final String? coverUrl;
  final bool isOled;

  /// Opens the anime's details when the poster itself is clicked.
  final VoidCallback onOpen;

  const _CalendarCoverPreviewData({
    required this.owner,
    required this.anchor,
    required this.coverUrl,
    required this.isOled,
    required this.onOpen,
  });
}

/// Owns the single cover preview shown above the month grid.
///
/// The poster used to be an `OverlayEntry` inserted into the *root* overlay,
/// which put it above every route: opening a day or a detail page while it was
/// visible left it floating over the whole app. It is now rendered inside the
/// month view's own stack, so it cannot outlive the calendar page.
class _CalendarCoverPreview {
  static const double width = 160;
  static const double height = 240;
  static const double gap = 10;

  static final ValueNotifier<_CalendarCoverPreviewData?> notifier =
      ValueNotifier<_CalendarCoverPreviewData?>(null);

  static Timer? _hideTimer;

  static void show(_CalendarCoverPreviewData data) {
    cancelHide();
    notifier.value = data;
  }

  /// Keeps the poster alive while the pointer travels from the title to it.
  static void cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  /// Dismisses the poster soon unless the pointer enters the poster itself.
  static void hideAfterDelay([Object? owner]) {
    final current = notifier.value;
    if (current == null) return;
    if (owner != null && !identical(owner, current.owner)) return;
    cancelHide();
    _hideTimer = Timer(const Duration(milliseconds: 180), () {
      _hideTimer = null;
      notifier.value = null;
    });
  }

  static void hide([Object? owner]) {
    final current = notifier.value;
    if (current == null) {
      cancelHide();
      return;
    }
    if (owner != null && !identical(owner, current.owner)) return;
    cancelHide();
    notifier.value = null;
  }

  static bool isOwnedBy(Object owner) =>
      identical(notifier.value?.owner, owner);
}

/// Anime Title item in the month view cell.
class _AiringTitleHoverItem extends StatefulWidget {
  final AiringScheduleItem item;
  final String title;
  final TitleLanguage titleLang;
  final bool isOled;
  final VoidCallback onOpenDayModal;

  const _AiringTitleHoverItem({
    required this.item,
    required this.title,
    required this.titleLang,
    required this.isOled,
    required this.onOpenDayModal,
  });

  @override
  State<_AiringTitleHoverItem> createState() => _AiringTitleHoverItemState();
}

class _AiringTitleHoverItemState extends State<_AiringTitleHoverItem> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _isHovered = false;

  @override
  void dispose() {
    if (_CalendarCoverPreview.isOwnedBy(this)) {
      // The grid may dispose this item while a page is being rebuilt; notify
      // after the current frame to avoid rebuilding the month view mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _CalendarCoverPreview.hide(this);
      });
    }
    super.dispose();
  }

  void _hidePreview() {
    _CalendarCoverPreview.hide(this);
  }

  void _showPreview() {
    final anchorBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.attached || !anchorBox.hasSize) {
      return;
    }

    _CalendarCoverPreview.show(
      _CalendarCoverPreviewData(
        owner: this,
        anchor: anchorBox.localToGlobal(Offset.zero) & anchorBox.size,
        coverUrl: widget.item.media.coverImage,
        isOled: widget.isOled,
        onOpen: () {
          AnimeDetailScreen.navigate(
            context,
            mediaId: widget.item.media.mediaId,
            initialEntry: widget.item.media,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final anime = widget.item.media;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _showPreview();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _CalendarCoverPreview.hideAfterDelay(this);
      },
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) => _hidePreview(),
        child: ShowQuickViewDetector(
          heroTag: 'quick_prev_${widget.item.id}_${anime.mediaId}',
          hoverDelay: const Duration(
            days: 365,
          ), // Disables idle auto-popup so only right-click triggers it!
          dataBuilder: () => ShowPreviewData.fromAnime(anime, widget.titleLang),
          onOpenDetails: () {
            AnimeDetailScreen.navigate(
              context,
              mediaId: anime.mediaId,
              initialEntry: anime,
            );
          },
          child: InkWell(
            key: _anchorKey,
            onTap: () {
              _hidePreview();
              AnimeDetailScreen.navigate(
                context,
                mediaId: anime.mediaId,
                initialEntry: anime,
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      _formatTime(widget.item.airingAt),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: _isHovered
                            ? colors.accent
                            : (widget.isOled
                                  ? Colors.white.withValues(alpha: 0.56)
                                  : colors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        height: 1.1,
                        color: _isHovered
                            ? colors.accent
                            : (widget.isOled
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : colors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
