import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../profile/profile_providers.dart';
import 'auth_errors.dart';
import '../connections/connection_providers.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Capture avant tout await : la redirection go_router detruit cet ecran
    // des la connexion, donc `ref` ne serait plus utilisable ensuite.
    final auth = ref.read(authRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final directory = ref.read(directoryRepositoryProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Seule la connexion bloque le bouton ; un délai max évite le spinner
      // infini si le réseau ne répond pas.
      await auth
          .signIn(email: _email.text, password: _password.text)
          .timeout(const Duration(seconds: 25));
      // La redirection go_router navigue dès que l'auth change. Les tâches
      // d'entretien Firestore (profil, nom d'utilisateur) tournent en tâche
      // de fond pour ne JAMAIS retenir la navigation.
      final user = auth.currentUser;
      if (user != null) {
        unawaited(_postSignInSetup(profileRepo, directory, user));
      }
    } on TimeoutException {
      setState(() => _error =
          'La connexion prend trop de temps. Vérifie ta connexion et réessaie.');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Entretien post-connexion (non bloquant) : crée le profil manquant et
  /// rattrape le nom d'utilisateur pour les anciens comptes.
  Future<void> _postSignInSetup(
    profileRepo,
    directory,
    User user,
  ) async {
    try {
      await profileRepo.ensureProfile(user);
      if (user.emailVerified) {
        await directory.ensureUsername(
          uid: user.uid,
          displayName: user.displayName ?? '',
          email: user.email,
        );
      }
    } catch (_) {
      // Sans gravité : ces étapes seront retentées à l'usage.
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entre ton email pour réinitialiser le mot de passe.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Image.asset('assets/icon/header_wordmark.png', height: 48),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Connecte-toi pour retrouver ton petit monde.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Email invalide' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? '6 caractères minimum' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Se connecter'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pas encore de compte ?'),
                      TextButton(
                        onPressed: _loading ? null : () => context.push('/signup'),
                        child: const Text('Inscription'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
