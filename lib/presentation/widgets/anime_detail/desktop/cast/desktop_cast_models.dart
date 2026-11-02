/// Models and parser helpers for the Desktop Characters & Cast subsystem.
library;

class DesktopCastItem {
  final dynamic id;
  final String name;
  final String? nativeName;
  final List<String> alternativeNames;
  final String role;
  final String? imageUrl;
  final String? bio;
  final String? gender;
  final String? age;
  final String? birthday;
  final String? bloodType;
  final String? vaName;
  final String? vaNativeName;
  final String? vaImageUrl;
  final String? vaLanguage;

  const DesktopCastItem({
    required this.id,
    required this.name,
    this.nativeName,
    this.alternativeNames = const [],
    required this.role,
    this.imageUrl,
    this.bio,
    this.gender,
    this.age,
    this.birthday,
    this.bloodType,
    this.vaName,
    this.vaNativeName,
    this.vaImageUrl,
    this.vaLanguage,
  });

  bool get isMain => role.toUpperCase() == 'MAIN';

  /// Determines whether a character edge or TMDB cast item has a valid, non-placeholder image.
  static bool hasValidImage(dynamic item, {required bool isTmdb}) {
    if (item == null) return false;
    String? url;
    if (isTmdb) {
      if (item is Map) {
        final profilePath = item['profile_path'] as String?;
        if (profilePath != null && profilePath.trim().isNotEmpty) {
          url = 'https://image.tmdb.org/t/p/w300$profilePath';
        }
      }
    } else {
      if (item is Map) {
        final node = item['node'] as Map?;
        final imageMap = node?['image'] as Map?;
        url = (imageMap?['large'] ?? imageMap?['medium'])?.toString();
      }
    }
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains('default.jpg') ||
        lower.contains('default.png') ||
        lower.contains('no_image') ||
        lower.contains('no-image') ||
        lower.contains('placeholder')) {
      return false;
    }
    return true;
  }

  /// Parses a character edge (AniList) or credit map (TMDB) into a normalized [DesktopCastItem].
  factory DesktopCastItem.fromEdge(
    dynamic item, {
    required bool isTmdb,
    required int index,
  }) {
    if (isTmdb) {
      final map = item is Map ? item : {};
      final id = map['id'] ?? map['cast_id'] ?? index;
      final name = (map['name'] ?? map['original_name'] ?? '') as String;
      final charName = (map['character'] as String?)?.trim();
      final profilePath = map['profile_path'] as String?;
      final imageUrl = profilePath != null && profilePath.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w300$profilePath'
          : null;
      final knownFor = map['known_for_department'] as String?;

      return DesktopCastItem(
        id: id,
        name: charName != null && charName.isNotEmpty ? charName : name,
        nativeName: null,
        role: charName != null && charName.isNotEmpty ? 'ACTOR' : 'CAST',
        imageUrl: imageUrl,
        bio: null,
        gender: map['gender'] == 1 ? 'Female' : (map['gender'] == 2 ? 'Male' : null),
        vaName: name,
        vaNativeName: null,
        vaImageUrl: imageUrl,
        vaLanguage: knownFor ?? 'Cast / Actor',
      );
    }

    final edge = item is Map ? item : {};
    final node = edge['node'] as Map?;
    final id = node?['id'] ?? edge['id'] ?? index;

    final nameMap = node?['name'] as Map?;
    final name = (nameMap?['userPreferred'] ?? nameMap?['full'] ?? '') as String;
    final nativeName = nameMap?['native']?.toString();
    final altList = (nameMap?['alternative'] as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final role = (edge['role'] as String?)?.toUpperCase() ?? 'SUPPORTING';

    final imageMap = node?['image'] as Map?;
    final imageUrl = (imageMap?['large'] ?? imageMap?['medium'])?.toString();

    final rawBio = node?['description']?.toString();
    final bio = rawBio != null ? _cleanAniListBio(rawBio) : null;

    final gender = node?['gender']?.toString();
    final age = node?['age']?.toString();
    final bloodType = node?['bloodType']?.toString();

    String? birthday;
    final dob = node?['dateOfBirth'] as Map?;
    if (dob != null) {
      final day = dob['day'];
      final month = dob['month'];
      final year = dob['year'];
      if (day != null && month != null) {
        final months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        final mStr = (month is int && month >= 1 && month <= 12) ? months[month] : '$month';
        birthday = year != null ? '$day $mStr $year' : '$day $mStr';
      }
    }

    // Voice actors
    String? vaName;
    String? vaNativeName;
    String? vaImageUrl;
    String? vaLanguage;

    final voiceActors = edge['voiceActors'] as List?;
    if (voiceActors != null && voiceActors.isNotEmpty) {
      final firstVa = voiceActors.first;
      if (firstVa is Map) {
        final vaNameMap = firstVa['name'];
        if (vaNameMap is Map) {
          vaName = (vaNameMap['userPreferred'] ?? vaNameMap['full'])?.toString();
          vaNativeName = vaNameMap['native']?.toString();
        }
        final vaImgMap = firstVa['image'];
        if (vaImgMap is Map) {
          vaImageUrl = (vaImgMap['large'] ?? vaImgMap['medium'])?.toString();
        }
        vaLanguage = firstVa['languageV2']?.toString() ?? 'Japanese';
      }
    }

    return DesktopCastItem(
      id: id,
      name: name,
      nativeName: nativeName,
      alternativeNames: altList,
      role: role,
      imageUrl: imageUrl,
      bio: bio,
      gender: gender,
      age: age,
      birthday: birthday,
      bloodType: bloodType,
      vaName: vaName,
      vaNativeName: vaNativeName,
      vaImageUrl: vaImageUrl,
      vaLanguage: vaLanguage,
    );
  }

  DesktopCastItem copyWith({
    dynamic id,
    String? name,
    String? nativeName,
    List<String>? alternativeNames,
    String? role,
    String? imageUrl,
    String? bio,
    String? gender,
    String? age,
    String? birthday,
    String? bloodType,
    String? vaName,
    String? vaNativeName,
    String? vaImageUrl,
    String? vaLanguage,
  }) {
    return DesktopCastItem(
      id: id ?? this.id,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      alternativeNames: alternativeNames ?? this.alternativeNames,
      role: role ?? this.role,
      imageUrl: imageUrl ?? this.imageUrl,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      birthday: birthday ?? this.birthday,
      bloodType: bloodType ?? this.bloodType,
      vaName: vaName ?? this.vaName,
      vaNativeName: vaNativeName ?? this.vaNativeName,
      vaImageUrl: vaImageUrl ?? this.vaImageUrl,
      vaLanguage: vaLanguage ?? this.vaLanguage,
    );
  }

  static String _cleanAniListBio(String raw) {
    var text = raw;
    // Replace spoilers ~!text!~ with text
    text = text.replaceAll('~!', '').replaceAll('!~', '');
    // Clean html tags
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</?[a-zA-Z0-9]+[^>]*>'), '');
    // Clean markdown links [Title](url) -> Title
    text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '');
    // Clean repetitive newlines
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
