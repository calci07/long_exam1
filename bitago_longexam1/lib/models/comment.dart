class Comment {
  final int id;
  final int postId;
  final int userId;
  final String username;
  final String body;
  final int likes;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.body,
    this.likes = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] ?? 0,
    postId: json['postId'] ?? 0,
    userId: json['user']?['id'] ?? 0,
    username: json['user']?['username'] ?? 'User',
    body: json['body'] ?? '',
    likes: (json['likes'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'body': body,
    'likes': likes,
    'user': {'id': userId, 'username': username},
  };
}
