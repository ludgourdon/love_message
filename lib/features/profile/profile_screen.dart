import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import '../connections/connection_providers.dart';
import '../connections/username.dart';
import 'profile_providers.dart';
import 'user_profile.dart';

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
                    username != null
                        ? '@$username'
                        : 'Non defini — choisis-en un pour te connecter',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editUsername(context, ref, profile),
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
                  leading: const Icon(Icons.logout_rounded, color: kPink),
                  title: const Text('Se deconnecter'),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
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

  Future<void> _editUsername(
      BuildContext context, WidgetRef ref, UserProfile? profile) async {
    final controller = TextEditingController(text: profile?.username ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nom d\'utilisateur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'ton_pseudo',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unique. C\'est ce que tes proches saisiront pour te connecter.',
              style: TextStyle(fontSize: 12),
            ),
          ],
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
    if (result == null || result.isEmpty) return;
    final err = validateUsername(result);
    if (err != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    try {
      await ref.read(directoryRepositoryProvider).claimUsername(
            uid: user.uid,
            username: result,
            previousUsernameLower: profile?.usernameLower,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nom d\'utilisateur enregistre : @$result')),
        );
      }
    } on UsernameTakenException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce nom d\'utilisateur est deja pris.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Echec de l\'enregistrement. Reessaie.')),
        );
      }
    }
  }
}
