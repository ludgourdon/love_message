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

  /// Attribue automatiquement un nom d'utilisateur unique a partir du pseudo,
  /// s'il n'en a pas deja un. Idempotent : ne fait rien si deja attribue.
  ///
  /// Strategie : base = pseudo slugifie, puis base, base1, base2, ... jusqu'a
  /// en reserver un libre de facon atomique (transaction).
  Future<String?> ensureUsername({
    required String uid,
    required String displayName,
    String? email,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final snap = await userRef.get();
    final existing = (snap.data()?['username'] as String?)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final base = _slugBase(displayName, email);
    for (var i = 0; i < 50; i++) {
      final candidate = i == 0 ? base : '$base$i';
      final claimed = await _tryClaim(uid, userRef, candidate);
      if (claimed) return candidate;
    }
    // Filet de securite (tres improbable) : suffixe base sur l'uid.
    final fallback = '$base${uid.substring(0, uid.length >= 4 ? 4 : uid.length)}'
        .toLowerCase();
    final ok = await _tryClaim(uid, userRef, fallback);
    return ok ? fallback : null;
  }

  /// Tente de reserver [candidate] de facon atomique. Renvoie true si reussi.
  Future<bool> _tryClaim(
    String uid,
    DocumentReference<Map<String, dynamic>> userRef,
    String candidate,
  ) async {
    final key = normalizeUsername(candidate);
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _usernames.doc(key);
        final s = await tx.get(ref);
        if (s.exists) throw UsernameTakenException();
        tx.set(ref, {'uid': uid, 'username': candidate});
        tx.set(
          userRef,
          {'username': candidate, 'usernameLower': key},
          SetOptions(merge: true),
        );
      });
      return true;
    } on UsernameTakenException {
      return false;
    }
  }

  /// Construit une base d'identifiant : accents retires, minuscules,
  /// uniquement lettres/chiffres, longueur 3..15.
  String _slugBase(String displayName, String? email) {
    var slug = normalizeUsername(displayName).replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (slug.isEmpty && email != null) {
      slug = normalizeUsername(email.split('@').first)
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
    if (slug.isEmpty) slug = 'user';
    if (slug.length > 15) slug = slug.substring(0, 15);
    if (slug.length < 3) slug = '${slug}user'.substring(0, 4);
    return slug;
  }
}
