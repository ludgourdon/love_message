import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../hearts/heart.dart';
import '../hearts/hearts_providers.dart';
import '../people/loved_one.dart';
import '../people/people_providers.dart';
import '../profile/profile_providers.dart';
import '../notifications/notifications_providers.dart';
import 'connection_providers.dart';
import 'connections_repository.dart';

/// Centre de notifications : demandes de connexion, cœurs reçus récemment,
/// anniversaires du jour et nouvelles connexions via invitation.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Marque la page comme vue → réinitialise le compteur de la cloche.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsLastOpenedProvider.notifier).markOpened();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(incomingRequestsProvider).value ?? const [];
    final hearts = ref.watch(receivedHeartsProvider).value ?? const <Heart>[];
    final people = ref.watch(peopleProvider).value ?? const <LovedOne>[];
    final birthdays =
        ref.watch(birthdayTodayUidsProvider).value ?? const <String>{};
    final redeemed = ref.watch(redeemedInvitationsProvider).value ??
        const <RedeemedInvitation>[];

    final nameByUid = <String, String>{
      for (final p in people)
        if (p.linkedUid != null && p.linkedUid!.isNotEmpty)
          p.linkedUid!: p.name,
    };
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    // Uniquement les cœurs non encore consultés : ils disparaissent des
    // notifications dès qu'ils ont été vus.
    final recentHearts = hearts
        .where((h) =>
            !h.seen &&
            (h.createdAt == null || h.createdAt!.isAfter(weekAgo)))
        .take(12)
        .toList();
    final birthdayUids = birthdays.toList();

    final hasAny = requests.isNotEmpty ||
        recentHearts.isNotEmpty ||
        birthdayUids.isNotEmpty ||
        redeemed.isNotEmpty;

    void openHearts(String uid) {
      ref.read(pendingNotificationTapProvider.notifier).set(
            PendingTap('hearts', uid),
          );
      context.go('/');
    }

    void openSend(String uid) {
      ref
          .read(pendingNotificationTapProvider.notifier)
          .set(PendingTap('send', uid));
      context.go('/');
    }

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Notifications')),
      body: !hasAny
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Rien de neuf pour le moment 💌',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (requests.isNotEmpty) ...[
                  const _SectionTitle('Demandes de connexion'),
                  for (final r in requests)
                    _RequestCard(
                      username: r.fromUsername,
                      onAccept: () =>
                          ref.read(connectionsRepositoryProvider).accept(r),
                      onDecline: () => ref
                          .read(connectionsRepositoryProvider)
                          .decline(r.id),
                    ),
                  const SizedBox(height: 8),
                ],
                if (birthdayUids.isNotEmpty) ...[
                  const _SectionTitle('Anniversaires du jour'),
                  for (final uid in birthdayUids)
                    _NotifTile(
                      emoji: '🎂',
                      title: 'C\'est l\'anniversaire de '
                          '${nameByUid[uid] ?? 'un proche'} !',
                      subtitle: 'Touche pour lui envoyer des cœurs',
                      onTap: () => openSend(uid),
                    ),
                  const SizedBox(height: 8),
                ],
                if (redeemed.isNotEmpty) ...[
                  const _SectionTitle('Nouvelles connexions'),
                  for (final inv in redeemed)
                    _NotifTile(
                      emoji: '💗',
                      title:
                          '${inv.personName.isNotEmpty ? inv.personName : inv.toDisplayName} '
                          'a rejoint via ton invitation',
                      subtitle: 'Vous êtes maintenant connectés',
                    ),
                  const SizedBox(height: 8),
                ],
                if (recentHearts.isNotEmpty) ...[
                  const _SectionTitle('Cœurs reçus'),
                  for (final h in recentHearts)
                    _NotifTile(
                      emoji: '💌',
                      title:
                          '${nameByUid[h.fromUid] ?? h.fromName} t\'envoie '
                          '${h.count} cœur${h.count > 1 ? 's' : ''}',
                      subtitle: h.message.isNotEmpty ? '« ${h.message} »' : null,
                      onTap: () => openHearts(h.fromUid),
                    ),
                ],
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.username,
    required this.onAccept,
    required this.onDecline,
  });
  final String username;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('@$username',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('souhaite se connecter avec toi 💗'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDecline, child: const Text('Refuser')),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPink),
                onPressed: onAccept,
                child: const Text('Accepter'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.emoji,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 26)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing:
          onTap != null ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: onTap,
    ),
  );
}
