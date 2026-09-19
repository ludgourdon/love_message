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
