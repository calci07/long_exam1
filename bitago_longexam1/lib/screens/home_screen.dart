import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../providers/likes_provider.dart';
import '../providers/theme_provider.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';
import 'newsfeed_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.preferences,
    required this.theme,
  });
  final User user;
  final SharedPreferences preferences;
  final ThemeProvider theme;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  late final _likes = LikesProvider(widget.preferences, widget.user.id);
  late final _comments = CommentService(widget.preferences);
  final _posts = PostService();

  @override
  void dispose() {
    _likes.dispose();
    _comments.dispose();
    _posts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(['News feed', 'Notifications', 'My profile'][_index]),
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                preferences: widget.preferences,
                theme: widget.theme,
              ),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: IndexedStack(
            index: _index,
            children: [
              NewsfeedScreen(
                user: widget.user,
                posts: _posts,
                comments: _comments,
                likes: _likes,
              ),
              const NotificationScreen(),
              ProfileScreen(
                user: widget.user,
                posts: _posts,
                comments: _comments,
                likes: _likes,
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Feed',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          label: 'Notifications',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}
