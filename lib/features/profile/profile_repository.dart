import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserProfile?> watchProfile(String uid) => _doc(uid).snapshots().map(
        (snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null,
      );

  /// Lecture ponctuelle du profil (fiable meme si le stream n'est pas actif).
  Future<UserProfile?> fetchProfile(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null;
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    final name = displayName.trim();
    await _doc(uid).set({'displayName': name}, SetOptions(merge: true));
    await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
  }

  /// Cree le document profil s'il n'existe pas encore (comptes anterieurs).
  Future<void> ensureProfile(User user) async {
    final ref = _doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : (user.email?.split('@').first ?? 'Moi'),
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
