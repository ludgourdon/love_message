import 'package:cloud_firestore/cloud_firestore.dart';

import 'loved_one.dart';

class PeopleRepository {
  PeopleRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('people');

  /// Liste des proches, triee du plus ancien au plus recent (tri cote client
  /// pour eviter d'exclure un proche dont le serverTimestamp est en attente).
  Stream<List<LovedOne>> watchPeople(String uid) =>
      _col(uid).snapshots().map((snap) {
        final list = snap.docs.map(LovedOne.fromDoc).toList();
        list.sort((a, b) {
          final da = a.createdAt;
          final db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        return list;
      });

  Future<void> add(
    String uid, {
    required String name,
    required String note,
    required String emoji,
    required int color,
    String? linkedUid,
    String? linkedUsername,
    String? requestId,
    String linkStatus = 'none',
  }) {
    return _col(uid).add({
      'name': name.trim(),
      'note': note.trim(),
      'emoji': emoji,
      'color': color,
      'linkedUid': linkedUid,
      'linkedUsername': linkedUsername,
      'requestId': requestId,
      'linkStatus': linkStatus,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(
    String uid,
    String id, {
    required String name,
    required String note,
    required String emoji,
    required int color,
  }) {
    return _col(uid).doc(id).update({
      'name': name.trim(),
      'note': note.trim(),
      'emoji': emoji,
      'color': color,
    });
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();
}
