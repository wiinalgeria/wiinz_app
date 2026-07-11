import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart' show Store;
import '../../widgets/ui.dart';

/// Generic confirm dialog. Returns true if confirmed.
Future<bool> showConfirm(BuildContext context, {required String title, required String message, String confirmLabel = 'تأكيد', String cancelLabel = 'إلغاء', String icon = 'redeem', Color accent = C.green}) async {
  final res = await showDialog<bool>(
    context: context, barrierColor: const Color(0xB80C140E),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: Dialog(
      backgroundColor: C.sand, insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle), child: mi(icon, size: 36, color: accent)),
          const SizedBox(height: 16),
          Text(title, style: cairo(19, w: FontWeight.w800, color: C.forest), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: noto(14, color: C.textSecondary, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(height: 54, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
                child: Text(cancelLabel, style: cairo(15, w: FontWeight.w700, color: const Color(0xFF6B6459)))),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(height: 54, alignment: Alignment.center,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, accent]), borderRadius: BorderRadius.circular(16)),
                child: Text(confirmLabel, style: cairo(15, w: FontWeight.w700, color: Colors.white))),
            )),
          ]),
        ]),
      ),
    )),
  );
  return res ?? false;
}

/// Bottle-count stepper shown after a valid scan. Returns the confirmed count, or null if cancelled.
Future<int?> showBottleStepper(BuildContext context, {required String pointName, required int pointsPerBottle}) {
  int count = 1;
  return showDialog<int>(
    context: context, barrierColor: const Color(0xB80C140E), barrierDismissible: false,
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        backgroundColor: C.sand, insetPadding: const EdgeInsets.all(28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: C.tint1, shape: BoxShape.circle), child: mi('recycling', size: 38, color: C.greenMid)),
            const SizedBox(height: 16),
            Text('كم عدد القارورات التي جمعتها؟', style: cairo(19, w: FontWeight.w800, color: C.forest), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(pointName, style: noto(13, color: C.textSecondary)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _stepBtn('remove', () { if (count > 1) setLocal(() => count--); }, enabled: count > 1),
              Container(
                width: 96, alignment: Alignment.center,
                child: Text('$count', style: cairo(46, w: FontWeight.w900, color: C.forest)),
              ),
              _stepBtn('add', () => setLocal(() => count++)),
            ]),
            const SizedBox(height: 8),
            Text('= ${count * pointsPerBottle} Wz', style: cairo(16, w: FontWeight.w800, color: C.goldText)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, null),
                child: Container(height: 54, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
                  child: Text('إلغاء', style: cairo(15, w: FontWeight.w700, color: const Color(0xFF6B6459)))),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: GradientButton(label: 'تأكيد الإيداع', height: 54, onTap: () => Navigator.pop(context, count))),
            ]),
          ]),
        ),
      ),
    )),
  );
}

Widget _stepBtn(String icon, VoidCallback onTap, {bool enabled = true}) => GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: enabled ? C.greenButton : null,
          color: enabled ? null : const Color(0xFFE8E0CE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: mi(icon, size: 28, color: Colors.white),
      ),
    );

/// Scan success modal (+points).
Future<void> showScanSuccess(BuildContext context, {required int points, required int newBalance}) {
  return showDialog(
    context: context, barrierColor: const Color(0xB80C140E),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: Dialog(
      backgroundColor: C.sand, insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 96, height: 96, decoration: BoxDecoration(gradient: C.avatarGrad, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: C.greenMid.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 16))]),
            child: mi('check_circle', size: 56, color: Colors.white, fill: true)),
          const SizedBox(height: 18),
          Text('تمت إضافة نقاطك!', style: cairo(23, w: FontWeight.w800, color: C.forest)),
          const SizedBox(height: 6),
          Text('شكراً لمساهمتك في إعادة التدوير ♻️', style: noto(14, color: C.textSecondary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFFFF6E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF3E1BC))),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('+$points', style: cairo(44, w: FontWeight.w900, color: C.gold)),
              const SizedBox(width: 8),
              Text('Wz', style: cairo(20, w: FontWeight.w800, color: C.goldText)),
            ]),
          ),
          const SizedBox(height: 12),
          Text.rich(TextSpan(text: 'رصيدك الآن ', style: noto(13, color: const Color(0xFF6B6459)), children: [
            TextSpan(text: '$newBalance Wz', style: cairo(13, w: FontWeight.w800, color: C.goldText)),
          ])),
          const SizedBox(height: 20),
          GradientButton(label: 'رائع، تم', height: 54, onTap: () => Navigator.pop(context)),
        ]),
      ),
    )),
  );
}

/// Redemption / gift code popup (deep-forest header + QR + code + store info).
Future<void> showCodePopup(BuildContext context, {required String title, required String code, required int balance, Store? store}) {
  return showDialog(
    context: context, barrierColor: const Color(0xB80C140E),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: Dialog(
      backgroundColor: Colors.white, insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(gradient: C.forestGrad),
          child: Column(children: [
            Container(width: 66, height: 66, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: mi('confirmation_number', size: 36, color: C.gold)),
            const SizedBox(height: 12),
            Text('تم الاستلام بنجاح!', style: cairo(20, w: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(title, style: noto(13, color: Colors.white.withValues(alpha: 0.7))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(children: [
            Text('يتحقق المتجر من الكود يدوياً أو بمسح رمز QR لتسليمك هديتك', style: cairo(15, w: FontWeight.w700, color: C.forest, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Container(width: 150, height: 150, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.divider)),
              child: QrImageView(data: code, padding: EdgeInsets.zero)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5FBF7), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.tint4, width: 2)),
              child: Column(children: [
                Text('CODE', style: noto(10, color: C.textSecondary, w: FontWeight.w600)),
                Text(code, style: cairo(26, w: FontWeight.w900, color: C.forest, spacing: 3), textDirection: TextDirection.ltr),
              ]),
            ),
            // partner store card so the user knows where to redeem
            if (store != null && store.name.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder)),
                child: Column(children: [
                  Row(children: [
                    storeLogo(store.logo, 44),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(store.name, style: cairo(15, w: FontWeight.w800, color: C.forest)),
                      if (store.address.isNotEmpty) Row(children: [mi('location_on', size: 13, color: C.textTertiary), const SizedBox(width: 3), Expanded(child: Text(store.address, style: noto(11.5, color: C.textSecondary), overflow: TextOverflow.ellipsis))]),
                      if (store.phone.isNotEmpty) Row(children: [mi('call', size: 13, color: C.green), const SizedBox(width: 3), Text(store.phone, style: noto(11.5, color: C.textSecondary), textDirection: TextDirection.ltr)]),
                    ])),
                  ]),
                  if (store.hasLocation) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${store.lat},${store.lng}'), mode: LaunchMode.externalApplication),
                      child: Container(height: 46, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: C.tint4, width: 1.5)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          mi('directions', size: 20, color: const Color(0xFF1C7ED6)), const SizedBox(width: 8),
                          Text('موقع المتجر على الخريطة', style: cairo(14, w: FontWeight.w700, color: C.forest)),
                        ])),
                    ),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Text('رصيدك الآن $balance Wz', style: noto(12, color: C.textTertiary)),
            const SizedBox(height: 16),
            GradientButton(label: 'تم', height: 52, onTap: () => Navigator.pop(context)),
          ]),
        ),
      ])),
    )),
  );
}
