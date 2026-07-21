import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/i18n.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'bottle_icon.dart';
import 'ui.dart';

/// Settings card for a collect-point holder: their point, how much came in
/// today/this week/this month, and the container-emptying log. Renders nothing
/// for normal users.
class HolderCard extends ConsumerStatefulWidget {
  const HolderCard({super.key});
  @override
  ConsumerState<HolderCard> createState() => _HolderCardState();
}

class _HolderCardState extends ConsumerState<HolderCard> {
  Map<String, dynamic>? s;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = ref.read(sessionProvider).user;
    if (u == null || !u.isHolder) { if (mounted) setState(() => loading = false); return; }
    try { s = await ref.read(apiClientProvider).holderStats(); } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  // Propose new info for the point (everything except its location). This does
  // NOT change the point right away — the server queues it as a support ticket
  // an admin must approve, so a holder can't silently rewrite public point info.
  Future<void> _requestPointEdit(Map point) async {
    final name = TextEditingController(text: '${point['name'] ?? ''}');
    final area = TextEditingController(text: '${point['area'] ?? ''}');
    final address = TextEditingController(text: '${point['address'] ?? ''}');
    final accepts = TextEditingController(text: '${point['accepts'] ?? ''}');
    final hours = TextEditingController(text: '${point['hours'] ?? ''}');
    final phone = TextEditingController(text: '${point['phone'] ?? ''}');
    final details = TextEditingController(text: '${point['details'] ?? ''}');
    bool saving = false;
    String? err;

    InputDecoration dec(String l) => InputDecoration(labelText: tr(l), border: const OutlineInputBorder(), isDense: true);
    Widget field(TextEditingController c, String l, {int max = 1, bool phoneField = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c, maxLines: max,
        keyboardType: phoneField ? TextInputType.phone : TextInputType.text,
        textDirection: phoneField ? TextDirection.ltr : null,
        inputFormatters: phoneField ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)] : null,
        decoration: dec(l),
      ),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setD) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('تعديل معلومات النقطة'), style: cairo(17, w: FontWeight.w800, color: C.forest)),
          content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('يُرسل التعديل كطلب للإدارة، ولا يُطبّق إلا بعد الموافقة. لا يمكن تغيير موقع النقطة على الخريطة.'),
                style: noto(12.5, color: C.textSecondary, height: 1.5)),
            const SizedBox(height: 14),
            field(name, 'اسم النقطة'),
            field(area, 'المنطقة'),
            field(address, 'العنوان'),
            field(accepts, 'يقبل (أنواع القوارير المقبولة)'),
            field(hours, 'ساعات العمل'),
            field(phone, 'الهاتف', phoneField: true),
            field(details, 'تفاصيل إضافية', max: 3),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(err!, style: noto(12, color: C.danger))),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('إلغاء'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
            TextButton(
              onPressed: saving ? null : () async {
                // Confirm before sending (the request is reviewed by an admin).
                final confirmed = await showDialog<bool>(context: dctx, builder: (cctx) => Directionality(
                  textDirection: appDirection,
                  child: AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    content: Text(tr('هل تريد إرسال طلب التعديل إلى الإدارة؟'), style: noto(14, color: C.textSecondary, height: 1.5)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(cctx, false), child: Text(tr('إلغاء'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
                      TextButton(onPressed: () => Navigator.pop(cctx, true), child: Text(tr('تأكيد الإرسال'), style: cairo(14, w: FontWeight.w800, color: C.green))),
                    ],
                  ),
                ));
                if (confirmed != true) return;
                setD(() { saving = true; err = null; });
                try {
                  await ref.read(apiClientProvider).holderPointEditRequest({
                    'name': name.text.trim(), 'area': area.text.trim(), 'address': address.text.trim(),
                    'accepts': accepts.text.trim(), 'hours': hours.text.trim(), 'phone': phone.text.trim(),
                    'details': details.text.trim(),
                  });
                  if (dctx.mounted) Navigator.pop(dctx, true);
                } on ApiException catch (e) {
                  setD(() { saving = false; err = e.message; });
                } catch (_) {
                  setD(() { saving = false; err = tr('حدث خطأ، حاول مجدداً'); });
                }
              },
              child: Text(saving ? '...' : tr('إرسال الطلب'), style: cairo(14, w: FontWeight.w800, color: C.green)),
            ),
          ],
        ),
      )),
    );
    if (ok == true && mounted) showToast(context, tr('تم إرسال الطلب، سيُطبَّق بعد موافقة الإدارة ✓'));
  }

  // Flag the container as full → the dashboard and field app are notified so an
  // agent can come empty it. Confirm/cancel first.
  Future<void> _notifyBagFull() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56, alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFFFCE9D6), shape: BoxShape.circle),
              child: mi('notification_important', size: 30, color: Color(0xFFC24A18))),
            const SizedBox(height: 12),
            Text(tr('الإبلاغ عن امتلاء الحاوية'), style: cairo(16.5, w: FontWeight.w800, color: C.forest), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(tr('سيصل التنبيه إلى الإدارة وإلى موظف الميدان لتفريغ الحاوية. هل تؤكد؟'),
                style: noto(13, color: C.textSecondary, height: 1.5), textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('إلغاء'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text(tr('نعم، الحاوية ممتلئة'), style: cairo(14, w: FontWeight.w800, color: const Color(0xFFC24A18)))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).holderPointFull();
      if (mounted) showToast(context, tr('تم إرسال تنبيه الامتلاء ✓'));
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, tr('حدث خطأ، حاول مجدداً'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final u = ref.watch(sessionProvider).user;
    if (u == null || !u.isHolder) return const SizedBox.shrink();
    if (loading) return const SizedBox.shrink();
    final point = (s?['point'] as Map?) ?? {};
    final today = (s?['today'] as Map?) ?? {};
    final week = (s?['week'] as Map?) ?? {};
    final month = (s?['month'] as Map?) ?? {};
    final last = s?['lastEmptying'] as Map?;

    Widget cell(String v, String label) => Expanded(child: Column(children: [
      Text(v, style: cairo(18, w: FontWeight.w900, color: C.forest)),
      Text(tr(label), style: noto(10.5, color: C.textSecondary), textAlign: TextAlign.center),
    ]));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF6E6), Color(0xFFFDF3DE)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3E1BC)),
      ),
      child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.22), shape: BoxShape.circle),
            child: mi('star', size: 24, color: C.goldText, fill: true)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('نقطة الجمع الخاصة بك'), style: noto(11.5, color: C.textSecondary)),
            Text('${point['name'] ?? ''}', style: cairo(15.5, w: FontWeight.w800, color: C.forest)),
            Text('${point['code'] ?? ''}', style: noto(11, color: C.textTertiary), textDirection: TextDirection.ltr),
          ])),
          const BottleIcon(size: 34, color: C.goldText),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            cell('${today['bottles'] ?? 0}', 'قارورة اليوم'),
            cell('${today['deposits'] ?? 0}', 'إيداع اليوم'),
            cell('${week['bottles'] ?? 0}', 'قارورة هذا الأسبوع'),
            cell('${month['bottles'] ?? 0}', 'قارورة هذا الشهر'),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Pressable(
            onTap: () => _requestPointEdit(point),
            child: Container(height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(13)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                mi('edit', size: 19, color: Colors.white), const SizedBox(width: 6),
                Text(tr('تعديل معلومات النقطة'), style: cairo(13, w: FontWeight.w800, color: Colors.white)),
              ])),
          )),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => showPointsLeaderboardSheet(context, ref),
            child: Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: C.cardBorder)),
              child: mi('leaderboard', size: 20, color: C.greenMid)),
          ),
        ]),
        const SizedBox(height: 8),
        // "Notify bag is full" — a bold, attention-grabbing button under the edit
        // row. Alerts the dashboard + field app so an agent comes to empty it.
        Pressable(
          onTap: _notifyBagFull,
          child: Container(
            height: 48, width: double.infinity, alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFE8730C)]),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(color: const Color(0xFFE8730C).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              mi('notification_important', size: 21, color: Colors.white), const SizedBox(width: 8),
              Text(tr('الإبلاغ عن امتلاء الحاوية'), style: cairo(14, w: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
        if (last != null) ...[
          const SizedBox(height: 8),
          Text(trf('آخر تفريغ: {t}', {'t': timeAgo(DateTime.tryParse('${last['at']}')?.toLocal() ?? DateTime.now())}),
              style: noto(11, color: C.textTertiary)),
        ],
      ]),
    );
  }
}

/// Second leaderboard: how the collection points in this wilaya compare.
void showPointsLeaderboardSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, backgroundColor: C.sand, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _PointsBoardSheet(),
  );
}

class _PointsBoardSheet extends ConsumerStatefulWidget {
  const _PointsBoardSheet();
  @override
  ConsumerState<_PointsBoardSheet> createState() => _PointsBoardSheetState();
}

class _PointsBoardSheetState extends ConsumerState<_PointsBoardSheet> {
  List rows = [];
  String zone = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(apiClientProvider).pointsLeaderboard();
      rows = (b['leaderboard'] as List?) ?? [];
      zone = '${b['zone'] ?? ''}';
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    return Directionality(
      textDirection: appDirection,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8, maxChildSize: 0.94, minChildSize: 0.4, expand: false,
        builder: (context, scroll) => loading
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  Center(child: Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3)))),
                  Center(child: Text(trf('ترتيب نقاط الجمع · {zone}', {'zone': zone}),
                      style: cairo(17, w: FontWeight.w800, color: C.forest))),
                  const SizedBox(height: 4),
                  Center(child: Text(tr('حسب عدد القارورات المُجمَّعة'), style: noto(11.5, color: C.textTertiary))),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    Padding(padding: const EdgeInsets.all(30),
                        child: Center(child: Text(tr('لا توجد بيانات بعد'), style: noto(13, color: C.textTertiary))))
                  else
                    ...rows.map((r) {
                      final mine = r['isMine'] == true;
                      final rank = (r['rank'] as num?)?.toInt() ?? 0;
                      const medals = [Color(0xFFC9A227), Color(0xFFAEB7C2), Color(0xFFB08D57)];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: mine ? C.tint1 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: mine ? C.green : C.cardBorder, width: mine ? 1.5 : 1),
                        ),
                        child: Row(children: [
                          Container(width: 26, height: 26, alignment: Alignment.center,
                            decoration: BoxDecoration(color: rank <= 3 ? medals[rank - 1] : C.divider, shape: BoxShape.circle),
                            child: Text('$rank', style: cairo(12.5, w: FontWeight.w800, color: rank <= 3 ? Colors.white : C.textSecondary))),
                          const SizedBox(width: 11),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r['name'] ?? ''}', style: cairo(14, w: mine ? FontWeight.w800 : FontWeight.w700, color: mine ? C.forest : C.ink), overflow: TextOverflow.ellipsis),
                            Text(trf('{d} إيداع · {u} مستخدم', {'d': '${r['deposits'] ?? 0}', 'u': '${r['users'] ?? 0}'}),
                                style: noto(11, color: C.textTertiary)),
                          ])),
                          Row(children: [
                            const BottleIcon(size: 20, color: C.greenMid),
                            const SizedBox(width: 4),
                            Text('${r['bottles'] ?? 0}', style: cairo(15, w: FontWeight.w900, color: C.greenMid)),
                          ]),
                        ]),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
