import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hearts/heart.dart';
import '../hearts/hearts_providers.dart';

/// État du "lien" avec un proche : une série de jours où l'on s'est envoyé des
/// cœurs TOUS LES DEUX. Calculé côté client à partir des cœurs (aucune écriture
/// serveur), donc compatible avec les règles Firestore strictes.
class BondStreak {
  const BondStreak({
    required this.days,
    required this.completeToday,
    required this.alive,
  });

  /// Nombre de jours consécutifs "complets" (échange dans les deux sens).
  final int days;

  /// Vrai si l'échange mutuel a déjà eu lieu aujourd'hui.
  final bool completeToday;

  /// Vrai si la série est encore vivante (dernier jour complet = aujourd'hui
  /// ou hier — un jour de grâce).
  final bool alive;

  static const none = BondStreak(days: 0, completeToday: false, alive: false);
}

/// Numéro de jour proleptique en UTC (insensible aux changements d'heure/DST).
int _dayNum(DateTime dt) {
  final d = dt.toLocal();
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

int _todayNum() => _dayNum(DateTime.now());

/// Calcule le lien pour chaque proche (clé = uid de l'autre personne).
Map<String, BondStreak> computeBondStreaks(
  List<Heart> sent,
  List<Heart> received,
) {
  final sentDays = <String, Set<int>>{};
  for (final h in sent) {
    final c = h.createdAt;
    if (c == null || h.toUid.isEmpty) continue;
    (sentDays[h.toUid] ??= <int>{}).add(_dayNum(c));
  }
  final recvDays = <String, Set<int>>{};
  for (final h in received) {
    final c = h.createdAt;
    if (c == null || h.fromUid.isEmpty) continue;
    (recvDays[h.fromUid] ??= <int>{}).add(_dayNum(c));
  }

  final today = _todayNum();
  final yesterday = today - 1;
  final result = <String, BondStreak>{};
  final others = <String>{...sentDays.keys, ...recvDays.keys};

  for (final uid in others) {
    final s = sentDays[uid] ?? const <int>{};
    final r = recvDays[uid] ?? const <int>{};
    // Jours "complets" : cœurs échangés dans les deux sens le même jour.
    final complete = s.intersection(r);
    if (complete.isEmpty) {
      result[uid] = BondStreak.none;
      continue;
    }
    var last = complete.first;
    for (final d in complete) {
      if (d > last) last = d;
    }
    if (last != today && last != yesterday) {
      result[uid] = BondStreak.none; // série rompue
      continue;
    }
    var days = 0;
    var cursor = last;
    while (complete.contains(cursor)) {
      days++;
      cursor--;
    }
    result[uid] = BondStreak(
      days: days,
      completeToday: complete.contains(today),
      alive: true,
    );
  }
  return result;
}

/// Liens de l'utilisateur connecté, recalculés en temps réel.
final bondStreaksProvider = Provider<Map<String, BondStreak>>((ref) {
  final sent = ref.watch(sentHeartsProvider).value ?? const <Heart>[];
  final received = ref.watch(receivedHeartsProvider).value ?? const <Heart>[];
  return computeBondStreaks(sent, received);
});
