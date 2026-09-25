import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vrai une fois le consentement RGPD résolu ET AdMob initialisé.
/// Tant que c'est faux, aucune publicité n'est chargée.
class AdsAllowedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final adsAllowedProvider =
    NotifierProvider<AdsAllowedNotifier, bool>(AdsAllowedNotifier.new);
