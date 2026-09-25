import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_service.dart';
import '../premium/premium_prefs.dart';

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
  ),
);

/// Action d'ouverture demandée par un tap sur une notification.
///  - action 'receive' : ouvrir l'onglet « Recevoir »
///  - action 'hearts'  : ouvrir le détail des cœurs reçus de [uid]
///  - action 'send'    : ouvrir l'écran d'envoi vers le proche lié à [uid]
class PendingTap {
  const PendingTap(this.action, this.uid);
  final String action;
  final String uid;
}

class PendingNotificationTapNotifier extends Notifier<PendingTap?> {
  @override
  PendingTap? build() => null;
  void set(PendingTap? value) => state = value;
  void clear() => state = null;
}

final pendingNotificationTapProvider =
    NotifierProvider<PendingNotificationTapNotifier, PendingTap?>(
  PendingNotificationTapNotifier.new,
);

/// Horodatage (ms) de la dernière ouverture de la page Notifications, pour
/// piloter le compteur « non-lu » de la cloche. Persisté sur l'appareil.
class NotificationsSeenNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getInt('notif.lastOpened') ?? 0;
  }

  void markOpened() {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = now;
    ref.read(sharedPreferencesProvider).setInt('notif.lastOpened', now);
  }
}

final notificationsLastOpenedProvider =
    NotifierProvider<NotificationsSeenNotifier, int>(
  NotificationsSeenNotifier.new,
);
