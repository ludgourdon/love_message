import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'connection_request.dart';
import 'connections_repository.dart';
import 'directory_repository.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>(
  (ref) => DirectoryRepository(FirebaseFirestore.instance),
);

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(FirebaseFirestore.instance),
);

/// Demandes recues en attente (pour le badge + l'ecran des demandes).
final incomingRequestsProvider =
    StreamProvider<List<ConnectionRequest>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<List<ConnectionRequest>>.value(const []);
  return ref.watch(connectionsRepositoryProvider).watchIncoming(user.uid);
});

/// Demandes envoyees (pour deriver le statut des cartes).
final outgoingRequestsProvider =
    StreamProvider<List<ConnectionRequest>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<List<ConnectionRequest>>.value(const []);
  return ref.watch(connectionsRepositoryProvider).watchOutgoing(user.uid);
});
