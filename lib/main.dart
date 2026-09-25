import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'features/premium/premium_prefs.dart';

/// Handler des messages reçus quand l'app est en arrière-plan / fermée.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Le système affiche la notification automatiquement (payload notification).
  // Rien de spécial à faire ici pour l'instant.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check : atteste que les requêtes viennent bien de l'app authentique.
  // En debug on utilise le provider de debug (émulateurs/dev) ; en release,
  // Play Integrity (Android) et App Attest (iOS).
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  // Emails Firebase (vérification, réinitialisation) en français.
  await FirebaseAuth.instance.setLanguageCode('fr');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Affiche aussi la bannière quand l'app est au premier plan (iOS).
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Préférences locales (thème / animation / pack de mots premium).
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}
