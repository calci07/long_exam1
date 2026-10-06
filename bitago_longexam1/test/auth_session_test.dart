import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitago_longexam1/services/user_service.dart';
import 'package:bitago_longexam1/utils/validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'Expired demo token refreshes before fetching the current profile',
    () async {
      final preferences = await SharedPreferences.getInstance();
      var profileRequests = 0;
      final service = UserService(
        preferences,
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'username': 'demo',
                'accessToken': 'expired',
                'refreshToken': 'refresh',
              }),
              200,
            );
          }
          if (request.url.path == '/auth/refresh') {
            expect(jsonDecode(request.body)['refreshToken'], 'refresh');
            return http.Response(
              jsonEncode({
                'accessToken': 'renewed',
                'refreshToken': 'next-refresh',
              }),
              200,
            );
          }
          expect(request.url.path, '/auth/me');
          profileRequests++;
          if (profileRequests == 1) return http.Response('{}', 401);
          expect(request.headers['Authorization'], 'Bearer renewed');
          return http.Response(
            jsonEncode({
              'id': 1,
              'username': 'demo',
              'firstName': 'Gerald',
              'lastName': 'Bitago',
              'age': 22,
              'phone': '09123456789',
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      await service.signIn('demo', 'example');
      final user = await service.getUserData();
      expect(user!.fullName, 'Gerald Bitago');
      expect(user.age, 22);
      expect(user.contactNo, '09123456789');
      await service.signOut();
      expect(service.restoreUser(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );

  test('Revoked demo session cannot restore from a cached profile', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = UserService(
      preferences,
      client: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'username': 'demo',
              'accessToken': 'expired',
              'refreshToken': 'revoked',
            }),
            200,
          );
        }
        return http.Response('{}', 401);
      }),
    );
    addTearDown(service.dispose);
    await service.signIn('demo', 'example');
    expect(await service.getUserData(), isNull);
    expect(service.restoreUser(), isNull);
  });

  test('Signup rejects invalid age, contact, email and weak password', () {
    expect(Validators.age('abc'), isNotNull);
    expect(Validators.age('151'), isNotNull);
    expect(Validators.age('22'), isNull);
    expect(Validators.contactNo('abc'), isNotNull);
    expect(Validators.contactNo('+63 912 345 6789'), isNull);
    expect(Validators.email('invalid'), isNotNull);
    expect(Validators.email('gerald@example.com'), isNull);
    expect(Validators.password('short'), isNotNull);
    expect(Validators.password('Example123!'), isNull);
  });
}
