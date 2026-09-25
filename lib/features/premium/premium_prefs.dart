import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// --------------------------------------------------------------------------
/// Premium V1 : thèmes, animations et packs de petits mots.
///
/// Pour cette V1, TOUT est débloqué : aucune vérification d'abonnement.
/// Chaque choix est mémorisé sur l'appareil (SharedPreferences) pour survivre
/// à un redémarrage de l'app. Quand l'achat in-app sera branché, il suffira de
/// conditionner l'accès à ces sélecteurs.
/// --------------------------------------------------------------------------

/// Palette de couleurs sélectionnable. Le [seed] pilote tout le ColorScheme.
class ThemeAccent {
  const ThemeAccent(this.name, this.emoji, this.seed, this.background);
  final String name;
  final String emoji;

  /// Couleur d'accent principale (boutons, cœur, mises en avant).
  final Color seed;

  /// Fond d'écran harmonieux : teinte très claire de la même famille que
  /// [seed], pensée pour rester lisible avec le texte foncé.
  final Color background;
}

const kThemeAccents = <ThemeAccent>[
  ThemeAccent('Rose tendre', '🌸', Color(0xFFFF6F9F), Color(0xFFFFF0F5)),
  ThemeAccent('Lavande', '💜', Color(0xFF9B7EDE), Color(0xFFF4EFFC)),
  ThemeAccent('Océan', '🌊', Color(0xFF3FA7C4), Color(0xFFECF6FA)),
  ThemeAccent('Coucher de soleil', '🌅', Color(0xFFFF8360), Color(0xFFFFF1EA)),
  ThemeAccent('Forêt', '🌿', Color(0xFF5AA97B), Color(0xFFECF6EF)),
];

/// Style d'animation lors de la réception de cœurs (jeu d'emojis qui montent).
class AnimationStyle {
  const AnimationStyle(this.name, this.emojis);
  final String name;
  final List<String> emojis;
  String get preview => emojis.first;
}

const kAnimationStyles = <AnimationStyle>[
  AnimationStyle('Cœurs', ['💗', '💖', '💕', '❤️', '💞', '🩷']),
  AnimationStyle('Étoiles', ['⭐', '✨', '🌟', '💫', '🌠', '⚡']),
  AnimationStyle('Fleurs', ['🌸', '🌺', '🌼', '🌻', '🌷', '💐']),
  AnimationStyle('Confettis', ['🎉', '🎊', '✨', '🎈', '💫', '🥳']),
  AnimationStyle('Papillons', ['🦋', '🌈', '✨', '🌸', '💖', '🕊️']),
];

/// Pack de petits mots proposés en un clic sur l'écran d'envoi.
class WordPack {
  const WordPack(this.name, this.emoji, this.words);
  final String name;
  final String emoji;
  final List<String> words;
}

const kWordPacks = <WordPack>[
  WordPack('Tendresse', '💗', [
    'Je pense à toi 🌸',
    'Tu es mon petit soleil ☀️',
    'Un gros câlin 🧸',
    'Juste parce que je t’aime 💗',
  ]),
  WordPack('Bonne nuit', '🌙', [
    'Fais de beaux rêves 🌙',
    'Bonne nuit 😴',
    'Je veille sur toi ✨',
    'Dors bien mon cœur 💫',
  ]),
  WordPack('Occasions', '🎉', [
    'Joyeux anniversaire 🎂',
    'Félicitations ! 🎉',
    'Bonne fête 💐',
    'Bravo à toi 🌟',
  ]),
  WordPack('Mots doux', '💌', [
    'Tu me manques 🥺',
    'Toujours là pour toi 🤍',
    'Mon cœur est à toi 💌',
    'Merci d’exister 💞',
  ]),
  WordPack('Humour', '😄', [
    'Coucou toi 👀',
    'Team câlins 🧸',
    'Alerte tendresse 🚨',
    '100% amour 💯',
  ]),
];

/// Style visuel du "lien" (jeu de la flamme du lien) : flamme qui grandit
/// ou fleur qui s'ouvre.
class BondStyle {
  const BondStyle(this.name, this.emoji);
  final String name;
  final String emoji;
}

const kBondStyles = <BondStyle>[
  BondStyle('Flamme', '🔥'),
  BondStyle('Fleur', '🌸'),
];

/// Injecté depuis main() après préchargement.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences non initialisées'),
);

/// Nombre de proches autorisés sans Premium.
const kFreeContactsLimit = 5;

/// Statut Premium. Pour l'instant, activable manuellement (mode test) — à
/// brancher sur l'achat in-app quand il sera prêt. Persisté sur l'appareil.
class PremiumNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool('premium.active') ?? false;
  }

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool('premium.active', value);
  }
}

final isPremiumProvider =
    NotifierProvider<PremiumNotifier, bool>(PremiumNotifier.new);

/// Notifier générique : mémorise un index sélectionné (thème, animation, pack).
class PremiumChoiceNotifier extends Notifier<int> {
  PremiumChoiceNotifier(this.storageKey, this.count);
  final String storageKey;
  final int count;

  @override
  int build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final v = prefs.getInt(storageKey) ?? 0;
    return (v >= 0 && v < count) ? v : 0;
  }

  void select(int index) {
    if (index < 0 || index >= count || index == state) return;
    state = index;
    ref.read(sharedPreferencesProvider).setInt(storageKey, index);
  }
}

final themeAccentIndexProvider = NotifierProvider<PremiumChoiceNotifier, int>(
  () => PremiumChoiceNotifier('premium.theme', kThemeAccents.length),
);
final animationStyleIndexProvider =
    NotifierProvider<PremiumChoiceNotifier, int>(
  () => PremiumChoiceNotifier('premium.anim', kAnimationStyles.length),
);
/// Multi-sélection Premium : quels packs de petits mots apparaissent sur
/// l'écran d'envoi. Par défaut tous activés. Persisté sur l'appareil.
class WordPacksNotifier extends Notifier<Set<int>> {
  static const _key = 'premium.packs';

  @override
  Set<int> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getStringList(_key);
    if (stored == null) {
      return {for (var i = 0; i < kWordPacks.length; i++) i};
    }
    final set = <int>{};
    for (final s in stored) {
      final v = int.tryParse(s);
      if (v != null && v >= 0 && v < kWordPacks.length) set.add(v);
    }
    return set.isEmpty ? {0} : set;
  }

  void toggle(int index) {
    if (index < 0 || index >= kWordPacks.length) return;
    final next = {...state};
    if (next.contains(index)) {
      if (next.length <= 1) return; // on garde au moins un pack activé
      next.remove(index);
    } else {
      next.add(index);
    }
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, next.map((e) => e.toString()).toList());
  }
}

final enabledWordPacksProvider =
    NotifierProvider<WordPacksNotifier, Set<int>>(WordPacksNotifier.new);
final bondStyleIndexProvider = NotifierProvider<PremiumChoiceNotifier, int>(
  () => PremiumChoiceNotifier('premium.bond', kBondStyles.length),
);

/// Valeurs dérivées, pratiques à consommer dans l'UI.
// Les thèmes, animations et packs ne s'appliquent que pour un compte Premium ;
// sinon on retombe sur l'option par défaut (index 0).
final themeAccentProvider = Provider<ThemeAccent>((ref) {
  final i =
      ref.watch(isPremiumProvider) ? ref.watch(themeAccentIndexProvider) : 0;
  return kThemeAccents[i];
});
final animationStyleProvider = Provider<AnimationStyle>((ref) {
  final i =
      ref.watch(isPremiumProvider) ? ref.watch(animationStyleIndexProvider) : 0;
  return kAnimationStyles[i];
});
/// Packs à afficher sur l'écran d'envoi : non-Premium -> uniquement le premier ;
/// Premium -> les packs choisis (au moins un).
final sendWordPacksProvider = Provider<List<WordPack>>((ref) {
  if (!ref.watch(isPremiumProvider)) return [kWordPacks.first];
  final enabled = ref.watch(enabledWordPacksProvider);
  final list = <WordPack>[
    for (var i = 0; i < kWordPacks.length; i++)
      if (enabled.contains(i)) kWordPacks[i],
  ];
  return list.isEmpty ? [kWordPacks.first] : list;
});
final bondStyleProvider = Provider<BondStyle>(
  (ref) => kBondStyles[ref.watch(bondStyleIndexProvider)],
);
