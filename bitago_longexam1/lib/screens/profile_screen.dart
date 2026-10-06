import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../providers/likes_provider.dart';
import '../providers/theme_provider.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/account_actions.dart';
import '../widgets/custom_info.dart';
import '../widgets/post_card.dart';
import 'detail_screen.dart';
import 'signin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.posts,
    required this.comments,
    required this.likes,
    required this.preferences,
    required this.theme,
  });
  final User user;
  final PostService posts;
  final CommentService comments;
  final LikesProvider likes;
  final SharedPreferences preferences;
  final ThemeProvider theme;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _service = UserService(widget.preferences);
  late Future<User?> _profile = _service.getUserData();
  late Future<List<Post>> _posts = _loadPosts();

  Future<List<Post>> _loadPosts() => widget.user.loginType == LoginType.firebase
      ? Future.value([])
      : widget.posts.getPostsByUser(widget.user.id);

  void _login() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) =>
          SigninScreen(preferences: widget.preferences, theme: widget.theme),
    ),
    (_) => false,
  );

  Future<void> _refresh() async {
    final profile = _service.getUserData();
    final posts = _loadPosts();
    setState(() {
      _profile = profile;
      _posts = posts;
    });
    try {
      await Future.wait([profile, posts]);
    } catch (_) {
      /* Builders show errors. */
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        FutureBuilder<User?>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return CustomInfo(
                message: authErrorMessage(snapshot.error!),
                onRetry: _refresh,
              );
            }
            final user = snapshot.data;
            if (user == null) {
              return Column(
                children: [
                  const Text('Your session has ended.'),
                  TextButton(
                    onPressed: _login,
                    child: const Text('Back to login'),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (user.image.isEmpty)
                        const Icon(Icons.account_circle, size: 88)
                      else
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.image,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.account_circle, size: 88),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('@${user.username}'),
                      const SizedBox(height: 8),
                      Text(user.email),
                      if (user.age != null) Text('Age: ${user.age}'),
                      if (user.contactNo.isNotEmpty)
                        Text('Contact: ${user.contactNo}'),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          user.loginType == LoginType.firebase
                              ? 'Firebase account'
                              : 'DummyJSON account',
                        ),
                      ),
                    ],
                  ),
                ),
                AccountActions(
                  user: user,
                  service: _service,
                  onChanged: _refresh,
                  onDeleted: _login,
                ),
              ],
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'My posts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Post>>(
          future: _posts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
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
