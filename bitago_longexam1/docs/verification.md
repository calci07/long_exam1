# Verification — 3 October 2026

## Part II verification — 7 October 2026

- Existing region retained. Chat now replaces Notifications in the second tab.
- `flutter analyze`: no issues.
- `flutter test`: all 28 tests passed, including seven chat service/widget tests.
- Official Firestore emulator: all six security-rule tests passed. The previous
  emulator-download limitation below is resolved; downloading with IPv4 curl worked.
- Updated Firestore rules compiled and deployed to `advmobprog-firebase-dd6d7`.
- Web and Android debug builds succeeded. Updated APK: `outputs/bitago-longexam1.apk`.
- Two local browser sessions using real Firebase SDKs and Auth/Firestore emulators:
  sign-in, self-excluding user directory, message send/receive, and seen receipt
  verified. No production accounts or messages were created for this test.
- Existing build warnings remain: Cupertino font fallback in the web build and
  Firebase plugins' future Kotlin Gradle Plugin compatibility warning.
- See [Part II instructions and test steps](firebase-part-ii.md).

## Part I record

- Firebase CLI signed in as geraldb2417@gmail.com.
- Existing project advmobprog-firebase-dd6d7 reused; Android, iOS and web registered.
- Email/password provider enabled in the Firebase console.
- Firestore Standard database created in asia-southeast1 on Spark.
- firestore.rules compiled and deployed successfully; published rules verified in the console.
- flutter analyze: no issues.
- flutter test: all 21 tests passed, including token refresh/revocation, signup validation,
  Firebase profile persistence, username updates, incorrect-current-password rejection,
  account deletion, deletion rollback, logout navigation and existing feed interactions.
- flutter build web: succeeded. Clean rebuild corrected a stale web plugin registrant.
- flutter build apk --debug: succeeded; Android Studio SDK was sufficient for this build.
- Chrome smoke test: app startup, signup required-field validation, actual DummyJSON sign-in,
  feed, profile details and Settings logout succeeded.
- Test-only Node dependencies: npm audit reports zero vulnerabilities.

## Limits

- Official Firestore emulator tests are provided in test/rules but could not run because
  storage.googleapis.com repeatedly reset or failed the emulator JAR download.
  Production rule deployment/compiler validation succeeded; emulator runtime checks remain unverified.
- Firebase account lifecycle tests use SDK mocks, not a newly created real user account.
- iOS is configured with a minimum target of iOS 15; building it requires macOS/Xcode.
- Windows desktop is not a configured Firebase target. Flutter pub get may display a
  Developer Mode/symlink warning for desktop plugins; Android and web builds succeeded.
- Firebase plugins produce a future Kotlin Gradle Plugin compatibility warning with this
  Flutter version. This did not fail the Android build.

## Evidence

- [Published Firestore rules](evidence/firebase-rules.png)
- [Signup validation](evidence/signup-validation.png)
- [Login screen after logout](evidence/login.png)
