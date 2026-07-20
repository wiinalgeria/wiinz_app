import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/headers.dart';
import '../../widgets/bottom_nav.dart';
import '../overlays/dialogs.dart';

// Icon per known category (keyed by the stable Arabic value). Categories the
// admin adds later still work — they just fall back to a generic icon.
const _catIcons = {
  'مطاعم': 'restaurant', 'رياضة': 'fitness_center', 'عامة': 'public',
  'مقاهي': 'local_cafe', 'محلات': 'storefront', 'منتجات': 'shopping_bag', 'اخرى': 'more_horiz',
};
const _kAll = '__all__'; // sentinel key for the "all" tab

class GiftsScreen extends ConsumerStatefulWidget {
  const GiftsScreen({super.key});
  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  List<Gift> _gifts = [];
  HeroGift? _hero;
  bool _loading = true;
  // Selected category KEY (Arabic value, or _kAll). Labels come from the server.
  String _cat = _kAll;
  List<(String, String)> _cats = []; // (key, localized label)
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (gifts, hero, cats) = await ref.read(apiClientProvider).gifts();
      setState(() {
        _gifts = gifts; _hero = hero; _cats = cats; _loading = false;
        // if the selected category disappeared from the dashboard, fall back to "all"
        if (_cat != _kAll && !cats.any((c) => c.$1 == _cat)) _cat = _kAll;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _claim(String id, String title, int cost, {String confirmLabel = 'تأكيد الاستلام'}) async {
    // choosing a gift → confirm only → redeemed straight to مكافأتي
    final ok = await showConfirm(
      context,
      title: trf('استلام {title}؟', {'title': title}),
      message: cost > 0 ? trf('سيتم خصم {cost} Wz وتُضاف الهدية إلى «مكافأتي».', {'cost': '$cost'}) : tr('ستُضاف الهدية مجاناً إلى «مكافأتي».'),
      confirmLabel: confirmLabel, icon: 'redeem', accent: C.green,
    );
    if (!ok) return;
    setState(() => _busyId = id);
    try {
      final res = await ref.read(apiClientProvider).claimGift(id);
      ref.read(sessionProvider.notifier).setPoints(res['newBalance']);
      if (mounted) showToast(context, tr('تمت إضافة الهدية إلى «مكافأتي» 🎁'));
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final filtered = _cat == _kAll ? _gifts : _gifts.where((g) => g.cat == _cat).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PlainHeader('الهدايا'),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                  Text(tr('مكافآت خاصة ومحدودة — متوفرة لفترة قصيرة فقط ✨'), style: noto(13.5, color: C.textSecondary)),
                  const SizedBox(height: 18),
                  if (_hero != null) _heroCard(_hero!),
                  const SizedBox(height: 18),
                  _catRow(),
                  const SizedBox(height: 20),
                  if (filtered.isEmpty)
                    Padding(padding: const EdgeInsets.all(30), child: Column(children: [
                      mi('redeem', size: 40, color: const Color(0xFFD8CDB8)),
                      const SizedBox(height: 8),
                      Text(tr('لا توجد هدايا في هذه الفئة حالياً'), style: cairo(14, w: FontWeight.w700, color: C.textTertiary)),
                    ]))
                  else ...filtered.map(_giftCard),
                ])),
          const WiinzBottomNav(current: 'gifts'),
        ]),
      ),
    );
  }

  Widget _heroCard(HeroGift h) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(gradient: C.forestGrad, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: C.forest.withValues(alpha: 0.5), blurRadius: 36, spreadRadius: -6, offset: const Offset(0, 16))]),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: 0, left: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [mi('bolt', size: 14, color: const Color(0xFF3D2A05)), const SizedBox(width: 3), Text(tr('محدود'), style: cairo(11, w: FontWeight.w800, color: const Color(0xFF3D2A05)))]))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 30),
          h.logo.isNotEmpty ? storeLogo(h.logo, 48) : mi('redeem', size: 40, color: C.gold),
          const SizedBox(height: 10),
          Text(h.title, style: cairo(21, w: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(h.desc, style: noto(13, color: Colors.white.withValues(alpha: 0.75), height: 1.5)),
          const SizedBox(height: 16),
          Row(children: [
            mi('schedule', size: 16, color: C.goldLight), const SizedBox(width: 5),
            Text(h.ends, style: noto(12, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(width: 14),
            mi('inventory_2', size: 16, color: C.goldLight), const SizedBox(width: 5),
            Text(h.left, style: noto(12, color: Colors.white.withValues(alpha: 0.8))),
          ]),
          const SizedBox(height: 18),
          Pressable(onTap: _busyId == h.id ? null : () => _claim(h.id, h.title, h.cost, confirmLabel: tr('تأكيد')), child: Container(
            width: double.infinity, height: 52, decoration: BoxDecoration(gradient: C.goldGrad, borderRadius: BorderRadius.circular(15)),
            alignment: Alignment.center,
            child: _busyId == h.id ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF3D2A05), strokeWidth: 2))
              : Text(h.cta, style: cairo(16, w: FontWeight.w800, color: const Color(0xFF3D2A05))))),
        ]),
      ]),
    );
  }

  Widget _catRow() {
    // "All" first, then the admin-defined categories (already localized).
    final tabs = <(String, String, String)>[
      (_kAll, tr('الكل'), 'apps'),
      ..._cats.map((c) => (c.$1, c.$2, _catIcons[c.$1] ?? 'category')),
    ];
    // Extra height + Clip.none so the active chip's drop shadow renders fully
    // instead of being cut off by the horizontal list's edge.
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: tabs.length,
        separatorBuilder: (context, i) => const SizedBox(width: 9),
        itemBuilder: (context, i) {
          final (key, label, icon) = tabs[i];
          final on = _cat == key;
          return Pressable(
            onTap: () => setState(() => _cat = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: on ? C.green : Colors.white, borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? C.green : C.cardBorder, width: 1.5),
                boxShadow: on ? [BoxShadow(color: const Color(0xFF3D7C32).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 7))] : null),
              child: Row(children: [
                mi(icon, size: 18, color: on ? Colors.white : const Color(0xFF4A463E)),
                const SizedBox(width: 6),
                Text(label, style: cairo(13.5, w: FontWeight.w700, color: on ? Colors.white : const Color(0xFF4A463E))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _giftCard(Gift g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.cardBorder), boxShadow: C.cardShadow),
      child: Row(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: hexColor(g.iconBg, fallback: C.tint1), borderRadius: BorderRadius.circular(16)),
          child: mi(g.icon, size: 26, color: hexColor(g.iconColor, fallback: C.greenMid))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(g.title, style: cairo(15, w: FontWeight.w700, color: C.ink), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFCEBCB), borderRadius: BorderRadius.circular(999)),
              child: Text(g.badge, style: cairo(9.5, w: FontWeight.w700, color: C.goldText))),
          ]),
          if (g.store.name.isNotEmpty)
            Row(children: [storeLogo(g.store.logo, 16), const SizedBox(width: 4), Flexible(child: Text(g.store.name, style: cairo(12, w: FontWeight.w700, color: C.greenMid), overflow: TextOverflow.ellipsis))]),
          if (g.store.address.isNotEmpty)
            Row(children: [mi('location_on', size: 12, color: C.textTertiary), const SizedBox(width: 3), Flexible(child: Text(g.store.address, style: noto(11, color: C.textSecondary), overflow: TextOverflow.ellipsis))]),
          Text(g.left, style: noto(11.5, color: C.textTertiary)),
          const SizedBox(height: 4),
          Text(g.priceLabel, style: cairo(14, w: FontWeight.w800, color: C.goldText)),
        ])),
        const SizedBox(width: 8),
        Pressable(pressedScale: 0.92, onTap: _busyId == g.id ? null : () => _claim(g.id, g.title, g.cost), child: Container(
          height: 42, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: _busyId == g.id ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(tr('استلام'), style: cairo(13, w: FontWeight.w700, color: Colors.white)))),
      ]),
    );
  }
}
