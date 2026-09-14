import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'connection_request.dart';

class ConnectionsRepository {
  ConnectionsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('connectionRequests');
  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('invitations');

  Future<String> sendRequest({
    required String fromUid,
    required String fromUsername,
    required String fromDisplayName,
    required String toUid,
    required String toUsername,
    required String personName,
  }) async {
    final ref = await _requests.add({
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName,
      'toUid': toUid,
      'toUsername': toUsername,
      'personName': personName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Demandes recues (en attente) par cet utilisateur.
  Stream<List<ConnectionRequest>> watchIncoming(String uid) => _requests
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(ConnectionRequest.fromDoc).toList());

  /// Demandes envoyees par cet utilisateur (tous statuts).
  Stream<List<ConnectionRequest>> watchOutgoing(String uid) => _requests
      .where('fromUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(ConnectionRequest.fromDoc).toList());

  /// Accepte une demande : marque la demande acceptee ET ajoute l'expediteur
  /// au "petit monde" de celui qui accepte (request.toUid). Atomique.
  Future<void> accept(ConnectionRequest request) async {
    final batch = _firestore.batch();
    batch.update(_requests.doc(request.id), {'status': 'accepted'});

    final personRef = _firestore
        .collection('users')
        .doc(request.toUid)
        .collection('people')
        .doc();
    batch.set(personRef, {
      'name': request.fromDisplayName.trim().isNotEmpty
          ? request.fromDisplayName.trim()
          : '@${request.fromUsername}',
      'note': '',
      'emoji': '💗',
      'color': 0xFFFFD4E2,
      'linkedUid': request.fromUid,
      'linkedUsername': request.fromUsername,
      'requestId': request.id,
      'linkStatus': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> decline(String requestId) =>
      _requests.doc(requestId).update({'status': 'declined'});

  /// Cree une invitation et renvoie le lien a partager.
  Future<String> createInvitation({
    required String fromUid,
    required String fromUsername,
    required String personName,
  }) async {
    final code = _randomCode();
    await _invitations.doc(code).set({
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'personName': personName,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return 'https://love-message-2835b.web.app/invite?code=$code';
  }

  String _randomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
