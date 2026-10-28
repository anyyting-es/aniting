class DantotsuComment {
  final int commentId;
  final String userId;
  final int mediaId;
  final int? parentCommentId;
  final String content;
  final DateTime? timestamp;
  final int deleted;
  final int? tag;
  final int upvotes;
  final int downvotes;
  final int? userVoteType;
  final String username;
  final String? profilePictureUrl;
  final int isMod;
  final int isAdmin;
  final int replyCount;

  const DantotsuComment({
    required this.commentId,
    required this.userId,
    required this.mediaId,
    required this.parentCommentId,
    required this.content,
    required this.timestamp,
    required this.deleted,
    required this.tag,
    required this.upvotes,
    required this.downvotes,
    required this.userVoteType,
    required this.username,
    required this.profilePictureUrl,
    required this.isMod,
    required this.isAdmin,
    required this.replyCount,
  });

  factory DantotsuComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    final timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '');

    return DantotsuComment(
      commentId: _int(json['comment_id']),
      userId: (json['user_id'] ?? user['user_id'] ?? '').toString(),
      mediaId: _int(json['media_id']),
      parentCommentId: _nullableInt(json['parent_comment_id']),
      content: (json['content'] ?? '').toString(),
      timestamp: timestamp,
      deleted: _int(json['deleted']),
      tag: _nullableInt(json['tag']),
      upvotes: _int(json['upvotes']),
      downvotes: _int(json['downvotes']),
      userVoteType: _nullableInt(json['user_vote_type']),
      username: (json['username'] ?? user['username'] ?? '').toString(),
      profilePictureUrl:
          (json['profile_picture_url'] ?? user['profile_picture_url'])?.toString(),
      isMod: _int(json['is_mod']),
      isAdmin: _int(json['is_admin']),
      replyCount: _int(json['reply_count']),
    );
  }

  static int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    return value is num ? value.toInt() : int.tryParse('$value');
  }
}
