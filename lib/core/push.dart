import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'local_notify.dart';

/// Real out-of-app push notifications via Firebase Cloud Messaging.
///
/// How delivery works:
/// - **App closed / backgrounded**: Android itself shows the notification from the
///   FCM payload — no Dart code runs. This is what makes notifications arrive at
///   their real send time even when the app isn't open.
/// - **App in foreground**: Android suppresses the system notification, so we
///   re-raise it ourselves through flutter_local_notifications.
///
/// The device token is registered with the WIINZ backend after login, and cleared
/// on logout, so a signed-out phone stops receiving that user's notifications.

/// Notification channel used for both FCM and local notifications. It must match
/// the `channelId` the server sends, and the manifest's default-channel meta-data,
/// or Android will drop the notification into a nameless low-priority channel.
const _channel = AndroidNotificationChannel(
  'wiinz_general',
  'إشعارات WIINZ',
  description: 'إشعارات تطبيق WIINZ',
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
    await Firebase.initializeApp();
    _ready = true;

    // Create the high-importance channel up front so Android has it ready when a
    // push lands while the app is closed.
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Foreground: Android won't show it for us, so raise it locally.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      showLocalNotification(n.title ?? 'WIINZ', n.body ?? '');
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
    return await FirebaseMessaging.instance.getToken();
  } catch (_) {
    return null;
  }
}

/// Fires whenever FCM rotates the device token, so we can re-register it.
Stream<String>? get onTokenRefresh =>
    _ready ? FirebaseMessaging.instance.onTokenRefresh : null;
