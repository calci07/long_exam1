# Bitago Long Exam 1

Gerald Bitago — Flutter lab activity with Firebase authentication.

## Run

```sh
flutter pub get
flutter run -d chrome
```

For Android, select an emulator or connected device with `flutter devices`, then
run `flutter run -d <device-id>`. Firebase is configured for Android, iOS and web.
iOS requires a Mac with Xcode; its minimum deployment target is iOS 15.

## Assignment requirements

- Keeps the existing `models`, `providers`, `screens`, `services`, `utils` and
  `widgets` structure, feed, post details, likes, comments and theme settings.
- `main.dart` initializes Firebase using generated `firebase_options.dart`.
- Sign-in selects Firebase email/password or the DummyJSON `/auth/login` API.
- `signup_screen.dart` collects fName, lName, age, contactNo, username,
  emailAddress and a validated, confirmed password.
- `UserService` implements `signIn1`, `createAccount`, `signOut`,
  `updateUsername`, `deleteAccount`, `resetPasswordFromCurrentPassword`
  and `getUserData`.
- Profile fetches current user data through `getUserData`, shows the login type
  and offers Firebase username updates, password changes and account deletion.
- Password changes and deletion reauthenticate with the current password.
- Settings sign-out clears the saved session and tokens and returns to login.
  Deleted accounts also return to login; navigation history is cleared.
- Firebase handles ID-token refresh. DummyJSON tokens use secure storage and
  `/auth/refresh`; expired or revoked sessions cannot use a cached profile alone.
- Required profile fields live at `users/{Firebase UID}` in Cloud Firestore.
  Deployed rules allow only the owner to read/write their own profile, validate
  its fields, and prohibit storing passwords or arbitrary extra fields.

## Firebase project

Account: `geraldb2417@gmail.com`
Project: `advmobprog-firebase-dd6d7`
Database: `(default)`, Standard edition, `asia-southeast1` (Singapore), Spark plan.
Email/password authentication is enabled. Android, iOS and web apps are registered.
The generated Firebase client identifiers are public configuration, not admin secrets.

To regenerate configuration or publish changes to the rules:

```sh
firebase login
flutterfire configure --project=advmobprog-firebase-dd6d7 --platforms=android,ios,web
firebase deploy --only firestore:rules --project=advmobprog-firebase-dd6d7
```

On this computer, npm executables are in `%APPDATA%/npm` and FlutterFire is in
`%LOCALAPPDATA%/Pub/Cache/bin`. If Google API calls time out in Node, this session
used `NODE_OPTIONS=--dns-result-order=ipv4first` in PowerShell.

## DummyJSON behavior

Use the DummyJSON tab with a sample account such as `emilys` / `emilyspass`.
Do not enter a personal password in the demo service. DummyJSON additions,
updates and deletions are simulated, so permanent account management uses Firebase.
The shared feed remains DummyJSON data. Firebase accounts have no matching
DummyJSON author ID, so their profile does not claim another user's posts.
Comments by Firebase users are local to this app installation; DummyJSON comments
are submitted to the demo endpoint and retained locally. Likes and comments are
scoped by the Firebase UID or DummyJSON user ID. Notifications retain the original
empty state because the API has no notifications endpoint.

## Verification

```sh
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

Firebase service tests use Firebase Auth mocks and fake Firestore for account
lifecycle behavior. Rules tests use the official Firestore emulator (Java 21+):

```sh
npm ci --prefix test/rules
firebase emulators:exec --only firestore --project demo-bitago "node --test test/rules/rules.test.cjs"
```

The rules tests use an isolated demo project, never production data.

## Assets

The app uses `assets/images/nuicon.jpeg`. The original course fonts and `owl.jpg`
were not supplied; system font fallbacks remain in use.

References: [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup),
[Firebase account management](https://firebase.google.com/docs/auth/flutter/manage-users),
[DummyJSON authentication](https://dummyjson.com/docs/auth).
