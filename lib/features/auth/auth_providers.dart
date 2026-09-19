import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);

/// Etat de connexion courant, ecoute en temps reel.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// État de vérification de l'email (rafraîchi manuellement via la bannière).
class EmailVerifiedNotifier extends Notifier<bool> {
  @override
  bool build() => FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  void set(bool value) => state = value;
}

final emailVerifiedProvider =
    NotifierProvider<EmailVerifiedNotifier, bool>(EmailVerifiedNotifier.new);
