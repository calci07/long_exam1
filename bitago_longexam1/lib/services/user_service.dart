import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/user.dart';
import '../utils/validators.dart';

class UserService {
  UserService(
    this.preferences, {
    http.Client? client,
    auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FlutterSecureStorage? tokenStorage,
  }) : _client = client ?? http.Client(),
       _firebaseAuth = firebaseAuth,
       _firestore = firestore,
       _tokens = tokenStorage ?? const FlutterSecureStorage();
  final SharedPreferences preferences;
  final http.Client _client;
  final auth.FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;
  final FlutterSecureStorage _tokens;
  auth.FirebaseAuth get firebaseAuth =>
      _firebaseAuth ?? auth.FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  static const sessionKey = 'signed_in_user';
  static const _loginTypeKey = 'login_type';
  static const _accessKey = 'dummy_access_token';
  static const _refreshKey = 'dummy_refresh_token';
  auth.User? get currentUser => firebaseAuth.currentUser;
  Stream<auth.User?> get authStateChanges => firebaseAuth.authStateChanges();
  Stream<auth.User?> get idTokenChanges => firebaseAuth.idTokenChanges();
  LoginType get loginType => preferences.getString(_loginTypeKey) == 'firebase'
      ? LoginType.firebase
      : LoginType.dummyJson;

  User? restoreUser() {
    final saved = preferences.getString(sessionKey);
    if (saved == null) return null;
    try {
      final user = User.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      return user.username.isNotEmpty && (user.id > 0 || user.uid != null)
          ? user
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(User user) async {
    if (!await preferences.setString(_loginTypeKey, user.loginType.name) ||
        !await preferences.setString(sessionKey, jsonEncode(user.toJson()))) {
      throw const SignInException(
        'Could not save your session. Please try again.',
      );
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access != null) await _tokens.write(key: _accessKey, value: access);
    if (refresh != null) await _tokens.write(key: _refreshKey, value: refresh);
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
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = User.fromJson(data);
    await _saveTokens(data);
    await _save(user);
    return user;
  }

  Future<auth.UserCredential> signIn1({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await preferences.setString(_loginTypeKey, LoginType.firebase.name);
    await preferences.remove(sessionKey);
    await _tokens.delete(key: _accessKey);
    await _tokens.delete(key: _refreshKey);
    return credential;
  }

  Future<auth.UserCredential> createAccount({
    required String email,
    required String password,
    required String fName,
    required String lName,
    required int age,
    required String contactNo,
    required String username,
  }) async {
    final errors = [
      Validators.email(email),
      Validators.password(password),
      Validators.name(fName),
      Validators.name(lName),
      Validators.age('$age'),
      Validators.contactNo(contactNo),
      Validators.username(username),
    ];
    for (final error in errors) {
      if (error != null) throw SignInException(error);
    }
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final account = credential.user!;
    try {
      await account.updateDisplayName(username.trim());
      await firestore.collection('users').doc(account.uid).set({
        'fName': fName.trim(),
        'lName': lName.trim(),
        'age': age,
        'contactNo': contactNo.trim(),
        'username': username.trim(),
        'emailAddress': account.email!,
      });
    } catch (_) {
      // Roll back a signup whose required profile could not be saved.
      await account.delete();
      rethrow;
    }
    await preferences.setString(_loginTypeKey, LoginType.firebase.name);
    await preferences.remove(sessionKey);
    await _tokens.delete(key: _accessKey);
    await _tokens.delete(key: _refreshKey);
    return credential;
  }

  Future<User?> getUserData() async {
    if (loginType == LoginType.firebase) {
      final account =
          currentUser ?? await firebaseAuth.authStateChanges().first;
      if (account == null) {
        await signOut();
        return null;
      }
      try {
        await account.reload();
        await account.getIdToken(); // The SDK refreshes expired ID tokens.
      } on auth.FirebaseAuthException catch (error) {
        if ([
          'user-disabled',
          'user-not-found',
          'invalid-user-token',
          'user-token-expired',
        ].contains(error.code)) {
          await signOut();
          return null;
        }
        rethrow;
      }
      final data =
          (await firestore
                  .collection('users')
                  .doc(account.uid)
                  .get(const GetOptions(source: Source.server)))
              .data();
      if (data == null) {
        throw const SignInException(
          'Your profile is missing. Contact the app administrator.',
        );
      }
      final user = User(
        id: -1,
        uid: account.uid,
        username: data['username'] ?? account.displayName ?? '',
        firstName: data['fName'] ?? '',
        lastName: data['lName'] ?? '',
        email: account.email ?? '',
        image: account.photoURL ?? '',
        age: data['age'] as int?,
        contactNo: data['contactNo'] ?? '',
        loginType: LoginType.firebase,
      );
      await _save(user);
      return user;
    }
    var token = await _tokens.read(key: _accessKey);
    if (token == null) {
      await signOut();
      return null;
    }
    Future<http.Response> fetch() => _client
        .get(
          Uri.parse('$host/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(requestTimeout);
    var response = await fetch();
    if (response.statusCode == 401 || response.statusCode == 403) {
      final refresh = await _tokens.read(key: _refreshKey);
      if (refresh == null) {
        await signOut();
        return null;
      }
      final renewed = await _client
          .post(
            Uri.parse('$host/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(requestTimeout);
      if (renewed.statusCode == 400 ||
          renewed.statusCode == 401 ||
          renewed.statusCode == 403) {
        await signOut();
        return null;
      }
      if (renewed.statusCode != 200) {
        throw const SignInException(
          'Could not refresh your session. Try again.',
        );
      }
      await _saveTokens(jsonDecode(renewed.body));
      token = await _tokens.read(key: _accessKey);
      response = await fetch();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await signOut();
      return null;
    }
    if (response.statusCode != 200) {
      throw const SignInException('Could not load your profile. Try again.');
    }
    final user = User.fromJson(jsonDecode(response.body));
    await _save(user);
    return user;
  }

  auth.User _requireFirebaseUser() {
    if (loginType != LoginType.firebase || currentUser == null) {
      throw const SignInException(
        'Account changes require a Firebase account.',
      );
    }
    return currentUser!;
  }

  Future<void> updateUsername({required String username}) async {
    final error = Validators.username(username);
    if (error != null) throw SignInException(error);
    final account = _requireFirebaseUser();
    await account.updateDisplayName(username.trim());
    await firestore.collection('users').doc(account.uid).update({
      'username': username.trim(),
    });
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    final error = Validators.password(newPassword);
    if (error != null) throw SignInException(error);
    final account = _requireFirebaseUser();
    await account.reauthenticateWithCredential(
      auth.EmailAuthProvider.credential(
        email: email.trim(),
        password: currentPassword,
      ),
    );
    await account.updatePassword(newPassword);
    await account.getIdToken(true);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    final account = _requireFirebaseUser();
    await account.reauthenticateWithCredential(
      auth.EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      ),
    );
    final reference = firestore.collection('users').doc(account.uid);
    final saved = (await reference.get(
      const GetOptions(source: Source.server),
    )).data();
    await reference.delete();
    try {
      await account.delete();
    } catch (_) {
      if (saved != null) await reference.set(saved);
      rethrow;
    }
    await signOut();
  }

  Future<void> signOut() async {
    if (_firebaseAuth != null || Firebase.apps.isNotEmpty) {
      await firebaseAuth.signOut();
    }
    await _tokens.delete(key: _accessKey);
    await _tokens.delete(key: _refreshKey);
    if (!await preferences.remove(sessionKey) ||
        !await preferences.remove(_loginTypeKey)) {
      throw const SignInException(
        'Could not clear your session. Please try again.',
      );
    }
  }

  void dispose() => _client.close();
}

class SignInException implements Exception {
  const SignInException(this.message);
  final String message;
}

String authErrorMessage(Object error) {
  if (error is SignInException) return error.message;
  if (error is auth.FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Incorrect email or password.',
      'email-already-in-use' =>
        'This email already has an account. Sign in instead.',
      'weak-password' => 'Choose a stronger password.',
      'invalid-email' => 'Enter a valid email address.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'requires-recent-login' =>
        'Please sign in again before changing your account.',
      'user-disabled' => 'This account has been disabled.',
      'operation-not-allowed' => 'Email/password sign-in is not enabled.',
      _ =>
        'Could not complete the request. Check your connection and try again.',
    };
  }
  return 'Could not complete the request. Check your connection and try again.';
}
