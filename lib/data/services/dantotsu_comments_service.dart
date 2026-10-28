import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/dantotsu_comment.dart';

class DantotsuCommentsPage {
  final List<DantotsuComment> comments;
  final int totalPages;

  const DantotsuCommentsPage({
    required this.comments,
    required this.totalPages,
  });
}

class DantotsuCommentsService {
  final ApiClient _apiClient;

  DantotsuCommentsService(this._apiClient);

  Future<DantotsuCommentsPage> getComments({
    required int mediaId,
    int page = 1,
    int? episode,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/dantotsu/comments/$mediaId/$page',
      queryParameters: {
        if (episode != null && episode > 0) 'tag': episode,
        'sort': 'newest',
      },
    );
    final rawResponse = response.data;
    final data = rawResponse?['data'] is Map
        ? Map<String, dynamic>.from(rawResponse!['data'] as Map)
        : rawResponse;
    if (data == null) {
      return const DantotsuCommentsPage(comments: [], totalPages: 1);
    }

    final rawComments = data['comments'];
    if (rawComments is! List) {
      // No comment thread yet: the backend may omit the list entirely.
      return const DantotsuCommentsPage(comments: [], totalPages: 1);
    }

    return DantotsuCommentsPage(
      comments: rawComments
          .whereType<Map>()
          .map(
            (comment) =>
                DantotsuComment.fromJson(Map<String, dynamic>.from(comment)),
          )
          .toList(growable: false),
      totalPages: data['totalPages'] is num
          ? (data['totalPages'] as num).toInt()
          : page,
    );
  }

  Future<void> postComment({
    required int mediaId,
    required String content,
    int? episode,
    int? parentCommentId,
  }) async {
    await _apiClient.post(
      '/dantotsu/comments',
      data: {
        'mediaId': mediaId,
        'content': content,
        ...?episode != null && episode > 0 ? {'tag': episode} : null,
        ...?parentCommentId != null
            ? {'parentCommentId': parentCommentId}
            : null,
      },
    );
  }

  Future<void> vote({required int commentId, required int voteType}) async {
    await _apiClient.post('/dantotsu/comments/vote/$commentId/$voteType');
  }

  /// Uploads an image to a public host (catbox.moe) and returns its URL, since
  /// Dantotsu comments render images from external URLs.
  Future<String> uploadImage(
    Uint8List bytes, {
    String filename = 'frame.jpg',
  }) async {
    final form = FormData.fromMap({
      'reqtype': 'fileupload',
      'fileToUpload': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _apiClient.post<String>(
      'https://catbox.moe/user/api.php',
      data: form,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': 'Aniting/1.0 (Flutter)'},
      ),
    );
    final url = (response.data ?? '').trim();
    if (!url.startsWith('http')) {
      throw const FormatException('Image upload failed');
    }
    return url;
  }
}
