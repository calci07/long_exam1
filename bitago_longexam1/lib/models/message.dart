import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    this.id = '',
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    this.timestamp,
    this.deliveredAt,
    this.seenAt,
    this.pending = false,
  });

  final String id, senderId, senderEmail, receiverId, message;
  final Timestamp? timestamp, deliveredAt, seenAt;
  final bool pending;

  String get status => pending
      ? 'Sending…'
      : seenAt != null
      ? 'Seen'
      : deliveredAt != null
      ? 'Delivered'
      : 'Sent';

  factory MessageModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
    bool pending = false,
  }) => MessageModel(
    id: id,
    senderId: map['senderId'] as String,
    senderEmail: map['senderEmail'] as String? ?? '',
    receiverId: map['receiverId'] as String,
    message: map['message'] as String,
    timestamp: map['timestamp'] as Timestamp?,
    deliveredAt: map['deliveredAt'] as Timestamp?,
    seenAt: map['seenAt'] as Timestamp?,
    pending: pending,
  );

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderEmail': senderEmail,
    'receiverId': receiverId,
    'message': message,
    'timestamp': timestamp,
    'deliveredAt': deliveredAt,
    'seenAt': seenAt,
  };
}

class ChatUser {
  const ChatUser({required this.uid, required this.name, required this.email});
  final String uid, name, email;

  factory ChatUser.fromMap(String uid, Map<String, dynamic> data) {
    final name =
        '${data['fName'] ?? data['firstName'] ?? ''} ${data['lName'] ?? data['lastName'] ?? ''}'
            .trim();
    return ChatUser(
      uid: uid,
      name: name.isEmpty ? (data['username'] as String? ?? 'User') : name,
      email: (data['emailAddress'] ?? data['email'] ?? '') as String,
    );
  }

  bool matches(String query) =>
      name.toLowerCase().contains(query.trim().toLowerCase()) ||
      email.toLowerCase().contains(query.trim().toLowerCase());
}
