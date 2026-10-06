import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitago_longexam1/services/user_service.dart';
import 'package:bitago_longexam1/models/user.dart' as model;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore firestore;
  late UserService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    auth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: 'gerald-test',
        email: 'gerald@example.com',
        isAnonymous: false,
      ),
    );
    firestore = FakeFirebaseFirestore();
    service = UserService(
      preferences,
      firebaseAuth: auth,
      firestore: firestore,
    );
  });
  tearDown(() => service.dispose());

  Future<void> signup() => service
      .createAccount(
        email: 'gerald@example.com',
        password: 'Example123!',
        fName: 'Gerald',
        lName: 'Bitago',
        age: 22,
        contactNo: '09123456789',
        username: 'geraldb',
      )
      .then((_) {});

  test(
    'Signup persists required profile, excludes passwords and restores Firebase identity',
    () async {
      await signup();
      final user = await service.getUserData();
      expect(user!.loginType, model.LoginType.firebase);
      expect(user.fullName, 'Gerald Bitago');
      expect(user.age, 22);
      expect(user.contactNo, '09123456789');
      expect(user.storageId, startsWith('firebase_'));
      final data = (await firestore.doc('users/${user.uid}').get()).data()!;
      expect(
        data.keys,
        unorderedEquals([
          'fName',
          'lName',
          'age',
          'contactNo',
          'username',
          'emailAddress',
        ]),
      );
      expect(
        preferences.getString(UserService.sessionKey),
        isNot(contains('Example123!')),
      );
      await service.updateUsername(username: 'gerald_updated');
      expect((await service.getUserData())!.username, 'gerald_updated');
      expect(auth.currentUser!.displayName, 'gerald_updated');
      await service.signOut();
      expect(auth.currentUser, isNull);
      expect(service.restoreUser(), isNull);
    },
  );

  test(
    'Wrong current password blocks both password change and account deletion',
    () async {
      await signup();
      final user = auth.currentUser!;
      whenCalling(
        Invocation.method(#reauthenticateWithCredential, null),
      ).on(user).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      await expectLater(
        service.resetPasswordFromCurrentPassword(
          currentPassword: 'incorrect',
          newPassword: 'NewExample123!',
          email: 'gerald@example.com',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
      await expectLater(
        service.deleteAccount(
          email: 'gerald@example.com',
          password: 'incorrect',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect((await firestore.doc('users/${user.uid}').get()).exists, isTrue);
      expect(auth.currentUser, isNotNull);
    },
  );

  test('Account deletion removes the profile and saved session', () async {
    await signup();
    final uid = auth.currentUser!.uid;
    await service.getUserData();
    await service.deleteAccount(
      email: 'gerald@example.com',
      password: 'Example123!',
    );
    expect((await firestore.doc('users/$uid').get()).exists, isFalse);
    expect(auth.currentUser, isNull);
    expect(service.restoreUser(), isNull);
  });

  test('Failed authentication deletion restores the user profile', () async {
    await signup();
    final account = auth.currentUser!;
    whenCalling(Invocation.method(#delete, null))
        .on(account)
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    await expectLater(
      service.deleteAccount(
        email: 'gerald@example.com',
        password: 'Example123!',
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(
      (await firestore.doc('users/${account.uid}').get()).data()!['username'],
      'geraldb',
    );
    expect(auth.currentUser, isNotNull);
  });

  test(
    'Password validation rejects a weak replacement before changing the account',
    () async {
      await signup();
      await expectLater(
        service.resetPasswordFromCurrentPassword(
          currentPassword: 'Example123!',
          newPassword: 'short',
          email: 'gerald@example.com',
        ),
        throwsA(isA<SignInException>()),
      );
      expect(auth.currentUser, isNotNull);
    },
  );
}
