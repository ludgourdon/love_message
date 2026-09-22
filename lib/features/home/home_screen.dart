import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import '../connections/connection_providers.dart';
import '../connections/connections_repository.dart';
import '../people/loved_one.dart';
import '../people/people_providers.dart';
import '../people/person_editor.dart';
import '../blocks/blocks_providers.dart';
import '../bond/bond_streak.dart';
import '../notifications/notifications_providers.dart';
import '../ads/ad_banner.dart';
import '../premium/premium_prefs.dart';
import '../hearts/heart.dart';
import '../hearts/hearts_providers.dart';
import '../profile/profile_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;
  int? _celebration;
  int _celebrationSeq = 0;
  String? _heartsUid;
  final Set<String> _animatedHeartIds = <String>{};
  final Set<String> _reconciling = <String>{};
  String? _notifUid;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    // App ouverte depuis une notification alors qu'elle était fermée.
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _handleNotificationTap(m);
    });
    // App en arrière-plan puis notification tapée.
    _openedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  @override
  void dispose() {
    _openedAppSub?.cancel();
    super.dispose();
  }

  /// Mémorise la cible d'ouverture demandée par le tap ; la navigation réelle
  /// se fait dans build() une fois les proches chargés.
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final fromUid = (data['fromUid'] ?? '').toString();
    if (type == 'reply_reminder') {
      // Relance : on ouvre l'écran d'envoi vers la personne (ou l'onglet
      // « Recevoir » si la relance concernait plusieurs personnes).
      ref.read(pendingNotificationTapProvider.notifier).set(fromUid);
    } else if (type == 'heart') {
      // Réception : on ouvre l'onglet « Recevoir » pour voir les cœurs reçus.
      ref.read(pendingNotificationTapProvider.notifier).set('');
    }
  }

  /// Consomme une cible en attente : ouvre l'écran d'envoi vers le proche
  /// concerné, ou à défaut l'onglet « Recevoir ».
  void _handlePendingTap(String pending, List<LovedOne>? people) {
    if (_navigating) return;
    // Pour une cible précise, on attend que la liste des proches soit prête.
    if (pending.isNotEmpty && people == null) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingNotificationTapProvider.notifier).clear();
      if (!mounted) {
        _navigating = false;
        return;
      }
      LovedOne? target;
      if (pending.isNotEmpty && people != null) {
        for (final p in people) {
          if (p.linkedUid == pending) {
            target = p;
            break;
          }
        }
      }
      if (target != null) {
        _openSend(target);
      } else {
        setState(() => _tab = 1); // onglet « Recevoir »
      }
      _navigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final incomingCount =
        ref.watch(incomingRequestsProvider).value?.length ?? 0;
    final unseenHearts = ref.watch(unseenHeartsCountProvider);
    final accent = ref.watch(themeAccentProvider).seed;
    final pendingTap = ref.watch(pendingNotificationTapProvider);
    if (pendingTap != null) {
      _handlePendingTap(pendingTap, ref.watch(peopleProvider).value);
    }
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid != _heartsUid) {
      _heartsUid = uid;
      _animatedHeartIds.clear();
    }
    if (uid != null && uid != _notifUid) {
      _notifUid = uid;
      Future.microtask(
        () => ref.read(notificationsServiceProvider).registerForUser(uid),
      );
    }
    ref.listen<AsyncValue<List<Heart>>>(
      receivedHeartsProvider,
      _onHeartsReceived,
    );
    ref.listen<AsyncValue<List<RedeemedInvitation>>>(
      redeemedInvitationsProvider,
      (prev, next) => _onRedeemedInvitations(next),
    );
    final pages = <Widget>[
      WorldPage(onChoose: _openSend),
      const ReceivePage(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icon/header_wordmark.png',
                    height: 26,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PremiumPage(),
                      ),
                    ),
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Premium'),
                    style: TextButton.styleFrom(foregroundColor: accent),
                  ),
                  Badge.count(
                    count: incomingCount,
                    isLabelVisible: incomingCount > 0,
                    child: IconButton(
                      onPressed: () => context.push('/requests'),
                      icon: const Icon(Icons.notifications_none_rounded),
                      color: accent,
                      tooltip: 'Demandes',
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.account_circle_outlined),
                    color: accent,
                    tooltip: 'Mon profil',
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _tab, children: pages),
            ),
          ],
        ),
      ),
          if (_celebration != null)
            Positioned.fill(
              child: HeartsCelebration(
                key: ValueKey(_celebrationSeq),
                count: _celebration!,
                emojis: ref.watch(animationStyleProvider).emojis,
                glow: accent,
                onDone: () {
                  if (mounted) setState(() => _celebration = null);
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_celebration == null) const AdBanner(),
          NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Mon monde',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: unseenHearts,
              isLabelVisible: unseenHearts > 0,
              child: const Icon(Icons.auto_awesome_outlined),
            ),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: 'Recevoir',
          ),
        ],
          ),
        ],
      ),
    );
  }

  void _openSend(LovedOne person) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SendLovePage(person: person)));

  void _onTabSelected(int value) {
    final previous = _tab;
    setState(() => _tab = value);
    // On marque les coeurs comme vus en QUITTANT l'onglet Recevoir : ils
    // restent affiches pendant la consultation, puis disparaissent ensuite.
    if (previous == 1 && value != 1) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        _markSeen(uid);
      }
    }
  }

  Future<void> _markSeen(String uid) async {
    try {
      await ref.read(heartsRepositoryProvider).markAllSeen(uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marquage "vus" echoue : $e')),
        );
      }
    }
  }

  // Cote invitant : integre automatiquement les invites qui ont accepte.
  void _onRedeemedInvitations(AsyncValue<List<RedeemedInvitation>> value) {
    final list = value.value;
    final uid = ref.read(authStateProvider).value?.uid;
    if (list == null || uid == null) return;
    final repo = ref.read(connectionsRepositoryProvider);
    for (final inv in list) {
      if (_reconciling.contains(inv.code)) continue;
      _reconciling.add(inv.code);
      repo.reconcileInvitation(inv, uid).catchError((_) {
        // Un echec sera retente au prochain snapshot.
      }).whenComplete(() => _reconciling.remove(inv.code));
    }
  }

  void _onHeartsReceived(
    AsyncValue<List<Heart>>? previous,
    AsyncValue<List<Heart>> next,
  ) {
    // On ignore les etats transitoires (chargement, reconnexion en cours).
    if (next.isLoading) return;
    final list = next.value;
    if (list == null) return;

    // Coeurs encore non-vus a cet instant.
    final unseen = list.where((h) => !h.seen).toList();
    // Au moins un non-vu pas encore anime cette session ?
    final hasNew = unseen.any((h) => !_animatedHeartIds.contains(h.id));
    // On memorise tous les non-vus courants comme deja animes (evite la boucle).
    _animatedHeartIds
      ..clear()
      ..addAll(unseen.map((h) => h.id));
    if (!hasNew) return;

    // On anime avec le TOTAL des coeurs encore non-vus.
    final totalUnseen = unseen.fold<int>(0, (sum, h) => sum + h.count);
    if (totalUnseen > 0) {
      setState(() {
        _tab = 0;
        _celebration = totalUnseen;
        _celebrationSeq++;
      });
    }
  }
}

class WorldPage extends ConsumerWidget {
  const WorldPage({super.key, required this.onChoose});
  final ValueChanged<LovedOne> onChoose;

  /// Libelle + couleur du statut de connexion, ou null si proche local simple.
  (String, Color)? _statusFor(LovedOne person, Map<String, String> byRequest) {
    switch (person.linkStatus) {
      case 'accepted':
        // Compte connecte : pas de badge.
        return null;
      case 'invited':
        return ('Invité ✉️', kLavender);
      case 'pending':
        // Cote expediteur : le statut reel vient de la demande envoyee.
        final rid = person.requestId;
        final status =
            rid != null ? (byRequest[rid] ?? 'pending') : 'pending';
        switch (status) {
          case 'accepted':
            // Connecte : pas de badge.
            return null;
          case 'declined':
            return ('Refusé', Colors.redAccent);
          default:
            return ('En attente ⏳', kInk);
        }
      default:
        return null;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LovedOne person,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer ${person.name} ?'),
        content: const Text('Ce proche sera retiré de ton petit monde.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPink),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(peopleRepositoryProvider).delete(user.uid, person.id);
    }
  }

  Future<void> _confirmBlock(
    BuildContext context,
    WidgetRef ref,
    LovedOne person,
  ) async {
    final user = ref.read(authStateProvider).value;
    final blockedUid = person.linkedUid;
    if (user == null || blockedUid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bloquer ${person.name} ?'),
        content: Text(
          '${person.name} ne pourra plus t\'envoyer de cœurs. '
          'Tu pourras le débloquer à tout moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(blocksRepositoryProvider)
          .block(user.uid, blockedUid, name: person.name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${person.name} a été bloqué.')),
        );
      }
    }
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    LovedOne person,
  ) async {
    final user = ref.read(authStateProvider).value;
    final blockedUid = person.linkedUid;
    if (user == null || blockedUid == null) return;
    await ref.read(blocksRepositoryProvider).unblock(user.uid, blockedUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${person.name} a été débloqué 💗')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleProvider);
    final outgoing = ref.watch(outgoingRequestsProvider).value ?? const [];
    final statusByRequest = <String, String>{
      for (final r in outgoing) r.id: r.status,
    };
    final blocked = ref.watch(blockedUidsProvider).value ?? const <String>{};
    final deletedAccounts =
        ref.watch(deletedLinkedUidsProvider).value ?? const <String>{};
    final streaks = ref.watch(bondStreaksProvider);
    final bondStyleIndex = ref.watch(bondStyleIndexProvider);
    final accent = ref.watch(themeAccentProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const _VerifyEmailBanner(),
        Text(
          'Mon petit monde',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.2,
            color: accent.seed,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Les personnes qui comptent, réunies ici.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: kInk.withValues(alpha: .70),
          ),
        ),
        const SizedBox(height: 24),
        peopleAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: kPink)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Impossible de charger tes proches.\n$e'),
          ),
          data: (people) {
            if (people.isEmpty) {
              return const Column(
                children: [
                  _EmptyPeople(),
                  SizedBox(height: 20),
                ],
              );
            }
            return Column(
              children: [
                for (final person in people) ...[
                  _PersonCard(
                    person: person,
                    status: _statusFor(person, statusByRequest),
                    blocked: person.linkedUid != null &&
                        blocked.contains(person.linkedUid),
                    accountDeleted: person.linkedUid != null &&
                        deletedAccounts.contains(person.linkedUid),
                    streak: (person.linkedUid != null &&
                            !deletedAccounts.contains(person.linkedUid))
                        ? streaks[person.linkedUid]
                        : null,
                    bondStyleIndex: bondStyleIndex,
                    onTap: () {
                      if (person.linkedUid != null &&
                          deletedAccounts.contains(person.linkedUid)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Ce compte a été supprimé. Tu ne peux plus lui '
                                'envoyer de cœurs.'),
                          ),
                        );
                        return;
                      }
                      if (person.linkStatus == 'invited') {
                        final uid = ref.read(authStateProvider).value?.uid;
                        if (uid != null) {
                          reshareInvitation(ref,
                              uid: uid, personName: person.name);
                        }
                      } else {
                        onChoose(person);
                      }
                    },
                    onEdit: () =>
                        showPersonEditor(context, ref, existing: person),
                    onDelete: () => _confirmDelete(context, ref, person),
                    onBlock: person.linkedUid == null
                        ? null
                        : () => _confirmBlock(context, ref, person),
                    onUnblock: person.linkedUid == null
                        ? null
                        : () => _unblock(context, ref, person),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => showPersonEditor(context, ref),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Ajouter quelqu’un'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => context.push('/redeem'),
          icon: const Icon(Icons.card_giftcard_rounded, size: 18),
          label: const Text('J’ai un code d’invitation'),
          style: TextButton.styleFrom(foregroundColor: kPink),
        ),
      ],
    );
  }
}

class _EmptyPeople extends StatelessWidget {
  const _EmptyPeople();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: kLavender.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Column(
      children: [
        Text('🌱', style: TextStyle(fontSize: 44)),
        SizedBox(height: 12),
        Text(
          'Ton petit monde est encore vide',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          'Ajoute une personne que tu aimes pour commencer à lui envoyer des cœurs.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _VerifyEmailBanner extends ConsumerWidget {
  const _VerifyEmailBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(emailVerifiedProvider);
    if (verified) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kLavender.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, color: kPink),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vérifie ton adresse email',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tant que ton email n\'est pas validé, tu ne peux pas ajouter de '
            'proche ni être ajouté. Ouvre le lien reçu par email, puis appuie '
            'sur « J\'ai validé ».',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPink),
                onPressed: () => _checkVerified(context, ref),
                child: const Text('J\'ai validé'),
              ),
              TextButton(
                onPressed: () => _resend(context, ref),
                style: TextButton.styleFrom(foregroundColor: kPink),
                child: const Text('Renvoyer l\'email'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkVerified(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final verified = await auth.reloadAndCheckVerified();
    ref.read(emailVerifiedProvider.notifier).set(verified);
    if (verified) {
      // Attribue le nom d'utilisateur maintenant que le compte est vérifié.
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref.read(directoryRepositoryProvider).ensureUsername(
              uid: user.uid,
              displayName: user.displayName ?? '',
              email: user.email,
            );
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Email validé ✅')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pas encore validé. Ouvre le lien reçu par email.'),
        ),
      );
    }
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authRepositoryProvider).resendVerificationEmail();
    messenger.showSnackBar(
      const SnackBar(content: Text('Email de vérification renvoyé 💌')),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.status,
    this.blocked = false,
    this.accountDeleted = false,
    this.onBlock,
    this.onUnblock,
    this.streak,
    this.bondStyleIndex = 0,
  });
  final LovedOne person;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final (String, Color)? status;
  final bool blocked;
  final bool accountDeleted;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final BondStreak? streak;
  final int bondStyleIndex;

  void _showMenu(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!accountDeleted)
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: kPink),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onEdit();
              },
            ),
          if (!accountDeleted && (onBlock != null || onUnblock != null))
            ListTile(
              leading: Icon(
                blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                color: blocked ? const Color(0xFF2E9E6B) : Colors.redAccent,
              ),
              title: Text(blocked ? 'Débloquer' : 'Bloquer'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (blocked) {
                  onUnblock?.call();
                } else {
                  onBlock?.call();
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: kPink),
            title: const Text('Supprimer'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onDelete();
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final statusData = status;
    return Material(
      color: person.color,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        onLongPress: () => _showMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white70,
                child: Text(person.emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (person.note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(person.note),
                    ],
                    if (accountDeleted) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Compte supprimé',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ] else if (blocked) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Bloqué 🚫',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ] else if (statusData != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusData.$1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusData.$2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (streak != null && streak!.days > 0) ...[
                _BondBadge(streak: streak!, styleIndex: bondStyleIndex),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: () => _showMenu(context),
                icon: const Icon(Icons.more_vert, color: kInk),
                tooltip: 'Options',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choisit l'emoji du lien selon le style (0 = flamme, 1 = fleur qui s'ouvre)
/// et le nombre de jours.
String _bondEmojiFor(int styleIndex, int days) {
  if (styleIndex == 1) {
    if (days >= 30) return '🌺';
    if (days >= 14) return '🌸';
    if (days >= 7) return '🌷';
    if (days >= 3) return '🌿';
    return '🌱';
  }
  return '🔥'; // la flamme grandit via la taille
}

/// Petit badge de lien affiché sur la carte d'un proche.
class _BondBadge extends StatelessWidget {
  const _BondBadge({required this.streak, required this.styleIndex});
  final BondStreak streak;
  final int styleIndex;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = streak.completeToday;
    final emoji = _bondEmojiFor(styleIndex, streak.days);
    // La flamme grandit avec les jours ; la fleur garde une taille stable
    // (c'est l'emoji qui "s'ouvre").
    final size =
        styleIndex == 0 ? 18.0 + streak.days.clamp(0, 12) * 1.3 : 26.0;
    return Tooltip(
      message: active
          ? 'Lien entretenu aujourd\'hui'
          : 'À entretenir aujourd\'hui',
      child: Opacity(
        opacity: active ? 1 : .55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: size)),
            Text(
              '${streak.days} j',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? primary : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SendLovePage extends ConsumerStatefulWidget {
  const SendLovePage({super.key, required this.person});
  final LovedOne person;
  @override
  ConsumerState<SendLovePage> createState() => _SendLovePageState();
}

class _SendLovePageState extends ConsumerState<SendLovePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _message = TextEditingController();
  var _count = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _message.dispose();
    super.dispose();
  }

  void _sendHeart() {
    setState(() => _count++);
    _controller.forward(from: 0);
  }

  void _pickWord(String word) {
    setState(() {
      _message.text = word;
      _message.selection = TextSelection.collapsed(offset: word.length);
    });
  }

  Future<void> _confirmSend() async {
    final person = widget.person;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final s = _count > 1 ? 's' : '';
    final message = _message.text.trim();

    // Email obligatoirement vérifié pour envoyer des cœurs.
    final verified =
        await ref.read(authRepositoryProvider).reloadAndCheckVerified();
    ref.read(emailVerifiedProvider.notifier).set(verified);
    if (!verified) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Valide ton adresse email avant d\'envoyer des cœurs '
              '(un lien t\'a été envoyé à l\'inscription).'),
        ),
      );
      return;
    }

    final linkedUid = person.linkedUid;

    var connected = false;
    if (linkedUid != null) {
      if (person.linkStatus == 'accepted') {
        connected = true;
      } else if (person.requestId != null) {
        final outgoing = ref.read(outgoingRequestsProvider).value ?? const [];
        connected = outgoing
            .any((r) => r.id == person.requestId && r.status == 'accepted');
      }
    }

    if (linkedUid != null && connected) {
      final me = ref.read(authStateProvider).value;
      if (me == null) return;
      final profile = ref.read(userProfileProvider).value;
      String? pick(String? v) =>
          (v != null && v.trim().isNotEmpty) ? v.trim() : null;
      final myName = pick(profile?.displayName) ??
          pick(me.displayName) ??
          pick(profile?.username) ??
          pick(me.email?.split('@').first) ??
          'Quelqu\'un';
      setState(() => _sending = true);
      try {
        await ref.read(heartsRepositoryProvider).send(
              fromUid: me.uid,
              fromName: myName,
              toUid: linkedUid,
              count: _count,
              message: message,
            );
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(content: Text('$_count cœur$s envoyé$s à ${person.name} 💌')),
        );
      } catch (e) {
        if (mounted) setState(() => _sending = false);
        final blocked = e.toString().contains('permission-denied');
        messenger.showSnackBar(
          SnackBar(
            content: Text(blocked
                ? 'Tes cœurs n\'ont pas pu être envoyés à cette personne.'
                : 'Échec de l\'envoi : $e'),
          ),
        );
      }
      return;
    }

    if (linkedUid != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Ce proche n\'a pas encore accepté la connexion — tu pourras lui '
              'envoyer des cœurs une fois connecté.'),
        ),
      );
      return;
    }

    _sent(context, _count, person.name);
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(wordPackProvider);
    final accent = ref.watch(themeAccentProvider).seed;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  Text(
                    'Pour ${widget.person.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      _count == 0
                          ? 'Appuie pour envoyer de l’amour'
                          : 'Encore un peu d’amour !',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _sendHeart,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) => Transform.scale(
                          scale: 1 + math.sin(_controller.value * math.pi) * .12,
                          child: child,
                        ),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: .35),
                                blurRadius: 28,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 120,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '💗 × $_count',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text('Chaque appui prépare un cœur pour ton proche.'),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ajouter un petit mot (facultatif)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final word in pack.words)
                          ChoiceChip(
                            label: Text(word),
                            selected: _message.text == word,
                            selectedColor: accent.withValues(alpha: .2),
                            onSelected: (_) => _pickWord(word),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _message,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [LengthLimitingTextInputFormatter(26)],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Ton petit mot…',
                        prefixIcon: Icon(Icons.mode_edit_outline),
                        border: OutlineInputBorder(),
                        helperText: '26 caractères max en saisie libre',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton.icon(
                onPressed: (_count == 0 || _sending) ? null : _confirmSend,
                icon: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending
                      ? 'Envoi...'
                      : (_count == 0
                          ? 'Envoie quelques cœurs'
                          : 'Envoyer $_count cœur${_count > 1 ? 's' : ''}'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceivePage extends ConsumerWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receivedHeartsProvider);
    // Alias local : le nom que J'AI donne a chaque expediteur (par compte lie).
    final people = ref.watch(peopleProvider).value ?? const <LovedOne>[];
    final aliasByUid = <String, String>{
      for (final p in people)
        if (p.linkedUid != null && p.linkedUid!.isNotEmpty) p.linkedUid!: p.name,
    };
    // Proche lié à chaque expéditeur (pour pouvoir lui répondre).
    final personByUid = <String, LovedOne>{
      for (final p in people)
        if (p.linkedUid != null && p.linkedUid!.isNotEmpty) p.linkedUid!: p,
    };
    // Comptes supprimés : on ne propose pas d'y répondre.
    final deleted =
        ref.watch(deletedLinkedUidsProvider).value ?? const <String>{};
    final accentSeed = ref.watch(themeAccentProvider).seed;
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: kPink)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Impossible de charger les cœurs reçus.\n$e',
              textAlign: TextAlign.center),
        ),
      ),
      data: (all) => _content(
          context, all, aliasByUid, personByUid, deleted, accentSeed),
    );
  }

  Widget _content(
    BuildContext context,
    List<Heart> hearts,
    Map<String, String> aliasByUid,
    Map<String, LovedOne> personByUid,
    Set<String> deleted,
    Color accentSeed,
  ) {
    final total = hearts.fold<int>(0, (sum, h) => sum + h.count);
    // Total de cœurs reçus par contact (expéditeur).
    final countByUid = <String, int>{};
    final nameByUid = <String, String>{};
    for (final h in hearts) {
      countByUid[h.fromUid] = (countByUid[h.fromUid] ?? 0) + h.count;
      nameByUid[h.fromUid] = aliasByUid[h.fromUid] ?? h.fromName;
    }
    final heartsByUid = <String, List<Heart>>{};
    for (final h in hearts) {
      (heartsByUid[h.fromUid] ??= <Heart>[]).add(h);
    }
    final senders = countByUid.keys.toList()
      ..sort((a, b) => countByUid[b]!.compareTo(countByUid[a]!));
    if (hearts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨  💗  ✨', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text('Une pluie d’amour',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                'Ici, les nouveaux cœurs reçus apparaîtront comme une petite fête.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(
          'Une pluie d’amour',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.2,
            color: accentSeed,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kLavender.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Text('💗', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              Text('$total',
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w800)),
              Text(
                'cœur${total > 1 ? 's' : ''} reçu${total > 1 ? 's' : ''} en tout',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final uid in senders) ...[
          _SenderTotalRow(
            name: nameByUid[uid] ?? 'Quelqu\'un',
            count: countByUid[uid]!,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _SenderHeartsPage(
                  name: nameByUid[uid] ?? 'Quelqu\'un',
                  hearts: heartsByUid[uid] ?? const <Heart>[],
                  person: deleted.contains(uid) ? null : personByUid[uid],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

String _heartDateLabel(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'le ${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';
}

class _SenderTotalRow extends StatelessWidget {
  const _SenderTotalRow({required this.name, required this.count, this.onTap});
  final String name;
  final int count;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = count > 1 ? 's' : '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$count cœur$s 💗',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kPink),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: kInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail : toutes les réceptions de cœurs d'une même personne.
class _SenderHeartsPage extends StatelessWidget {
  const _SenderHeartsPage({
    required this.name,
    required this.hearts,
    this.person,
  });
  final String name;
  final List<Heart> hearts;
  final LovedOne? person;

  @override
  Widget build(BuildContext context) {
    final total = hearts.fold<int>(0, (sum, h) => sum + h.count);
    final target = person;
    void reply() {
      if (target == null) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SendLovePage(person: target)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Cœurs de $name')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            '$total cœur${total > 1 ? 's' : ''} reçu${total > 1 ? 's' : ''} '
            'de $name',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final h in hearts) ...[
            _HeartTile(
              heart: h,
              displayName: name,
              onReply: (!h.seen && target != null) ? reply : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HeartTile extends StatelessWidget {
  const _HeartTile({
    required this.heart,
    required this.displayName,
    this.onReply,
  });
  final Heart heart;
  final String displayName;

  /// Si non nul, la carte devient cliquable pour répondre à ce contact.
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: heart.seen ? Colors.white : kPink.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: heart.seen ? Colors.transparent : kPink,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!heart.seen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kPink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('nouveau',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              if (heart.createdAt != null)
                Text(
                  _heartDateLabel(heart.createdAt!),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💌', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                        't’envoie ${heart.count} cœur${heart.count > 1 ? 's' : ''} 💗'),
                    if (heart.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '« ${heart.message} »',
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, color: kInk),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onReply != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text('Répondre en cœurs',
                    style: TextStyle(
                        color: kPink, fontWeight: FontWeight.w800)),
                SizedBox(width: 4),
                Text('💌'),
                Icon(Icons.chevron_right_rounded, color: kPink, size: 20),
              ],
            ),
          ],
        ],
      ),
    );
    if (onReply == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onReply,
        child: card,
      ),
    );
  }
}

class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key});
  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage> {
  int _previewSeq = 0;
  bool _playingPreview = false;

  void _testAnimation() {
    setState(() {
      _playingPreview = true;
      _previewSeq++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeAccentProvider);
    final animIndex = ref.watch(animationStyleIndexProvider);
    final packIndex = ref.watch(wordPackIndexProvider);
    final themeIndex = ref.watch(themeAccentIndexProvider);
    final bondIndex = ref.watch(bondStyleIndexProvider);
    final anim = kAnimationStyles[animIndex];
    final pack = kWordPacks[packIndex];
    final seed = accent.seed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cœur à cœur+'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(
                child: Text(accent.emoji, style: const TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Personnalise ton\npetit monde',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: seed.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Version découverte : tout est débloqué pour que tu '
                        'puisses essayer librement.',
                        style: TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ---- Thème ----
              const _PremiumSection('🎨', 'Thème'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < kThemeAccents.length; i++)
                    _AccentSwatch(
                      accent: kThemeAccents[i],
                      selected: i == themeIndex,
                      onTap: () =>
                          ref.read(themeAccentIndexProvider.notifier).select(i),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // ---- Animation ----
              const _PremiumSection('✨', 'Animation à la réception'),
              const SizedBox(height: 12),
              for (var i = 0; i < kAnimationStyles.length; i++)
                _ChoiceTile(
                  selected: i == animIndex,
                  seed: seed,
                  onTap: () => ref
                      .read(animationStyleIndexProvider.notifier)
                      .select(i),
                  title: kAnimationStyles[i].name,
                  trailing: Text(
                    kAnimationStyles[i].emojis.take(4).join(' '),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _testAnimation,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Tester « ${anim.name} »'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: seed,
                  side: BorderSide(color: seed),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 28),

              // ---- Packs de petits mots ----
              const _PremiumSection('💬', 'Packs de petits mots'),
              const SizedBox(height: 12),
              for (var i = 0; i < kWordPacks.length; i++)
                _ChoiceTile(
                  selected: i == packIndex,
                  seed: seed,
                  onTap: () =>
                      ref.read(wordPackIndexProvider.notifier).select(i),
                  title: '${kWordPacks[i].emoji}  ${kWordPacks[i].name}',
                  subtitle: kWordPacks[i].words.take(2).join(' · '),
                ),
              const SizedBox(height: 10),
              Text(
                'Aperçu de « ${pack.name} » :',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in pack.words)
                    Chip(
                      label: Text(w),
                      backgroundColor: seed.withValues(alpha: .12),
                      side: BorderSide.none,
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // ---- Style du lien ----
              const _PremiumSection('🔥', 'Style du lien'),
              const SizedBox(height: 6),
              const Text(
                'La récompense qui grandit quand vous vous envoyez des cœurs '
                'chaque jour, tous les deux.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < kBondStyles.length; i++)
                _ChoiceTile(
                  selected: i == bondIndex,
                  seed: seed,
                  onTap: () =>
                      ref.read(bondStyleIndexProvider.notifier).select(i),
                  title: '${kBondStyles[i].emoji}  ${kBondStyles[i].name}',
                  subtitle: i == 0
                      ? 'Une flamme qui grandit jour après jour'
                      : 'Une fleur qui s\'ouvre peu à peu',
                ),
              const SizedBox(height: 28),

              // ---- Proches illimités ----
              const _PremiumSection('♾️', 'Proches illimités'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: seed),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Déjà actif : ajoute autant de proches que tu veux.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 14),
              const Text(
                'Bientôt : passe à Premium pour garder tout ça et retirer la '
                'publicité.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _comingSoon(context),
                style: FilledButton.styleFrom(
                  backgroundColor: seed,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('En savoir plus 💕'),
              ),
            ],
          ),
          if (_playingPreview)
            Positioned.fill(
              child: HeartsCelebration(
                key: ValueKey(_previewSeq),
                count: 14,
                emojis: anim.emojis,
                glow: seed,
                onDone: () {
                  if (mounted) setState(() => _playingPreview = false);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumSection extends StatelessWidget {
  const _PremiumSection(this.emoji, this.title);
  final String emoji, title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final ThemeAccent accent;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: accent.seed,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? kInk : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.seed.withValues(alpha: .35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 66,
          child: Text(
            accent.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.seed,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final bool selected;
  final Color seed;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: selected ? seed.withValues(alpha: .12) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? seed : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? seed : kInk,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    ),
  );
}

void _comingSoon(BuildContext context) => ScaffoldMessenger.of(context)
    .showSnackBar(
      const SnackBar(
        content: Text('Cette fonction sera connectée dans la prochaine étape.'),
      ),
    );
void _sent(BuildContext context, int count, String name) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Text('💌', style: TextStyle(fontSize: 40)),
    title: const Text('Cœurs prêts !'),
    content: Text(
      '$count cœur${count > 1 ? 's' : ''} sont prêts à partir pour $name.',
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        child: const Text('Super !'),
      ),
    ],
  ),
);

/// Overlay de celebration : un compteur central qui pulse, et des coeurs qui
/// montent puis s'estompent. Joue une fois puis appelle [onDone].
class HeartsCelebration extends StatefulWidget {
  const HeartsCelebration({
    super.key,
    required this.count,
    required this.onDone,
    this.emojis = const ['💗', '💖', '💕', '❤️', '💞', '🩷'],
    this.glow = kPink,
  });

  final int count;
  final VoidCallback onDone;
  final List<String> emojis;
  final Color glow;

  @override
  State<HeartsCelebration> createState() => _HeartsCelebrationState();
}

class _HeartsCelebrationState extends State<HeartsCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_FloatingHeart> _hearts;

  @override
  void initState() {
    super.initState();
    final rand = math.Random();
    final n = widget.count.clamp(8, 22);
    _hearts = List.generate(
      n,
      (_) => _FloatingHeart(
        startX: 0.05 + rand.nextDouble() * 0.85,
        drift: (rand.nextDouble() - 0.5) * 0.18,
        delay: rand.nextDouble() * 0.4,
        scale: 0.7 + rand.nextDouble() * 0.9,
        emoji: widget.emojis[rand.nextInt(widget.emojis.length)],
      ),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          final t = _controller.value;
          return Stack(
            children: [
              for (final h in _hearts) _floatingHeart(h, t, size),
              _counter(t),
            ],
          );
        },
      ),
    );
  }

  Widget _floatingHeart(_FloatingHeart h, double t, Size size) {
    final local = ((t - h.delay) / (1 - h.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();
    final top = size.height * (0.78 - local * 0.72);
    final left = size.width * (h.startX + h.drift * local);
    final opacity =
        local < 0.15 ? local / 0.15 : (1 - (local - 0.15) / 0.85);
    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: h.scale,
          child: Text(h.emoji, style: const TextStyle(fontSize: 34)),
        ),
      ),
    );
  }

  Widget _counter(double t) {
    final appear = (t / 0.22).clamp(0.0, 1.0);
    final fade = t > 0.72 ? (1 - (t - 0.72) / 0.28).clamp(0.0, 1.0) : 1.0;
    final opacity = (appear * fade).clamp(0.0, 1.0);
    final scale = 0.6 + appear * 0.45;
    return Center(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: widget.glow.withValues(alpha: .35),
                  blurRadius: 28,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💗', style: TextStyle(fontSize: 46)),
                const SizedBox(height: 4),
                Text(
                  '+${widget.count}',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: kPink,
                  ),
                ),
                Text(
                  'cœur${widget.count > 1 ? 's' : ''} reçu${widget.count > 1 ? 's' : ''} !',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingHeart {
  _FloatingHeart({
    required this.startX,
    required this.drift,
    required this.delay,
    required this.scale,
    required this.emoji,
  });

  final double startX;
  final double drift;
  final double delay;
  final double scale;
  final String emoji;
}
