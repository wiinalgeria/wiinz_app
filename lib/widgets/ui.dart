import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';

/// Wraps any tappable so it feels alive: a subtle scale-down + light haptic on
/// press, springing back on release. This is the single biggest "responsive"
/// cue — every pressable in the app should feel like it heard the tap.
///
/// Press feedback is fast and ease-out on purpose (Emil Kowalski's framework:
/// buttons must confirm the press instantly; 90–130ms, ease-out, never ease-in).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  final HitTestBehavior behavior;
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) { if (mounted && _down != v) setState(() => _down = v); }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Renders a store/point logo from a base64 data-URI OR an http(s) URL (once
/// images are offloaded to external storage), or a fallback storefront icon.
Widget storeLogo(String logo, double size, {String fallbackIcon = 'storefront'}) {
  final img = imageProviderFor(logo);
  if (img != null) {
    return ClipRRect(borderRadius: BorderRadius.circular(size * 0.28), child: Image(image: img, width: size, height: size, fit: BoxFit.cover));
  }
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(size * 0.28)),
    child: mi(fallbackIcon, size: size * 0.6, color: C.greenMid),
  );
}

/// The user's profile picture as a circle — their uploaded photo when they have
/// one, otherwise the green gradient + person icon. Single source of truth so the
/// avatar looks identical everywhere (home bar, headers, settings, edit sheet).
/// [star] marks a collect-point holder — a small gold star sits on the circle.
Widget avatarCircle(String avatar, double size, {Border? border, bool star = false}) {
  final img = dataUriImage(avatar);
  // ClipOval guarantees a true circular crop of the photo (a plain Container clip
  // can leave the image looking square-cut on some devices).
  final inner = img != null
      ? Image(image: img, width: size, height: size, fit: BoxFit.cover)
      : Container(
          width: size, height: size,
          decoration: const BoxDecoration(gradient: C.avatarGrad),
          alignment: Alignment.center,
          child: mi('person', size: size * 0.55, color: Colors.white),
        );
  final circle = Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, border: border),
    child: ClipOval(child: inner),
  );
  return starBadge(circle, size, show: star);
}

/// Wraps any avatar-sized circle (a photo, an initial-letter disc, …) with the
/// small gold star that marks a collect-point holder. Shared so every place
/// that shows a custom avatar fallback (e.g. the leaderboard's initial disc)
/// gets the exact same badge as [avatarCircle] instead of a one-off copy.
Widget starBadge(Widget child, double size, {bool show = true}) {
  if (!show) return child;
  final badge = (size * 0.34).clamp(14.0, 26.0);
  return SizedBox(
    width: size, height: size,
    child: Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(
        right: -1, top: -1,
        child: Container(
          width: badge, height: badge, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.gold, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: badge * 0.11),
          ),
          child: mi('star', size: badge * 0.62, color: Colors.white, fill: true),
        ),
      ),
    ]),
  );
}

/// An ImageProvider for a stored image string, or null if it's empty/unusable.
/// Handles both base64 `data:` URIs (how images were stored originally) and
/// `http(s)` URLs (once images are offloaded to external storage like
/// Cloudinary), so both work during and after the migration.
ImageProvider? imageProviderFor(String s) {
  if (s.isEmpty) return null;
  if (s.startsWith('data:')) {
    try {
      return MemoryImage(base64Decode(s.substring(s.indexOf(',') + 1)));
    } catch (_) {}
  } else if (s.startsWith('http://') || s.startsWith('https://')) {
    return NetworkImage(s);
  }
  return null;
}

/// Back-compat alias — now returns a provider for data URIs *or* URLs.
ImageProvider? dataUriImage(String s) => imageProviderFor(s);

/// Map the design's Material-Symbol ligature names to IconData (rounded style).
const Map<String, IconData> _icons = {
  'qr_code_scanner': Symbols.qr_code_scanner,
  'qr_code_2': Symbols.qr_code_2,
  'location_on': Symbols.location_on,
  'notifications': Symbols.notifications,
  'person': Symbols.person,
  'redeem': Symbols.redeem,
  'confirmation_number': Symbols.confirmation_number,
  'leaderboard': Symbols.leaderboard,
  'recycling': Symbols.recycling,
  'mail': Symbols.mail,
  'lock': Symbols.lock,
  'visibility': Symbols.visibility,
  'visibility_off': Symbols.visibility_off,
  'person_off': Symbols.person_off,
  'lock_reset': Symbols.lock_reset,
  'travel_explore': Symbols.travel_explore,
  'local_offer': Symbols.local_offer,
  'phone': Symbols.phone,
  'map': Symbols.map,
  'expand_more': Symbols.expand_more,
  'cake': Symbols.cake,
  'male': Symbols.male,
  'female': Symbols.female,
  'arrow_forward': Symbols.arrow_forward,
  'touch_app': Symbols.touch_app,
  'my_location': Symbols.my_location,
  'sort': Symbols.sort,
  'call': Symbols.call,
  'star': Symbols.star,
  'chevron_right': Symbols.chevron_right,
  'chevron_left': Symbols.chevron_left,
  'open_in_new': Symbols.open_in_new,
  'schedule': Symbols.schedule,
  'inventory_2': Symbols.inventory_2,
  'bolt': Symbols.bolt,
  'apps': Symbols.apps,
  'restaurant': Symbols.restaurant,
  'fitness_center': Symbols.fitness_center,
  'public': Symbols.public,
  'local_cafe': Symbols.local_cafe,
  'storefront': Symbols.storefront,
  'shopping_bag': Symbols.shopping_bag,
  'more_horiz': Symbols.more_horiz,
  'smart_display': Symbols.smart_display,
  'play_circle': Symbols.play_circle,
  'group': Symbols.group,
  'content_copy': Symbols.content_copy,
  'ios_share': Symbols.ios_share,
  'photo_camera': Symbols.photo_camera,
  'edit': Symbols.edit,
  'help': Symbols.help,
  'info': Symbols.info,
  'logout': Symbols.logout,
  'add_circle': Symbols.add_circle,
  'check_circle': Symbols.check_circle,
  'language': Symbols.language,
  'campaign': Symbols.campaign,
  'sell': Symbols.sell,
  'card_giftcard': Symbols.card_giftcard,
  'park': Symbols.park,
  'water_drop': Symbols.water_drop,
  'water_bottle': Symbols.water_bottle,
  'timer': Symbols.timer,
  'school': Symbols.school,
  'toll': Symbols.toll,
  'emoji_events': Symbols.emoji_events,
  'military_tech': Symbols.military_tech,
  'workspace_premium': Symbols.workspace_premium,
  'eco': Symbols.eco,
  'close': Symbols.close,
  'refresh': Symbols.refresh,
  'undo': Symbols.undo,
  'home': Symbols.home,
  'grid_view': Symbols.grid_view,
  'settings': Symbols.settings,
  'add': Symbols.add,
  'remove': Symbols.remove,
  'directions': Symbols.directions,
  'navigation': Symbols.navigation,
  'support_agent': Symbols.support_agent,
};

IconData wIcon(String name) => _icons[name] ?? Symbols.circle;

/// A Material-Symbol icon widget. [fill] toggles the filled variant.
Widget mi(String name, {double size = 24, Color color = C.ink, bool fill = false, double weight = 400}) => Icon(
      wIcon(name),
      size: size,
      color: color,
      fill: fill ? 1 : 0,
      weight: weight,
    );

Color hexColor(String hex, {Color fallback = C.green}) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Full-width gradient primary button used across the app.
/// Pass [loading] while an async action runs: it shows a spinner and ignores
/// taps, giving feedback and preventing accidental double-submits.
class GradientButton extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback onTap;
  final double height;
  final Gradient gradient;
  final Color textColor;
  final Widget? leading;
  final bool loading;

  const GradientButton({
    super.key, required this.label, this.icon, required this.onTap,
    this.height = 58, this.gradient = C.greenButton, this.textColor = Colors.white, this.leading,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        opacity: loading ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: height,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18), boxShadow: C.greenBtnShadow),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation(textColor)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 12)],
                      if (leading == null && icon != null) ...[mi(icon!, color: textColor, size: 24), const SizedBox(width: 10)],
                      Text(label, style: cairo(17, w: FontWeight.w700, color: textColor)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String msg, {bool top = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [mi('info', color: C.gold, size: 20), const SizedBox(width: 8), Expanded(child: Text(msg, style: cairo(14, w: FontWeight.w600, color: Colors.white)))]),
    backgroundColor: C.ink,
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.only(bottom: top ? 700 : 100, left: 24, right: 24),
    duration: const Duration(seconds: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ));
}
