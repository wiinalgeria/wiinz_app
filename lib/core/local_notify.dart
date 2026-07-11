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
