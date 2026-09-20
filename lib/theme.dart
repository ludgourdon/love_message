import 'package:flutter/material.dart';

const kPink = Color(0xFFFF6F9F);
const kCream = Color(0xFFFFFBF7);
const kLavender = Color(0xFFCBB8FF);
const kInk = Color(0xFF3D314A);

/// Construit le thème de l'app à partir de la couleur d'accent [seed] et du
/// fond d'écran [background] (voir ThemeAccent côté premium).
///
/// Le fond est appliqué au scaffold, aux barres d'app et aux bottom sheets
/// pour un rendu cohérent quel que soit l'écran.
ThemeData buildAppTheme([Color seed = kPink, Color background = kCream]) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, surface: background);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: kInk,
      displayColor: kInk,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: background,
      modalBackgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
