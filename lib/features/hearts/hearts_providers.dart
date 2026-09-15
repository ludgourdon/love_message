import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'heart.dart';
import 'hearts_repository.dart';

final heartsRepositoryProvider = Provider<HeartsRepository>(
  (ref) => HeartsRepository(FirebaseFirestore.instance),
);

/// Coeurs recus par l'utilisateur connecte, en temps reel.
final receivedHeartsProvider = StreamProvider<List<Heart>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<List<Heart>>.value(const []);
  return ref.watch(heartsRepositoryProvider).watchReceived(user.uid);
});

/// Nombre de coeurs recus non encore vus (pour le badge de l'onglet Recevoir).
final unseenHeartsCountProvider = Provider<int>((ref) {
  final hearts = ref.watch(receivedHeartsProvider).value ?? const [];
  return hearts.where((h) => !h.seen).length;
});
