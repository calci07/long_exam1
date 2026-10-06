import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../providers/likes_provider.dart';
import '../services/comment_service.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/custom_info.dart';
import '../widgets/custom_inkwell_button.dart';
import '../widgets/post_card.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.post,
    required this.user,
    required this.comments,
    required this.likes,
  });
  final Post post;
  final User user;
  final CommentService comments;
  final LikesProvider likes;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _text = TextEditingController();
  List<Comment> _comments = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || _sending) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await widget.comments.getComments(
        widget.post.id,
        widget.user.storageId,
      );
      if (mounted) setState(() => _comments = comments);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load comments.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _loading || _error != null) return;
    if (_text.text.trim().isEmpty) {
      CustomDialogs.message(context, 'Write a comment first.');
      return;
    }
    setState(() => _sending = true);
    try {
      final comment = await widget.comments.addComment(
        widget.post.id,
        widget.user,
        _text.text,
      );
      if (!mounted) return;
      setState(() => _comments.add(comment));
      _text.clear();
      FocusScope.of(context).unfocus();
      CustomDialogs.message(context, 'Comment added.');
    } catch (_) {
      if (mounted) {
        CustomDialogs.message(
          context,
          'Could not add your comment. Your text has been kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Post & comments')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      PostCard(post: widget.post, likes: widget.likes),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Comments (${_comments.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null)
                        CustomInfo(message: _error!, onRetry: _load)
                      else if (_comments.isEmpty)
                        const CustomInfo(
                          message: 'No comments yet. Start the conversation.',
                        )
                      else
                        ..._comments.map(
                          (comment) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${comment.username}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(comment.body),
                                ListenableBuilder(
                                  listenable: widget.likes,
                                  builder: (context, _) {
                                    final key = 'comment_${comment.id}';
                                    final liked = widget.likes.contains(key);
                                    return CustomInkwellButton(
                                      icon: liked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      label:
                                          '${comment.likes + (liked ? 1 : 0)} likes',
                                      selected: liked,
                                      onTap: () async {
                                        try {
                                          await widget.likes.toggle(key);
                                        } catch (_) {
                                          if (context.mounted) {
                                            CustomDialogs.message(
                                              context,
                                              'Could not save your like.',
                                            );
                                          }
                                        }
                                      },
                                    );
                                  },
                                ),
                                const Divider(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Write a comment',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send comment',
                      onPressed: _sending || _loading || _error != null
                          ? null
                          : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
