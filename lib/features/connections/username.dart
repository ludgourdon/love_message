/// Table de correspondance accent -> lettre de base (minuscules).
const _accentMap = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
};

String _stripDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentMap[ch] ?? ch);
  }
  return buffer.toString();
}

/// Cle de l'annuaire : minuscules, sans accent, sans espaces de bord.
/// Ainsi "Léa", "lea" et "LÉA" pointent tous vers la meme cle "lea".
String normalizeUsername(String input) =>
    _stripDiacritics(input.trim().toLowerCase());

/// Retourne un message d'erreur, ou null si le format saisi est valide.
/// La saisie autorise les accents (é, è, ù, ç...) ; ils sont conserves pour
/// l'affichage mais retires dans [normalizeUsername] pour la cle d'annuaire.
String? validateUsername(String input) {
  final u = input.trim();
  if (u.length < 3) return 'Au moins 3 caractères';
  if (u.length > 20) return 'Maximum 20 caractères';
  if (!RegExp(r'^[\p{L}\p{N}._-]+$', unicode: true).hasMatch(u)) {
    return 'Lettres, chiffres, . _ - uniquement (pas d\'espace)';
  }
  return null;
}

/// Levee quand le nom d'utilisateur demandé est déjà pris par quelqu'un d'autre.
class UsernameTakenException implements Exception {
  @override
  String toString() => 'UsernameTakenException';
}
