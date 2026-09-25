import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import 'auth_errors.dart';
import 'auth_providers.dart';
import '../profile/birthday_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _emailTaken = false;
  int? _bDay;
  int? _bMonth;
  int? _bYear;

  static const _cguUrl = 'https://love-message-2835b.web.app/cgu';
  static const _privacyUrl = 'https://love-message-2835b.web.app/privacy';
  late final TapGestureRecognizer _tapCgu =
      TapGestureRecognizer()..onTap = () => _openUrl(_cguUrl);
  late final TapGestureRecognizer _tapPrivacy =
      TapGestureRecognizer()..onTap = () => _openUrl(_privacyUrl);

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _tapCgu.dispose();
    _tapPrivacy.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = (_bDay != null && _bMonth != null && _bYear != null)
        ? DateTime(_bYear!, _bMonth!, _bDay!)
        : DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Date de naissance',
    );
    if (picked != null) {
      setState(() {
        _bDay = picked.day;
        _bMonth = picked.month;
        _bYear = picked.year;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final age = ageFrom(_bDay, _bMonth, _bYear);
    if (age == null) {
      setState(() => _error = 'Renseigne ta date de naissance complète.');
      return;
    }
    if (age < 15) {
      setState(() => _error =
          'Tu dois avoir au moins 15 ans pour créer un compte.');
      return;
    }
    // Capture avant tout await : la redirection go_router detruit cet ecran
    // des la creation du compte, donc `ref` ne serait plus utilisable ensuite.
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _loading = true;
      _error = null;
      _emailTaken = false;
    });
    try {
      await auth.register(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            birthdayDay: _bDay!,
            birthdayMonth: _bMonth!,
            birthdayYear: _bYear!,
          );
      // Le nom d'utilisateur n'est attribué qu'après vérification de l'email
      // (voir la bannière sur l'accueil) : un compte non vérifié n'est pas
      // découvrable et ne peut donc pas être ajouté.
      // La redirection go_router s'occupe de la navigation vers l'accueil.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = authErrorMessage(e);
        _emailTaken = e.code == 'email-already-in-use';
      });
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Inscription'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crée ton petit monde 💗',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Pseudo',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Choisis un pseudo' : null,
                ),
                const SizedBox(height: 14),
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
                  autofillHints: const [AutofillHints.newPassword],
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirme le mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v != _password.text ? 'Les mots de passe ne correspondent pas' : null,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance',
                      prefixIcon: Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      dobLabel(_bDay, _bMonth, _bYear) ?? 'Choisir…',
                      style: TextStyle(
                        color:
                            (_bDay != null && _bMonth != null && _bYear != null)
                                ? kInk
                                : Colors.black54,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  if (_emailTaken) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () => context.pop(),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Se connecter à ce compte'),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
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
                      : const Text('Créer mon compte'),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12.5, color: kInk),
                    children: [
                      const TextSpan(
                          text: 'En créant ton compte, tu acceptes les '),
                      TextSpan(
                        text: 'Conditions d\'utilisation',
                        style: const TextStyle(
                            color: kPink, fontWeight: FontWeight.w700),
                        recognizer: _tapCgu,
                      ),
                      const TextSpan(text: ' et la '),
                      TextSpan(
                        text: 'Politique de confidentialité',
                        style: const TextStyle(
                            color: kPink, fontWeight: FontWeight.w700),
                        recognizer: _tapPrivacy,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà un compte ?'),
                    TextButton(
                      onPressed: _loading ? null : () => context.pop(),
                      child: const Text('Se connecter'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
