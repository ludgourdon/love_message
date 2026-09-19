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
    final people = _firestore
        .collection('users')
        .doc(request.toUid)
        .collection('people');

    // Si l'expéditeur est déjà présent dans mon monde, on réutilise cette
    // carte (et on conserve le nom que j'ai éventuellement choisi) au lieu
    // d'en créer une seconde.
    final existing = await people
        .where('linkedUid', isEqualTo: request.fromUid)
        .limit(1)
        .get();

    final batch = _firestore.batch();
    batch.update(_requests.doc(request.id), {'status': 'accepted'});

    if (existing.docs.isNotEmpty) {
      batch.update(existing.docs.first.reference, {
        'linkedUsername': request.fromUsername,
        'requestId': request.id,
        'linkStatus': 'accepted',
      });
    } else {
      batch.set(people.doc(), {
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
    }

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

  /// Cote INVITE : utilise un code d'invitation. N'ecrit QUE dans mes
  /// propres donnees + met a jour l'invitation. L'invitant se reconcilie
  /// ensuite tout seul (voir watchRedeemedInvitations / reconcileInvitation).
  Future<InvitationResult> redeemInvitation({
    required String code,
    required String myUid,
    required String myUsername,
    required String myDisplayName,
  }) async {
    final cleaned = code.trim().toLowerCase();
    if (cleaned.isEmpty) {
      throw const InvitationException('Entre un code d\'invitation.');
    }
    final invSnap = await _invitations.doc(cleaned).get();
    if (!invSnap.exists) {
      throw const InvitationException(
          'Ce code d\'invitation est invalide ou a expire.');
    }
    final data = invSnap.data() ?? const <String, dynamic>{};
    final fromUid = data['fromUid'] as String?;
    final fromUsername = (data['fromUsername'] as String?) ?? '';
    if (fromUid == null || fromUid.isEmpty) {
      throw const InvitationException('Invitation invalide.');
    }
    if (fromUid == myUid) {
      throw const InvitationException(
          'Tu ne peux pas utiliser ta propre invitation.');
    }

    final myPeople =
        _firestore.collection('users').doc(myUid).collection('people');
    final inviterName = fromUsername.isNotEmpty ? '@$fromUsername' : 'ton invitant';

    // Deja connecte ? (evite les doublons si on retape le code)
    final already =
        await myPeople.where('linkedUid', isEqualTo: fromUid).limit(1).get();
    if (already.docs.isNotEmpty) {
      throw InvitationException('Tu es déjà connecté à $inviterName.');
    }

    final batch = _firestore.batch();
    // 1) L'invitant apparait dans MON monde (connecte).
    batch.set(myPeople.doc(), {
      'name': inviterName,
      'note': '',
      'emoji': '💗',
      'color': 0xFFFFD4E2,
      'linkedUid': fromUid,
      'linkedUsername': fromUsername,
      'linkStatus': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 2) Marque l'invitation acceptee + mes infos, pour que l'invitant se
    //    reconcilie de son cote (il ne peut lire mon profil).
    batch.update(_invitations.doc(cleaned), {
      'status': 'accepted',
      'toUid': myUid,
      'toUsername': myUsername,
      'toDisplayName': myDisplayName,
      'reconciled': false,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return InvitationResult(inviterName: inviterName);
  }

  /// Cote INVITANT : invitations que j'ai envoyees et qui ont ete acceptees
  /// mais pas encore integrees dans mon monde. Filtre cote client pour eviter
  /// un index compose.
  Stream<List<RedeemedInvitation>> watchRedeemedInvitations(String myUid) =>
      _invitations.where('fromUid', isEqualTo: myUid).snapshots().map((snap) =>
          snap.docs
              .where((d) {
                final m = d.data();
                return m['status'] == 'accepted' &&
                    m['reconciled'] != true &&
                    (m['toUid'] as String?) != null &&
                    (m['toUid'] as String).isNotEmpty;
              })
              .map(RedeemedInvitation.fromDoc)
              .toList());

  /// Cote INVITANT : integre l'invite dans mon monde (ecrit dans MES donnees
  /// uniquement) et marque l'invitation comme reconciliee. Idempotent.
  Future<void> reconcileInvitation(RedeemedInvitation inv, String myUid) async {
    final myPeople =
        _firestore.collection('users').doc(myUid).collection('people');

    final batch = _firestore.batch();

    // Deja integre ?
    final existing =
        await myPeople.where('linkedUid', isEqualTo: inv.toUid).limit(1).get();
    if (existing.docs.isEmpty) {
      // Retrouve la carte "invited" a mettre a jour : par code, sinon par nom.
      DocumentReference<Map<String, dynamic>>? cardRef;
      if (inv.code.isNotEmpty) {
        final byCode =
            await myPeople.where('inviteCode', isEqualTo: inv.code).limit(1).get();
        if (byCode.docs.isNotEmpty) cardRef = byCode.docs.first.reference;
      }
      if (cardRef == null && inv.personName.isNotEmpty) {
        final invited =
            await myPeople.where('linkStatus', isEqualTo: 'invited').get();
        for (final d in invited.docs) {
          if (((d.data()['name'] as String?) ?? '').trim() ==
              inv.personName.trim()) {
            cardRef = d.reference;
            break;
          }
        }
      }
      final name = inv.toDisplayName.trim().isNotEmpty
          ? inv.toDisplayName.trim()
          : (inv.toUsername.isNotEmpty ? '@${inv.toUsername}' : 'Nouveau proche');
      if (cardRef != null) {
        // On conserve le nom choisi par l'invitant lors de l'ajout ;
        // on ne met à jour que le lien.
        batch.update(cardRef, {
          'linkedUid': inv.toUid,
          'linkedUsername': inv.toUsername,
          'linkStatus': 'accepted',
        });
      } else {
        batch.set(myPeople.doc(), {
          'name': name,
          'note': '',
          'emoji': '💗',
          'color': 0xFFFFD4E2,
          'linkedUid': inv.toUid,
          'linkedUsername': inv.toUsername,
          'linkStatus': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.update(_invitations.doc(inv.code), {'reconciled': true});
    await batch.commit();
  }

  String _randomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

/// Resultat d'une connexion par code d'invitation.
class InvitationResult {
  const InvitationResult({required this.inviterName});
  final String inviterName;
}

/// Invitation acceptee par un invite, vue du cote de l'invitant.
class RedeemedInvitation {
  const RedeemedInvitation({
    required this.code,
    required this.toUid,
    required this.toUsername,
    required this.toDisplayName,
    required this.personName,
  });

  final String code;
  final String toUid;
  final String toUsername;
  final String toDisplayName;
  final String personName;

  factory RedeemedInvitation.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return RedeemedInvitation(
      code: (m['code'] as String?) ?? doc.id,
      toUid: (m['toUid'] as String?) ?? '',
      toUsername: (m['toUsername'] as String?) ?? '',
      toDisplayName: (m['toDisplayName'] as String?) ?? '',
      personName: (m['personName'] as String?) ?? '',
    );
  }
}

/// Erreur "attendue" lors de l'utilisation d'un code d'invitation
/// (code invalide, deja connecte, etc.), a afficher telle quelle.
class InvitationException implements Exception {
  const InvitationException(this.message);
  final String message;
  @override
  String toString() => message;
}
