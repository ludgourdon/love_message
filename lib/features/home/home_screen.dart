import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import '../connections/connection_providers.dart';
import '../people/loved_one.dart';
import '../people/people_providers.dart';
import '../people/person_editor.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;
  @override
  Widget build(BuildContext context) {
    final incomingCount =
        ref.watch(incomingRequestsProvider).value?.length ?? 0;
    final pages = <Widget>[
      WorldPage(onChoose: _openSend),
      const LittleWordsPage(),
      const ReceivePage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Cœur à cœur',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Mon monde',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Petits mots',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Recevoir',
          ),
        ],
      ),
    );
  }

  void _openSend(LovedOne person) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SendLovePage(person: person)));
}

class WorldPage extends ConsumerWidget {
  const WorldPage({super.key, required this.onChoose});
  final ValueChanged<LovedOne> onChoose;

  /// Libelle + couleur du statut de connexion, ou null si proche local simple.
  (String, Color)? _statusFor(LovedOne person, Map<String, String> byRequest) {
    switch (person.linkStatus) {
      case 'accepted':
        // Cote accepteur : la connexion est enregistree directement.
        return ('Connecté ✅', const Color(0xFF2E9E6B));
      case 'invited':
        return ('Invité ✉️', kLavender);
      case 'pending':
        // Cote expediteur : le statut reel vient de la demande envoyee.
        final rid = person.requestId;
        final status =
            rid != null ? (byRequest[rid] ?? 'pending') : 'pending';
        switch (status) {
          case 'accepted':
            return ('Connecté ✅', const Color(0xFF2E9E6B));
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
        content: const Text('Ce proche sera retire de ton petit monde.'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleProvider);
    final outgoing = ref.watch(outgoingRequestsProvider).value ?? const [];
    final statusByRequest = <String, String>{
      for (final r in outgoing) r.id: r.status,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
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
            if (people.isEmpty) return const _EmptyPeople();
            return Column(
              children: [
                for (final person in people) ...[
                  _PersonCard(
                    person: person,
                    status: _statusFor(person, statusByRequest),
                    onTap: () => onChoose(person),
                    onEdit: () =>
                        showPersonEditor(context, ref, existing: person),
                    onDelete: () => _confirmDelete(context, ref, person),
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

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.status,
  });
  final LovedOne person;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final (String, Color)? status;

  void _showMenu(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: kPink),
            title: const Text('Modifier'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onEdit();
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
                    if (statusData != null) ...[
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

class SendLovePage extends StatefulWidget {
  const SendLovePage({super.key, required this.person});
  final LovedOne person;
  @override
  State<SendLovePage> createState() => _SendLovePageState();
}

class _SendLovePageState extends State<SendLovePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _count = 0;
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
    super.dispose();
  }

  void _sendHeart() {
    setState(() => _count++);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
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
            const Spacer(),
            Text(
              _count == 0
                  ? 'Appuie pour envoyer de l’amour'
                  : 'Encore un peu d’amour !',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _sendHeart,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.scale(
                  scale: 1 + math.sin(_controller.value * math.pi) * .12,
                  child: child,
                ),
                child: Container(
                  width: 230,
                  height: 230,
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
                    size: 142,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '💗 × $_count',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Chaque appui prépare un cœur pour ton proche.'),
            const Spacer(),
            FilledButton.icon(
              onPressed: _count == 0
                  ? null
                  : () => _sent(context, _count, widget.person.name),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _count == 0
                    ? 'Envoie quelques cœurs'
                    : 'Envoyer $_count cœur${_count > 1 ? 's' : ''}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kPink,
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LittleWordsPage extends StatelessWidget {
  const LittleWordsPage({super.key});
  static const _words = [
    'Je pense à toi 🌸',
    'Tu es mon petit soleil ☀️',
    'Un gros câlin 🧸',
    'Juste parce que je t’aime 💗',
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    children: [
      const Text(
        'Les petits mots',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text('Choisis un petit message à glisser avec tes cœurs.'),
      const SizedBox(height: 24),
      for (final word in _words) ...[
        Card(
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            title: Text(
              word,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.arrow_forward_rounded, color: kPink),
            onTap: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Petit mot choisi : $word'))),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨  💗  ✨', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'Une pluie d’amour',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ici, les cœurs reçus apparaîtront comme une petite fête.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: kLavender.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              children: [
                Text(
                  'Léa t’envoie plein d’amour 💌',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Tu as reçu 24 cœurs !',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
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
