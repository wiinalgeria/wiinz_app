import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around flutter_local_notifications so the app can raise a
/// system (out-of-app) notification when a new admin notification arrives.
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _inited = false;
int _id = 100;

Future<void> initLocalNotifications() async {
  if (_inited) return;
  _inited = true;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  try {
    await _plugin.initialize(settings);
    await Permission.notification.request(); // Android 13+ runtime prompt
  } catch (_) {}
}

/// Ensure the OS notification permission is granted. Returns whether it ended up
/// granted. Safe to call on every app entry: the system dialog is only shown when
/// it can still be shown (i.e. not permanently denied).
Future<bool> ensureNotificationPermission() async {
  try {
    var status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (!status.isPermanentlyDenied) status = await Permission.notification.request();
    return status.isGranted;
  } catch (_) {
    return true; // don't block/nag the app if the check fails
  }
}

/// Opens the app's OS settings page so the user can re-enable notifications.
Future<void> openNotificationSettings() async {
  try { await openAppSettings(); } catch (_) {}
}

Future<void> showLocalNotification(String title, String body) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'wiinz_general', 'إشعارات WIINZ',
      channelDescription: 'إشعارات تطبيق WIINZ',
      importance: Importance.max, priority: Priority.high,
    ),
  );
  try {
    await _plugin.show(_id++, title, body, details);
  } catch (_) {}
}
