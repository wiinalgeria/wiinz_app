import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Bottom sheet to pick the app language (Arabic / French / English).
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(localeProvider);
  return showModalBottomSheet<void>(
    context: context, backgroundColor: C.sand,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Directionality(
      textDirection: appDirection,
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Text(tr('اللغة'), style: cairo(18, w: FontWeight.w800, color: C.forest)),
          const SizedBox(height: 16),
          ...supportedLangs.map((l) {
            final on = l == current;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () { ref.read(localeProvider.notifier).setLang(l); Navigator.pop(context); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: on ? C.tint1 : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: on ? C.green : C.cardBorder, width: on ? 1.8 : 1),
                  ),
                  child: Row(children: [
                    Text(langFlags[l] ?? '', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(langNames[l] ?? l, style: cairo(16, w: FontWeight.w700, color: on ? C.forest : C.ink))),
                    if (on) mi('check_circle', size: 22, color: C.green),
                  ]),
                ),
              ),
            );
          }),
        ]),
      )),
    ),
  );
}

/// Compact language button (globe + current language name).
class LanguagePill extends ConsumerWidget {
  final Color? color;
  final Color? textColor;
  const LanguagePill({super.key, this.color, this.textColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final fg = textColor ?? C.forest;
    return Pressable(
      pressedScale: 0.94,
      onTap: () => showLanguageSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.4), width: 1.3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          mi('language', size: 18, color: fg),
          const SizedBox(width: 6),
          Text(langNames[lang] ?? lang, style: cairo(13.5, w: FontWeight.w800, color: fg)),
        ]),
      ),
    );
  }
}
