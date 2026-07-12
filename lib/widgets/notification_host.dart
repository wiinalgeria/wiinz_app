import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications.dart';
import '../core/local_notify.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../screens/overlays/overlays.dart';
import 'ui.dart';

/// Wraps the whole app (via MaterialApp.builder) so a freshly-arrived
/// notification surfaces as a top banner on EVERY screen, not just home.
class NotificationHost extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const NotificationHost({super.key, required this.child, required this.navigatorKey});
  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost> with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _hideTimer;
  String? _lastTopId;
  bool _primed = false;
  bool _ticking = false; // guards against overlapping polls during a slow request
  AppNotification? _banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _tick(); // refresh immediately on return instead of waiting up to 8s
    } else {
      // Stop polling while backgrounded so we don't stack hung requests.
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _tick() async {
    if (_ticking) return;
    final loggedIn = ref.read(sessionProvider).user != null;
    if (!loggedIn) { _lastTopId = null; _primed = false; return; }
    _ticking = true;
    try {
      await ref.read(notifProvider.notifier).load();
    } finally {
      _ticking = false;
    }
    if (!mounted) return;
    final items = ref.read(notifProvider).items;
    if (items.isEmpty) return;
    final topId = items.first.id;
    if (!_primed) { _lastTopId = topId; _primed = true; return; } // don't fire on first load
    if (_lastTopId != topId) {
      _showBanner(items.first);
      showLocalNotification(items.first.title, items.first.body); // out-of-app system notification
    }
    _lastTopId = topId;
  }

  void _showBanner(AppNotification n) {
    setState(() => _banner = n);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () { if (mounted) setState(() => _banner = null); });
  }

  void _openSheet() {
    final n = _banner;
    if (n == null) return;
    setState(() => _banner = null);
    ref.read(notifProvider.notifier).markSeen();
    final ctx = widget.navigatorKey.currentContext;
    if (ctx != null) showNotificationsSheet(ctx, ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _banner;
    return Stack(children: [
      widget.child,
      if (n != null)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _openSheet,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.tint4),
                      boxShadow: [BoxShadow(color: C.forest.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: hexColor(n.bg, fallback: C.tint2), borderRadius: BorderRadius.circular(12)), child: mi(n.icon, size: 22, color: hexColor(n.color, fallback: C.greenMid))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: cairo(14, w: FontWeight.w800, color: C.forest)),
                        Text(n.body, style: noto(12, color: C.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                      mi('notifications', size: 20, color: C.gold, fill: true),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
