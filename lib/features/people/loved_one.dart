import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Un proche du "petit monde" de l'utilisateur (users/{uid}/people/{id}).
class LovedOne {
  const LovedOne({
    required this.id,
    required this.name,
    required this.note,
    required this.emoji,
    required this.color,
    this.createdAt,
    this.linkedUid,
    this.linkedUsername,
    this.requestId,
    this.linkStatus = 'none',
    this.inviteCode,
  });

  final String id;
  final String name;
  final String note;
  final String emoji;
  final Color color;
  final DateTime? createdAt;

  /// Connexion a un compte existant.
  final String? linkedUid;
  final String? linkedUsername;
  final String? requestId;

  /// Code d'invitation associe a une carte "invited" (pour la connexion).
  final String? inviteCode;

  /// none | pending | invited (le statut "accepted" est derive des demandes).
  final String linkStatus;

  factory LovedOne.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return LovedOne(
      id: doc.id,
      name: (map['name'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '💗',
      color: Color((map['color'] as num?)?.toInt() ?? 0xFFFFD4E2),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      linkedUid: map['linkedUid'] as String?,
      linkedUsername: map['linkedUsername'] as String?,
      requestId: map['requestId'] as String?,
      linkStatus: (map['linkStatus'] as String?) ?? 'none',
      inviteCode: map['inviteCode'] as String?,
    );
  }
}
