enum LoginType { dummyJson, firebase }

class User {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String image;
  final String? uid;
  final int? age;
  final String contactNo;
  final LoginType loginType;

  const User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.image,
    this.uid,
    this.age,
    this.contactNo = '',
    this.loginType = LoginType.dummyJson,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get storageId => uid == null ? '$id' : 'firebase_$uid';

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int? ?? -1,
    username: json['username'] as String,
    firstName: json['firstName'] ?? '',
    lastName: json['lastName'] ?? '',
    email: json['email'] ?? '',
    image: json['image'] ?? '',
    uid: json['uid'] as String?,
    age: json['age'] as int?,
    contactNo: json['contactNo'] ?? json['phone'] ?? '',
    loginType: json['loginType'] == 'firebase'
        ? LoginType.firebase
        : LoginType.dummyJson,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'image': image,
    'uid': uid,
    'age': age,
    'contactNo': contactNo,
    'loginType': loginType.name,
  };
}
