import 'package:cloud_firestore/cloud_firestore.dart';

/// Demande de connexion entre deux comptes (collection `connectionRequests`).
class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.toUid,
    required this.personName,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String fromUid;
  final String fromUsername;
  final String fromDisplayName;
  final String toUid;
  final String personName;
  final String status; // pending | accepted | declined
  final DateTime? createdAt;

  factory ConnectionRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? const <String, dynamic>{};
    return ConnectionRequest(
      id: doc.id,
      fromUid: (map['fromUid'] as String?) ?? '',
      fromUsername: (map['fromUsername'] as String?) ?? '',
      fromDisplayName: (map['fromDisplayName'] as String?) ?? '',
      toUid: (map['toUid'] as String?) ?? '',
      personName: (map['personName'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
