import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/session.dart';
import '../../core/notifications.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/change_password.dart';
import '../../widgets/bottom_nav.dart';
import '../overlays/overlays.dart';

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
  AdBanner? _ad;

  @override
  void initState() {
    super.initState();
    _loadAd();
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
    });
  }

  Future<void> _maybeShowPromo() async {
    final promo = await ref.read(apiClientProvider).getPromo();
    if (promo == null || !mounted) return;
    final img = dataUriImage(promo.image);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(children: [
              if (img != null)
                AspectRatio(aspectRatio: 4 / 3, child: Image(image: img, fit: BoxFit.cover, width: double.infinity))
              else
                Container(height: 150, width: double.infinity, decoration: const BoxDecoration(gradient: C.forestGrad),
                  child: Center(child: mi('local_offer', size: 60, color: Colors.white))),
              Positioned(top: 8, left: 8, child: GestureDetector(
                onTap: () => Navigator.pop(dctx),
                child: Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                  child: mi('close', size: 20, color: Colors.white)),
              )),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (promo.title.isNotEmpty) Text(promo.title, textAlign: TextAlign.center, style: cairo(19, w: FontWeight.w800, color: C.forest)),
                if (promo.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(promo.subtitle, textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6)),
                ],
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () async {
                    ref.read(apiClientProvider).promoClick();
                    final url = promo.ctaUrl.trim();
                    if (url.isNotEmpty) {
                      try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
                    }
                    if (dctx.mounted) Navigator.pop(dctx);
                  },
                  child: Container(
                    width: double.infinity, height: 54, alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(16), boxShadow: C.greenBtnShadow),
                    child: Text(promo.ctaText.isEmpty ? 'اكتشف المزيد' : promo.ctaText, style: cairo(16, w: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
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
        'أودِع قواريرك',
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
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/wiin-logo-green.png', width: 104),
                const SizedBox(height: 14),
                Text('اجمع القارورات، اكسب النقاط، واربح الهدايا', textAlign: TextAlign.center, style: cairo(16.5, w: FontWeight.w800, color: C.forest, height: 1.5)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    controller: pageCtrl,
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
                        Text(s.$1, textAlign: TextAlign.center, style: cairo(19, w: FontWeight.w800, color: C.ink)),
                        const SizedBox(height: 8),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(s.$2, textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6))),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // page indicator
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: page == i ? 22 : 8, height: 8,
                  decoration: BoxDecoration(color: page == i ? C.green : const Color(0xFFD9E4D4), borderRadius: BorderRadius.circular(4)),
                ))),
                const SizedBox(height: 18),
                Row(children: [
                  // back button (hidden on the first slide)
                  if (page > 0)
                    Expanded(child: GestureDetector(
                      onTap: () => pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      child: Container(height: 52, alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFF1F8EF), borderRadius: BorderRadius.circular(15), border: Border.all(color: C.cardBorder)),
                        child: Text('السابق', style: cairo(15, w: FontWeight.w700, color: C.forest))),
                    )),
                  if (page > 0) const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
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
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFFCEBCB), shape: BoxShape.circle), child: mi('lock_reset', size: 28, color: Color(0xFFB7791F))),
            const SizedBox(height: 14),
            Text('كلمة مرور مؤقتة', style: cairo(18, w: FontWeight.w800, color: C.forest)),
            const SizedBox(height: 8),
            Text('تم تعيين كلمة مرور مؤقتة لحسابك من قِبل الإدارة. هل تريد تغييرها الآن إلى كلمة مرور خاصة بك؟',
                textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text('تخطّي', style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
            TextButton(
              onPressed: () { Navigator.pop(dctx); showChangePasswordDialog(context, ref, confirmFirst: false); },
              child: Text('تغيير كلمة المرور', style: cairo(14, w: FontWeight.w800, color: C.green)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAd() async {
    final ad = await ref.read(apiClientProvider).homeAd();
    if (mounted) setState(() => _ad = ad);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Text.rich(TextSpan(text: 'مرحباً، ', style: noto(14, color: C.textSecondary), children: [
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
                    GestureDetector(
                      onTap: () => context.go('/scan'),
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(20), boxShadow: C.greenBtnShadow),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                            child: mi('qr_code_scanner', color: Colors.white, size: 26)),
                          const SizedBox(width: 12),
                          Text('مسح رمز QR لكسب النقاط', style: cairo(18, w: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // secondary map
                    GestureDetector(
                      onTap: () => context.go('/map'),
                      child: Container(
                        height: 62,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.tint4, width: 1.5),
                          boxShadow: [BoxShadow(color: const Color(0xFF3D7C32).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))]),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          mi('location_on', size: 24, color: C.green),
                          const SizedBox(width: 10),
                          Text('اكتشف نقاط الجمع القريبة', style: cairo(16, w: FontWeight.w700, color: C.forest)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _adBanner(),
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
            _circleBtn('person', () => context.go('/more'), gradient: C.avatarGrad, iconColor: Colors.white, border: Colors.white),
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
          Align(alignment: Alignment.centerLeft, child: GestureDetector(
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
    return GestureDetector(
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
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
                child: Text('أخضر', style: cairo(10, w: FontWeight.w700, color: Colors.white))),
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
          Text('الكود الشخصي', style: noto(12, color: Colors.white.withValues(alpha: 0.6))),
          Text(user.name, style: cairo(17, w: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          Text('اعرض هذا الرمز لموظف نقطة الجمع ليضيف نقاطك', style: noto(11.5, color: Colors.white.withValues(alpha: 0.55), height: 1.5), textAlign: TextAlign.right),
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
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999)),
                child: Text(badge, style: cairo(10, w: FontWeight.w700, color: Colors.white))),
            ]),
            Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), shape: BoxShape.circle), child: mi('lock', size: 20, color: Colors.white)),
          ]),
          const SizedBox(height: 12),
          mi(icon, size: 34, color: Colors.white.withValues(alpha: 0.9)),
          Text(title, style: cairo(18, w: FontWeight.w800, color: Colors.white)),
          Text('افتحها عند جمع $goal Wz', style: noto(12, color: Colors.white.withValues(alpha: 0.85))),
          const Spacer(),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.black.withValues(alpha: 0.22), valueColor: const AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$balance / $goal Wz', style: cairo(11, w: FontWeight.w700, color: Colors.white)),
            Text('باقٍ $left Wz', style: cairo(11, w: FontWeight.w700, color: Colors.white)),
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

  Widget _adBanner() {
    final title = _ad?.title ?? 'إنترنت أسرع مع شريكنا';
    final sub = _ad?.subtitle ?? 'عرض حصري لمستخدمي WIINZ';
    final adImg = dataUriImage(_ad?.image ?? '');
    return Container(
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
          child: Text('إعلان', style: noto(10, w: FontWeight.w600, color: Colors.white)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: cairo(19, w: FontWeight.w800, color: Colors.white, height: 1.3)),
          const SizedBox(height: 4),
          Text(sub, style: noto(12.5, color: Colors.white.withValues(alpha: 0.85))),
        ])),
      ]),
    );
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
