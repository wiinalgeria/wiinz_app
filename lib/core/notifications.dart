import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session.dart';
import '../models/models.dart';

class NotifState {
  final List<AppNotification> items;
  final bool hasUnread;
  const NotifState({this.items = const [], this.hasUnread = false});
}

class NotifNotifier extends Notifier<NotifState> {
  static const _seenKey = 'notif_seen_top';

  @override
  NotifState build() {
    return const NotifState();
  }

  Future<void> load() async {
    try {
      final items = await ref.read(apiClientProvider).notifications();
      final prefs = await SharedPreferences.getInstance();
      final seenTop = prefs.getString(_seenKey);
      final hasUnread = items.isNotEmpty && items.first.id != seenTop;
      state = NotifState(items: items, hasUnread: hasUnread);
    } catch (_) {}
  }

  Future<void> markSeen() async {
    if (state.items.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey, state.items.first.id);
    state = NotifState(items: state.items, hasUnread: false);
  }
}

final notifProvider = NotifierProvider<NotifNotifier, NotifState>(NotifNotifier.new);
