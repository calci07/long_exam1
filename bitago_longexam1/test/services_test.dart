import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitago_longexam1/models/post.dart';
import 'package:bitago_longexam1/models/user.dart';
import 'package:bitago_longexam1/providers/likes_provider.dart';
import 'package:bitago_longexam1/providers/theme_provider.dart';
import 'package:bitago_longexam1/services/user_service.dart';
import 'package:bitago_longexam1/services/post_service.dart';
import 'package:bitago_longexam1/services/comment_service.dart';

const userJson = {
  'id': 1,
  'username': 'emilys',
  'firstName': 'Emily',
  'lastName': 'Johnson',
  'email': 'emily@example.com',
  'image': '',
};

void main() {
  late SharedPreferences preferences;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('Post supports nested reactions, legacy keys and missing values', () {
    final post = Post.fromJson({
      'id': 4,
      'user_id': 2,
      'post_id': 3,
      'reactions': {'likes': 12.0, 'dislikes': 2},
      'created_at': 'today',
    });
    expect(post.likes, 12);
    expect(post.dislikes, 2);
    expect(post.userId, 2);
    expect(post.postId, 3);
    expect(post.createdAt, 'today');
    expect(Post.fromJson(post.toJson()).toJson(), post.toJson());
    expect(Post.fromJson({'likes': 4}).likes, 4);
    expect(Post.fromJson({}).body, '');
  });

  test(
    'Login persists only profile and sign-out clears restored session',
    () async {
      final service = UserService(
        preferences,
        client: MockClient((request) async {
          expect(request.url.path, '/auth/login');
          expect(jsonDecode(request.body), {
            'username': 'emilys',
            'password': 'demo-password',
          });
          return http.Response(
            jsonEncode({
              ...userJson,
              'accessToken': 'token',
              'refreshToken': 'refresh',
              'password': 'not-for-storage',
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      await service.signIn(' emilys ', 'demo-password');
      expect(service.restoreUser()!.id, 1);
      final stored = jsonDecode(preferences.getString(UserService.sessionKey)!);
      expect(stored.containsKey('password'), false);
      expect(stored.containsKey('accessToken'), false);
      final restarted = UserService(preferences);
      addTearDown(restarted.dispose);
      expect(restarted.restoreUser()!.username, 'emilys');
      await service.signOut();
      expect(restarted.restoreUser(), isNull);
    },
  );

  test('Rejected login does not create a session', () async {
    final service = UserService(
      preferences,
      client: MockClient((_) async => http.Response('{}', 400)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.signIn('bad', 'bad'),
      throwsA(isA<SignInException>()),
    );
    expect(service.restoreUser(), isNull);
  });

  test('Malformed saved user returns to signed-out state', () async {
    await preferences.setString(UserService.sessionKey, 'broken json');
    final service = UserService(preferences);
    addTearDown(service.dispose);
    expect(service.restoreUser(), isNull);
  });

  test(
    'Feed paginates and profile fetches posts by the signed-in user ID',
    () async {
      final paths = <String>[];
      final service = PostService(
        client: MockClient((request) async {
          paths.add(request.url.toString());
          return http.Response(
            jsonEncode({
              'posts': [
                {'id': 7, 'userId': 1, 'body': 'Hello'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      expect((await service.getPosts(skip: 30)).single.id, 7);
      expect((await service.getPostsByUser(1)).single.userId, 1);
      expect(paths[0], endsWith('/posts?limit=30&skip=30'));
      expect(paths[1], endsWith('/posts/user/1?limit=0'));
    },
  );

  test(
    'Failed post requests report an error instead of an empty feed',
    () async {
      final service = PostService(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(service.dispose);
      await expectLater(service.getPosts(), throwsException);
    },
  );

  test(
    'Comments are scoped to post; added comments survive service recreation',
    () async {
      final user = User.fromJson(userJson);
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'body': 'My comment',
            'postId': 7,
            'userId': 1,
          });
          return http.Response(
            jsonEncode({
              'id': 341,
              'postId': 7,
              'body': 'My comment',
              'user': {'id': 1, 'username': 'emilys'},
            }),
            201,
          );
        }
        expect(request.url.path, '/comments/post/7');
        expect(request.url.queryParameters['limit'], '0');
        return http.Response(
          jsonEncode({
            'comments': [
              {
                'id': 2,
                'postId': 7,
                'body': 'Existing comment',
                'user': {'id': 2, 'username': 'another'},
              },
            ],
          }),
          200,
        );
      });
      final service = CommentService(preferences, client: client);
      addTearDown(service.dispose);
      await service.addComment(7, user, ' My comment ');
      final restarted = CommentService(preferences, client: client);
      final comments = await restarted.getComments(7, 1);
      expect(comments.map((c) => c.body), ['Existing comment', 'My comment']);
      expect((await restarted.getComments(7, 2)).length, 1);
      await expectLater(service.addComment(7, user, '  '), throwsArgumentError);
    },
  );

  test('Failed comment submission is not saved locally', () async {
    final service = CommentService(
      preferences,
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.addComment(7, User.fromJson(userJson), 'Comment'),
      throwsException,
    );
    expect(preferences.getStringList('comments_1_7'), isNull);
  });

  test('Likes persist, toggle off, and stay separate for each user', () async {
    final likes = LikesProvider(preferences, 1);
    addTearDown(likes.dispose);
    await likes.toggle('post_7');
    final restarted = LikesProvider(preferences, 1);
    final other = LikesProvider(preferences, 2);
    addTearDown(restarted.dispose);
    addTearDown(other.dispose);
    expect(restarted.contains('post_7'), true);
    expect(other.contains('post_7'), false);
    await restarted.toggle('post_7');
    expect(restarted.contains('post_7'), false);
    await restarted.toggle('comment_2');
    expect(restarted.contains('comment_2'), true);
  });

  test('Theme preference survives reopening', () async {
    final theme = ThemeProvider(preferences);
    addTearDown(theme.dispose);
    expect(theme.mode, ThemeMode.system);
    await theme.setMode(ThemeMode.dark);
    final restarted = ThemeProvider(preferences);
    addTearDown(restarted.dispose);
    expect(restarted.mode, ThemeMode.dark);
  });
}
