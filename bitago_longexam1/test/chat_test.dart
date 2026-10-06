import 'dart:async';
import 'package:bitago_longexam1/models/message.dart';
import 'package:bitago_longexam1/screens/chat_detailscreen.dart';
import 'package:bitago_longexam1/services/chat_service.dart';
import 'package:bitago_longexam1/screens/chat_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late ChatService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'alice', email: 'alice@example.com'),
    );
    service = ChatService(firestore: db, firebaseAuth: auth);
    await db.doc('users/alice').set({
      'fName': 'Alice',
      'lName': 'A',
      'emailAddress': 'alice@example.com',
    });
    await db.doc('users/bob').set({
      'fName': 'Bob',
      'lName': 'Bitago',
      'emailAddress': 'bob@example.com',
    });
    await db.doc('users/carol').set({
      'firstName': 'Carol',
      'lastName': 'C',
      'email': 'carol@example.com',
      'uid': 'carol',
    });
  });

  test(
    'Existing profiles appear with document UID; current user is excluded',
    () async {
      final users = await service.getUsersStream().first;
      expect(users.map((u) => u.uid), ['bob', 'carol']);
      expect(users.first.name, 'Bob Bitago');
      expect(await service.getUidByEmail('bob@example.com'), 'bob');
      expect(await service.getUidByEmail('missing@example.com'), isNull);
    },
  );

  test(
    'Both participants share one room and receipts require the recipient',
    () async {
      await service.openConversation('bob');
      await service.sendMessage('bob', ' Hello Bob ');
      var messages = await service.getMessages('bob').first;
      expect(messages.single.message, 'Hello Bob');
      expect(messages.single.senderId, 'alice');
      expect(messages.single.status, 'Sent');
      await service.acknowledge('bob', messages, seen: true);
      expect((await service.getMessages('bob').first).single.status, 'Sent');
      final bob = ChatService(
        firestore: db,
        firebaseAuth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'bob', email: 'bob@example.com'),
        ),
      );
      await bob.openConversation('alice');
      await bob.acknowledge(
        'alice',
        await bob.getMessages('alice').first,
        seen: false,
      );
      expect(
        (await service.getMessages('bob').first).single.status,
        'Delivered',
      );
      await bob.acknowledge(
        'alice',
        await bob.getMessages('alice').first,
        seen: true,
      );
      expect((await service.getMessages('bob').first).single.status, 'Seen');
      await bob.sendMessage('alice', 'Hello Alice');
      expect((await db.collection('chat_rooms').get()).docs, hasLength(1));
      expect(await service.getMessages('bob').first, hasLength(2));
    },
  );

  test(
    'Empty, oversized, self-addressed and signed-out messages are rejected',
    () async {
      await expectLater(service.sendMessage('bob', '  '), throwsArgumentError);
      await expectLater(
        service.sendMessage('bob', 'a' * 4001),
        throwsArgumentError,
      );
      await expectLater(
        service.sendMessage('alice', 'hello'),
        throwsArgumentError,
      );
      await auth.signOut();
      await expectLater(service.sendMessage('bob', 'hello'), throwsStateError);
      expect((await db.collection('chat_rooms').get()).docs, isEmpty);
    },
  );

  testWidgets('Chat search filters by name or email and clear restores users', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice A'), findsNothing);
    expect(find.text('Bob Bitago'), findsOneWidget);
    expect(find.text('Carol C'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'BITAGO');
    await tester.pumpAndSettle();
    expect(find.text('Bob Bitago'), findsOneWidget);
    expect(find.text('Carol C'), findsNothing);
    await tester.enterText(find.byType(TextField), 'carol@');
    await tester.pumpAndSettle();
    expect(find.text('Carol C'), findsOneWidget);
    expect(find.text('Bob Bitago'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Bob Bitago'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No matching users'), findsOneWidget);
  });

  testWidgets(
    'Conversation sends, receives and displays recipient seen receipt',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatScreen(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob Bitago'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello from Alice');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Hello from Alice'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      final bob = ChatService(
        firestore: db,
        firebaseAuth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'bob', email: 'bob@example.com'),
        ),
      );
      await bob.acknowledge(
        'alice',
        await bob.getMessages('alice').first,
        seen: true,
      );
      await bob.sendMessage('alice', 'Hello from Bob');
      await tester.pumpAndSettle();
      expect(find.text('Seen'), findsOneWidget);
      expect(find.text('Hello from Bob'), findsOneWidget);
      expect((await bob.getMessages('alice').first).first.status, 'Seen');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Hidden conversation acknowledges delivery without claiming seen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatDetailScreen(
            user: const ChatUser(
              uid: 'bob',
              name: 'Bob',
              email: 'bob@example.com',
            ),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final bob = ChatService(
        firestore: db,
        firebaseAuth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'bob', email: 'bob@example.com'),
        ),
      );
      await bob.sendMessage('alice', 'Read when you return');
      await tester.pumpAndSettle();
      expect((await bob.getMessages('alice').first).single.status, 'Delivered');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect((await bob.getMessages('alice').first).single.status, 'Seen');
    },
  );

  testWidgets(
    'Pending send disables duplicate submission; failure preserves draft',
    (tester) async {
      final pending = Completer<void>();
      final delayed = _DelayedChatService(db, auth, pending);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatDetailScreen(
            user: const ChatUser(
              uid: 'bob',
              name: 'Bob',
              email: 'bob@example.com',
            ),
            service: delayed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.byTooltip('Sending message'), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep my draft',
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(find.textContaining('Message was not sent.'), findsOneWidget);
    },
  );
}

class _DelayedChatService extends ChatService {
  _DelayedChatService(
    FakeFirebaseFirestore db,
    MockFirebaseAuth auth,
    this.pending,
  ) : super(firestore: db, firebaseAuth: auth);
  final Completer<void> pending;
  @override
  Future<void> sendMessage(String receiverId, String message) => pending.future;
}
