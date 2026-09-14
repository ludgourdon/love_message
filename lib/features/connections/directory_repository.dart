import 'package:cloud_firestore/cloud_firestore.dart';

import 'username.dart';

/// Annuaire public username -> uid (collection `usernames`).
class DirectoryRepository {
  DirectoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection('usernames');

  /// Renvoie l'uid associe a ce username, ou null s'il n'existe pas.
  Future<String?> lookupUid(String username) async {
    final key = normalizeUsername(username);
    final snap = await _usernames.doc(key).get();
    return snap.exists ? snap.data()!['uid'] as String? : null;
  }

  /// Reclame un username unique pour l'utilisateur.
  /// Leve [UsernameTakenException] s'il est deja pris par quelqu'un d'autre.
  Future<void> claimUsername({
    required String uid,
    required String username,
    String? previousUsernameLower,
  }) async {
    final key = normalizeUsername(username);
    await _firestore.runTransaction((tx) async {
      final ref = _usernames.doc(key);
      final snap = await tx.get(ref);
      if (snap.exists && (snap.data()!['uid'] as String?) != uid) {
        throw UsernameTakenException();
      }
      tx.set(ref, {'uid': uid, 'username': username.trim()});
      if (previousUsernameLower != null && previousUsernameLower != key) {
        tx.delete(_usernames.doc(previousUsernameLower));
      }
      tx.set(
        _firestore.collection('users').doc(uid),
        {'username': username.trim(), 'usernameLower': key},
        SetOptions(merge: true),
      );
    });
  }
}
