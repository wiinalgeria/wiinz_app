import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/i18n.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'bottle_icon.dart';
import 'ui.dart';

/// Achievements the admin defined in the dashboard: unlock by depositing N
/// bottles, then claim the bonus once. Opened from the leaderboard.
void showAchievementsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context, backgroundColor: C.sand, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _AchievementsSheet(),
  );
}

class _AchievementsSheet extends ConsumerStatefulWidget {
  const _AchievementsSheet();
  @override
  ConsumerState<_AchievementsSheet> createState() => _AchievementsSheetState();
}

class _AchievementsSheetState extends ConsumerState<_AchievementsSheet> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      items = await ref.read(apiClientProvider).achievements();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _claim(Map<String, dynamic> a) async {
    setState(() => busyId = '${a['id']}');
    try {
      final res = await ref.read(apiClientProvider).claimAchievement('${a['id']}');
      ref.read(sessionProvider.notifier).setPoints(res['newBalance']);
      if (mounted) showToast(context, trf('+{n} Wz — تمت إضافة المكافأة', {'n': '${res['bonus']}'}));
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final done = items.where((a) => a['unlocked'] == true).length;
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
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    mi('military_tech', size: 22, color: C.greenMid), const SizedBox(width: 6),
                    Text(tr('الإنجازات'), style: cairo(18, w: FontWeight.w800, color: C.forest)),
                  ]),
                  const SizedBox(height: 4),
                  if (items.isNotEmpty)
                    Center(child: Text('$done / ${items.length}', style: cairo(13, w: FontWeight.w800, color: C.goldText))),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    Padding(padding: const EdgeInsets.all(30),
                        child: Center(child: Text(tr('لا توجد إنجازات بعد'), style: noto(13, color: C.textTertiary))))
                  else
                    ...items.map(_row),
                ],
              ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> a) {
    final unlocked = a['unlocked'] == true;
    final claimed = a['claimed'] == true;
    final claimable = a['claimable'] == true;
    final need = (a['need'] as num?)?.toInt() ?? 0;
    final have = (a['bottles'] as num?)?.toInt() ?? 0;
    final bonus = (a['bonus'] as num?)?.toInt() ?? 0;
    final progress = ((a['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    final busy = busyId == '${a['id']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFFFFF6E6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? const Color(0xFFF3E1BC) : C.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: unlocked ? C.gold.withValues(alpha: 0.2) : const Color(0xFFF1EEE6),
            shape: BoxShape.circle,
          ),
          child: BottleIcon(size: 30, color: unlocked ? C.goldText : C.textTertiary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${a['name'] ?? ''}', style: cairo(14.5, w: FontWeight.w800, color: unlocked ? C.forest : C.ink)),
          const SizedBox(height: 3),
          Text(trf('{have} / {need} قارورة', {'have': '$have', 'need': '$need'}),
              style: noto(11.5, color: C.textSecondary)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress, minHeight: 6,
              backgroundColor: const Color(0xFFEDE7DA),
              valueColor: AlwaysStoppedAnimation(unlocked ? C.gold : C.greenMid),
            ),
          ),
        ])),
        const SizedBox(width: 10),
        if (claimed)
          Column(children: [
            mi('check_circle', size: 22, color: C.greenMid, fill: true),
            Text(tr('تم الاستلام'), style: cairo(10, w: FontWeight.w700, color: C.greenMid)),
          ])
        else if (claimable)
          Pressable(
            onTap: busy ? null : () => _claim(a),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(12)),
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(trf('استلم {n} Wz', {'n': '$bonus'}), style: cairo(12, w: FontWeight.w800, color: Colors.white)),
            ),
          )
        else
          Column(children: [
            mi('lock', size: 18, color: C.textTertiary),
            if (bonus > 0) Text('$bonus Wz', style: cairo(10.5, w: FontWeight.w700, color: C.textTertiary)),
          ]),
      ]),
    );
  }
}
