import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        title: const Text('Mon profil'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kPink)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Impossible de charger le profil.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (profile) {
          final user = ref.watch(authStateProvider).value;
          final name = profile?.displayName ??
              (user?.displayName ?? user?.email?.split('@').first ?? 'Moi');
          final email = profile?.email ?? user?.email ?? '';
          final username = profile?.username;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: kPink.withValues(alpha: .15),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '💗',
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w800, color: kPink),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  username != null ? '@$username' : email,
                  style: const TextStyle(color: kInk),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.alternate_email, color: kPink),
                  title: const Text('Nom d\'utilisateur'),
                  subtitle: Text(
                    username != null ? '@$username' : 'Attribution en cours…',
                  ),
                  trailing: const Icon(Icons.lock_outline),
                  // Identifiant attribue automatiquement : non modifiable.
                  onTap: null,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined, color: kPink),
                  title: const Text('Modifier mon pseudo'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editName(context, ref, name),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard_rounded, color: kPink),
                  title: const Text('J\'ai un code d\'invitation'),
                  subtitle: const Text('Me connecter a la personne qui m\'a invite'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/redeem'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: kPink),
                  title: const Text('Se deconnecter'),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmDeleteAccount(context, ref),
                  icon: const Icon(Icons.delete_forever_rounded,
                      color: Colors.redAccent),
                  label: const Text('Supprimer mon compte'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mon pseudo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Ton pseudo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPink),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == current) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).updateDisplayName(user.uid, newName);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pseudo mis a jour ✨')));
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton compte a ete supprime.')),
      );
    }
  }
}

/// Boite de dialogue : confirmation + mot de passe + suppression.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();
  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Entre ton mot de passe pour confirmer.');
      return;
    }
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.deleteAccount(password: _password.text);
      if (mounted) Navigator.of(context).pop(true);
      // La redirection go_router ramene vers /login apres la suppression.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          'wrong-password' || 'invalid-credential' =>
            'Mot de passe incorrect.',
          'requires-recent-login' =>
            'Reconnecte-toi puis reessaie.',
          _ => 'Suppression impossible. Reessaie.',
        };
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Une erreur est survenue. Reessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supprimer mon compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cette action est definitive. Ton profil, ton nom d\'utilisateur '
            'et tes proches seront supprimes. Entre ton mot de passe pour '
            'confirmer.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: _loading ? null : _delete,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Supprimer'),
        ),
      ],
    );
  }
}
