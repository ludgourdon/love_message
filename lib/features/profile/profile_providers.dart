import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../people/loved_one.dart';
import '../people/people_providers.dart';
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

/// uid des proches connectés dont c'est l'anniversaire aujourd'hui
/// (et qui ont activé le rappel : seuls ceux-là publient leur jour+mois).
final birthdayTodayUidsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const <String>{};
  final people = ref.watch(peopleProvider).value ?? const <LovedOne>[];
  final repo = ref.watch(profileRepositoryProvider);
  final now = DateTime.now();
  final linked = <String>{
    for (final p in people)
      if (p.linkedUid != null && p.linkedUid!.isNotEmpty) p.linkedUid!,
  };
  final today = <String>{};
  await Future.wait(linked.map((uid) async {
    final bd = await repo.fetchPublicBirthday(uid);
    if (bd != null && bd.$1 == now.day && bd.$2 == now.month) {
      today.add(uid);
    }
  }));
  return today;
});
