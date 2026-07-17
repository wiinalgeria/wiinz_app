import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/change_password.dart';

Widget _grabber() => Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3)));

void showNotificationsSheet(BuildContext context, WidgetRef ref) {
  final opener = context; // survives after the sheet is popped (for opening dialogs)
  showModalBottomSheet(
    context: context, backgroundColor: C.sand, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _NotificationsSheet(opener: opener),
  );
}

/// Small pill telling the user whether a notification was aimed at them
/// specifically or broadcast to everyone. Only rendered when the admin ticked
/// "show the audience" on the notification.
Widget _audienceChip(AppNotification n) {
  final targeted = n.targeted;
  final fg = targeted ? C.goldText : const Color(0xFF5A6470);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: targeted ? const Color(0xFFFCEBCB) : const Color(0xFFEDF2F7),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: targeted ? const Color(0xFFF3E1BC) : const Color(0xFFDCE3EA)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      mi(targeted ? 'person' : 'campaign', size: 12, color: fg),
      const SizedBox(width: 4),
      Text(targeted ? tr('رسالة موجّهة إليك') : tr('إشعار عام'), style: cairo(10.5, w: FontWeight.w800, color: fg)),
    ]),
  );
}

/// Full-message popup, opened by tapping a notification row. The list truncates
/// long bodies, so this is where the user reads the whole thing — and where the
/// optional CTA button lives.
Future<void> showNotificationDetail(BuildContext context, AppNotification n) {
  return showDialog<void>(
    context: context, barrierColor: const Color(0xB80C140E),
    builder: (dctx) => Directionality(textDirection: appDirection, child: Dialog(
      backgroundColor: C.sand, insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(dctx).size.height * 0.78),
        child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 66, height: 66,
              decoration: BoxDecoration(color: hexColor(n.bg, fallback: C.tint2), shape: BoxShape.circle),
              child: mi(n.icon, size: 32, color: hexColor(n.color, fallback: C.greenMid))),
            const SizedBox(height: 14),
            Text(n.title, style: cairo(19, w: FontWeight.w800, color: C.forest), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(n.whenLabel, style: noto(11.5, color: C.textTertiary)),
            if (n.showAudience) ...[const SizedBox(height: 10), _audienceChip(n)],
            const SizedBox(height: 14),
            Text(n.body, style: noto(14, color: C.textSecondary, height: 1.6), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (n.hasCta) ...[
              GradientButton(label: n.ctaText, height: 52, onTap: () async {
                final uri = Uri.tryParse(n.ctaUrl.trim());
                if (uri != null) {
                  try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
                }
              }),
              const SizedBox(height: 10),
            ],
            Pressable(
              onTap: () => Navigator.pop(dctx),
              child: Container(height: 50, width: double.infinity, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: C.inputBorder, width: 1.5)),
                child: Text(tr('إغلاق'), style: cairo(15, w: FontWeight.w700, color: const Color(0xFF6B6459)))),
            ),
          ]),
        )),
      ),
    )),
  );
}

class _NotificationsSheet extends ConsumerStatefulWidget {
  final BuildContext opener;
  const _NotificationsSheet({required this.opener});
  @override
  ConsumerState<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<_NotificationsSheet> {
  List<AppNotification> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      items = await ref.read(apiClientProvider).notifications();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tempPw = ref.watch(sessionProvider).user?.tempPassword == true;
    return Directionality(
      textDirection: appDirection,
      // A draggable sheet (rather than a fixed-height box) so a long list
      // scrolls properly and can be flicked away.
      child: DraggableScrollableSheet(
        initialChildSize: 0.78, maxChildSize: 0.94, minChildSize: 0.4, expand: false,
        builder: (context, scroll) => loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(22, 20, 22, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Center(child: _grabber()),
                Center(child: Text(tr('الإشعارات'), style: cairo(18, w: FontWeight.w800, color: C.forest))),
                const SizedBox(height: 8),
                if (tempPw) _tempPasswordBanner(),
                if (items.isEmpty && !tempPw)
                  Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr('لا توجد إشعارات'), style: noto(13, color: C.textTertiary))))
                else
                  ...items.map(_row),
              ],
            ),
      ),
    );
  }

  Widget _tempPasswordBanner() => Container(
    margin: const EdgeInsets.only(bottom: 6, top: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0D9A8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFCEBCB), borderRadius: BorderRadius.circular(12)), child: mi('lock_reset', size: 22, color: const Color(0xFFB7791F))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('كلمة مرور مؤقتة'), style: cairo(14, w: FontWeight.w800, color: C.forest)),
          Text(tr('تم تعيين كلمة مرور مؤقتة لحسابك. غيّرها الآن.'), style: noto(12, color: C.textSecondary)),
        ])),
      ]),
      const SizedBox(height: 10),
      Pressable(
        onTap: () { Navigator.pop(context); showChangePasswordDialog(widget.opener, ref, confirmFirst: false); },
        child: Container(height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(12)),
          child: Text(tr('تغيير كلمة المرور'), style: cairo(14, w: FontWeight.w800, color: Colors.white))),
      ),
    ]),
  );

  Widget _row(AppNotification n) => Pressable(
    onTap: () => showNotificationDetail(context, n),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0E9DA)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: hexColor(n.bg, fallback: C.tint2), borderRadius: BorderRadius.circular(12)),
          child: mi(n.icon, size: 22, color: hexColor(n.color, fallback: C.greenMid))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: cairo(14, w: FontWeight.w700, color: C.ink)),
          if (n.body.isNotEmpty)
            Text(n.body, style: noto(12, color: C.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (n.showAudience || n.hasCta) ...[
            const SizedBox(height: 6),
            Row(children: [
              if (n.showAudience) _audienceChip(n),
              if (n.showAudience && n.hasCta) const SizedBox(width: 6),
              if (n.hasCta) mi('open_in_new', size: 13, color: C.greenMid),
            ]),
          ],
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(n.whenLabel, style: noto(11, color: C.textTertiary)),
          const SizedBox(height: 8),
          mi(isRtl ? 'chevron_left' : 'chevron_right', size: 18, color: C.textTertiary),
        ]),
      ]),
    ),
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

    return Directionality(textDirection: appDirection,
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
                          child: Row(mainAxisSize: MainAxisSize.min, children: [mi('eco', size: 15, color: const Color(0xFFCFF3E0)), const SizedBox(width: 5), Text(trf('المستوى: {name}', {'name': tr(levelName)}), style: cairo(12, w: FontWeight.w700, color: const Color(0xFFCFF3E0)))])),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(text: tr('باقٍ '), style: noto(12.5, color: Colors.white.withValues(alpha: 0.75)), children: [
                          TextSpan(text: '$nextLeft Wz', style: cairo(12.5, w: FontWeight.w800, color: C.goldLight)),
                          TextSpan(text: tr(' للوصول إلى '), style: noto(12.5, color: Colors.white.withValues(alpha: 0.75))),
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
                  Row(children: [mi('leaderboard', size: 20, color: C.greenMid), const SizedBox(width: 6), Text(trf('لوحة الصدارة · {zone}', {'zone': '$zone'}), style: cairo(15, w: FontWeight.w800, color: C.forest))]),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF1EEE6), borderRadius: BorderRadius.circular(999)), child: Text(tr('هذا الأسبوع'), style: noto(11, color: C.textSecondary))),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.tint1, C.tint3]), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.tint4)),
                  child: Row(children: [
                    mi('military_tech', size: 22, color: C.greenMid),
                    const SizedBox(width: 10),
                    Expanded(child: Text.rich(TextSpan(text: tr('أنت في المركز '), style: cairo(13.5, w: FontWeight.w700, color: C.forest), children: [
                      TextSpan(text: '#$myRank', style: cairo(13.5, w: FontWeight.w900, color: C.forest)),
                      TextSpan(text: tr(' من $totalPlayers'), style: cairo(13.5, w: FontWeight.w700, color: C.forest)),
                    ]))),
                    Text(myRank > 1 ? trf('تحتاج {n} Wz للتقدم', {'n': '$ahead'}) : tr('في الصدارة! 🏆'), style: cairo(11.5, w: FontWeight.w700, color: C.greenBtnEnd)),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder)),
                  child: Column(children: leaders.map((l) => _leaderRow(l)).toList()),
                ),
                const SizedBox(height: 20),
                Text(tr('سجل النقاط'), style: cairo(15, w: FontWeight.w800, color: C.forest)),
                const SizedBox(height: 8),
                if (history.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(tr('لا توجد حركات بعد'), style: noto(13, color: C.textTertiary))))
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
        // profile picture when set, otherwise the initial on a coloured disc
        l.avatar.isNotEmpty
          ? avatarCircle(l.avatar, 36, border: Border.all(color: l.isMe ? C.green : const Color(0xFFE6DFCF), width: 1.5))
          : Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: l.isMe ? C.green : const Color(0xFFF0E9DA), shape: BoxShape.circle),
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
