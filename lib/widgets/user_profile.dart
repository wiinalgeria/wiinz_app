import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/session.dart';
import '../core/i18n.dart';
import '../core/place_names.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

// Achievement display (icon + Arabic title/desc) keyed by the id the server
// sends. The server decides which are unlocked; the app owns how they look, so
// translations stay in i18n. Order here is the display order.
const _achievementDefs = <String, (String, String, String)>{
  'first_deposit': ('recycling', 'أول إيداع', 'أودعت قاروراتك الأولى'),
  'bottles_10': ('water_bottle', 'جامع مبتدئ', 'أودعت 10 قارورات'),
  'bottles_50': ('water_bottle', 'جامع نشيط', 'أودعت 50 قارورة'),
  'bottles_100': ('workspace_premium', 'بطل التدوير', 'أودعت 100 قارورة'),
  'bottles_500': ('military_tech', 'أسطورة القارورات', 'أودعت 500 قارورة'),
  'tier_silver': ('workspace_premium', 'المستوى الفضي', 'وصلت إلى المستوى الفضي'),
  'tier_gold': ('military_tech', 'المستوى الذهبي', 'وصلت إلى المستوى الذهبي'),
  'refer_1': ('group', 'صديق البيئة', 'دعوت صديقاً واحداً'),
  'refer_5': ('group', 'سفير WIIN', 'دعوت 5 أصدقاء'),
  'top3': ('emoji_events', 'في القمة', 'ضمن أفضل 3 في ولايتك'),
};

/// Open the public profile of another user (tapped from the leaderboard).
void showUserProfileSheet(BuildContext context, WidgetRef ref, String userId) {
  showModalBottomSheet(
    context: context, backgroundColor: C.sand, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _UserProfileSheet(userId: userId),
  );
}

class _UserProfileSheet extends ConsumerStatefulWidget {
  final String userId;
  const _UserProfileSheet({required this.userId});
  @override
  ConsumerState<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends ConsumerState<_UserProfileSheet> {
  Map<String, dynamic>? p;
  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      p = await ref.read(apiClientProvider).userProfile(widget.userId);
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    return Directionality(
      textDirection: appDirection,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.94, minChildSize: 0.5, expand: false,
        builder: (context, scroll) {
          if (loading) return const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()));
          if (failed || p == null) {
            return Center(child: Padding(padding: const EdgeInsets.all(40),
              child: Text(tr('تعذّر تحميل الملف الشخصي'), style: noto(14, color: C.textSecondary))));
          }
          return ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(22, 16, 22, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              Center(child: Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3)))),
              _header(),
              const SizedBox(height: 18),
              _statsRow(),
              const SizedBox(height: 22),
              _achievements(),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    final tier = '${p!['tier'] ?? ''}';
    final rank = (p!['rank'] as num?)?.toInt() ?? 0;
    final total = (p!['totalInWilaya'] as num?)?.toInt() ?? 0;
    final region = [p!['wilaya'], p!['commune']]
        .map((e) => placeName('$e'))
        .where((e) => e.isNotEmpty)
        .join(' · ');
    final joined = DateTime.tryParse('${p!['joinedAt']}');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: C.forestGrad, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        avatarCircle('${p!['avatar'] ?? ''}', 84, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)),
        const SizedBox(height: 12),
        Text('${p!['name'] ?? ''}', style: cairo(20, w: FontWeight.w900, color: Colors.white), textAlign: TextAlign.center),
        if (region.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            mi('location_on', size: 14, color: const Color(0xFFCFF3E0)), const SizedBox(width: 4),
            Text(region, style: noto(12.5, color: const Color(0xFFCFF3E0))),
          ]),
        ],
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _headerChip('military_tech', trf('المستوى: {name}', {'name': tr(tier)})),
          const SizedBox(width: 8),
          if (rank > 0) _headerChip('emoji_events', trf('المركز {n} من {m}', {'n': '$rank', 'm': '$total'})),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${p!['points'] ?? 0}', style: cairo(28, w: FontWeight.w900, color: C.goldLight)),
            const SizedBox(width: 6),
            Text('Wz', style: cairo(15, w: FontWeight.w800, color: Colors.white.withValues(alpha: 0.7))),
          ]),
        ),
        if (joined != null) ...[
          const SizedBox(height: 10),
          Text(trf('انضم {t}', {'t': timeAgo(joined)}), style: noto(11.5, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ]),
    );
  }

  Widget _headerChip(String icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      mi(icon, size: 14, color: C.goldLight), const SizedBox(width: 5),
      Text(label, style: cairo(11.5, w: FontWeight.w700, color: Colors.white)),
    ]),
  );

  Widget _statsRow() {
    Widget cell(String v, String label, String icon, Color color) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder)),
      child: Column(children: [
        mi(icon, size: 22, color: color), const SizedBox(height: 6),
        Text(v, style: cairo(20, w: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(tr(label), style: noto(11, color: C.textSecondary), textAlign: TextAlign.center),
      ]),
    ));
    return Row(children: [
      cell('${p!['totalBottles'] ?? 0}', 'قارورة', 'water_bottle', C.greenMid),
      const SizedBox(width: 10),
      cell('${p!['totalScans'] ?? 0}', 'عملية إيداع', 'recycling', C.goldText),
      const SizedBox(width: 10),
      cell('${p!['totalEarned'] ?? 0}', 'مجموع المكتسب', 'toll', C.greenMid),
    ]);
  }

  Widget _achievements() {
    final raw = (p!['achievements'] as List?) ?? [];
    final unlockedIds = {for (final a in raw) if (a['unlocked'] == true) '${a['id']}'};
    final unlockedCount = unlockedIds.length;
    // Show in the canonical order, both earned and locked.
    final entries = _achievementDefs.entries.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        mi('emoji_events', size: 20, color: C.greenMid), const SizedBox(width: 6),
        Text(tr('الإنجازات'), style: cairo(15, w: FontWeight.w800, color: C.forest)),
        const Spacer(),
        Text('$unlockedCount / ${entries.length}', style: cairo(13, w: FontWeight.w800, color: C.goldText)),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82,
        children: entries.map((e) {
          final def = e.value;
          final unlocked = unlockedIds.contains(e.key);
          return _badge(def.$1, def.$2, def.$3, unlocked);
        }).toList(),
      ),
    ]);
  }

  Widget _badge(String icon, String title, String desc, bool unlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFFFFF6E6) : const Color(0xFFF1EEE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? const Color(0xFFF3E1BC) : C.cardBorder),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: unlocked ? C.gold.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04), shape: BoxShape.circle),
            child: mi(icon, size: 26, color: unlocked ? C.goldText : C.textTertiary, fill: unlocked),
          ),
          if (!unlocked) Positioned(right: 2, bottom: 2, child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: mi('lock', size: 12, color: C.textTertiary))),
        ]),
        const SizedBox(height: 8),
        Text(tr(title), style: cairo(11, w: FontWeight.w800, color: unlocked ? C.forest : C.textTertiary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(tr(desc), style: noto(8.5, color: C.textTertiary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
