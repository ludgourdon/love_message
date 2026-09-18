import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../connections/connection_providers.dart';
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

/// uid des comptes liés qui n'existent plus (compte supprimé) : on le détecte
/// via l'annuaire des pseudos, libéré à la suppression. Recalculé quand la
/// liste des proches change.
final deletedLinkedUidsProvider = FutureProvider<Set<String>>((ref) async {
  final people = ref.watch(peopleProvider).value ?? const <LovedOne>[];
  final dir = ref.watch(directoryRepositoryProvider);
  final linked = <String, String>{}; // linkedUid -> linkedUsername
  for (final p in people) {
    final uid = p.linkedUid;
    final uname = p.linkedUsername;
    if (uid != null && uid.isNotEmpty && uname != null && uname.isNotEmpty) {
      linked[uid] = uname;
    }
  }
  final deleted = <String>{};
  for (final entry in linked.entries) {
    final resolved = await dir.lookupUid(entry.value);
    if (resolved != entry.key) deleted.add(entry.key);
  }
  return deleted;
});
