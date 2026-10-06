import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/comment.dart';
import '../models/user.dart';

class CommentService {
  CommentService(this.preferences, {http.Client? client})
    : _client = client ?? http.Client();
  final SharedPreferences preferences;
  final http.Client _client;

  String _key(Object userId, int postId) => 'comments_${userId}_$postId';

  List<Comment> _local(int postId, Object userId) {
    final raw = preferences.getStringList(_key(userId, postId)) ?? [];
    return raw.map((entry) => Comment.fromJson(jsonDecode(entry))).toList();
  }

  Future<List<Comment>> getComments(int postId, Object userId) async {
    final response = await _client
        .get(Uri.parse('$host/comments/post/$postId?limit=0'))
        .timeout(requestTimeout);
    if (response.statusCode != 200) throw Exception('Could not load comments.');
    final Map<String, dynamic> data = jsonDecode(response.body);
    return [
      ...(data['comments'] as List).map((json) => Comment.fromJson(json)),
      ..._local(postId, userId),
    ];
  }

  Future<Comment> addComment(int postId, User user, String body) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 1000) {
      throw ArgumentError('Enter a comment of 1 to 1,000 characters.');
    }
    if (user.loginType == LoginType.firebase) {
      final comment = Comment(
        id: -DateTime.now().microsecondsSinceEpoch,
        postId: postId,
        userId: user.id,
        username: user.username,
        body: text,
        likes: 0,
      );
      await _saveLocal(postId, user, comment);
      return comment;
    }
    final response = await _client
        .post(
          Uri.parse('$host/comments/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'body': text, 'postId': postId, 'userId': user.id}),
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Could not add your comment.');
    }
    final remote = Comment.fromJson(jsonDecode(response.body));
    // DummyJSON reuses simulated IDs; local IDs must remain unique.
    final comment = Comment(
      id: -DateTime.now().microsecondsSinceEpoch,
      postId: postId,
      userId: user.id,
      username: user.username,
      body: remote.body,
      likes: remote.likes,
    );
    await _saveLocal(postId, user, comment);
    return comment;
  }

  Future<void> _saveLocal(int postId, User user, Comment comment) async {
    final comments = [..._local(postId, user.storageId), comment];
    if (!await preferences.setStringList(
      _key(user.storageId, postId),
      comments.map((c) => jsonEncode(c.toJson())).toList(),
    )) {
      throw Exception('Could not save your comment.');
    }
  }

  void dispose() => _client.close();
}
