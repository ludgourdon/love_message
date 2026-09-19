import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../notifications/notifications_providers.dart';
import '../ads/ad_banner.dart';
import '../hearts/heart.dart';
import '../hearts/hearts_providers.dart';
import '../profile/profile_providers.dart';

const _kLittleWords = <String>[
  'Je pense à toi 🌸',
  'Tu es mon petit soleil ☀️',
  'Un gros câlin 🧸',
  'Juste parce que je t’aime 💗',
];

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
  @override
  Widget build(BuildContext context) {
    final incomingCount =
        ref.watch(incomingRequestsProvider).value?.length ?? 0;
    final unseenHearts = ref.watch(unseenHeartsCountProvider);
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
                    style: TextButton.styleFrom(foregroundColor: kPink),
                  ),
                  Badge.count(
                    count: incomingCount,
                    isLabelVisible: incomingCount > 0,
                    child: IconButton(
                      onPressed: () => context.push('/requests'),
                      icon: const Icon(Icons.notifications_none_rounded),
                      color: kPink,
                      tooltip: 'Demandes',
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.account_circle_outlined),
                    color: kPink,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const _VerifyEmailBanner(),
        const Text(
          'Mon petit monde',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'À qui veux-tu envoyer de l’amour aujourd’hui ?',
          style: TextStyle(fontSize: 16),
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
                            color: kPink,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kPink.withValues(alpha: .35),
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
                        for (final word in _kLittleWords)
                          ChoiceChip(
                            label: Text(word),
                            selected: _message.text == word,
                            selectedColor: kPink.withValues(alpha: .2),
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
                  backgroundColor: kPink,
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
      data: (all) => _content(all, aliasByUid),
    );
  }

  Widget _content(List<Heart> hearts, Map<String, String> aliasByUid) {
    final total = hearts.fold<int>(0, (sum, h) => sum + h.count);
    // Total de cœurs reçus par contact (expéditeur).
    final countByUid = <String, int>{};
    final nameByUid = <String, String>{};
    for (final h in hearts) {
      countByUid[h.fromUid] = (countByUid[h.fromUid] ?? 0) + h.count;
      nameByUid[h.fromUid] = aliasByUid[h.fromUid] ?? h.fromName;
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
        const Text('Une pluie d’amour',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
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
        if (senders.length > 1) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Par personne',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          for (final uid in senders) ...[
            _SenderTotalRow(
              name: nameByUid[uid] ?? 'Quelqu\'un',
              count: countByUid[uid]!,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Tes cœurs reçus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        for (final h in hearts) ...[
          _HeartTile(
            heart: h,
            displayName: aliasByUid[h.fromUid] ?? h.fromName,
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
  const _SenderTotalRow({required this.name, required this.count});
  final String name;
  final int count;
  @override
  Widget build(BuildContext context) {
    final s = count > 1 ? 's' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$count cœur$s 💗',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kPink),
          ),
        ],
      ),
    );
  }
}

class _HeartTile extends StatelessWidget {
  const _HeartTile({required this.heart, required this.displayName});
  final Heart heart;
  final String displayName;
  @override
  Widget build(BuildContext context) => Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      't\u2019envoie ${heart.count} c\u0153ur${heart.count > 1 ? 's' : ''} \ud83d\udc97'),
                  if (heart.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\u00ab ${heart.message} \u00bb',
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, color: kInk),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});
  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  var _annual = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: kCream, title: const Text('Cœur à cœur+')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: Text('💗', style: TextStyle(fontSize: 84))),
        const SizedBox(height: 8),
        const Text(
          'Un petit monde\nsans publicité',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Parce que les moments d’amour méritent de rester doux.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        const _Benefit(Icons.favorite_rounded, 'Tous tes cœurs et tes proches'),
        const _Benefit(
          Icons.auto_awesome_rounded,
          'Toutes les animations de base',
        ),
        const _Benefit(Icons.block_rounded, 'Aucune publicité'),
        const SizedBox(height: 18),
        _Plan(
          'Mensuel',
          'Flexible',
          '2,99 € / mois',
          !_annual,
          () => setState(() => _annual = false),
        ),
        const SizedBox(height: 12),
        _Plan(
          'Annuel',
          'Économise · 2,08 € / mois',
          '24,99 € / an',
          _annual,
          () => setState(() => _annual = true),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => _comingSoon(context),
          style: FilledButton.styleFrom(
            backgroundColor: kPink,
            minimumSize: const Size.fromHeight(56),
          ),
          child: const Text('Continuer vers Premium 💕'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Annulable à tout moment · Conditions et confidentialité',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, color: kPink),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Plan extends StatelessWidget {
  const _Plan(this.title, this.subtitle, this.price, this.selected, this.onTap);
  final String title, subtitle, price;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? kPink.withValues(alpha: .12) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kPink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? kPink : kInk,
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
                  Text(subtitle),
                ],
              ),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
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
  const HeartsCelebration({super.key, required this.count, required this.onDone});

  final int count;
  final VoidCallback onDone;

  @override
  State<HeartsCelebration> createState() => _HeartsCelebrationState();
}

class _HeartsCelebrationState extends State<HeartsCelebration>
    with SingleTickerProviderStateMixin {
  static const _emojis = ['💗', '💖', '💕', '❤️', '💞', '🩷'];

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
        emoji: _emojis[rand.nextInt(_emojis.length)],
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
                  color: kPink.withValues(alpha: .35),
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
