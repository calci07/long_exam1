import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../providers/likes_provider.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';
import '../widgets/custom_info.dart';
import '../widgets/post_card.dart';
import 'detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Post>> _posts = widget.posts.getPostsByUser(widget.user.id);

  Future<void> _refresh() async {
    final request = widget.posts.getPostsByUser(widget.user.id);
    setState(() => _posts = request);
    try {
      await request;
    } catch (_) {
      /* FutureBuilder displays the retry state. */
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.user.image,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox(
                    width: 88,
                    height: 88,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.account_circle, size: 88),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.user.fullName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('@${widget.user.username}'),
              const SizedBox(height: 8),
              Text(widget.user.email),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'My posts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Post>>(
          future: _posts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return CustomInfo(
                message: 'Could not load your posts.',
                onRetry: _refresh,
              );
            }
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return const CustomInfo(message: 'You have no posts yet.');
            }
            return Column(
              children: posts
                  .map(
                    (post) => PostCard(
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
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
