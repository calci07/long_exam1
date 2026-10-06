# Firebase Part II — Chat

The existing Firebase project, Firebase initialization, email/password authentication,
Firestore database, `cloud_firestore`, and `provider` were already configured in Part I.
The database remains in `asia-southeast1`, as requested on 6 October 2026.

## Implemented

- Second bottom navigation destination is Chat, with a chat icon.
- All registered Firestore profiles appear except the current Firebase user.
- Search filters full name or email, ignoring case; clear restores the list.
- Message model and chat service use `chat_rooms/{sortedUIDs}/messages`.
- Real-time conversation history, sender/receiver bubbles, timestamps, fade/slide
  transitions, send progress, and error/retry states.
- Sending: local write awaiting acknowledgement. Sent: Firestore committed the write.
  Delivered: recipient's conversation listener acknowledged receipt.
  Seen: recipient's conversation is current and the app is foregrounded.
  Opening a conversation marks its loaded messages read. No background push delivery
  or online-presence system is implied by these labels.
- Failed sends retain the draft. Blank messages and messages over 4000 characters
  are rejected. Duplicate submissions are disabled while sending.
- DummyJSON users see a Firebase sign-in explanation instead of attempting chat.

## Adaptations to the handout

- Existing profiles use `fName`, `lName`, and `emailAddress`; their document ID is
  the Firebase UID. The chat service maps those fields and also understands the
  sample's `firstName`, `lastName`, and `email`. Existing accounts need no migration.
- Server timestamps order messages instead of trusting each device's clock.
- Rules require authentication for profile discovery, ownership for profile writes,
  and conversation membership for message reads. Only the receiver can add receipts;
  neither participant can rewrite a sent message or forge the sender.
- The course's public `allow read, write: if true` rule is not used. Profile documents
  are readable by signed-in accounts for the course directory; Firestore document
  reads include all profile fields (including age/contact number), although chat
  displays only name/email. This is a course-app access model, not a public directory
  with separate private-profile storage.

## Test in the app

1. Restart the Flutter app and sign in with Firebase.
2. Use two Firebase accounts in separate browser profiles, or one browser and one phone.
   Two normal tabs on the same origin share Firebase sign-in state.
3. Open Chat. Each account should see the other, never itself.
4. Search by part of the other's name and then email. Clear the search.
5. Open the other account and send a message. It appears immediately in both open
   conversations, with opposite alignment. Reply in the second account.
6. Keep the receiver's conversation open but put its window/tab in the background.
   A new message may become Delivered when that client processes it, but must not
   become Seen until the receiver returns. A fully suspended/offline receiver may
   not acknowledge delivery until it resumes.
7. Return to the list and reopen the conversation to check saved history.
8. In Firebase Console, inspect `chat_rooms` → room → `messages` for message and receipt
   timestamps. Account registration/profile storage remains under `users`.

## Local emulator verification

No real user accounts are required. From the Flutter project directory:

```powershell
firebase emulators:start --only auth,firestore --project demo-bitago
```

In another terminal:

```powershell
./tool/seed_chat_emulator.ps1
flutter run -d chrome -t tool/emulator_main.dart
```

Local-only accounts: `alice@example.com` and `bob@example.com`, password
`DemoChat2026!`. These credentials do not belong to production accounts.
The emulator entry point is separate from `lib/main.dart`; normal builds continue
to use the existing Firebase project.

```powershell
flutter analyze
flutter test
firebase emulators:exec --only firestore --project demo-bitago "node --test test/rules/rules.test.cjs"
```

Stop a running emulator before using `emulators:exec` on the same ports.
