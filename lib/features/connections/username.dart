/// Normalise un nom d'utilisateur (cle de l'annuaire) : minuscules + trim.
String normalizeUsername(String input) => input.trim().toLowerCase();

/// Retourne un message d'erreur, ou null si le format est valide.
String? validateUsername(String input) {
  final u = input.trim();
  if (u.length < 3) return 'Au moins 3 caracteres';
  if (u.length > 20) return 'Maximum 20 caracteres';
  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(u)) {
    return 'Lettres, chiffres, . et _ uniquement';
  }
  return null;
}

/// Levee quand le nom d'utilisateur demande est deja pris par quelqu'un d'autre.
class UsernameTakenException implements Exception {
  @override
  String toString() => 'UsernameTakenException';
}
