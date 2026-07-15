import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/session.dart';
import '../../core/notifications.dart';
import '../../core/local_notify.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/change_password.dart';
import '../../widgets/bottom_nav.dart';
import '../overlays/overlays.dart';

// Shown at most once per app launch so we don't nag on every return to Home.
bool _notifNudgeShownThisSession = false;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // viewportFraction < 1 leaves a sliver of the next (silver) card visible so
  // users can tell the cards are swipeable.
  final _pageCtrl = PageController(viewportFraction: 0.96);
  int _cardIndex = 0;
  bool _flipped = false;
  List<AdBanner> _ads = [];
  bool _adsLoaded = false; // true once the server answered (even with zero ads)

  @override
  void initState() {
    super.initState();
    _loadAds();
    // Initial load so the bell's unread dot is correct on entry.
    // Realtime polling + incoming banner are handled globally by NotificationHost.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(notifProvider.notifier).load();
      final signedUp = ref.read(sessionProvider.notifier).consumeJustSignedUp();
      final tempPw = ref.read(sessionProvider.notifier).consumeTempPwPrompt();
      final showPromo = ref.read(sessionProvider.notifier).consumePromo();
      if (signedUp) {
        await _showOnboarding(); // welcome splash first
      } else if (tempPw) {
        _showTempPwPrompt();
      }
      if (showPromo && mounted) await _maybeShowPromo(); // promotional popup on app entry
      await _ensureNotifPermission(); // ask for notifications on entry; nudge if disabled
      await _ensureLocationPermission(); // ask for location once on entry (not if already granted)
    });
  }

  // Prompt for location permission when the user first enters the app after
  // signing in. If it's already granted we don't ask again; if it was permanently
  // denied we don't nag (they can enable it from the map gate / settings).
  Future<void> _ensureLocationPermission() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
    } catch (_) {}
  }

  // Ask for notification permission so the user gets alerts even outside the app.
  // If notifications are disabled, nudge them (once per app session) to re-enable.
  Future<void> _ensureNotifPermission() async {
    final granted = await ensureNotificationPermission();
    if (granted || !mounted || _notifNudgeShownThisSession) return;
    _notifNudgeShownThisSession = true;
    await showDialog<void>(
      context: context,
      builder: (dctx) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFFEAF6EF), shape: BoxShape.circle), child: mi('notifications_active', size: 32, color: C.green)),
            const SizedBox(height: 14),
            Text(tr('فعّل الإشعارات'), style: cairo(18, w: FontWeight.w800, color: C.forest)),
            const SizedBox(height: 8),
            Text(tr('الإشعارات معطّلة. فعّلها لتصلك التنبيهات عن الهدايا والنقاط الجديدة حتى وأنت خارج التطبيق.'),
                textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text(tr('لاحقاً'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
            TextButton(onPressed: () { Navigator.pop(dctx); openNotificationSettings(); },
              child: Text(tr('فتح الإعدادات'), style: cairo(14, w: FontWeight.w800, color: C.green))),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeShowPromo() async {
    final promo = await ref.read(apiClientProvider).getPromo();
    if (promo == null || promo.slides.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dctx) => _PromoDialog(
        promo: promo,
        onCta: (slide) async {
          ref.read(apiClientProvider).promoClick(slide: slide.idx); // per-slide click stats
          final url = slide.ctaUrl.trim();
          if (url.isNotEmpty) {
            try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
          }
        },
      ),
    );
  }

  Future<void> _showOnboarding() async {
    if (!mounted) return;
    final pageCtrl = PageController();
    int page = 0;
    const slides = [
      (
        'ابحث عن نقطة الجمع',
        'افتح الخريطة لتجد أقرب نقطة جمع إليك بسهولة',
        'travel_explore', 'location_on', Color(0xFFE3F0F7), Color(0xFF1C7ED6),
      ),
      (
        'أودِع القارورات',
        'توجّه إلى النقطة وامسح رمز QR لإيداع القارورات',
        'qr_code_scanner', 'recycling', Color(0xFFEAF6EF), C.green,
      ),
      (
        'اكسب واربح',
        'استلم نقاطك مباشرةً واستبدلها بهدايا رائعة',
        'redeem', 'card_giftcard', Color(0xFFFCEBCB), Color(0xFFB7791F),
      ),
    ];
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => Directionality(
          textDirection: appDirection,
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/wiin-logo-green.png', width: 104),
                const SizedBox(height: 14),
                Text(tr('اجمع القارورات، اكسب النقاط، واربح الهدايا'), textAlign: TextAlign.center, style: cairo(16.5, w: FontWeight.w800, color: C.forest, height: 1.5)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    controller: pageCtrl,
                    reverse: false, // swipe + progress travel left → right
                    itemCount: slides.length,
                    onPageChanged: (i) => setD(() => page = i),
                    itemBuilder: (_, i) {
                      final s = slides[i];
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        // layered "illustration" badge
                        Container(
                          width: 130, height: 130,
                          decoration: BoxDecoration(color: s.$5, shape: BoxShape.circle),
                          child: Stack(alignment: Alignment.center, children: [
                            mi(s.$3, size: 66, color: s.$6),
                            Positioned(bottom: 18, left: 22, child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)]),
                              child: mi(s.$4, size: 20, color: s.$6),
                            )),
                          ]),
                        ),
                        const SizedBox(height: 22),
                        Text(tr(s.$1), textAlign: TextAlign.center, style: cairo(19, w: FontWeight.w800, color: C.ink)),
                        const SizedBox(height: 8),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(tr(s.$2), textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6))),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // page indicator — forced LTR so the growing dot travels left → right
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: page == i ? 22 : 8, height: 8,
                    decoration: BoxDecoration(color: page == i ? C.green : const Color(0xFFD9E4D4), borderRadius: BorderRadius.circular(4)),
                  ))),
                ),
                const SizedBox(height: 18),
                // RTL: "التالي/ابدأ" on the RIGHT (first child), "السابق" on the LEFT.
                Row(children: [
                  Expanded(child: Pressable(
                    onTap: () {
                      if (page < slides.length - 1) {
                        pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      } else {
                        Navigator.pop(dctx);
                      }
                    },
                    child: Container(height: 52, alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: const Color(0xFF3D7C32).withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))]),
                      child: Text(page < slides.length - 1 ? 'التالي' : 'ابدأ الآن', style: cairo(15.5, w: FontWeight.w800, color: Colors.white))),
                  )),
                  // back button (hidden on the first slide) — appears on the LEFT
                  if (page > 0) const SizedBox(width: 10),
                  if (page > 0)
                    Expanded(child: Pressable(
                      onTap: () => pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      child: Container(height: 52, alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFF1F8EF), borderRadius: BorderRadius.circular(15), border: Border.all(color: C.cardBorder)),
                        child: Text(tr('السابق'), style: cairo(15, w: FontWeight.w700, color: C.forest))),
                    )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showTempPwPrompt() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dctx) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFFCEBCB), shape: BoxShape.circle), child: mi('lock_reset', size: 28, color: Color(0xFFB7791F))),
            const SizedBox(height: 14),
            Text(tr('كلمة مرور مؤقتة'), style: cairo(18, w: FontWeight.w800, color: C.forest)),
            const SizedBox(height: 8),
            Text(tr('تم تعيين كلمة مرور مؤقتة لحسابك من قِبل الإدارة. هل تريد تغييرها الآن إلى كلمة مرور خاصة بك؟'),
                textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text(tr('تخطّي'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
            TextButton(
              onPressed: () { Navigator.pop(dctx); showChangePasswordDialog(context, ref, confirmFirst: false); },
              child: Text(tr('تغيير كلمة المرور'), style: cairo(14, w: FontWeight.w800, color: C.green)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAds() async {
    final ads = await ref.read(apiClientProvider).homeAds();
    if (mounted) setState(() { _ads = ads; _adsLoaded = true; });
  }

  Future<void> _openAd(AdBanner ad) async {
    final url = ad.ctaUrl.trim();
    if (url.isEmpty) return;
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final cfg = session.config;
    if (user == null) return const SizedBox();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(user),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text.rich(TextSpan(text: tr('مرحباً، '), style: noto(14, color: C.textSecondary), children: [
                        TextSpan(text: user.name, style: cairo(14, w: FontWeight.w700, color: C.ink)),
                        const TextSpan(text: ' 👋'),
                      ])),
                    ),
                    SizedBox(
                      height: 250,
                      child: PageView(
                        controller: _pageCtrl,
                        clipBehavior: Clip.none,
                        onPageChanged: (i) => setState(() { _cardIndex = i; _flipped = false; }),
                        children: [
                          _cardPage(_greenCard(user)),
                          _cardPage(_tierCard('البطاقة الفضية', 'فضية', 'workspace_premium', C.silverCard, user.points, cfg.silverGoal)),
                          _cardPage(_tierCard('البطاقة الذهبية', 'ذهبية', 'military_tech', C.goldCard, user.points, cfg.goldGoal)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _dots(),
                    const SizedBox(height: 8),
                    Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      mi('touch_app', size: 16, color: C.textTertiary),
                      const SizedBox(width: 6),
                      Flexible(child: Text(
                        _flipped ? 'اضغط للعودة إلى الرصيد' : 'اضغط على البطاقة لعرض رمز QR · اسحب للبطاقات الأخرى',
                        style: noto(11.5, color: C.textTertiary), overflow: TextOverflow.ellipsis)),
                    ])),
                    const SizedBox(height: 14),
                    // primary scan
                    Pressable(
                      onTap: () => context.go('/scan'),
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(20), boxShadow: C.greenBtnShadow),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                            child: mi('qr_code_scanner', color: Colors.white, size: 26)),
                          const SizedBox(width: 12),
                          Text(tr('مسح رمز QR لكسب النقاط'), style: cairo(18, w: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // secondary map
                    Pressable(
                      onTap: () => context.go('/map'),
                      child: Container(
                        height: 62,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.tint4, width: 1.5),
                          boxShadow: [BoxShadow(color: const Color(0xFF3D7C32).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))]),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          mi('location_on', size: 24, color: C.green),
                          const SizedBox(width: 10),
                          Text(tr('اكتشف نقاط الجمع القريبة'), style: cairo(16, w: FontWeight.w700, color: C.forest)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._adsSection(),
                  ],
                ),
              ),
            ),
            const WiinzBottomNav(current: 'home'),
          ],
        ),
      ),
    );
  }

  Widget _topBar(WiinzUser user) {
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [
            // profile picture (falls back to the person icon when none is set)
            Pressable(
              pressedScale: 0.88,
              onTap: () => context.go('/more'),
              child: avatarCircle(user.avatar, 44, border: Border.all(color: Colors.white, width: 2)),
            ),
            const SizedBox(width: 10),
            Stack(children: [
              _circleBtn('notifications', () {
                ref.read(notifProvider.notifier).markSeen();
                showNotificationsSheet(context, ref);
              }, iconColor: C.forest, border: C.cardBorder, bg: Colors.white),
              if (ref.watch(notifProvider).hasUnread)
                const Positioned(top: 8, left: 11, child: _ShiningDot()),
            ]),
          ])),
          Image.asset('assets/images/wiin-logo-green.png', width: 92),
          Align(alignment: Alignment.centerLeft, child: Pressable(
            pressedScale: 0.93,
            onTap: () => showStatsSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 20, 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.cardBorder),
                boxShadow: [BoxShadow(color: const Color(0xFF785A14).withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 28, height: 28, decoration: const BoxDecoration(gradient: C.goldGrad, shape: BoxShape.circle),
                  alignment: Alignment.center, child: Text('Wz', style: cairo(12, w: FontWeight.w800, color: Colors.white))),
                const SizedBox(width: 9),
                Text('${user.points}', style: cairo(18, w: FontWeight.w800, color: C.goldText)),
              ]),
            ),
          )),
        ],
      ),
    );
  }

  Widget _circleBtn(String icon, VoidCallback onTap, {Gradient? gradient, Color? bg, required Color iconColor, required Color border}) {
    return Pressable(
      pressedScale: 0.88,
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(gradient: gradient, color: bg, shape: BoxShape.circle, border: Border.all(color: border, width: gradient != null ? 2 : 1)),
        child: mi(icon, size: 24, color: iconColor),
      ),
    );
  }

  // Wraps a fixed-height card with vertical room so its shadow isn't clipped by the PageView.
  Widget _cardPage(Widget card) => Padding(padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 5), child: card);

  Widget _greenCard(WiinzUser user) {
    return GestureDetector(
      onTap: () => setState(() => _flipped = !_flipped),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _flipped ? 1 : 0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final angle = t * 3.14159;
          final showBack = t > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(angle),
            child: showBack
                ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(3.14159), child: _cardBack(user))
                : _cardFront(user),
          );
        },
      ),
    );
  }

  Widget _cardFront(WiinzUser user) {
    return Container(
      height: 206,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(gradient: C.greenCard, borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: C.forest.withValues(alpha: 0.45), blurRadius: 36, spreadRadius: -6, offset: const Offset(0, 18))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Image.asset('assets/images/wiin-logo-white.png', width: 62),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
                child: Text(tr('أخضر'), style: cairo(14, w: FontWeight.w800, color: Colors.white))),
            ]),
            Container(width: 38, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(9)), child: mi('qr_code_2', size: 20, color: Colors.white)),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AVAILABLE BALANCE', style: cairo(10, w: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), spacing: 2)),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('${user.points}', style: cairo(44, w: FontWeight.w900, color: Colors.white, height: 1.05)),
              const SizedBox(width: 7),
              Text('Wz', style: cairo(18, w: FontWeight.w800, color: Colors.white.withValues(alpha: 0.92))),
            ]),
          ])),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(user.name, style: cairo(21, w: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
              Row(mainAxisSize: MainAxisSize.min, children: [
                mi('location_on', size: 14, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 4),
                Text(user.commune, style: noto(12.5, color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('CARD / INVITE', style: cairo(9, w: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), spacing: 1)),
              Text(user.cardCode, style: cairo(16, w: FontWeight.w900, color: Colors.white, spacing: 1)),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _cardBack(WiinzUser user) {
    return Container(
      height: 206,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: C.forestGrad, borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: C.forest.withValues(alpha: 0.45), blurRadius: 36, spreadRadius: -6, offset: const Offset(0, 18))]),
      child: Row(children: [
        Container(width: 150, height: 150, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: QrImageView(data: user.qrCode, padding: EdgeInsets.zero)),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('WIINZ', style: cairo(18, w: FontWeight.w800, color: Colors.white, spacing: 1)),
          const SizedBox(height: 12),
          Text(tr('الكود الشخصي'), style: noto(12, color: Colors.white.withValues(alpha: 0.6))),
          Text(user.name, style: cairo(17, w: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          Text(tr('اعرض هذا الرمز لموظف نقطة الجمع ليضيف نقاطك'), style: noto(11.5, color: Colors.white.withValues(alpha: 0.55), height: 1.5), textAlign: TextAlign.right),
        ])),
      ]),
    );
  }

  Widget _tierCard(String title, String badge, String icon, Gradient grad, int balance, int goal) {
    final pct = (balance / goal).clamp(0.0, 1.0);
    final left = (goal - balance).clamp(0, goal);
    return Container(
      height: 206,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 36, spreadRadius: -6, offset: const Offset(0, 18))]),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text('WIINZ', style: cairo(19, w: FontWeight.w800, color: Colors.white, spacing: 2)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999)),
                child: Text(tr(badge), style: cairo(14, w: FontWeight.w800, color: Colors.white))),
            ]),
            // Bigger lock so it's obvious the tier is not yet available.
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), shape: BoxShape.circle), child: mi('lock', size: 30, color: Colors.white)),
          ]),
          const SizedBox(height: 10),
          mi(icon, size: 34, color: Colors.white.withValues(alpha: 0.9)),
          Text(title, style: cairo(18, w: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(tr('ستتوفر قريباً'), style: cairo(16, w: FontWeight.w800, color: Colors.white)),
          const Spacer(),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.black.withValues(alpha: 0.22), valueColor: const AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$balance / $goal Wz', style: cairo(11, w: FontWeight.w700, color: Colors.white)),
            Text(trf('باقٍ {n} Wz', {'n': '$left'}), style: cairo(11, w: FontWeight.w700, color: Colors.white)),
          ]),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) {
      final on = _cardIndex == i;
      return AnimatedContainer(duration: const Duration(milliseconds: 250), width: on ? 20 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3.5),
        decoration: BoxDecoration(color: on ? C.greenMid : const Color(0xFFD8CDB8), borderRadius: BorderRadius.circular(999)));
    }));
  }

  // Home ads: one banner per active ad, stacked one under another. Each can
  // carry a CTA button that opens its link outside the app. If the admin has
  // no active ads, the section simply disappears (no fake placeholder ad).
  List<Widget> _adsSection() {
    if (_adsLoaded && _ads.isEmpty) return const [];
    final ads = _ads.isNotEmpty
        ? _ads
        : [AdBanner(id: '_', title: tr('إنترنت أسرع مع شريكنا'), subtitle: tr('عرض حصري لمستخدمي WIINZ'))]; // pre-load placeholder
    final widgets = <Widget>[];
    for (var i = 0; i < ads.length; i++) {
      widgets.add(_adBanner(ads[i]));
      if (i != ads.length - 1) widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _adBanner(AdBanner ad) {
    final title = ad.title;
    final sub = ad.subtitle;
    final adImg = dataUriImage(ad.image);
    final hasCta = ad.ctaUrl.trim().isNotEmpty;
    final ctaLabel = ad.ctaText.trim().isEmpty ? 'اكتشف المزيد' : ad.ctaText.trim();
    return Pressable(
      pressedScale: 0.98,
      onTap: hasCta ? () => _openAd(ad) : null,
      child: Container(
        height: 130,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: C.tealCard, borderRadius: BorderRadius.circular(22),
          image: adImg == null ? null : DecorationImage(image: adImg, fit: BoxFit.cover),
          boxShadow: [BoxShadow(color: C.teal1.withValues(alpha: 0.5), blurRadius: 26, offset: const Offset(0, 12))]),
        child: Stack(children: [
          // dark scrim so the title/subtitle stay legible over an uploaded image
          if (adImg != null)
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.centerRight, end: Alignment.centerLeft,
              colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.15)])))),
          if (adImg == null) Positioned(left: -30, bottom: -40, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.85), shape: BoxShape.circle))),
          if (adImg == null) Positioned(left: 20, top: 20, child: Container(width: 90, height: 90, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle))),
          Positioned(top: 8, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(6)),
            child: Text(tr('إعلان'), style: noto(10, w: FontWeight.w600, color: Colors.white)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: cairo(19, w: FontWeight.w800, color: Colors.white, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(sub, style: noto(12.5, color: Colors.white.withValues(alpha: 0.85)), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (hasCta) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(ctaLabel, style: cairo(12.5, w: FontWeight.w800, color: C.forest)),
                  const SizedBox(width: 4),
                  Transform.flip(flipX: true, child: mi('arrow_forward', size: 15, color: C.forest)),
                ]),
              ),
            ],
          ])),
        ]),
      ),
    );
  }
}

/// Full-screen promotional popup that cycles through several slides, each shown
/// for its own number of seconds before auto-advancing (also swipeable by hand).
class _PromoDialog extends StatefulWidget {
  final Promo promo;
  final Future<void> Function(PromoSlide slide) onCta;
  const _PromoDialog({required this.promo, required this.onCta});
  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final _ctrl = PageController();
  Timer? _timer;
  int _index = 0;
  List<PromoSlide> get _slides => widget.promo.slides;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (_slides.length < 2) return; // single slide: no auto-advance
    _timer = Timer(Duration(seconds: _slides[_index].seconds), () {
      if (!mounted) return;
      final next = (_index + 1) % _slides.length;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.6).clamp(380.0, 520.0);
    return Directionality(
      textDirection: appDirection,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: h,
          child: Stack(children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: _slides.length,
              onPageChanged: (i) { setState(() => _index = i); _schedule(); },
              itemBuilder: (_, i) => _slideView(_slides[i]),
            ),
            // close button
            Positioned(top: 8, left: 8, child: Pressable(
              pressedScale: 0.85,
              onTap: () => Navigator.pop(context),
              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: mi('close', size: 20, color: Colors.white)),
            )),
            // slide dots
            if (_slides.length > 1)
              Positioned(bottom: 12, left: 0, right: 0, child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _index == i ? 20 : 7, height: 7,
                  decoration: BoxDecoration(color: _index == i ? C.green : Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                ))),
              )),
          ]),
        ),
      ),
    );
  }

  Widget _slideView(PromoSlide s) {
    final img = dataUriImage(s.image);
    final hasCta = s.ctaUrl.trim().isNotEmpty || s.ctaText.trim().isNotEmpty;
    return Column(children: [
      Expanded(child: img != null
          ? Image(image: img, fit: BoxFit.cover, width: double.infinity)
          : Container(width: double.infinity, decoration: const BoxDecoration(gradient: C.forestGrad),
              child: Center(child: mi('local_offer', size: 60, color: Colors.white)))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (s.title.isNotEmpty) Text(s.title, textAlign: TextAlign.center, style: cairo(19, w: FontWeight.w800, color: C.forest)),
          if (s.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: noto(13.5, color: C.textSecondary, height: 1.6)),
          ],
          if (hasCta) ...[
            const SizedBox(height: 16),
            Pressable(
              onTap: () async {
                await widget.onCta(s);
                if (mounted) Navigator.pop(context);
              },
              child: Container(
                width: double.infinity, height: 52, alignment: Alignment.center,
                decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(16), boxShadow: C.greenBtnShadow),
                child: Text(s.ctaText.trim().isEmpty ? 'اكتشف المزيد' : s.ctaText.trim(), style: cairo(16, w: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}

/// Pulsing/shining notification dot shown when there are unread notifications.
class _ShiningDot extends StatefulWidget {
  const _ShiningDot();
  @override
  State<_ShiningDot> createState() => _ShiningDotState();
}

class _ShiningDotState extends State<_ShiningDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return SizedBox(
          width: 12, height: 12,
          child: Stack(alignment: Alignment.center, children: [
            // expanding halo
            Container(
              width: 9 + t * 12, height: 9 + t * 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: C.gold.withValues(alpha: (1 - t) * 0.5)),
            ),
            // solid dot with a soft glow
            Container(
              width: 9, height: 9,
              decoration: BoxDecoration(
                color: C.gold, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2)), blurRadius: 6)],
              ),
            ),
          ]),
        );
      },
    );
  }
}
