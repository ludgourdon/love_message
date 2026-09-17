import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'connection_providers.dart';
import 'connections_repository.dart';

/// Ecran "J'ai un code d'invitation" : l'utilisateur colle le code (ou le lien)
/// recu et se connecte automatiquement a la personne qui l'a invite.
class RedeemInviteScreen extends ConsumerStatefulWidget {
  const RedeemInviteScreen({super.key});

  @override
  ConsumerState<RedeemInviteScreen> createState() => _RedeemInviteScreenState();
}

class _RedeemInviteScreenState extends ConsumerState<RedeemInviteScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Accepte soit un code brut, soit un lien complet (…/invite?code=xxxx).
  String _extractCode(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    final fromLink = uri?.queryParameters['code'];
    if (fromLink != null && fromLink.isNotEmpty) return fromLink;
    return trimmed;
  }

  Future<void> _submit() async {
    final code = _extractCode(_code.text);
    if (code.isEmpty) {
      setState(() => _error = 'Entre le code d\'invitation que tu as recu.');
      return;
    }
    final me = ref.read(authStateProvider).value;
    if (me == null) return;

    // Capture les repos avant tout await.
    final connections = ref.read(connectionsRepositoryProvider);
    final profiles = ref.read(profileRepositoryProvider);

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final myProfile = await profiles.fetchProfile(me.uid);
      final result = await connections.redeemInvitation(
        code: code,
        myUid: me.uid,
        myUsername: myProfile?.username ?? '',
        myDisplayName: myProfile?.displayName ?? me.displayName ?? '',
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tu es maintenant connecte a ${result.inviterName} 💗'),
        ),
      );
      context.go('/');
    } on InvitationException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      // Affiche l'erreur brute pour diagnostic (ex: permission Firestore).
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      _code.text = _extractCode(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        title: const Text('J\'ai un code d\'invitation'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Text('💌', style: TextStyle(fontSize: 64))),
              const SizedBox(height: 16),
              const Text(
                'Connecte-toi a la personne qui t\'a invite',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Colle ici le code (ou le lien) que tu as recu. Vous serez '
                'ajoutes automatiquement dans vos petits mondes respectifs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kInk),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _code,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                // Force la barre d'outils Flutter au lieu du menu systeme iOS
                // (contourne un bug SystemContextMenu sur iOS recent).
                contextMenuBuilder: (context, editableTextState) =>
                    AdaptiveTextSelectionToolbar.editableText(
                  editableTextState: editableTextState,
                ),
                decoration: InputDecoration(
                  labelText: 'Code d\'invitation',
                  hintText: 'ex : a1b2c3d4',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Coller'),
                    style: TextButton.styleFrom(foregroundColor: kPink),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kPink,
                  minimumSize: const Size.fromHeight(56),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Me connecter 💕'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
