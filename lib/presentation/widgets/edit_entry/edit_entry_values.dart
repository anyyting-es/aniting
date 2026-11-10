
/// Estado y utilidades de valores compartidos por el modal de edición
/// ([EditEntryModal]) y el panel lateral glass del preview
/// ([EditEntryStatusPanel]).
mixin EditEntryValues {
  late String status;
  late double score;
  late int progress;
  late int repeat;
  DateTime? startDate;
  DateTime? completionDate;
  bool loadingInitialData = false;

  bool _initialized = false;

  /// Inicializa los valores de edición. Solo tiene efecto la primera vez.
  void initEditValues({
    String? initialStatus,
    double? initialScore,
    int? initialProgress,
    int? initialRepeat,
    String? initialStartedAt,
    String? initialCompletedAt,
  }) {
    if (_initialized) return;
    _initialized = true;

    status = normalizeStatus(initialStatus);

    if (initialScore != null && initialScore > 0) {
      score = (initialScore > 10.0 ? initialScore / 10.0 : initialScore).clamp(0.0, 10.0);
    } else {
      score = 0.0;
    }

    progress = initialProgress ?? 0;
    repeat = initialRepeat ?? 0;
    startDate = parseDate(initialStartedAt);
    completionDate = parseDate(initialCompletedAt);
  }

  /// Aplica los datos más recientes consultados a AniList sobre el estado local.
  void applyFetchedListData(Map listData) {
    if (listData['status'] is String) {
      status = normalizeStatus(listData['status'] as String);
    }
    if (listData['progress'] is num) {
      progress = (listData['progress'] as num).toInt();
    }
    if (listData['score'] is num) {
      final s = (listData['score'] as num).toDouble();
      score = (s > 10.0 ? s / 10.0 : s).clamp(0.0, 10.0);
    }
    if (listData['repeat'] is num) {
      repeat = (listData['repeat'] as num).toInt();
    }
    if (listData['startedAt'] is Map) {
      final parsed = parseDateFromMap(listData['startedAt'] as Map);
      if (parsed != null) startDate = parsed;
    }
    if (listData['completedAt'] is Map) {
      final parsed = parseDateFromMap(listData['completedAt'] as Map);
      if (parsed != null) completionDate = parsed;
    }
  }

  String normalizeStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'CURRENT';
    final upper = raw.toUpperCase().trim();
    const valid = ['CURRENT', 'PLANNING', 'COMPLETED', 'REPEATING', 'PAUSED', 'DROPPED'];
    if (valid.contains(upper)) return upper;
    if (upper == 'WATCHING' || upper == 'READING') return 'CURRENT';
    return 'CURRENT';
  }

  DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? parseDateFromMap(Map data) {
    try {
      final y = data['year'] as int?;
      final m = data['month'] as int?;
      final d = data['day'] as int?;
      if (y != null && y > 0 && m != null && m > 0 && d != null && d > 0) {
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  String? formatDate(DateTime? d) {
    if (d == null) return null;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
