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
import 'package:bitago_longexam1/screens/detail_screen.dart';
import 'package:bitago_longexam1/screens/settings_screen.dart';
import 'package:bitago_longexam1/services/comment_service.dart';
import 'package:bitago_longexam1/services/user_service.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'Post detail displays comments, toggles likes and submits a comment',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final likes = LikesProvider(preferences, 1);
      final comments = CommentService(
        preferences,
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body);
            return http.Response(
              jsonEncode({
                'id': 341,
                'postId': body['postId'],
                'body': body['body'],
                'user': {'id': 1, 'username': 'emilys'},
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({
              'comments': [
                {
                  'id': 1,
                  'postId': 7,
                  'body': 'Existing reply',
                  'user': {'id': 2, 'username': 'reader'},
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(likes.dispose);
      addTearDown(comments.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DetailScreen(
            post: Post.fromJson({
              'id': 7,
              'userId': 1,
              'body': 'A short post',
              'likes': 2,
            }),
            user: User.fromJson({'id': 1, 'username': 'emilys'}),
            comments: comments,
            likes: likes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Existing reply'), findsOneWidget);
      await tester.tap(find.text('2 likes'));
      await tester.pumpAndSettle();
      expect(find.text('3 likes'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'A new reply');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(find.text('Comments (2)'), findsOneWidget);
      expect(find.text('A new reply'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sign-out clears session and removes the settings route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      UserService.sessionKey: jsonEncode({'id': 1, 'username': 'emilys'}),
    });
    final preferences = await SharedPreferences.getInstance();
    final theme = ThemeProvider(preferences);
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(preferences: preferences, theme: theme),
      ),
    );
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(preferences.getString(UserService.sessionKey), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(
      Navigator.of(tester.element(find.text('Welcome back'))).canPop(),
      false,
    );
    expect(tester.takeException(), isNull);
  });
}
