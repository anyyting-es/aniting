/// Representación de un archivo multimedia local indexado por el backend de Seanime.
class LocalFileItem {
  final String path;
  final String name;
  final int mediaId;
  final bool locked;
  final bool ignored;
  final String? parsedTitle;
  final String? parsedEpisode;
  final String? parsedSeason;
  final String folderPath;
  final String folderName;

  const LocalFileItem({
    required this.path,
    required this.name,
    required this.mediaId,
    this.locked = false,
    this.ignored = false,
    this.parsedTitle,
    this.parsedEpisode,
    this.parsedSeason,
    required this.folderPath,
    required this.folderName,
  });

  bool get isMatched => mediaId > 0;
  bool get isUnmatched => mediaId == 0 && !ignored;

  String get fileExtension {
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return '';
  }

  factory LocalFileItem.fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String? ?? '';
    final name = json['name'] as String? ?? (path.isNotEmpty ? path.split(RegExp(r'[/\\]')).last : '');

    // Extract directory path and folder name
    String folderPath = '';
    String folderName = '';
    final sepIndex = path.lastIndexOf(RegExp(r'[/\\]'));
    if (sepIndex != -1) {
      folderPath = path.substring(0, sepIndex);
      final prevSep = folderPath.lastIndexOf(RegExp(r'[/\\]'));
      folderName = prevSep != -1 ? folderPath.substring(prevSep + 1) : folderPath;
    }

    final parsedInfo = json['parsedInfo'] as Map<String, dynamic>?;
    final parsedTitle = parsedInfo?['title'] as String?;
    final parsedEpisode = parsedInfo?['episode'] as String?;
    final parsedSeason = parsedInfo?['season'] as String?;

    return LocalFileItem(
      path: path,
      name: name,
      mediaId: json['mediaId'] as int? ?? 0,
      locked: json['locked'] as bool? ?? false,
      ignored: json['ignored'] as bool? ?? false,
      parsedTitle: parsedTitle != null && parsedTitle.trim().isNotEmpty ? parsedTitle.trim() : null,
      parsedEpisode: parsedEpisode,
      parsedSeason: parsedSeason,
      folderPath: folderPath,
      folderName: folderName.isNotEmpty ? folderName : (parsedTitle ?? 'Anime'),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'mediaId': mediaId,
    'locked': locked,
    'ignored': ignored,
    'folderPath': folderPath,
    'folderName': folderName,
    if (parsedTitle != null) 'parsedTitle': parsedTitle,
    if (parsedEpisode != null) 'parsedEpisode': parsedEpisode,
  };
}

/// Agrupación de archivos locales sin emparejar pertenecientes a la misma carpeta
class UnmatchedFolderGroup {
  final String folderPath;
  final String folderName;
  final String guessedTitle;
  final List<LocalFileItem> files;

  const UnmatchedFolderGroup({
    required this.folderPath,
    required this.folderName,
    required this.guessedTitle,
    required this.files,
  });

  int get count => files.length;
}
