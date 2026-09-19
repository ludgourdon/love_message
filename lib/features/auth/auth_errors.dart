import 'package:firebase_auth/firebase_auth.dart';

/// Traduit les codes d'erreur Firebase Auth en messages lisibles (FR).
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Adresse email invalide.';
    case 'user-disabled':
      return 'Ce compte a été désactivé.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email ou mot de passe incorrect.';
    case 'email-already-in-use':
      return 'Un compte existe déjà avec cet email.';
    case 'weak-password':
      return 'Mot de passe trop faible (6 caractères minimum).';
    case 'too-many-requests':
      return 'Trop de tentatives. Réessaie plus tard.';
    case 'network-request-failed':
      return 'Probleme de connexion reseau.';
    default:
      return e.message ?? 'Erreur d\'authentification.';
  }
}
