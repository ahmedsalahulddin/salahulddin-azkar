import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'app_locale.dart';
import 'notification_router.dart';
import 'notification_service.dart';

/// Messages sent from the app's own server (Cloudflare Worker → FCM) to
/// every reader: an occasion, a reminder, news of an update.
///
/// No device token is stored anywhere. Every install subscribes to the topic
/// "all" and to "lang_<code>" for the language it reads in, and the server
/// sends to a topic. A message may carry `route` in its data ("surah:18",
/// "adhkar:morning") to open that place when tapped.
class PushService {
  PushService._();

  static const _langKey = '@noor_push_lang_topic';
  static bool _started = false;

  static Future<void> init() async {
    if (_started || kIsWeb) return;
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return;
    _started = true;
    await NotificationService.ensureNewsChannel();
    try {
      await Firebase.initializeApp(options: options);
      final fcm = FirebaseMessaging.instance;
      await fcm.setAutoInitEnabled(true);
      // iPhone: show the banner even with the app open, like the others.
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Android shows nothing by itself while the app is open.
      FirebaseMessaging.onMessage.listen((m) {
        if (defaultTargetPlatform != TargetPlatform.android) return;
        final n = m.notification;
        if (n == null) return;
        NotificationService.showNews(
          id: m.messageId.hashCode & 0x3fffffff,
          title: n.title ?? '',
          body: n.body ?? '',
          payload: m.data['route'] as String?,
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final first = await fcm.getInitialMessage();
      if (first != null) _open(first);

      unawaited(_subscribe());
      AppLocale.locale.addListener(() => unawaited(_subscribe()));
    } catch (_) {
      // No Play services, no network, or iOS before APNs is set up: the app
      // works the same, it just hears nothing from the server.
    }
  }

  static void _open(RemoteMessage m) {
    final route = m.data['route'] as String?;
    if (route != null && route.isNotEmpty) NotificationRouter.open(route);
  }

  /// "all", plus the reader's language — moving the language topic when the
  /// language changes.
  static Future<void> _subscribe() async {
    try {
      final fcm = FirebaseMessaging.instance;
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await fcm.getAPNSToken() == null) {
        // Topics need the APNs token; it arrives a moment after launch.
        await Future<void>.delayed(const Duration(seconds: 5));
        if (await fcm.getAPNSToken() == null) return;
      }
      await fcm.subscribeToTopic('all');
      final prefs = await SharedPreferences.getInstance();
      final want = 'lang_${AppLocale.code}';
      final had = prefs.getString(_langKey);
      if (had == want) return;
      if (had != null) await fcm.unsubscribeFromTopic(had);
      await fcm.subscribeToTopic(want);
      await prefs.setString(_langKey, want);
    } catch (_) {
      // Tried again at the next launch.
    }
  }
}
