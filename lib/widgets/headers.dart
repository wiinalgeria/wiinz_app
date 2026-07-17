import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Header for map / perks / gifts: title + avatar(→more) + back(→home).
class PlainHeader extends ConsumerWidget {
  final String title;
  final bool showAvatar;
  const PlainHeader(this.title, {super.key, this.showAvatar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Screens build this as `const PlainHeader(...)`, so a parent rebuild reuses
    // the identical canonicalized instance and Flutter skips the subtree. Watch
    // the locale here or the title keeps the old language after a switch.
    ref.watch(localeProvider);
    final avatar = ref.watch(sessionProvider).user?.avatar ?? '';
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      color: C.sand,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tr(title), style: cairo(22, w: FontWeight.w800, color: C.forest)),
          Row(children: [
            if (showAvatar) ...[
              Pressable(
                pressedScale: 0.88,
                onTap: () => context.go('/more'),
                child: avatarCircle(avatar, 42, border: Border.all(color: Colors.white, width: 2)),
              ),
              const SizedBox(width: 10),
            ],
            Pressable(
              pressedScale: 0.88,
              onTap: () => context.go('/home'),
              child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.cardBorder)),
                child: Transform.flip(flipX: true, child: mi('arrow_forward', size: 22, color: C.forest))),
            ),
          ]),
        ],
      ),
    );
  }
}
