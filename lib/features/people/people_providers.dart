import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'loved_one.dart';
import 'people_repository.dart';

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepository(FirebaseFirestore.instance),
);

/// Proches de l'utilisateur connecte, en temps reel.
final peopleProvider = StreamProvider<List<LovedOne>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<List<LovedOne>>.value(const []);
  return ref.watch(peopleRepositoryProvider).watchPeople(user.uid);
});
