import 'package:cloud_firestore/cloud_firestore.dart';

/// Profil utilisateur stocke dans Firestore (collection `users`).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.username,
    this.usernameLower,
    this.createdAt,
  });

  final String uid;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final String? username;
  final String? usernameLower;
  final DateTime? createdAt;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] as String?,
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? map['displayName'] as String
          : 'Moi',
      photoUrl: map['photoUrl'] as String?,
      username: map['username'] as String?,
      usernameLower: map['usernameLower'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
