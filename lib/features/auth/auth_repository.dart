import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Encapsule Firebase Auth + la création initiale du profil Firestore.
class AuthRepository {
  AuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required int birthdayDay,
    required int birthdayMonth,
    required int birthdayYear,
    bool birthdayRemindersEnabled = true,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName.trim());
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName.trim(),
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'birthdayDay': birthdayDay,
      'birthdayMonth': birthdayMonth,
      'birthdayYear': birthdayYear,
      'birthdayRemindersEnabled': birthdayRemindersEnabled,
      'ageConfirmedAt': FieldValue.serverTimestamp(),
    });
    // Version publique (jour + mois) lisible par les proches, si rappel activé.
    if (birthdayRemindersEnabled) {
      await _firestore.collection('birthdays').doc(user.uid).set({
        'day': birthdayDay,
        'month': birthdayMonth,
      });
    }
    // Envoie l'email de vérification (en français).
    await _auth.setLanguageCode('fr');
    await user.sendEmailVerification();
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> resendVerificationEmail() async {
    await _auth.setLanguageCode('fr');
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Recharge l'utilisateur et renvoie l'état de vérification à jour.
  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Supprime definitivement le compte : re-authentifie avec le mot de passe,
  /// nettoie les donnees Firestore de l'utilisateur, puis supprime le compte Auth.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = user.email;
    if (email == null) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'Compte sans email : suppression impossible ici.',
      );
    }

    // 1) Re-authentification (obligatoire pour une operation sensible).
    final cred = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(cred);

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);

    // 2) Nettoyage Firestore (tant qu'on est encore authentifie).
    // Libere le nom d'utilisateur.
    final profileSnap = await userRef.get();
    final usernameLower = profileSnap.data()?['usernameLower'] as String?;
    if (usernameLower != null && usernameLower.isNotEmpty) {
      await _firestore
          .collection('usernames')
          .doc(usernameLower)
          .delete()
          .catchError((_) {});
    }
    // Supprime les sous-collections (proches + blocages).
    for (final sub in ['people', 'blocked', 'fcmTokens']) {
      final docs = await userRef.collection(sub).get();
      for (final d in docs.docs) {
        await d.reference.delete().catchError((_) {});
      }
    }
    // Supprime le document profil.
    await userRef.delete().catchError((_) {});

    // 3) Supprime le compte Auth.
    await user.delete();
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
