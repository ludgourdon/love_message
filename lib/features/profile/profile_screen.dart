import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart';
import '../auth/auth_providers.dart';
import 'profile_providers.dart';
import '../premium/premium_prefs.dart';
import 'birthday_field.dart';
import '../notifications/notifications_providers.dart';
import '../ads/consent_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final accent = ref.watch(themeAccentProvider).seed;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Mon profil'),
      ),
      body: profileAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: accent)),
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
          final bLabel = dobLabel(
            profile?.birthdayDay,
            profile?.birthdayMonth,
            profile?.birthdayYear,
          );
          final remindersOn = profile?.birthdayRemindersEnabled ?? true;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: accent.withValues(alpha: .15),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '💗',
                    style: TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w800, color: accent),
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
                  leading: Icon(Icons.mail_outline, color: accent),
                  title: const Text('Email'),
                  subtitle: Text(email.isNotEmpty ? email : '—'),
                  trailing: const Icon(Icons.lock_outline),
                  // Email d'inscription : rappel, non modifiable.
                  onTap: null,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.alternate_email, color: accent),
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
                  leading: Icon(Icons.edit_outlined, color: accent),
                  title: const Text('Modifier mon pseudo'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editName(context, ref, name),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.cake_outlined, color: accent),
                  title: const Text('Date de naissance'),
                  subtitle: Text(bLabel ?? 'Non renseignée'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editBirthday(
                    context,
                    ref,
                    profile?.birthdayDay,
                    profile?.birthdayMonth,
                    profile?.birthdayYear,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: accent,
                  ),
                  title: const Text('Rappel d\'anniversaire'),
                  subtitle: const Text(
                    'Prévenir mes proches le jour de mon anniversaire',
                  ),
                  activeColor: accent,
                  value: remindersOn,
                  onChanged: (v) async {
                    final u = ref.read(authStateProvider).value;
                    if (u == null) return;
                    await ref
                        .read(profileRepositoryProvider)
                        .updateBirthdayReminders(u.uid, v);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.card_giftcard_rounded, color: accent),
                  title: const Text('J\'ai un code d\'invitation'),
                  subtitle: const Text('Me connecter à la personne qui m\'a invité'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/redeem'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: accent),
                  title: const Text('Gérer mon consentement'),
                  subtitle: const Text('Choix de confidentialité pour les publicités'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await ConsentService.showPrivacyOptions();
                    if (error != null) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Options de confidentialité indisponibles pour le moment.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.article_outlined, color: accent),
                  title: const Text('Conditions d\'utilisation'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openExternal(
                    context,
                    'https://love-message-2835b.web.app/cgu',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.description_outlined, color: accent),
                  title: const Text('Politique de confidentialité'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openExternal(
                    context,
                    'https://love-message-2835b.web.app/privacy',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.gavel_rounded, color: accent),
                  title: const Text('Mentions légales'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openExternal(
                    context,
                    'https://love-message-2835b.web.app/mentions',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: accent),
                  title: const Text('Se déconnecter'),
                  onTap: () async {
                    final u = ref.read(authStateProvider).value;
                    if (u != null) {
                      await ref
                          .read(notificationsServiceProvider)
                          .removeCurrentToken(u.uid);
                    }
                    await ref.read(authRepositoryProvider).signOut();
                  },
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

  Future<void> _openExternal(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la page.')),
      );
    }
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final accent = ref.read(themeAccentProvider).seed;
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
            style: FilledButton.styleFrom(backgroundColor: accent),
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
          .showSnackBar(const SnackBar(content: Text('Pseudo mis à jour ✨')));
    }
  }

  Future<void> _editBirthday(
    BuildContext context,
    WidgetRef ref,
    int? currentDay,
    int? currentMonth,
    int? currentYear,
  ) async {
    final accent = ref.read(themeAccentProvider).seed;
    int? d = currentDay;
    int? m = currentMonth;
    int? y = currentYear;
    final result = await showDialog<(int, int, int)?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          String? err;
          return AlertDialog(
            title: const Text('Date de naissance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DobPicker(
                  day: d,
                  month: m,
                  year: y,
                  onChanged: (nd, nm, ny) => setLocal(() {
                    d = nd;
                    m = nm;
                    y = ny;
                  }),
                ),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  Text(err!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: () {
                  final age = ageFrom(d, m, y);
                  if (age == null) {
                    setLocal(() => err = 'Renseigne une date complète.');
                    return;
                  }
                  if (age < 15) {
                    setLocal(() => err = 'Tu dois avoir au moins 15 ans.');
                    return;
                  }
                  Navigator.of(context).pop((d!, m!, y!));
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return; // annulé
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).updateDateOfBirth(
          user.uid,
          day: result.$1,
          month: result.$2,
          year: result.$3,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date de naissance enregistrée 🎂')),
      );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton compte a été supprimé.')),
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
            'Reconnecte-toi puis réessaie.',
          _ => 'Suppression impossible. Réessaie.',
        };
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Une erreur est survenue. Réessaie.';
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
            'Cette action est définitive. Ton profil, ton nom d\'utilisateur '
            'et tes proches seront supprimés. Entre ton mot de passe pour '
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
