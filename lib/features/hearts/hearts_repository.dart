import 'package:cloud_firestore/cloud_firestore.dart';

import 'heart.dart';

class HeartsRepository {
  HeartsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('hearts');

  Future<void> send({
    required String fromUid,
    required String fromName,
    required String toUid,
    required int count,
  }) {
    return _col.add({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'count': count,
      'seen': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Coeurs recus par cet utilisateur, du plus recent au plus ancien
  /// (tri cote client pour eviter un index composite).
  Stream<List<Heart>> watchReceived(String uid) =>
      _col.where('toUid', isEqualTo: uid).snapshots().map((snap) {
        final list = snap.docs.map(Heart.fromDoc).toList();
        list.sort((a, b) {
          final da = a.createdAt;
          final db = b.createdAt;
          // Les envois tout juste recus (timestamp en attente = null) en premier.
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return db.compareTo(da);
        });
        return list;
      });

  /// Marque comme vus tous les coeurs recus non lus.
  Future<void> markAllSeen(String uid) async {
    final snap = await _col
        .where('toUid', isEqualTo: uid)
        .where('seen', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }
}
