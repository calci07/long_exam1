import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User get _user =>
      _auth.currentUser ??
      (throw StateError('Sign in to Firebase to use chat.'));
  String get currentUserId => _user.uid;

  Stream<List<ChatUser>> getUsersStream() {
    final uid = currentUserId;
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .where((doc) => doc.id != uid)
          .map((doc) => ChatUser.fromMap(doc.id, doc.data()))
          .toList();
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    });
  }

  Future<String?> getUidByEmail(String email) async {
    _user;
    for (final field in ['emailAddress', 'email']) {
      final result = await _firestore
          .collection('users')
          .where(field, isEqualTo: email.trim())
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) return result.docs.first.id;
    }
    return null;
  }

  List<String> _members(String otherId) {
    final uid = currentUserId;
    if (otherId.isEmpty || otherId == uid || otherId.contains('/')) {
      throw ArgumentError('Choose another registered user.');
    }
    return [uid, otherId]..sort();
  }

  DocumentReference<Map<String, dynamic>> _room(String otherId) =>
      _firestore.collection('chat_rooms').doc(_members(otherId).join('_'));

  Future<void> openConversation(String otherId) => _room(
    otherId,
  ).set({'members': _members(otherId)}, SetOptions(merge: true));

  Future<void> sendMessage(String receiverId, String message) async {
    final sender = _user;
    final members = _members(receiverId);
    final text = message.trim();
    if (text.isEmpty || text.length > 4000) {
      throw ArgumentError('Messages must contain 1–4000 characters.');
    }
    final room = _room(receiverId);
    final batch = _firestore.batch();
    batch.set(room, {'members': members}, SetOptions(merge: true));
    batch.set(room.collection('messages').doc(), {
      ...MessageModel(
        senderId: sender.uid,
        senderEmail: sender.email ?? '',
        receiverId: receiverId,
        message: text,
      ).toMap(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<MessageModel>> getMessages(String otherId) => _room(otherId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => MessageModel.fromMap(
                doc.data(),
                id: doc.id,
                pending: doc.metadata.hasPendingWrites,
              ),
            )
            .toList(),
      );

  // Only the receiving client acknowledges delivery and viewing.
  Future<void> acknowledge(
    String otherId,
    List<MessageModel> messages, {
    required bool seen,
  }) async {
    final uid = currentUserId;
    final room = _room(otherId);
    final incoming = messages
        .where(
          (m) =>
              m.receiverId == uid &&
              !m.pending &&
              (m.deliveredAt == null || (seen && m.seenAt == null)),
        )
        .toList();
    for (var start = 0; start < incoming.length; start += 400) {
      final batch = _firestore.batch();
      for (final message in incoming.skip(start).take(400)) {
        batch.update(room.collection('messages').doc(message.id), {
          if (message.deliveredAt == null)
            'deliveredAt': FieldValue.serverTimestamp(),
          if (seen && message.seenAt == null)
            'seenAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
