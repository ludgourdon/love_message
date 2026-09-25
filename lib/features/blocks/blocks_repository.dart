import 'package:cloud_firestore/cloud_firestore.dart';

/// Gère la liste des comptes bloqués par un utilisateur.
/// Chaque blocage est un document users/{uid}/blocked/{blockedUid}.
class BlocksRepository {
  BlocksRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('blocked');

  /// Ensemble des uid que [uid] a bloqués.
  Stream<Set<String>> watchBlocked(String uid) =>
      _col(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  Future<void> block(String uid, String blockedUid, {String? name}) =>
      _col(uid).doc(blockedUid).set({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> unblock(String uid, String blockedUid) =>
      _col(uid).doc(blockedUid).delete();

  /// Indique si [otherUid] a bloqué [myUid] (lecture du seul doc me concernant).
  Future<bool> isBlockedBy(String otherUid, String myUid) async {
    final snap = await _col(otherUid).doc(myUid).get();
    return snap.exists;
  }
}
