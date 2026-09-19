import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Gère les notifications push : permission, enregistrement du token FCM
/// (dans users/{uid}/fcmTokens), et rafraîchissement.
class NotificationsService {
  NotificationsService(this._messaging, this._firestore);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  bool _refreshHooked = false;

  CollectionReference<Map<String, dynamic>> _tokensCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('fcmTokens');

  /// Demande la permission, récupère le token et l'enregistre pour [uid].
  Future<void> registerForUser(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // l'utilisateur a refusé : rien à enregistrer
      }
      // iOS : s'assure que le token APNs est prêt avant getToken.
      if (!kIsWeb && Platform.isIOS) {
        await _messaging.getAPNSToken();
      }
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }
      // Sauvegarde aussi les tokens régénérés (une seule fois).
      if (!_refreshHooked) {
        _refreshHooked = true;
        _messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));
      }
    } catch (e) {
      debugPrint('Notifications: enregistrement impossible ($e)');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await _tokensCol(uid).doc(token).set({
      'token': token,
      'platform': _platformName(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// À appeler avant la déconnexion : retire le token de cet appareil.
  Future<void> removeCurrentToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _tokensCol(uid).doc(token).delete();
      }
    } catch (_) {}
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }
}
