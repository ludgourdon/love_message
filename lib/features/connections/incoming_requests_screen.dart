import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import 'connection_providers.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomingRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        title: const Text('Demandes de connexion'),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPink)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Impossible de charger les demandes.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucune demande pour le moment 💌',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = requests[i];
              return Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${r.fromUsername}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      const Text('souhaite se connecter avec toi 💗'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => ref
                                .read(connectionsRepositoryProvider)
                                .decline(r.id),
                            child: const Text('Refuser'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style:
                                FilledButton.styleFrom(backgroundColor: kPink),
                            onPressed: () => ref
                                .read(connectionsRepositoryProvider)
                                .accept(r),
                            child: const Text('Accepter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
