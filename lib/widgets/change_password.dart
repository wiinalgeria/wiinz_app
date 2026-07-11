import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Shared "change password" flow used from Settings, the temporary-password
/// popup, and the notifications list. When [confirmFirst] is true it shows a
/// confirm/cancel step before the form (used from Settings).
Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref, {bool confirmFirst = true}) async {
  if (confirmFirst) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFEAF6EF), shape: BoxShape.circle), child: mi('lock', size: 28, color: C.green)),
            const SizedBox(height: 14),
            Text('تغيير كلمة المرور', style: cairo(18, w: FontWeight.w800, color: C.forest)),
            const SizedBox(height: 6),
            Text('هل تريد تغيير كلمة مرورك؟', textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text('إلغاء', style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text('تأكيد', style: cairo(14, w: FontWeight.w800, color: C.green))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
  }
  if (!context.mounted) return;

  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool showCur = false, showNew = false, showConf = false, saving = false;
  String? err;
  await showDialog<void>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setD) {
        Widget pwField(TextEditingController c, String hint, bool show, VoidCallback toggle) => Container(
          height: 52, margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.only(right: 14, left: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.inputBorder, width: 1.5)),
          child: Row(children: [
            mi('lock', size: 20, color: C.green), const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: c, obscureText: !show, textDirection: TextDirection.ltr, textAlign: TextAlign.right,
              decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true, hintStyle: noto(14, color: C.textTertiary)),
              style: noto(15, color: C.ink),
            )),
            IconButton(
              onPressed: toggle, visualDensity: VisualDensity.compact,
              icon: mi(show ? 'visibility_off' : 'visibility', size: 20, color: C.textTertiary),
            ),
          ]),
        );
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('تغيير كلمة المرور', style: cairo(18, w: FontWeight.w800, color: C.forest)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              pwField(current, 'كلمة المرور الحالية', showCur, () => setD(() => showCur = !showCur)),
              pwField(next, 'كلمة المرور الجديدة', showNew, () => setD(() => showNew = !showNew)),
              pwField(confirm, 'تأكيد كلمة المرور الجديدة', showConf, () => setD(() => showConf = !showConf)),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: noto(12.5, color: C.danger))),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: Text('إلغاء', style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
              TextButton(
                onPressed: saving ? null : () async {
                  if (next.text.length < 8) { setD(() => err = 'كلمة المرور الجديدة قصيرة (8 أحرف على الأقل)'); return; }
                  if (next.text != confirm.text) { setD(() => err = 'كلمتا المرور غير متطابقتين'); return; }
                  setD(() { saving = true; err = null; });
                  try {
                    await ref.read(apiClientProvider).changePassword(current.text, next.text);
                    await ref.read(sessionProvider.notifier).refreshMe(); // clears the tempPassword flag
                    if (!dctx.mounted) return;
                    Navigator.pop(dctx);
                    if (context.mounted) showToast(context, 'تم تغيير كلمة المرور ✓');
                  } on ApiException catch (e) {
                    setD(() { saving = false; err = e.message; });
                  } catch (_) {
                    setD(() { saving = false; err = 'حدث خطأ، حاول مجدداً'; });
                  }
                },
                child: Text(saving ? '...' : 'حفظ', style: cairo(14, w: FontWeight.w800, color: C.green)),
              ),
            ],
          ),
        );
      },
    ),
  );
}
