import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/ads/consent_service.dart';
import 'router.dart';
import 'theme.dart';
import 'features/premium/premium_prefs.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lance une seule fois le flux de consentement RGPD (puis AdMob).
    ref.watch(consentBootstrapProvider);
    final accent = ref.watch(themeAccentProvider);
    return MaterialApp.router(
      title: 'Cœur à cœur',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(accent.seed, accent.background),
      routerConfig: appRouter,
    );
  }
}
