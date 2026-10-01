import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

class AiringCalendarScreen extends ConsumerStatefulWidget {
  const AiringCalendarScreen({super.key});

  @override
  ConsumerState<AiringCalendarScreen> createState() => _AiringCalendarScreenState();
}

class _AiringCalendarScreenState extends ConsumerState<AiringCalendarScreen> {
  int _selectedDayIndex = 0;
  List<AiringScheduleItem> _allSchedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    final serverState = ref.read(serverNotifierProvider);
    if (!serverState.isOnline) {
      setState(() {
        _allSchedules = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = startTimestamp + (7 * 86400);

    final repo = ref.read(repositoryProvider);
    final schedules = await repo.getAiringSchedule(
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      perPage: 50,
    );

    if (mounted) {
      setState(() {
        _allSchedules = schedules;
        _isLoading = false;
      });
    }
  }

  List<DateTime> _getWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  List<AiringScheduleItem> _getSchedulesForDay(DateTime day) {
    final start = day.millisecondsSinceEpoch ~/ 1000;
    final end = start + 86400;
    return _allSchedules.where((s) => s.airingAt >= start && s.airingAt < end).toList()
      ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('HH:mm').format(date);
  }

  String _timeRemaining(int timestamp, AppTranslations l10n) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = timestamp - now;
    if (diff <= 0) return 'Emitido';
    final hours = diff ~/ 3600;
    final mins = (diff % 3600) ~/ 60;
    if (hours > 24) {
      final days = hours ~/ 24;
      return 'en $days d';
    } else if (hours > 0) {
      return 'en ${hours}h ${mins}m';
    } else {
      return 'en ${mins}m';
    }
  }

  String _formatWeekday(DateTime day, bool isSpanish) {
    const esDays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    const enDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final idx = (day.weekday - 1).clamp(0, 6);
    return isSpanish ? esDays[idx] : enDays[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final days = _getWeekDays();
    final currentDay = days[_selectedDayIndex];
    final daySchedules = _getSchedulesForDay(currentDay);

    final canPop = Navigator.canPop(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.airingCalendar),
        automaticallyImplyLeading: canPop,
        titleSpacing: canPop ? 0 : 16,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: _fetchSchedules,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Horizontal Day Selector (Respects theme and OLED pure black)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final isSelected = index == _selectedDayIndex;
                final isToday = index == 0;
                final weekdayName = _formatWeekday(day, isSpanish);
                final dayNum = day.day.toString();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isToday ? l10n.today : weekdayName,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : theme.colorScheme.primary)
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.white : theme.colorScheme.primary)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 4 : 0,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Content List (Unboxed, clean typography)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : daySchedules.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 48,
                              color: theme.colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noAiringToday,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchSchedules,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                          itemCount: daySchedules.length,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                          itemBuilder: (context, index) {
                            final item = daySchedules[index];
                            final anime = item.media;
                            final title = anime.displayTitle(titleLang);
                            final timeStr = _formatTime(item.airingAt);
                            final remaining = _timeRemaining(item.airingAt, l10n);

                            return InkWell(
                              onTap: () {
                                AnimeDetailScreen.navigate(
                                  context,
                                  mediaId: anime.mediaId,
                                  initialEntry: anime,
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                child: Row(
                                  children: [
                                    // Poster
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 52,
                                        height: 74,
                                        child: anime.coverImage != null
                                            ? CachedNetworkImage(
                                                memCacheWidth: 130,
                                                memCacheHeight: 185,
                                                maxWidthDiskCache: 210,
                                                maxHeightDiskCache: 300,
                                                imageUrl: anime.coverImage!,
                                                fit: BoxFit.cover,
                                                errorWidget: (context, url, error) => Container(
                                                  color: isDark
                                                      ? const Color(0xFF1E2228)
                                                      : theme.colorScheme.surfaceContainerHighest,
                                                ),
                                              )
                                            : Container(
                                                color: isDark
                                                    ? const Color(0xFF1E2228)
                                                    : theme.colorScheme.surfaceContainerHighest,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Details (Clean, unboxed typography)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              height: 1.25,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                'Ep. ${item.episode}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  '•',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white30 : theme.colorScheme.outlineVariant,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  '•',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white30 : theme.colorScheme.outlineVariant,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                remaining,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: remaining == 'Emitido'
                                                      ? (isDark ? Colors.white54 : theme.colorScheme.outline)
                                                      : (isDark ? const Color(0xFF68D391) : Colors.green.shade700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
