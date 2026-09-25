import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../people/loved_one.dart';
import '../people/people_providers.dart';
import 'blocks_repository.dart';

final blocksRepositoryProvider = Provider<BlocksRepository>(
  (ref) => BlocksRepository(FirebaseFirestore.instance),
);

/// uid bloqués par l'utilisateur courant.
final blockedUidsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<Set<String>>.value(const <String>{});
  return ref.watch(blocksRepositoryProvider).watchBlocked(user.uid);
});

/// uid des proches connectés qui ont bloqué l'utilisateur courant.
/// (Chaque check lit uniquement le doc users/{proche}/blocked/{moi}.)
final blockedByUidsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const <String>{};
  final people = ref.watch(peopleProvider).value ?? const <LovedOne>[];
  final repo = ref.watch(blocksRepositoryProvider);
  final linked = <String>{
    for (final p in people)
      if (p.linkedUid != null && p.linkedUid!.isNotEmpty) p.linkedUid!,
  };
  final blockedBy = <String>{};
  await Future.wait(linked.map((uid) async {
    if (await repo.isBlockedBy(uid, user.uid)) blockedBy.add(uid);
  }));
  return blockedBy;
});
