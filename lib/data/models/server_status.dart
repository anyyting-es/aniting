class ServerStatus {
  final String? version;
  final String? username;
  final String? avatarUrl;
  final bool isSettingsConfigured;
  final bool isSimulated;
  final String? anilistClientId;

  ServerStatus({
    this.version,
    this.username,
    this.avatarUrl,
    this.isSettingsConfigured = false,
    this.isSimulated = false,
    this.anilistClientId,
  });

  bool get isLoggedIn => !isSimulated && username != null && username != 'User' && username!.isNotEmpty;

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    final user = data['user'] as Map<String, dynamic>?;
    final viewer = user?['viewer'] as Map<String, dynamic>? ?? user;
    final avatar = viewer?['avatar'] as Map<String, dynamic>?;
    final isSimulated = user?['isSimulated'] as bool? ?? (user?['token'] == 'SIMULATED');

    return ServerStatus(
      version: data['version'] as String?,
      username: viewer?['name'] as String?,
      avatarUrl: avatar?['large'] as String? ?? avatar?['medium'] as String?,
      isSettingsConfigured: data['serverReady'] as bool? ?? data['isSettingsConfigured'] as bool? ?? true,
      isSimulated: isSimulated,
      anilistClientId: data['anilistClientId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'user': {
      'viewer': {
        'name': username,
        'avatar': {
          'large': avatarUrl,
        },
      },
      'isSimulated': isSimulated,
    },
    'isSettingsConfigured': isSettingsConfigured,
    'serverReady': isSettingsConfigured,
    'anilistClientId': anilistClientId,
  };
}
