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
          // Horizontal Day Selector
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
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
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isToday ? l10n.today : weekdayName,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
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

          // Content List
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
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                          itemCount: daySchedules.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
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
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                                  ),
                                ),
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
                                                memCacheWidth: 130, memCacheHeight: 185, maxWidthDiskCache: 210, maxHeightDiskCache: 300,
                                                imageUrl: anime.coverImage!,
                                                fit: BoxFit.cover,
                                                errorWidget: (context, url, error) => Container(
                                                  color: theme.colorScheme.surfaceContainerHighest,
                                                ),
                                              )
                                            : Container(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              // Episode Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Ep. ${item.episode}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme.onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Airing time
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 13,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                remaining,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, size: 20),
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
