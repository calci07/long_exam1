import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/user.dart';

class UserService {
  UserService(this.preferences, {http.Client? client})
    : _client = client ?? http.Client();
  final SharedPreferences preferences;
  final http.Client _client;
  static const sessionKey = 'signed_in_user';

  User? restoreUser() {
    final saved = preferences.getString(sessionKey);
    if (saved == null) return null;
    try {
      final user = User.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      return user.id > 0 && user.username.isNotEmpty ? user : null;
    } catch (_) {
      return null;
    }
  }

  Future<User> signIn(String username, String password) async {
    final response = await _client
        .post(
          Uri.parse('$host/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username.trim(), 'password': password}),
        )
        .timeout(requestTimeout);
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw const SignInException('Incorrect username or password.');
    }
    if (response.statusCode != 200) {
      throw const SignInException('Sign-in is unavailable. Please try again.');
    }
    final user = User.fromJson(jsonDecode(response.body));
    if (!await preferences.setString(sessionKey, jsonEncode(user.toJson()))) {
      throw const SignInException(
        'Could not save your session. Please try again.',
      );
    }
    return user;
  }

  Future<void> signOut() async {
    if (!await preferences.remove(sessionKey)) {
      throw Exception('Could not clear your session. Please try again.');
    }
  }

  void dispose() => _client.close();
}

class SignInException implements Exception {
  const SignInException(this.message);
  final String message;
}
