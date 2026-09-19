import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';

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

  // Emails Firebase (vérification, réinitialisation) en français.
  await FirebaseAuth.instance.setLanguageCode('fr');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Affiche aussi la bannière quand l'app est au premier plan (iOS).
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const ProviderScope(child: MyApp()));
}
