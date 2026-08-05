import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Why init failed, kept for the diagnostics sheet. Every failure path in
/// `initPush()` used to end in a bare `return`, so "Firebase threw", "iOS config
/// missing" and "permission denied" were indistinguishable from the outside —
/// which is exactly why the first iOS push bug took several build cycles.
String? _initError;

/// Called once at app start (before runApp).
Future<void> initPush() async {
  if (_ready) return;
  try {
    // Both platforms now configure from their bundled config file — Android
    // from google-services.json, iOS from GoogleService-Info.plist, which
    // AppDelegate already applied via FirebaseApp.configure() before Flutter
    // started. This call therefore just returns the existing default app on
    // iOS. Passing explicit options here would be wrong: firebase_core throws
    // if the default app already exists with a different configuration.
    await Firebase.initializeApp();
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
    _initError = e.toString();
  }
}

/// A readable snapshot of every step push depends on, for the diagnostics sheet
/// in Settings. Each line is a step that can fail independently and silently.
Future<Map<String, String>> pushDiagnostics() async {
  final out = <String, String>{};
  out['Platform'] = Platform.isIOS ? 'iOS' : 'Android';
  if (Platform.isIOS) {
    // Written natively by AppDelegate when Apple answers the registration —
    // either with a token or with the reason it refused. This is the only place
    // an APNs registration failure is visible at all; iOS surfaces it nowhere
    // else, and the app would otherwise just see a null token forever.
    try {
      final prefs = await SharedPreferences.getInstance();
      out['APNs registration'] = prefs.getString('apns_status') ?? '⏳ no answer from Apple yet';
    } catch (e) {
      out['APNs registration'] = 'error: $e';
    }
  }
  out['Firebase init'] = _ready ? '✅ ready' : '❌ ${_initError ?? 'not initialised'}';
  if (!_ready) return out;

  try {
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    out['Permission'] = s.authorizationStatus.name;
  } catch (e) {
    out['Permission'] = 'error: $e';
  }

  if (Platform.isIOS) {
    // The step that silently blocked everything: no APNs token means FCM can
    // never mint one, and getToken() throws instead of returning null.
    try {
      final a = await FirebaseMessaging.instance.getAPNSToken();
      out['APNs token'] = a == null ? '❌ null' : '✅ ${a.length} chars';
    } catch (e) {
      out['APNs token'] = 'error: $e';
    }
  }

  try {
    final t = await FirebaseMessaging.instance.getToken();
    out['FCM token'] = t == null ? '❌ null' : '✅ ${t.substring(0, 12)}…';
  } catch (e) {
    out['FCM token'] = 'error: $e';
  }
  return out;
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
