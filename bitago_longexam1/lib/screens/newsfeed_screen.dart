import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../providers/likes_provider.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';
import '../widgets/custom_info.dart';
import '../widgets/post_card.dart';
import 'detail_screen.dart';

class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({
    super.key,
    required this.user,
    required this.posts,
    required this.comments,
    required this.likes,
  });
  final User user;
  final PostService posts;
  final CommentService comments;
  final LikesProvider likes;
  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  final List<Post> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.posts.getPosts(
        skip: refresh ? 0 : _posts.length,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _posts.clear();
        _posts.addAll(page);
        _hasMore = page.length == 30;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load posts. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty && _error != null) {
      return CustomInfo(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null) {
              return CustomInfo(message: _error!, onRetry: _load);
            }
            if (_posts.isEmpty) {
              return const CustomInfo(
                message: 'No posts yet. Pull down to refresh.',
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _hasMore
                    ? TextButton(
                        onPressed: _load,
                        child: const Text('Load more posts'),
                      )
                    : const Text('You have reached the end.'),
              ),
            );
          }
          final post = _posts[index];
          return PostCard(
            post: post,
            likes: widget.likes,
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(
                  post: post,
                  user: widget.user,
                  comments: widget.comments,
                  likes: widget.likes,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
