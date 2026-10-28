import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/anilist_auth_sheet.dart';
import 'package:seanime_app/data/models/dantotsu_comment.dart';
import 'package:seanime_app/data/services/dantotsu_comments_service.dart';

class PlayerChatPanel extends ConsumerStatefulWidget {
  final int? mediaId;
  final int? episodeNumber;
  final bool embedded;
  final ValueListenable<Duration>? positionNotifier;
  final Future<Uint8List?> Function()? captureFrame;

  const PlayerChatPanel({
    super.key,
    required this.mediaId,
    required this.episodeNumber,
    this.embedded = false,
    this.positionNotifier,
    this.captureFrame,
  });

  @override
  ConsumerState<PlayerChatPanel> createState() => _PlayerChatPanelState();
}

class _PlayerChatPanelState extends ConsumerState<PlayerChatPanel> {
  late final DantotsuCommentsService _service;
  final _scrollController = ScrollController();
  List<DantotsuComment> _comments = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _hasMorePages = false;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  DantotsuComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _service = DantotsuCommentsService(ref.read(apiClientProvider));
    _loadComments();
  }

  @override
  void didUpdateWidget(covariant PlayerChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.episodeNumber != widget.episodeNumber) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _errorSummary() {
    final raw = (_error ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return '';
    return raw.length > 200 ? '${raw.substring(0, 200)}…' : raw;
  }

  String _errorText(AppTranslations l10n) {
    final err = (_error ?? '').toLowerCase();
    final isNetwork = err.contains('socketexception') ||
        err.contains('connection error') ||
        err.contains('connectionerror') ||
        err.contains('timeout') ||
        err.contains('failed host lookup') ||
        err.contains('network is unreachable');
    return isNetwork ? l10n.chatNoConnection : l10n.chatServerError;
  }

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _insertText(String text) {
    final value = _commentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    _commentController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
    setState(() {});
  }

  void _insertTimestamp() {
    final position = widget.positionNotifier?.value ?? Duration.zero;
    _insertText('[${_formatTime(position)}] ');
  }

  Future<void> _insertFrame() async {
    final capture = widget.captureFrame;
    if (capture == null || _isUploadingImage) return;
    setState(() => _isUploadingImage = true);
    try {
      final bytes = await capture();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('no frame');
      }
      final url = await _service.uploadImage(bytes);
      if (!mounted) return;
      _insertText('$url ');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.read(translationsProvider).chatActionError}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _loadComments({bool refresh = false}) async {
    final mediaId = widget.mediaId;
    if (mediaId == null || mediaId <= 0) {
      if (mounted) {
        setState(() {
          _comments = const [];
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = refresh || _comments.isEmpty;
        _error = null;
        if (refresh) {
          _page = 1;
          _totalPages = 1;
          _hasMorePages = false;
        }
      });
    }

    try {
      final result = await _service.getComments(
        mediaId: mediaId,
        page: 1,
        episode: widget.episodeNumber,
      );
      if (!mounted) return;
      setState(() {
        _comments = result.comments;
        _page = 1;
        _totalPages = result.totalPages;
        _hasMorePages = result.comments.isNotEmpty && result.totalPages > 1;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore ||
        !_hasMorePages ||
        _page >= _totalPages ||
        widget.mediaId == null) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.getComments(
        mediaId: widget.mediaId!,
        page: _page + 1,
        episode: widget.episodeNumber,
      );
      if (!mounted) return;
      setState(() {
        if (result.comments.isNotEmpty) {
          _comments = [..._comments, ...result.comments];
          _page++;
        }
        _totalPages = result.totalPages;
        _hasMorePages = result.comments.isNotEmpty && _page < result.totalPages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMorePages = false;
        });
      }
    }
  }

  Future<void> _openLogin() async {
    await AnilistAuthSheet.show(context);
    if (mounted) {
      await _loadComments(refresh: true);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || widget.mediaId == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _service.postComment(
        mediaId: widget.mediaId!,
        content: content,
        episode: widget.episodeNumber,
        parentCommentId: _replyingTo?.commentId,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() => _replyingTo = null);
      await _loadComments(refresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.read(translationsProvider).chatActionError}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _vote(DantotsuComment comment, int voteType) async {
    try {
      await _service.vote(commentId: comment.commentId, voteType: voteType);
      await _loadComments(refresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.read(translationsProvider).chatActionError}: $error',
          ),
        ),
      );
    }
  }

  Widget _composerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
        ),
      ),
    );
  }

  Widget _buildComposer(AppTranslations l10n, ThemeData theme) {
    final replyingTo = _replyingTo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${l10n.chatReplyingTo} ${replyingTo.username}',
                      style: theme.textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (widget.positionNotifier != null)
                _composerAction(
                  icon: Icons.schedule_rounded,
                  tooltip: l10n.chatPutTimestamp,
                  onTap: _insertTimestamp,
                ),
              if (widget.captureFrame != null) ...[
                if (widget.positionNotifier != null) const SizedBox(width: 4),
                _composerAction(
                  icon: Icons.add_photo_alternate_outlined,
                  tooltip: l10n.chatPutImage,
                  loading: _isUploadingImage,
                  onTap: _insertFrame,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _commentController,
            placeholder: replyingTo == null
                ? l10n.chatWriteComment
                : l10n.chatWriteReply,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitComment(),
            trailing: IconButton(
              onPressed: _isSubmitting ? null : _submitComment,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 20),
              tooltip: l10n.chatSend,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final iconPack = ref.watch(iconPackProvider);
    final isLoggedIn =
        ref.watch(serverNotifierProvider).status?.isLoggedIn ?? false;

    if (widget.embedded) {
      return _buildEmbedded(l10n, theme, iconPack, isLoggedIn);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.mediaId == null || widget.mediaId! <= 0) {
      return Center(child: Text(l10n.chatUnavailable));
    }
    if (!isLoggedIn) {
      return _EmptyChatState(
        icon: AppIcons.profile(iconPack),
        message: l10n.chatLoginRequired,
        actionLabel: l10n.chatLoginWithAnilist,
        onPressed: _openLogin,
      );
    }
    if (_error != null) {
      final requiresLogin =
          _error!.toLowerCase().contains('anilist account') ||
          _error!.toLowerCase().contains('unauthorized');
      return Column(
        children: [
          Expanded(
            child: _EmptyChatState(
              icon: requiresLogin
                  ? AppIcons.profile(iconPack)
                  : AppIcons.refresh(iconPack),
              message: requiresLogin
                  ? l10n.chatLoginRequired
                  : '${_errorText(l10n)}\n\n${_errorSummary()}',
              actionLabel: requiresLogin
                  ? l10n.chatLoginWithAnilist
                  : l10n.retry,
              onPressed: requiresLogin
                  ? _openLogin
                  : () => _loadComments(refresh: true),
            ),
          ),
          if (!requiresLogin) _buildComposer(l10n, theme),
        ],
      );
    }
    if (_comments.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: _EmptyChatState(
              icon: AppIcons.chatBubble(iconPack),
              message: l10n.chatBeFirst,
              actionLabel: l10n.refresh,
              onPressed: () => _loadComments(refresh: true),
            ),
          ),
          _buildComposer(l10n, theme),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadComments(refresh: true),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: _comments.length + (_hasMorePages ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == _comments.length) {
                  return TextButton(
                    onPressed: _isLoadingMore ? null : _loadMore,
                    child: _isLoadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.loadMore),
                  );
                }
                return _CommentCard(
                  comment: _comments[index],
                  theme: theme,
                  l10n: l10n,
                  onReply: () => setState(() => _replyingTo = _comments[index]),
                  onCopy: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: _comments[index].content),
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.chatCopied)),
                      );
                    }
                  },
                  onVote: (voteType) => _vote(_comments[index], voteType),
                );
              },
            ),
          ),
        ),
        _buildComposer(l10n, theme),
      ],
    );
  }

  /// Non-scrolling variant used inside the desktop watch content column, so the
  /// comments flow within the page scroll instead of owning their own viewport.
  Widget _buildEmbedded(
    AppTranslations l10n,
    ThemeData theme,
    AppIconPack iconPack,
    bool isLoggedIn,
  ) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.mediaId == null || widget.mediaId! <= 0) {
      return _EmptyChatState(
        icon: AppIcons.chatBubble(iconPack),
        message: l10n.chatUnavailable,
        actionLabel: l10n.refresh,
        onPressed: () => _loadComments(refresh: true),
      );
    }
    if (!isLoggedIn) {
      return _EmptyChatState(
        icon: AppIcons.profile(iconPack),
        message: l10n.chatLoginRequired,
        actionLabel: l10n.chatLoginWithAnilist,
        onPressed: _openLogin,
      );
    }
    if (_error != null) {
      final requiresLogin = _error!.toLowerCase().contains('anilist account') ||
          _error!.toLowerCase().contains('unauthorized');
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildComposer(l10n, theme),
          _EmptyChatState(
            icon: requiresLogin ? AppIcons.profile(iconPack) : AppIcons.refresh(iconPack),
            message: requiresLogin ? l10n.chatLoginRequired : '${_errorText(l10n)}\n\n${_errorSummary()}',
            actionLabel: requiresLogin ? l10n.chatLoginWithAnilist : l10n.retry,
            onPressed: requiresLogin ? _openLogin : () => _loadComments(refresh: true),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildComposer(l10n, theme),
        const SizedBox(height: 4),
        if (_comments.isEmpty)
          _EmptyChatState(
            icon: AppIcons.chatBubble(iconPack),
            message: l10n.chatBeFirst,
            actionLabel: l10n.refresh,
            onPressed: () => _loadComments(refresh: true),
          )
        else ...[
          for (int index = 0; index < _comments.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CommentCard(
                comment: _comments[index],
                theme: theme,
                l10n: l10n,
                onReply: () => setState(() => _replyingTo = _comments[index]),
                onCopy: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(text: _comments[index].content),
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.chatCopied)),
                    );
                  }
                },
                onVote: (voteType) => _vote(_comments[index], voteType),
              ),
            ),
          if (_hasMorePages)
            TextButton(
              onPressed: _isLoadingMore ? null : _loadMore,
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.loadMore),
            ),
        ],
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final DantotsuComment comment;
  final ThemeData theme;
  final AppTranslations l10n;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final ValueChanged<int> onVote;

  const _CommentCard({
    required this.comment,
    required this.theme,
    required this.l10n,
    required this.onReply,
    required this.onCopy,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final date = comment.timestamp == null
        ? ''
        : DateFormat.yMMMd().add_jm().format(comment.timestamp!.toLocal());
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundImage: comment.profilePictureUrl == null
                      ? null
                      : NetworkImage(comment.profilePictureUrl!),
                  child: comment.profilePictureUrl == null
                      ? Text(
                          comment.username.isEmpty
                              ? '?'
                              : comment.username[0].toUpperCase(),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment.username.isEmpty
                        ? l10n.anilistUser
                        : comment.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(date, style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            _CommentBody(
              content: comment.content,
              style: theme.textTheme.bodyMedium,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => onVote(comment.userVoteType == 1 ? 0 : 1),
                  icon: Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 17,
                    color: comment.userVoteType == 1
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  tooltip: l10n.chatUpvote,
                ),
                Text('${comment.upvotes}'),
                IconButton(
                  onPressed: () => onVote(comment.userVoteType == -1 ? 0 : -1),
                  icon: Icon(
                    Icons.thumb_down_alt_outlined,
                    size: 17,
                    color: comment.userVoteType == -1
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  tooltip: l10n.chatDownvote,
                ),
                const Spacer(),
                IconButton(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_outlined, size: 18),
                  tooltip: l10n.chatReply,
                ),
                IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: l10n.chatCopied,
                ),
              ],
            ),
            if (comment.upvotes > 0 || comment.replyCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${comment.upvotes} ${comment.upvotes == 1 ? l10n.chatVote : l10n.chatVotes}'
                '${comment.replyCount > 0 ? '  •  ${comment.replyCount} ${comment.replyCount == 1 ? l10n.chatReply : l10n.chatReplies}' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  static final _mediaPattern = RegExp(
    r'(!?\[[^\]]*\]\((https?://[^)\s]+)\)|https?://[^\s]+)',
    caseSensitive: false,
  );

  final String content;
  final TextStyle? style;

  const _CommentBody({required this.content, required this.style});

  bool _isImageUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final path = uri.path.toLowerCase();
    return RegExp(r'\.(gif|png|jpe?g|webp)$').hasMatch(path);
  }

  String _urlFromMatch(String value) {
    final markdownMatch = RegExp(
      r'^\!?\[[^\]]*\]\((https?://[^)\s]+)\)$',
      caseSensitive: false,
    ).firstMatch(value);
    return markdownMatch?.group(1) ??
        value.replaceFirst(RegExp(r'[),.!?]+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final matches = _mediaPattern.allMatches(content).toList(growable: false);
    if (matches.isEmpty) {
      return Text(content, style: style);
    }

    final children = <Widget>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          Text(content.substring(cursor, match.start), style: style),
        );
      }

      final raw = match.group(0)!;
      final url = _urlFromMatch(raw);
      if (_isImageUrl(url)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  placeholder: (context, url) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Text(raw, style: style),
                ),
              ),
            ),
          ),
        );
      } else {
        children.add(Text(raw, style: style));
      }
      cursor = match.end;
    }
    if (cursor < content.length) {
      children.add(Text(content.substring(cursor), style: style));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _EmptyChatState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
