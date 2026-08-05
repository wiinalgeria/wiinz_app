import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_ios.dart';
import 'local_notify.dart';

/// Real out-of-app push notifications via Firebase Cloud Messaging.
///
/// How delivery works:
/// - **App closed / backgrounded**: the OS itself shows the notification from the
///   FCM payload — no Dart code runs. This is what makes notifications arrive at
///   their real send time even when the app isn't open.
/// - **App in foreground**: neither Android nor iOS shows it for us, so we
///   re-raise it ourselves through flutter_local_notifications.
///
/// iOS differs from Android in two ways that are easy to miss:
/// - **No permission, no token.** APNs will not issue a device token until the
///   user has granted notification authorization, so `requestPermission()` has
///   to run before `getToken()` can ever return.
/// - **The APNs token arrives asynchronously**, and `getToken()` throws
///   `apns-token-not-set` if it is called first — see `pushToken()`.
///
/// The device token is registered with the WIIN backend after login, and cleared
/// on logout, so a signed-out phone stops receiving that user's notifications.

/// Notification channel used for both FCM and local notifications. It must match
/// the `channelId` the server sends, and the manifest's default-channel meta-data,
/// or Android will drop the notification into a nameless low-priority channel.
const _channel = AndroidNotificationChannel(
  'wiinz_general',
  'إشعارات WIIN',
  description: 'إشعارات تطبيق WIIN',
  importance: Importance.max,
);

/// Background/terminated handler. Must be a top-level function.
/// The payload already carries a `notification` block, so Android renders it
/// natively — there's nothing to do here, but FCM requires the handler to exist.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

bool _ready = false;

/// Called once at app start (before runApp).
Future<void> initPush() async {
  if (_ready) return;
  try {
    if (Platform.isIOS) {
      // iOS carries no GoogleService-Info.plist — the config is passed in from
      // Dart instead (see firebase_ios.dart for why, and how to fill it).
      final opts = iosFirebaseOptions();
      if (opts == null) return; // not configured yet → run without push
      await Firebase.initializeApp(options: opts);
    } else {
      await Firebase.initializeApp();
    }
    _ready = true;

    // Create the high-importance channel up front so Android has it ready when a
    // push lands while the app is closed. (No-op on iOS: it has no channels.)
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // iOS: ask APNs for authorization. Android's own prompt is raised later, in
    // context, by ensureNotificationPermission() from Home — but on iOS this is
    // also what unblocks the device token, so it cannot wait that long.
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission();
    }

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Foreground: neither OS shows it for us, so raise it locally.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      showLocalNotification(n.title ?? 'WIIN', n.body ?? '');
    });
  } catch (e) {
    // No Firebase config / offline → app still works, just without push.
    _ready = false;
  }
}

/// The device's current FCM token, or null if push isn't available.
Future<String?> pushToken() async {
  if (!_ready) return null;
  try {
    // iOS: FCM can only mint a token once APNs has handed one over, which happens
    // asynchronously after authorization is granted. Calling getToken() before
    // then throws `apns-token-not-set`, and the session would register nothing —
    // the phone would simply never receive a push. Wait briefly for it.
    if (Platform.isIOS) {
      var apns = await FirebaseMessaging.instance.getAPNSToken();
      for (var i = 0; apns == null && i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        apns = await FirebaseMessaging.instance.getAPNSToken();
      }
      // Still nothing (user denied, or a simulator with no push support): there
      // is no token to register, and asking for one would only throw.
      if (apns == null) return null;
    }
    return await FirebaseMessaging.instance.getToken();
  } catch (_) {
    return null;
  }
}

/// Fires whenever FCM rotates the device token, so we can re-register it.
Stream<String>? get onTokenRefresh =>
    _ready ? FirebaseMessaging.instance.onTokenRefresh : null;
