class User {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String image;

  const User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.image,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String,
    firstName: json['firstName'] ?? '',
    lastName: json['lastName'] ?? '',
    email: json['email'] ?? '',
    image: json['image'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'image': image,
  };
}
