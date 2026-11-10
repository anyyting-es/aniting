import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/layout_mode_provider.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/data/models/airing_schedule.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/calendar/calendar_desktop_view.dart';
import 'package:aniting/presentation/widgets/calendar/calendar_loading_line.dart';
import 'package:aniting/presentation/widgets/calendar/calendar_mobile_view.dart';
import 'package:aniting/presentation/widgets/calendar/calendar_month_view.dart';
import 'package:aniting/presentation/widgets/calendar/calendar_only_watching_toggle.dart';
import 'package:aniting/presentation/widgets/desktop_title_bar.dart';

enum AiringCalendarViewMode { week, month }

class AiringCalendarScreen extends ConsumerStatefulWidget {
  const AiringCalendarScreen({super.key});

  @override
  ConsumerState<AiringCalendarScreen> createState() => _AiringCalendarScreenState();
}

class _AiringCalendarScreenState extends ConsumerState<AiringCalendarScreen> {
  int _selectedDayIndex = 0;
  List<AiringScheduleItem> _allSchedules = [];
  List<AiringScheduleItem> _monthSchedules = [];
  bool _isLoading = true;
  bool _onlyWatching = true; // Marked by default as requested
  AiringCalendarViewMode _viewMode = AiringCalendarViewMode.week;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _fetchSchedules();
    _fetchMonthSchedules(_currentMonth);
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = startTimestamp + (7 * 86400);

    try {
      final repo = ref.read(repositoryProvider);
      final schedules = await repo.getAiringSchedule(
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
        perPage: 50,
        maxItems: 250,
      );

      if (mounted) {
        setState(() {
          _allSchedules = schedules;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMonthSchedules(DateTime month) async {
    setState(() {
      _currentMonth = DateTime(month.year, month.month, 1);
      _isLoading = true;
    });

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final startTimestamp = startOfMonth.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endOfMonth.millisecondsSinceEpoch ~/ 1000;

    try {
      final repo = ref.read(repositoryProvider);
      final schedules = await repo.getAiringSchedule(
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
        perPage: 50,
        maxItems: 400,
      );

      if (mounted) {
        setState(() {
          _monthSchedules = schedules;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DateTime> _getWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final layoutPref = ref.watch(layoutModeProvider);
    final resolvedMode = LayoutModeNotifier.resolve(context, layoutPref);
    final days = _getWeekDays();
    final canPop = Navigator.canPop(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactHeader = screenWidth < 520;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final animeCollection = ref.watch(animeCollectionProvider).asData?.value ?? [];
    final watchingMediaIds = animeCollection
        .where((e) =>
            e.status.toUpperCase() == 'CURRENT' ||
            e.status.toUpperCase() == 'WATCHING' ||
            e.status.toUpperCase() == 'REPEATING')
        .map((e) => e.mediaId)
        .toSet();

    final sourceSchedules = _viewMode == AiringCalendarViewMode.month
        ? _monthSchedules
        : _allSchedules;

    final displayedSchedules = _onlyWatching
        ? sourceSchedules
            .where((s) =>
                watchingMediaIds.contains(s.media.mediaId) ||
                watchingMediaIds.contains(s.media.id))
            .toList()
        : sourceSchedules;

    return Scaffold(
      appBar: DesktopSafeAppBar(
        child: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            l10n.airingCalendar,
            style: TextStyle(
              fontSize: compactHeader ? 17 : 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          automaticallyImplyLeading: canPop,
          titleSpacing: canPop ? 0 : 16,
          actions: [
            // View Mode Toggle (Semana / Mes)
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModePill(
                    icon: Icons.view_week_rounded,
                    label: l10n.calendarWeekView,
                    showLabel: !compactHeader,
                    isSelected: _viewMode == AiringCalendarViewMode.week,
                    onTap: () {
                      if (_viewMode != AiringCalendarViewMode.week) {
                        setState(() => _viewMode = AiringCalendarViewMode.week);
                        if (_allSchedules.isEmpty) _fetchSchedules();
                      }
                    },
                  ),
                  _ModePill(
                    icon: Icons.calendar_month_rounded,
                    label: l10n.calendarMonthView,
                    showLabel: !compactHeader,
                    isSelected: _viewMode == AiringCalendarViewMode.month,
                    onTap: () {
                      if (_viewMode != AiringCalendarViewMode.month) {
                        setState(() => _viewMode = AiringCalendarViewMode.month);
                        if (_monthSchedules.isEmpty) {
                          _fetchMonthSchedules(_currentMonth);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Only watching toggle
            CalendarOnlyWatchingToggle(
              value: _onlyWatching,
              label: l10n.onlyWatching,
              showLabel: !compactHeader,
              onChanged: (val) => setState(() => _onlyWatching = val),
            ),
            SizedBox(width: compactHeader ? 12 : 20),
          ],
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: CalendarLoadingLine(),
                )
              : null,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = resolvedMode == LayoutMode.desktop ||
              (resolvedMode == LayoutMode.auto && constraints.maxWidth >= 768);

          if (_viewMode == AiringCalendarViewMode.month) {
            return CalendarMonthView(
              currentMonth: _currentMonth,
              onMonthChanged: _fetchMonthSchedules,
              allSchedules: displayedSchedules,
              titleLang: titleLang,
              l10n: l10n,
              isSpanish: isSpanish,
            );
          }

          if (isDesktop) {
            return CalendarDesktopView(
              days: days,
              selectedIndex: _selectedDayIndex,
              onDaySelected: (idx) => setState(() => _selectedDayIndex = idx),
              allSchedules: displayedSchedules,
              titleLang: titleLang,
              l10n: l10n,
              isSpanish: isSpanish,
            );
          }

          return CalendarMobileView(
            days: days,
            selectedIndex: _selectedDayIndex,
            onDaySelected: (idx) => setState(() => _selectedDayIndex = idx),
            allSchedules: displayedSchedules,
            titleLang: titleLang,
            l10n: l10n,
            isSpanish: isSpanish,
            onRefresh: _fetchSchedules,
          );
        },
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModePill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final foreground = isSelected
        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
        : (isDark ? Colors.white.withValues(alpha: 0.55) : theme.colorScheme.onSurfaceVariant);

    final pill = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 10 : 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : theme.colorScheme.surface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            if (showLabel) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (showLabel) return pill;
    return Tooltip(message: label, child: pill);
  }
}
