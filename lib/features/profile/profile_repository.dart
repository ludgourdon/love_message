import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserProfile?> watchProfile(String uid) => _doc(uid).snapshots().map(
        (snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null,
      );

  /// Lecture ponctuelle du profil (fiable meme si le stream n'est pas actif).
  Future<UserProfile?> fetchProfile(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null;
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    final name = displayName.trim();
    await _doc(uid).set({'displayName': name}, SetOptions(merge: true));
    await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
  }

  /// Met à jour la date de naissance (jour + mois + année).
  Future<void> updateDateOfBirth(
    String uid, {
    required int day,
    required int month,
    required int year,
  }) async {
    await _doc(uid).set({
      'birthdayDay': day,
      'birthdayMonth': month,
      'birthdayYear': year,
    }, SetOptions(merge: true));
    // Met à jour la version publique (jour + mois) si le rappel est activé.
    final snap = await _doc(uid).get();
    final enabled = (snap.data()?['birthdayRemindersEnabled'] as bool?) ?? true;
    await _syncPublicBirthday(uid, enabled: enabled, day: day, month: month);
  }

  /// Active/désactive le rappel d'anniversaire envoyé aux proches.
  Future<void> updateBirthdayReminders(String uid, bool enabled) async {
    await _doc(uid).set({
      'birthdayRemindersEnabled': enabled,
    }, SetOptions(merge: true));
    final snap = await _doc(uid).get();
    final day = (snap.data()?['birthdayDay'] as num?)?.toInt();
    final month = (snap.data()?['birthdayMonth'] as num?)?.toInt();
    await _syncPublicBirthday(uid, enabled: enabled, day: day, month: month);
  }

  /// Publie (ou retire) le jour + mois d'anniversaire dans `birthdays/{uid}`,
  /// lisible par les proches. Le doc n'existe que si le rappel est activé.
  Future<void> _syncPublicBirthday(
    String uid, {
    required bool enabled,
    int? day,
    int? month,
  }) async {
    final ref = _firestore.collection('birthdays').doc(uid);
    if (enabled && day != null && month != null) {
      await ref.set({'day': day, 'month': month});
    } else {
      await ref.delete().catchError((_) {});
    }
  }

  /// Lit le jour + mois d'anniversaire public d'un proche (null si non publié).
  Future<(int, int)?> fetchPublicBirthday(String uid) async {
    final snap = await _firestore.collection('birthdays').doc(uid).get();
    if (!snap.exists) return null;
    final d = (snap.data()?['day'] as num?)?.toInt();
    final m = (snap.data()?['month'] as num?)?.toInt();
    if (d == null || m == null) return null;
    return (d, m);
  }

  /// Cree le document profil s'il n'existe pas encore (comptes anterieurs).
  Future<void> ensureProfile(User user) async {
    final ref = _doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : (user.email?.split('@').first ?? 'Moi'),
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
