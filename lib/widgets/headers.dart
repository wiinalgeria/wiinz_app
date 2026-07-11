import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Header for map / perks / gifts: title + avatar(→more) + back(→home).
class PlainHeader extends StatelessWidget {
  final String title;
  final bool showAvatar;
  const PlainHeader(this.title, {super.key, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      color: C.sand,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: cairo(22, w: FontWeight.w800, color: C.forest)),
          Row(children: [
            if (showAvatar) ...[
              GestureDetector(
                onTap: () => context.go('/more'),
                child: Container(width: 42, height: 42, decoration: BoxDecoration(gradient: C.avatarGrad, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: mi('person', size: 24, color: Colors.white)),
              ),
              const SizedBox(width: 10),
            ],
            GestureDetector(
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
