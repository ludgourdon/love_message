import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_providers.dart';
import '../premium/premium_prefs.dart';

/// Bannière publicitaire discrète, ancrée en bas.
/// IDs de TEST pour l'instant : à remplacer par tes vrais blocs AdMob.
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  // Blocs de TEST officiels Google (à ne jamais utiliser en production).
  static const _androidTest = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosTest = 'ca-app-pub-3940256099942544/2934735716';

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void _load() {
    final unitId = Platform.isIOS ? _iosTest : _androidTest;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: unitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(isPremiumProvider)) return const SizedBox.shrink();
    final allowed = ref.watch(adsAllowedProvider);
    if (allowed && _supported && !_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (!_supported || !_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
