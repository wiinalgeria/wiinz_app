import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Floating pill bottom nav with a center scan reticle.
/// [current] is one of: home, map, perks, gifts (null = none highlighted).
class WiinzBottomNav extends ConsumerWidget {
  final String? current;
  const WiinzBottomNav({super.key, this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Screens build this as `const WiinzBottomNav(...)`, so a parent rebuild
    // reuses the identical canonicalized instance and Flutter skips the subtree.
    // Watch the locale here or the labels keep the old language after a switch.
    ref.watch(localeProvider);
    // Extra bottom padding keeps the pill clear of the Android gesture/nav bar.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 6, 14, 12 + (bottomInset > 0 ? bottomInset : 12)),
      color: Colors.transparent,
      child: SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                border: Border.all(color: C.divider),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: C.forest.withValues(alpha: 0.25), blurRadius: 34, offset: const Offset(0, 14))],
              ),
              child: Row(
                children: [
                  _tab(context, 'home', 'الرئيسية', 'home', '/home'),
                  _tab(context, 'map', 'خريطة', 'location_on', '/map'),
                  const SizedBox(width: 74),
                  _tab(context, 'perks', 'مكافأتي', 'confirmation_number', '/perks'),
                  _tab(context, 'gifts', 'الهدايا', 'redeem', '/gifts'),
                ],
              ),
            ),
            Positioned(
              top: -24,
              child: Column(
                children: [
                  Pressable(
                    pressedScale: 0.92,
                    onTap: () => context.go('/scan'),
                    child: Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        gradient: C.avatarGrad,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: C.sand, width: 4),
                        boxShadow: [BoxShadow(color: C.greenMid.withValues(alpha: 0.75), blurRadius: 26, offset: const Offset(0, 14))],
                      ),
                      child: mi('qr_code_2', color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // same one-line/scale-down treatment as the tabs
                  SizedBox(
                    width: 74,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tr('امسح'), maxLines: 1, softWrap: false, style: cairo(10.5, w: FontWeight.w800, color: C.greenMid)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String key, String label, String icon, String route) {
    final active = current == key;
    return Expanded(
      child: Pressable(
        pressedScale: 0.90,
        onTap: () => context.go(route),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: active ? const Color(0xFFDDF0E5) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                mi(icon, size: 24, color: active ? C.forest : C.textTertiary, fill: active),
                const SizedBox(height: 2),
                // Longer labels (French, or Arabic at small display scales) used
                // to wrap and break mid-word. Keep them on ONE line and shrink
                // to fit instead of hyphenating.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr(label), maxLines: 1, softWrap: false, overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    style: cairo(10.5, w: active ? FontWeight.w800 : FontWeight.w600, color: active ? C.forest : C.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
