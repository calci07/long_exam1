import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/post.dart';

class PostService {
  PostService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<Post>> getPosts({int limit = 30, int skip = 0}) =>
      _getPosts('$host/posts?limit=$limit&skip=$skip');

  Future<List<Post>> getPostsByUser(int userId) =>
      _getPosts('$host/posts/user/$userId?limit=0');

  Future<List<Post>> _getPosts(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    final List postsJson = data['posts'] ?? [];
    return postsJson.map((p) => Post.fromJson(p)).toList();
  }

  void dispose() => _client.close();
}
