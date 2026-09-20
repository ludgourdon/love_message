import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_service.dart';

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
  ),
);

/// Cible d'ouverture demandée par un tap sur une notification.
///  - `null`  : rien en attente
///  - `''`    : ouvrir l'onglet « Recevoir »
///  - `<uid>` : ouvrir l'écran d'envoi vers le proche lié à cet uid
class PendingNotificationTapNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
  void clear() => state = null;
}

final pendingNotificationTapProvider =
    NotifierProvider<PendingNotificationTapNotifier, String?>(
  PendingNotificationTapNotifier.new,
);
