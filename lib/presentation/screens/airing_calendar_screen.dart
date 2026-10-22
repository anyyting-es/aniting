import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_desktop_view.dart';
import 'package:seanime_app/presentation/widgets/calendar/calendar_mobile_view.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';

class AiringCalendarScreen extends ConsumerStatefulWidget {
  const AiringCalendarScreen({super.key});

  @override
  ConsumerState<AiringCalendarScreen> createState() => _AiringCalendarScreenState();
}

class _AiringCalendarScreenState extends ConsumerState<AiringCalendarScreen> {
  int _selectedDayIndex = 0;
  List<AiringScheduleItem> _allSchedules = [];
  bool _isLoading = true;
  bool _onlyWatching = false;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
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

  List<DateTime> _getWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final layoutPref = ref.watch(layoutModeProvider);
    final resolvedMode = LayoutModeNotifier.resolve(context, layoutPref);
    final days = _getWeekDays();
    final canPop = Navigator.canPop(context);

    final animeCollection = ref.watch(animeCollectionProvider).asData?.value ?? [];
    final watchingMediaIds = animeCollection
        .where((e) =>
            e.status.toUpperCase() == 'CURRENT' ||
            e.status.toUpperCase() == 'WATCHING' ||
            e.status.toUpperCase() == 'REPEATING')
        .map((e) => e.mediaId)
        .toSet();

    final displayedSchedules = _onlyWatching
        ? _allSchedules
            .where((s) =>
                watchingMediaIds.contains(s.media.mediaId) ||
                watchingMediaIds.contains(s.media.id))
            .toList()
        : _allSchedules;

    return Scaffold(
      appBar: DesktopSafeAppBar(
        child: AppBar(
          title: Text(l10n.airingCalendar),
          automaticallyImplyLeading: canPop,
          titleSpacing: canPop ? 0 : 16,
          actions: [
            FilterChip(
              avatar: Icon(
                _onlyWatching ? Icons.visibility_rounded : Icons.visibility_outlined,
                size: 15,
                color: _onlyWatching ? Colors.black : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(
                l10n.onlyWatching,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _onlyWatching ? FontWeight.bold : FontWeight.w500,
                  color: _onlyWatching ? Colors.black : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              selected: _onlyWatching,
              selectedColor: Colors.white,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _onlyWatching
                      ? Colors.white
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              onSelected: (val) => setState(() => _onlyWatching = val),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n.refresh,
              onPressed: _fetchSchedules,
            ),
            const SizedBox(width: 8),
          ],
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = resolvedMode == LayoutMode.desktop ||
              (resolvedMode == LayoutMode.auto && constraints.maxWidth >= 768);

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
