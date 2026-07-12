import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _qr?.dispose();
    super.dispose();
  }

  // validate the code → ask for bottle count → confirm → award → success.
  Future<void> _submit(String code) async {
    if (_busy || _handling || code.trim().isEmpty) return;
    _handling = true;
    setState(() => _busy = true);
    await _qr?.pauseCamera();
    final api = ref.read(apiClientProvider);
    try {
      final v = await api.validateScan(code.trim());
      if (!mounted) return;
      final bottles = await showBottleStepper(context, pointName: v['pointName'], pointsPerBottle: v['pointsPerBottle']);
      if (bottles == null || bottles <= 0) return; // cancelled
      final res = await api.scan(code.trim(), bottles: bottles);
      ref.read(sessionProvider.notifier).setPoints(res['newBalance']);
      if (!mounted) return;
      await showScanSuccess(context, points: res['pointsAwarded'], newBalance: res['newBalance']);
      if (mounted) await _showRating(code.trim());
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'حدث خطأ، حاول مجدداً');
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
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFEAF6EF), shape: BoxShape.circle), child: mi('recycling', size: 28, color: C.green)),
              const SizedBox(height: 14),
              Text('قيّم نقطة الجمع', style: cairo(18, w: FontWeight.w800, color: C.forest)),
              const SizedBox(height: 6),
              Text('كيف كانت تجربتك في هذه النقطة؟', textAlign: TextAlign.center, style: noto(13, color: C.textSecondary)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
                onTap: () => setD(() => rating = i + 1),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: mi('star', size: 40, color: i < rating ? C.gold : const Color(0xFFDDD6C7), fill: i < rating)),
              ))),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: Text('تخطّي', style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
              TextButton(
                onPressed: rating == 0 ? null : () {
                  ref.read(apiClientProvider).ratePoint(code, rating);
                  Navigator.pop(dctx);
                  if (mounted) showToast(context, 'شكراً لتقييمك ⭐');
                },
                child: Text('إرسال التقييم', style: cairo(14, w: FontWeight.w800, color: rating == 0 ? C.textTertiary : C.green)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      Text('يحتاج التطبيق إلى إذن الكاميرا لمسح الرموز',
                        textAlign: TextAlign.center, style: noto(14, color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async { await openAppSettings(); },
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                          decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(12)),
                          child: Text('فتح الإعدادات', style: cairo(14, w: FontWeight.w700, color: Colors.white))),
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
                        Text('مسح رمز QR', style: cairo(20, w: FontWeight.w800, color: Colors.white)),
                        Pressable(onTap: () => context.go('/home'), child: Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
                          child: Transform.flip(flipX: true, child: mi('arrow_forward', size: 22, color: Colors.white)))),
                      ]),
                    ),
                    const Spacer(),
                    Padding(padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                      child: Text('وجّه الكاميرا نحو رمز QR الموجود على نقطة الجمع', textAlign: TextAlign.center, style: noto(14, color: Colors.white.withValues(alpha: 0.85)))),
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
              Text('لا تعرف أين توجد نقاط الجمع؟', style: noto(12.5, color: C.textTertiary)),
              const SizedBox(height: 10),
              Pressable(onTap: () => context.go('/map'), child: Container(
                height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: C.tint4, width: 1.5)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  mi('location_on', size: 22, color: C.green), const SizedBox(width: 9),
                  Text('اعرض نقاط الجمع على الخريطة', style: cairo(15, w: FontWeight.w700, color: C.forest)),
                ]))),
            ]))),
        ],
      ),
    );
  }
}
