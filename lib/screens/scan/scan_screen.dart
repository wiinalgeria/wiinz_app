import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../overlays/dialogs.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  // ZXing-based scanner (camera2) — no CameraX / Google ML Kit, so it works on
  // devices where the ML Kit stack fails ("An unexpected error occurred").
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'wiinz-qr');
  QRViewController? _qr;
  bool _busy = false;
  bool _handling = false; // guards against double-detection while a deposit is in progress
  bool _denied = false;
  // Collect-point holders can scan in two modes: credit ANOTHER user's deposit
  // at their point, or deposit their own bottles like a normal user.
  bool _creditMode = true;
  bool _intro = true; // ignore scans until the 3-step guide is dismissed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The 3-step guide, shown over the camera as soon as the scanner opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showScanIntro(context);
      if (mounted) setState(() => _intro = false);
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    _qr = controller;
    controller.scannedDataStream.listen((barcode) {
      final code = barcode.code;
      if (code != null) _submit(code);
    });
  }

  // Pause the camera when the app is backgrounded and resume it on return, so
  // it doesn't come back as a frozen black frame after leaving and re-entering.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_qr == null) return;
    if (state == AppLifecycleState.resumed) {
      if (!_busy && !_handling) _qr?.resumeCamera();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _qr?.pauseCamera();
    }
  }

  // On hot-reload the camera must be nudged (no-op in release).
  @override
  void reassemble() {
    super.reassemble();
    _qr?.pauseCamera();
    _qr?.resumeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // QRViewController self-disposes when the QRView unmounts (plugin ≥2.x).
    super.dispose();
  }

  // A holder scanning in "credit" mode is reading a USER's QR to award that
  // user a deposit at the holder's own point — the opposite direction to a
  // normal scan, so it takes its own flow.
  Future<void> _creditUser(String userQr) async {
    if (_busy || _handling || userQr.trim().isEmpty) return;
    _handling = true;
    setState(() => _busy = true);
    await _qr?.pauseCamera();
    final api = ref.read(apiClientProvider);
    final point = ref.read(sessionProvider).user?.holderPoint;
    try {
      if (!mounted) return;
      final bottles = await showBottleStepper(context,
          pointName: point?.name ?? '', pointsPerBottle: 0,
          maxBottles: 0, title: 'كم عدد القارورات التي أودعها؟');
      if (bottles == null || bottles <= 0) return;
      final res = await api.holderCredit(userQr.trim(), bottles);
      if (!mounted) return;
      showToast(context, trf('تمت إضافة {n} Wz إلى {name}', {'n': '${res['pointsAwarded']}', 'name': '${res['userName']}'}));
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, tr('حدث خطأ، حاول مجدداً'));
    } finally {
      _handling = false;
      if (mounted) {
        setState(() => _busy = false);
        _qr?.resumeCamera();
      }
    }
  }

  // validate the code → ask for bottle count → confirm → award → success.
  Future<void> _submit(String code) async {
    if (_intro || _busy || _handling || code.trim().isEmpty) return;
    // Holder in credit mode: the scanned code is a USER, not a point.
    final me = ref.read(sessionProvider).user;
    if (me != null && me.isHolder && me.holderPoint != null && _creditMode) {
      return _creditUser(code);
    }
    _handling = true;
    setState(() => _busy = true);
    await _qr?.pauseCamera();
    final api = ref.read(apiClientProvider);
    try {
      final v = await api.validateScan(code.trim());
      if (!mounted) return;
      // Still cooling down from the last deposit → show the countdown instead of
      // the stepper, so a user who re-scans sees exactly how long is left. They
      // can go straight through once it hits zero.
      final left = (v['cooldownLeft'] as num?)?.toInt() ?? 0;
      if (left > 0) {
        final proceed = await showDepositCooldown(context, seconds: left);
        if (!proceed || !mounted) return;
      }
      final bottles = await showBottleStepper(context,
          pointName: v['pointName'], pointsPerBottle: v['pointsPerBottle'],
          maxBottles: (v['maxBottles'] as num?)?.toInt() ?? 0);
      if (bottles == null || bottles <= 0) return; // cancelled
      final res = await api.scan(code.trim(), bottles: bottles);
      ref.read(sessionProvider.notifier).setPoints(res['newBalance']);
      if (!mounted) return;
      await showScanSuccess(context, points: res['pointsAwarded'], newBalance: res['newBalance']);
      if (mounted) await _showRating(code.trim());
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      // The server is the authority on the limits, so honour its rejection even
      // if the app's copy of them was stale (or the UI was bypassed).
      if (e.code == 'cooldown') {
        await showDepositCooldown(context, seconds: e.intField('retryAfter') ?? 0);
      } else if (e.code == 'too_many_bottles') {
        showToast(context, trf('الحد الأقصى {n} قارورة في الإيداع الواحد', {'n': '${e.intField('maxBottles') ?? 0}'}));
      } else {
        showToast(context, e.message);
      }
    } catch (_) {
      if (mounted) showToast(context, tr('حدث خطأ، حاول مجدداً'));
    } finally {
      _handling = false;
      if (mounted) {
        setState(() => _busy = false);
        _qr?.resumeCamera();
      }
    }
  }

  // 5-star rating for the collection point after a successful deposit.
  Future<void> _showRating(String code) async {
    int rating = 0;
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => Directionality(
          textDirection: appDirection,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFEAF6EF), shape: BoxShape.circle), child: mi('recycling', size: 28, color: C.green)),
              const SizedBox(height: 14),
              Text(tr('قيّم نقطة الجمع'), style: cairo(18, w: FontWeight.w800, color: C.forest)),
              const SizedBox(height: 6),
              Text(tr('كيف كانت تجربتك في هذه النقطة؟'), textAlign: TextAlign.center, style: noto(13, color: C.textSecondary)),
              const SizedBox(height: 16),
              // Stars laid out left → right (star 1 on the left) regardless of RTL.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => Pressable(
                  pressedScale: 0.8,
                  onTap: () => setD(() => rating = i + 1),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: mi('star', size: 40, color: i < rating ? C.gold : const Color(0xFFDDD6C7), fill: i < rating)),
                ))),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: Text(tr('تخطّي'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
              TextButton(
                onPressed: rating == 0 ? null : () {
                  ref.read(apiClientProvider).ratePoint(code, rating);
                  Navigator.pop(dctx);
                  if (mounted) showToast(context, tr('شكراً لتقييمك ⭐'));
                },
                child: Text(tr('إرسال التقييم'), style: cairo(14, w: FontWeight.w800, color: rating == 0 ? C.textTertiary : C.green)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeBtn(String label, String icon, bool on, VoidCallback onTap) => Pressable(
    onTap: onTap,
    child: Container(
      height: 46, alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: on ? C.greenButton : null,
        color: on ? null : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? Colors.transparent : C.cardBorder, width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        mi(icon, size: 18, color: on ? Colors.white : C.textSecondary),
        const SizedBox(width: 6),
        Flexible(child: Text(tr(label), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: cairo(12.5, w: FontWeight.w800, color: on ? Colors.white : C.textSecondary))),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final me = ref.watch(sessionProvider).user;
    final holder = (me != null && me.isHolder) ? me.holderPoint : null;
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F0C),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ===== camera area =====
          Expanded(
            child: Stack(
              children: [
                QRView(
                  key: _qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  onPermissionSet: (ctrl, granted) { if (mounted) setState(() => _denied = !granted); },
                  overlay: QrScannerOverlayShape(
                    borderColor: C.green,
                    borderRadius: 16,
                    borderLength: 34,
                    borderWidth: 9,
                    cutOutSize: 250,
                    overlayColor: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                if (_denied)
                  Container(color: const Color(0xFF0C0F0C), child: Center(child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      mi('qr_code_scanner', size: 56, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(tr('يحتاج التطبيق إلى إذن الكاميرا لمسح الرموز'),
                        textAlign: TextAlign.center, style: noto(14, color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 16),
                      Pressable(
                        onTap: () async { await openAppSettings(); },
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                          decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(12)),
                          child: Text(tr('فتح الإعدادات'), style: cairo(14, w: FontWeight.w700, color: Colors.white))),
                      ),
                    ]),
                  ))),
                // header + hint on top of the camera
                SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(tr('مسح رمز QR'), style: cairo(20, w: FontWeight.w800, color: Colors.white)),
                        Pressable(onTap: () => context.go('/home'), child: Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
                          child: Transform.flip(flipX: true, child: mi('arrow_forward', size: 22, color: Colors.white)))),
                      ]),
                    ),
                    const Spacer(),
                    Padding(padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                      child: Text(tr('وجّه الكاميرا نحو رمز QR الموجود على نقطة الجمع'), textAlign: TextAlign.center, style: noto(14, color: Colors.white.withValues(alpha: 0.85)))),
                  ]),
                ),
              ],
            ),
          ),
          // ===== bottom sheet: just the "find points on the map" shortcut =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(color: C.sand, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 14),
              // Holders choose what they're scanning: another user's code (to
              // credit that user at their point) or a point's code (to deposit
              // their own bottles like any user).
              if (holder != null) ...[
                Row(children: [
                  Expanded(child: _modeBtn('امسح كنقطة جمع', 'store', _creditMode, () => setState(() => _creditMode = true))),
                  const SizedBox(width: 8),
                  Expanded(child: _modeBtn('أودع كمستخدم', 'person', !_creditMode, () => setState(() => _creditMode = false))),
                ]),
                const SizedBox(height: 8),
                Text(
                  _creditMode
                    ? trf('امسح رمز المستخدم لإضافة إيداعه في {name}', {'name': holder.name})
                    : tr('امسح رمز نقطة الجمع لإيداع قواريرك أنت'),
                  textAlign: TextAlign.center, style: noto(11.5, color: C.textTertiary)),
                const SizedBox(height: 12),
              ],
              Text(tr('لا تعرف أين توجد نقاط الجمع؟'), style: noto(12.5, color: C.textTertiary)),
              const SizedBox(height: 10),
              Pressable(onTap: () => context.go('/map'), child: Container(
                height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: C.tint4, width: 1.5)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  mi('location_on', size: 22, color: C.green), const SizedBox(width: 9),
                  Text(tr('اعرض نقاط الجمع على الخريطة'), style: cairo(15, w: FontWeight.w700, color: C.forest)),
                ]))),
            ]))),
        ],
      ),
    );
  }
}
