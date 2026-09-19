import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_providers.dart';

/// Gère le consentement RGPD via le SDK Google UMP, puis initialise AdMob
/// uniquement si les publicités sont autorisées.
class ConsentService {
  static bool _done = false;

  static Future<void> gatherAndInit(Ref ref) async {
    if (_done) return;
    _done = true;
    try {
      final params = ConsentRequestParameters();
      final updated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () => updated.complete(),
        (error) => updated.complete(),
      );
      await updated.future;

      // Affiche le formulaire de consentement si nécessaire.
      final shown = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        shown.complete();
      });
      await shown.future;
    } catch (_) {
      // On continue : canRequestAds décide de la suite.
    }

    try {
      final canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (canRequestAds) {
        await MobileAds.instance.initialize();
        ref.read(adsAllowedProvider.notifier).set(true);
      }
    } catch (_) {
      // Pas de pub si l'initialisation échoue.
    }
  }

  /// Rouvre le formulaire d'options de confidentialité (RGPD).
  static Future<FormError?> showPrivacyOptions() {
    final c = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!c.isCompleted) c.complete(error);
    });
    return c.future;
  }
}

/// Déclenche le flux de consentement une seule fois au démarrage.
final consentBootstrapProvider = Provider<void>((ref) {
  ConsentService.gatherAndInit(ref);
});
