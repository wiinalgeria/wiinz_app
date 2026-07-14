import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/change_password.dart';

Widget _grabber() => Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3)));

void showNotificationsSheet(BuildContext context, WidgetRef ref) {
  final opener = context; // survives after the sheet is popped (for opening dialogs)
  final navInset = MediaQuery.of(context).padding.bottom;
  final maxH = MediaQuery.of(context).size.height * 0.78;
  showModalBottomSheet(
    context: context, backgroundColor: C.sand, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20 + navInset),
      child: FutureBuilder<List<AppNotification>>(
        future: ref.read(apiClientProvider).notifications(),
        builder: (context, snap) {
          final items = snap.data ?? [];
          final tempPw = ref.read(sessionProvider).user?.tempPassword == true;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: _grabber()),
            Text('الإشعارات', style: cairo(18, w: FontWeight.w800, color: C.forest)),
            const SizedBox(height: 8),
            if (tempPw)
              Container(
                margin: const EdgeInsets.only(bottom: 6, top: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0D9A8))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFCEBCB), borderRadius: BorderRadius.circular(12)), child: mi('lock_reset', size: 22, color: const Color(0xFFB7791F))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('كلمة مرور مؤقتة', style: cairo(14, w: FontWeight.w800, color: C.forest)),
                      Text('تم تعيين كلمة مرور مؤقتة لحسابك. غيّرها الآن.', style: noto(12, color: C.textSecondary)),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Pressable(
                    onTap: () { Navigator.pop(context); showChangePasswordDialog(opener, ref, confirmFirst: false); },
                    child: Container(height: 44, alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(12)),
                      child: Text('تغيير كلمة المرور', style: cairo(14, w: FontWeight.w800, color: Colors.white))),
                  ),
                ]),
              ),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (items.isEmpty && !tempPw)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('لا توجد إشعارات', style: noto(13, color: C.textTertiary))))
            else
              Flexible(child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: items.map((n) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0E9DA)))),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: hexColor(n.bg, fallback: C.tint2), borderRadius: BorderRadius.circular(12)),
                      child: mi(n.icon, size: 22, color: hexColor(n.color, fallback: C.greenMid))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, style: cairo(14, w: FontWeight.w700, color: C.ink)),
                      Text(n.body, style: noto(12, color: C.textSecondary)),
                    ])),
                    Text(n.time, style: noto(11, color: C.textTertiary)),
                  ]),
                )).toList(),
              )),
          ]);
        },
      ),
    ))),
  );
}

void showStatsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, backgroundColor: C.sand, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _StatsSheet(),
  );
}

class _StatsSheet extends ConsumerStatefulWidget {
  const _StatsSheet();
  @override
  ConsumerState<_StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends ConsumerState<_StatsSheet> {
  Map<String, dynamic>? stats;
  Map<String, dynamic>? board;
  List<HistoryItem> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([api.stats(), api.leaderboard(), api.history()]);
      stats = results[0] as Map<String, dynamic>;
      board = results[1] as Map<String, dynamic>;
      history = results[2] as List<HistoryItem>;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.user!;
    final cfg = session.config;
    final balance = user.points;

    // level info
    int floor = 0, ceil = cfg.silverGoal;
    String levelName = 'أخضر', nextName = 'فضي';
    if (balance >= cfg.goldGoal) { floor = cfg.goldGoal; ceil = cfg.goldGoal * 2; levelName = 'ذهبي'; nextName = 'ذهبي+'; }
    else if (balance >= cfg.silverGoal) { floor = cfg.silverGoal; ceil = cfg.goldGoal; levelName = 'فضي'; nextName = 'ذهبي'; }
    final span = (ceil - floor).clamp(1, 1 << 30);
    final pct = ((balance - floor) / span).clamp(0.0, 1.0);
    final nextLeft = (ceil - balance).clamp(0, ceil);

    final leaders = (board?['leaderboard'] as List?)?.map((e) => LeaderRow.fromJson(e)).toList() ?? [];
    final myRank = board?['myRank'] ?? 0;
    final totalPlayers = board?['totalPlayers'] ?? 0;
    final zone = board?['zone'] ?? '';
    final ahead = board?['ahead'] ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.88, maxChildSize: 0.92, minChildSize: 0.5, expand: false,
        builder: (context, scroll) => loading
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : ListView(controller: scroll, padding: EdgeInsets.fromLTRB(22, 20, 22, 30 + MediaQuery.of(context).padding.bottom), children: [
                Center(child: _grabber()),
                // level ring card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: C.forestGrad, borderRadius: BorderRadius.circular(22)),
                  child: Column(children: [
                    Row(children: [
                      SizedBox(width: 88, height: 88, child: Stack(alignment: Alignment.center, children: [
                        SizedBox(width: 88, height: 88, child: CircularProgressIndicator(value: pct, strokeWidth: 9, backgroundColor: Colors.white.withValues(alpha: 0.14), valueColor: const AlwaysStoppedAnimation(C.gold))),
                        Container(width: 70, height: 70, decoration: const BoxDecoration(color: C.forest, shape: BoxShape.circle),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('$balance', style: cairo(22, w: FontWeight.w900, color: C.gold, height: 1)),
                            Text('Wz', style: cairo(9, w: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
                          ])),
                      ])),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: C.green.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [mi('eco', size: 15, color: const Color(0xFFCFF3E0)), const SizedBox(width: 5), Text('المستوى: $levelName', style: cairo(12, w: FontWeight.w700, color: const Color(0xFFCFF3E0)))])),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(text: 'باقٍ ', style: noto(12.5, color: Colors.white.withValues(alpha: 0.75)), children: [
                          TextSpan(text: '$nextLeft Wz', style: cairo(12.5, w: FontWeight.w800, color: C.goldLight)),
                          TextSpan(text: ' للوصول إلى ', style: noto(12.5, color: Colors.white.withValues(alpha: 0.75))),
                          TextSpan(text: nextName, style: cairo(12.5, w: FontWeight.w700, color: Colors.white)),
                        ]), textAlign: TextAlign.right),
                      ])),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.15), valueColor: const AlwaysStoppedAnimation(C.gold))),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _quick('${stats?['totalEarned'] ?? 0}', 'مجموع المكتسب', C.greenMid),
                  const SizedBox(width: 10),
                  _quick('${stats?['totalScans'] ?? 0}', 'عملية مسح', C.goldText),
                  const SizedBox(width: 10),
                  _quick('${stats?['totalRedeemed'] ?? 0}', 'استبدال', C.greenMid),
                ]),
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [mi('leaderboard', size: 20, color: C.greenMid), const SizedBox(width: 6), Text('لوحة الصدارة · $zone', style: cairo(15, w: FontWeight.w800, color: C.forest))]),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF1EEE6), borderRadius: BorderRadius.circular(999)), child: Text('هذا الأسبوع', style: noto(11, color: C.textSecondary))),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.tint1, C.tint3]), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.tint4)),
                  child: Row(children: [
                    mi('military_tech', size: 22, color: C.greenMid),
                    const SizedBox(width: 10),
                    Expanded(child: Text.rich(TextSpan(text: 'أنت في المركز ', style: cairo(13.5, w: FontWeight.w700, color: C.forest), children: [
                      TextSpan(text: '#$myRank', style: cairo(13.5, w: FontWeight.w900, color: C.forest)),
                      TextSpan(text: ' من $totalPlayers', style: cairo(13.5, w: FontWeight.w700, color: C.forest)),
                    ]))),
                    Text(myRank > 1 ? 'تحتاج $ahead Wz للتقدم' : 'في الصدارة! 🏆', style: cairo(11.5, w: FontWeight.w700, color: C.greenBtnEnd)),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder)),
                  child: Column(children: leaders.map((l) => _leaderRow(l)).toList()),
                ),
                const SizedBox(height: 20),
                Text('سجل النقاط', style: cairo(15, w: FontWeight.w800, color: C.forest)),
                const SizedBox(height: 8),
                if (history.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('لا توجد حركات بعد', style: noto(13, color: C.textTertiary))))
                else ...history.map((h) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0E9DA)))),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: h.positive ? C.tint2 : const Color(0xFFFCEBCB), borderRadius: BorderRadius.circular(12)),
                      child: mi(h.icon, size: 22, color: h.positive ? C.greenMid : C.goldText)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.title, style: cairo(14, w: FontWeight.w700, color: C.ink)),
                      Text(h.when, style: noto(11.5, color: C.textTertiary)),
                    ])),
                    Text(h.amount, style: cairo(15, w: FontWeight.w800, color: h.positive ? C.greenMid : C.goldText)),
                  ]),
                )),
              ]),
      ),
    );
  }

  Widget _quick(String v, String l, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder)),
    child: Column(children: [Text(v, style: cairo(22, w: FontWeight.w900, color: color)), const SizedBox(height: 2), Text(l, style: noto(11, color: C.textSecondary), textAlign: TextAlign.center)]),
  ));

  Widget _leaderRow(LeaderRow l) {
    const medals = [Color(0xFFC9A227), Color(0xFFAEB7C2), Color(0xFFB08D57)];
    final top3 = l.rank <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(color: l.isMe ? C.tint1 : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: l.isMe ? C.green : Colors.transparent, width: 1.5)),
      child: Row(children: [
        Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: top3 ? medals[l.rank - 1] : C.divider, shape: BoxShape.circle),
          child: Text('${l.rank}', style: cairo(13, w: FontWeight.w800, color: top3 ? Colors.white : C.textSecondary))),
        const SizedBox(width: 11),
        Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: l.isMe ? C.green : const Color(0xFFF0E9DA), shape: BoxShape.circle),
          child: Text(l.initial, style: cairo(14, w: FontWeight.w800, color: l.isMe ? Colors.white : C.textSecondary))),
        const SizedBox(width: 11),
        Expanded(child: Row(children: [
          Flexible(child: Text(l.name, style: cairo(14, w: l.isMe ? FontWeight.w800 : FontWeight.w700, color: l.isMe ? C.forest : C.ink), overflow: TextOverflow.ellipsis)),
          if (l.prize.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFCEBCB), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFF3E1BC))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                mi('emoji_events', size: 12, color: C.goldText), const SizedBox(width: 3),
                Text(l.prize, style: cairo(10.5, w: FontWeight.w800, color: C.goldText)),
              ])),
          ],
        ])),
        const SizedBox(width: 8),
        Text('${l.score} Wz', style: cairo(14, w: FontWeight.w800, color: C.goldText)),
      ]),
    );
  }
}
