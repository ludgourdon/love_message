import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import '../connections/connection_providers.dart';
import '../connections/username.dart';
import '../profile/profile_providers.dart';
import 'loved_one.dart';
import 'people_providers.dart';

const _emojiChoices = <String>[
  '🌷', '☀️', '🧸', '💗', '🌸', '⭐', '🌙', '🐻', '🌊', '🍀', '🎈', '🦋',
];

const _colorChoices = <int>[
  0xFFFFD4E2,
  0xFFFFECB2,
  0xFFD8F4E9,
  0xFFCBB8FF,
  0xFFB8E0FF,
  0xFFFFD9C0,
];

/// Ouvre la feuille d'ajout (existing == null) ou de modification d'un proche.
Future<void> showPersonEditor(
  BuildContext context,
  WidgetRef ref, {
  LovedOne? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PersonEditorSheet(existing: existing),
  );
}

/// Cree une invitation pour [personName] et ouvre la feuille de partage native
/// avec un texte personnalise. Utilisable depuis une carte "Invite".
Future<void> reshareInvitation(
  WidgetRef ref, {
  required String uid,
  required String personName,
}) async {
  final profiles = ref.read(profileRepositoryProvider);
  final connections = ref.read(connectionsRepositoryProvider);
  final myProfile = await profiles.fetchProfile(uid);
  final link = await connections.createInvitation(
    fromUid: uid,
    fromUsername: myProfile?.username ?? '',
    personName: personName,
  );
  final code = Uri.tryParse(link)?.queryParameters['code'] ?? link;
  await SharePlus.instance.share(
    ShareParams(
      text: 'Coucou c\'est ${myProfile?.displayName ?? 'Un ami'}, '
          'rejoins-moi sur Cœur à cœur 💗 !\n'
          'Installe l\'appli, ouvre « J\'ai un code d\'invitation » et entre '
          'ce code : $code',
      subject: 'Invitation Cœur à cœur',
    ),
  );
}

class _PersonEditorSheet extends ConsumerStatefulWidget {
  const _PersonEditorSheet({this.existing});

  final LovedOne? existing;

  @override
  ConsumerState<_PersonEditorSheet> createState() => _PersonEditorSheetState();
}

class _PersonEditorSheetState extends ConsumerState<_PersonEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _note;
  late final TextEditingController _username;
  late String _emoji;
  late int _color;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _username = TextEditingController(text: e?.linkedUsername ?? '');
    _emoji = e?.emoji ?? _emojiChoices.first;
    _color = e != null ? e.color.toARGB32() : _colorChoices.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final peopleRepo = ref.read(peopleRepositoryProvider);
    final name = _name.text.trim();
    final note = _note.text.trim();
    final usernameInput = _username.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Modification : on ne touche pas au lien ici.
      if (_isEdit) {
        await peopleRepo.update(
          user.uid,
          widget.existing!.id,
          name: name,
          note: note,
          emoji: _emoji,
          color: _color,
        );
        navigator.pop();
        return;
      }

      // Profil courant, lu directement dans Firestore (fiable meme si le
      // provider n'a jamais ete observe, ex. ecran Profil jamais ouvert).
      final myProfile =
          await ref.read(profileRepositoryProvider).fetchProfile(user.uid);
      final myUsername = myProfile?.username ?? '';

      // Champ VIDE -> le proche n'a pas de compte : invitation par lien.
      if (usernameInput.isEmpty) {
        final link =
            await ref.read(connectionsRepositoryProvider).createInvitation(
                  fromUid: user.uid,
                  fromUsername: myUsername,
                  personName: name,
                );
        final inviteCode = Uri.tryParse(link)?.queryParameters['code'];
        await peopleRepo.add(
          user.uid,
          name: name,
          note: note,
          emoji: _emoji,
          color: _color,
          linkStatus: 'invited',
          inviteCode: inviteCode,
        );
        navigator.pop();
        await SharePlus.instance.share(
          ShareParams(
            text: 'Coucou c\'est ${myProfile?.displayName ?? 'Un ami'}, '
                'rejoins-moi sur Cœur à cœur 💗 !\n'
                'Installe l\'appli, ouvre « J\'ai un code d\'invitation » et '
                'entre ce code : ${inviteCode ?? link}',
            subject: 'Invitation Cœur à cœur',
          ),
        );
        return;
      }

      // Champ REMPLI -> doit correspondre a un compte existant.
      final formatError = validateUsername(usernameInput);
      if (formatError != null) {
        setState(() {
          _saving = false;
          _error = formatError;
        });
        return;
      }

      if (myUsername.isEmpty) {
        setState(() {
          _saving = false;
          _error =
              'Ton nom d\'utilisateur n\'est pas encore pret. Reessaie dans un instant.';
        });
        return;
      }

      final targetUid =
          await ref.read(directoryRepositoryProvider).lookupUid(usernameInput);

      if (targetUid == user.uid) {
        setState(() {
          _saving = false;
          _error = 'C\'est toi ! Choisis le nom d\'utilisateur de ton proche.';
        });
        return;
      }

      if (targetUid == null) {
        // Compte inexistant -> erreur (pas d'invitation dans ce cas).
        setState(() {
          _saving = false;
          _error = 'Le compte @$usernameInput n\'existe pas. '
              'Laisse le champ vide pour envoyer une invitation.';
        });
        return;
      }

      // Compte trouve -> demande de connexion a accepter.
      final requestId = await ref.read(connectionsRepositoryProvider).sendRequest(
            fromUid: user.uid,
            fromUsername: myUsername,
            fromDisplayName: myProfile?.displayName ?? myUsername,
            toUid: targetUid,
            toUsername: normalizeUsername(usernameInput),
            personName: name,
          );
      await peopleRepo.add(
        user.uid,
        name: name,
        note: note,
        emoji: _emoji,
        color: _color,
        linkedUid: targetUid,
        linkedUsername: usernameInput,
        requestId: requestId,
        linkStatus: 'pending',
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Demande envoyee a @$usernameInput 💌')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Echec de l\'enregistrement. Reessaie.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isEdit ? 'Modifier ce proche' : 'Ajouter quelqu\'un',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              Center(
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(_color),
                  child: Text(_emoji, style: const TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Donne un nom' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Petit mot',
                  hintText: 'Ma personne preferee 🌸',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite_border),
                ),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _username,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Nom d\'utilisateur (optionnel)',
                    prefixText: '@',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    helperMaxLines: 3,
                    helperText:
                        'Rempli : une demande de connexion est envoyee (le compte '
                        'doit exister). Vide : tu partages un lien d\'invitation.',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Emoji', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _emojiChoices)
                    GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: _emoji == e
                            ? kPink.withValues(alpha: .22)
                            : Colors.white,
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Couleur', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _colorChoices)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? kInk : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kPink,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
