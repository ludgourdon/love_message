import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
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
