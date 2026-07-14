import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/headers.dart';
import '../../widgets/bottom_nav.dart';
import '../overlays/overlays.dart';
import '../overlays/dialogs.dart';

class PerksScreen extends ConsumerStatefulWidget {
  const PerksScreen({super.key});
  @override
  ConsumerState<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends ConsumerState<PerksScreen> {
  List<MyGift> _myGifts = [];
  bool _loading = true;
  int _myRank = 0, _totalPlayers = 0;
  String _zone = '';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final mine = await api.myGifts();
      final board = await api.leaderboard();
      setState(() {
        _myGifts = mine;
        _myRank = board['myRank'] ?? 0;
        _totalPlayers = board['totalPlayers'] ?? 0;
        _zone = board['zone'] ?? '';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refund(MyGift g) async {
    final ok = await showConfirm(
      context,
      title: 'استرجاع نقاط ${g.title}؟',
      message: g.cost > 0 ? 'ستُعاد ${g.cost} Wz إلى رصيدك وتُحذف الهدية من «مكافأتي».' : 'ستُحذف الهدية من «مكافأتي».',
      confirmLabel: 'نعم، استرجع', icon: 'undo', accent: C.goldText,
    );
    if (!ok) return;
    setState(() => _busyId = g.id);
    try {
      final res = await ref.read(apiClientProvider).refundGift(g.id);
      ref.read(sessionProvider.notifier).setPoints(res['newBalance']);
      setState(() => _myGifts.removeWhere((x) => x.id == g.id));
      if (mounted) showToast(context, g.cost > 0 ? 'تم استرجاع ${g.cost} Wz' : 'تمت الإزالة', top: true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, top: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(sessionProvider).user?.points ?? 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PlainHeader('مكافأتي'),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load, color: C.green,
                  child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                    // balance banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFF6E6), Color(0xFFFCEBCB)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3E1BC))),
                      child: Row(children: [
                        Container(width: 34, height: 34, decoration: const BoxDecoration(gradient: C.goldGrad, shape: BoxShape.circle), alignment: Alignment.center,
                          child: Text('Wz', style: cairo(13, w: FontWeight.w800, color: Colors.white))),
                        const SizedBox(width: 10),
                        Text('رصيدك الحالي', style: noto(13, color: const Color(0xFF8A6A1E))),
                        const Spacer(),
                        Text.rich(TextSpan(text: '$balance ', style: cairo(20, w: FontWeight.w800, color: C.goldText), children: [TextSpan(text: 'Wz', style: cairo(13, w: FontWeight.w800, color: C.goldText))])),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    // leaderboard entry
                    Pressable(pressedScale: 0.98,
                      onTap: () => showStatsSheet(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder), boxShadow: C.cardShadow),
                        child: Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(12)), child: mi('leaderboard', size: 24, color: C.greenMid)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('ترتيبك المحلي', style: cairo(15, w: FontWeight.w700, color: C.ink)),
                            Text('من أصل $_totalPlayers في $_zone', style: noto(12, color: C.textSecondary)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(12)),
                            child: Text('#$_myRank', style: cairo(18, w: FontWeight.w900, color: C.greenMid))),
                          const SizedBox(width: 4),
                          Transform.flip(flipX: true, child: mi('chevron_right', size: 22, color: const Color(0xFFC7BCA8))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('هداياي', style: cairo(16, w: FontWeight.w800, color: C.forest)),
                    const SizedBox(height: 4),
                    Text('اعرض الكود لموظف المتجر ليمسحه ويسلّمك هديتك', style: noto(12, color: C.textSecondary)),
                    const SizedBox(height: 12),
                    if (_myGifts.isEmpty)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Column(children: [
                        mi('card_giftcard', size: 44, color: const Color(0xFFD8CDB8)),
                        const SizedBox(height: 10),
                        Text('لا توجد مكافآت بعد', style: cairo(15, w: FontWeight.w700, color: C.textTertiary)),
                        const SizedBox(height: 4),
                        Text('اختر هدية من صفحة «الهدايا» لتظهر هنا', style: noto(12.5, color: C.textTertiary)),
                      ]))
                    else ..._myGifts.map(_giftCard),
                  ]),
                )),
          const WiinzBottomNav(current: 'perks'),
        ]),
      ),
    );
  }

  Widget _giftCard(MyGift g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.cardBorder), boxShadow: C.cardShadow),
      child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: hexColor(g.iconBg, fallback: C.tint1), borderRadius: BorderRadius.circular(16)), child: mi(g.icon, size: 28, color: hexColor(g.iconColor, fallback: C.greenMid))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.title, style: cairo(16, w: FontWeight.w700, color: C.ink)),
          if (g.store.name.isNotEmpty)
            Row(children: [storeLogo(g.store.logo, 15), const SizedBox(width: 4), Flexible(child: Text(g.store.name, style: cairo(11.5, w: FontWeight.w700, color: C.greenMid), overflow: TextOverflow.ellipsis))]),
          Text(g.code, style: noto(11, color: C.textTertiary), textDirection: TextDirection.ltr),
          const SizedBox(height: 4),
          Text(g.cost > 0 ? '${g.cost} Wz' : 'مجاناً', style: cairo(15, w: FontWeight.w800, color: C.goldText)),
        ])),
        const SizedBox(width: 10),
        SizedBox(width: 120, child: Column(children: [
          Pressable(onTap: () => showCodePopup(context, title: g.title, code: g.code, balance: ref.read(sessionProvider).user?.points ?? 0, store: g.store), child: Container(height: 44,
            decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(13)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [mi('qr_code_2', size: 18, color: Colors.white), const SizedBox(width: 5), Text('عرض الكود', style: cairo(14, w: FontWeight.w700, color: Colors.white))]))),
          const SizedBox(height: 7),
          Pressable(pressedScale: 0.95, onTap: _busyId == g.id ? null : () => _refund(g), child: Container(height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.inputBorder, width: 1.5)),
            child: _busyId == g.id
                ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.goldText)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [mi('undo', size: 16, color: const Color(0xFF8A6A1E)), const SizedBox(width: 5), Text('رد النقاط', style: cairo(13.5, w: FontWeight.w700, color: const Color(0xFF8A6A1E)))]))),
        ])),
      ]),
    );
  }
}
