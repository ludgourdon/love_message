import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'profile_repository.dart';
import 'user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(FirebaseFirestore.instance),
);

/// Profil de l'utilisateur connecte, en temps reel (null si deconnecte).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<UserProfile?>.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(user.uid);
});
