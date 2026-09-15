import 'package:cloud_firestore/cloud_firestore.dart';

/// Un envoi de coeurs d'un utilisateur a un autre (collection `hearts`).
class Heart {
  const Heart({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.count,
    required this.seen,
    this.message = '',
    this.createdAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final int count;
  final bool seen;
  final String message;
  final DateTime? createdAt;

  factory Heart.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return Heart(
      id: doc.id,
      fromUid: (map['fromUid'] as String?) ?? '',
      fromName: (map['fromName'] as String?) ?? 'Quelqu\'un',
      toUid: (map['toUid'] as String?) ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      seen: (map['seen'] as bool?) ?? false,
      message: (map['message'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
