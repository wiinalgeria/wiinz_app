import 'dart:async';

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

class _HolderCardState extends ConsumerState<HolderCard> with WidgetsBindingObserver {
  Map<String, dynamic>? s;
  bool loading = true;
  Timer? _alertPoll;

  /// The point's currently-open "bag is full" alert, or null. Comes from the
  /// server, never from local state — the alert is cleared by whoever empties
  /// the container (a field agent, or the holder), which this app can't observe.
  Map? get _openAlert => s?['bagAlert'] as Map?;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _alertPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app is the most likely moment for the agent to have
    // emptied the container, so refresh then rather than waiting for the poll.
    if (state == AppLifecycleState.resumed && _openAlert != null) _load();
  }

  Future<void> _load() async {
    final u = ref.read(sessionProvider).user;
    if (u == null || !u.isHolder) { if (mounted) setState(() => loading = false); return; }
    try { s = await ref.read(apiClientProvider).holderStats(); } catch (_) {}
    if (mounted) setState(() => loading = false);
    _syncAlertPoll();
  }

  /// Poll only while an alert is open, so the button re-enables on its own once
  /// the container is emptied. No alert → no timer, so an idle holder card costs
  /// nothing.
  void _syncAlertPoll() {
    final open = _openAlert != null;
    if (open && _alertPoll == null) {
      _alertPoll = Timer.periodic(const Duration(seconds: 60), (_) {
        if (!mounted) return;
        if (_openAlert == null) { _syncAlertPoll(); return; }
        _load();
      });
    } else if (!open && _alertPoll != null) {
      _alertPoll!.cancel();
      _alertPoll = null;
    }
  }

  // Propose new info for the point (everything except its location). This does
  // NOT change the point right away — the server queues it as a support ticket
  // an admin must approve, so a holder can't silently rewrite public point info.
  Future<void> _requestPointEdit(Map point) async {
    // Always open the form on the point's CURRENT stored values. `point` came
    // from the stats call made when this card was first built, so anything an
    // admin changed in the dashboard since then (or a previously approved edit)
    // would otherwise show stale — and re-saving would propose reverting it.
    // A failed refresh just falls back to what we already have.
    //
    // The refresh hits a Render free-tier server that may be cold (30–50s), so
    // it gets a blocking spinner. Without one the tap looked dead and people
    // tapped again.
    Map? pending;
    final fresh = await _withProgress(tr('جارٍ تحميل معلومات النقطة...'),
        () => ref.read(apiClientProvider).holderStats());
    if (fresh != null) {
      final p = fresh['point'];
      if (p is Map) point = p;
      final pe = fresh['pendingEdit'];
      if (pe is Map) pending = pe;
      if (mounted) setState(() => s = fresh);
    }
    if (!mounted) return;

    // A request is already queued: show what was proposed, read-only. Editing
    // again is blocked until an admin approves or rejects it (the server 409s
    // on a second one anyway) — otherwise the form would open on the OLD values
    // and look like the request had vanished.
    if (pending != null) { await _showPendingEdit(point, pending); return; }

    final name = TextEditingController(text: '${point['name'] ?? ''}');
    final area = TextEditingController(text: '${point['area'] ?? ''}');
    final address = TextEditingController(text: '${point['address'] ?? ''}');
    final phone = TextEditingController(text: '${point['phone'] ?? ''}');
    final details = TextEditingController(text: '${point['details'] ?? ''}');
    // Hours are picked from wheels, not typed, so the stored value is always
    // "HH:MM - HH:MM". A legacy free-text value parses to nulls and is kept
    // as-is unless the holder actually picks a new range.
    final rawHours = '${point['hours'] ?? ''}';
    final parsed = parseHoursRange(rawHours);
    TimeOfDay? hFrom = parsed[0], hTo = parsed[1];
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
            field(area, 'البلدية'),
            field(address, 'العنوان'),
            HoursWheelField(
              label: tr('ساعات العمل'),
              from: hFrom, to: hTo,
              fallback: rawHours,
              onFrom: (t) => setD(() => hFrom = t),
              onTo: (t) => setD(() => hTo = t),
              onClear: () => setD(() { hFrom = null; hTo = null; }),
            ),
            const SizedBox(height: 10),
            field(phone, 'الهاتف', phoneField: true),
            field(details, 'قاعة رياضية، مؤسسة، ..الخ', max: 3),
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
                    'hours': hoursRangeString(hFrom, hTo, fallback: rawHours), 'phone': phone.text.trim(),
                    'details': details.text.trim(),
                  });
                  if (dctx.mounted) Navigator.pop(dctx, true);
                } on ApiException catch (e) {
                  setD(() { saving = false; err = e.message; });
                } catch (_) {
                  setD(() { saving = false; err = tr('حدث خطأ، حاول مجدداً'); });
                }
              },
              // While the request is in flight this is a spinner + «جارٍ
              // الإرسال...», not a bare "...". The call can take 30–50s against a
              // cold Render instance, and the old label made that look frozen.
              child: saving
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2.2, color: C.green)),
                      const SizedBox(width: 8),
                      Text(tr('جارٍ الإرسال...'), style: cairo(14, w: FontWeight.w800, color: C.green)),
                    ])
                  : Text(tr('إرسال الطلب'), style: cairo(14, w: FontWeight.w800, color: C.green)),
            ),
          ],
        ),
      )),
    );
    if (ok == true && mounted) {
      showToast(context, tr('تم إرسال الطلب، سيُطبَّق بعد موافقة الإدارة ✓'));
      // Pull the queued request straight back in, so re-opening the form shows
      // the "under review" view immediately instead of the pre-edit values.
      _load();
    }
  }

  /// Run [task] behind a modal spinner. Returns null if it failed — every call
  /// site here has a sane fallback, and a dead-looking tap is worse than a
  /// degraded one. Used for the calls that hit a possibly-cold Render instance.
  Future<T?> _withProgress<T>(String label, Future<T> Function() task) async {
    if (!mounted) return null;
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.green)),
            const SizedBox(width: 14),
            Flexible(child: Text(label, style: noto(13.5, color: C.textSecondary))),
          ]),
        ),
      ),
    );
    T? out;
    try { out = await task(); } catch (_) {}
    if (nav.canPop()) nav.pop();
    return out;
  }

  /// The point already has an edit waiting on an admin. Show the proposed values
  /// read-only — the holder needs to see that their request survived, and what
  /// they asked for, without being able to stack a second request on top.
  Future<void> _showPendingEdit(Map point, Map pending) async {
    final changes = (pending['changes'] as Map?) ?? {};
    const labels = {
      'name': 'اسم النقطة', 'area': 'البلدية', 'address': 'العنوان',
      'phone': 'الهاتف', 'hours': 'ساعات العمل', 'details': 'قاعة رياضية، مؤسسة، ..الخ',
    };
    // Every field, so this reads as the point's full record — the ones being
    // changed are highlighted, the rest show what is currently stored.
    Widget row(String k) {
      final changed = changes.containsKey(k);
      final shown = changed ? '${changes[k] ?? ''}' : '${point[k] ?? ''}';
      final isPhone = k == 'phone';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr(labels[k]!), style: noto(11, color: C.textTertiary)),
            if (changed) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFCE9D6), borderRadius: BorderRadius.circular(6)),
                child: Text(tr('معدّل'), style: cairo(9.5, w: FontWeight.w800, color: const Color(0xFFC24A18))),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: changed ? const Color(0xFFFFF6E6) : const Color(0xFFF4F4F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: changed ? const Color(0xFFF3E1BC) : C.cardBorder),
            ),
            child: Text(shown.isEmpty ? '—' : shown,
                style: noto(13, color: C.ink, height: 1.4),
                textDirection: isPhone ? TextDirection.ltr : null),
          ),
        ]),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dctx) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            mi('pending_actions', size: 21, color: const Color(0xFFC24A18)),
            const SizedBox(width: 8),
            Flexible(child: Text(tr('طلب قيد المراجعة'), style: cairo(16.5, w: FontWeight.w800, color: C.forest))),
          ]),
          content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('أرسلت طلب تعديل ولم تردّ عليه الإدارة بعد. لا يمكن إرسال طلب جديد حتى تتم الموافقة أو الرفض.'),
                  style: noto(12.5, color: C.textSecondary, height: 1.5)),
              const SizedBox(height: 12),
              ...labels.keys.map(row),
            ],
          ))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text(tr('حسناً'), style: cairo(14, w: FontWeight.w800, color: C.green)),
            ),
          ],
        ),
      ),
    );
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
          // The confirmation is a solid GREEN button, not a text link: it is the
          // action the holder came here to take, so it should read as the
          // affirmative primary control rather than a warning-coloured one.
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: tr('نعم الحاوية ممتلئة'),
                    height: 50,
                    onTap: () => Navigator.pop(dctx, true),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(dctx, false),
                  child: Text(tr('إلغاء'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary)),
                ),
              ]),
            ),
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
    // Refresh either way: on success this flips the button to its reported
    // state, and on an "already reported" error it syncs the button with the
    // alert that already exists.
    await _load();
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
        // "Notify bag is full". Once reported, this LOCKS until the container is
        // actually emptied — a second report would be a no-op server-side (one
        // open alert per point) and repeat taps only made holders think the
        // first one hadn't registered. It unlocks by itself when a field agent
        // services the point, which resolves the alert.
        if (_openAlert != null)
          Container(
            height: 48, width: double.infinity, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF7EFE3),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE4D5BE)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              mi('check_circle', size: 20, color: const Color(0xFFB07A2E)),
              const SizedBox(width: 8),
              Flexible(child: Text(
                tr('تم الإبلاغ — بانتظار التفريغ'),
                style: cairo(13.5, w: FontWeight.w800, color: const Color(0xFFB07A2E)),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
            ]),
          )
        else
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
        if (_openAlert != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              trf('أُبلغ {t}', {'t': timeAgo(DateTime.tryParse('${_openAlert!['at']}')?.toLocal() ?? DateTime.now())}),
              style: noto(10.5, color: C.textTertiary),
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

// ---- opening hours -------------------------------------------------------
// Stored on the point as one "HH:MM - HH:MM" string — the shape the dashboard,
// the seed data and the field app already write. Wheels instead of a text box
// guarantee that format and remove AM/PM ambiguity for early/late shifts.

String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Parse "08:00 - 20:00" back into its two ends. Anything else (old free text
/// like «من 8 صباحاً») yields nulls rather than throwing.
List<TimeOfDay?> parseHoursRange(String? raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$').firstMatch((raw ?? '').trim());
  if (m == null) return [null, null];
  final h1 = int.tryParse(m.group(1)!), m1 = int.tryParse(m.group(2)!);
  final h2 = int.tryParse(m.group(3)!), m2 = int.tryParse(m.group(4)!);
  if (h1 == null || m1 == null || h2 == null || m2 == null) return [null, null];
  if (h1 > 23 || h2 > 23 || m1 > 59 || m2 > 59) return [null, null];
  return [TimeOfDay(hour: h1, minute: m1), TimeOfDay(hour: h2, minute: m2)];
}

/// Both ends picked → the canonical string. Nothing picked → keep whatever was
/// stored, so opening the form and saving can't wipe a legacy value.
String hoursRangeString(TimeOfDay? from, TimeOfDay? to, {String fallback = ''}) =>
    (from != null && to != null) ? '${_hhmm(from)} - ${_hhmm(to)}' : fallback.trim();

/// «من / إلى» opening-hours picker driven by scroll wheels.
class HoursWheelField extends StatelessWidget {
  final String label;
  final TimeOfDay? from, to;
  final String fallback;
  final ValueChanged<TimeOfDay> onFrom, onTo;
  final VoidCallback onClear;
  const HoursWheelField({
    super.key, required this.label, required this.from, required this.to,
    required this.onFrom, required this.onTo, required this.onClear, this.fallback = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(child: Text(label, style: cairo(13, w: FontWeight.w700, color: C.forest),
            maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
        const Spacer(),
        if (from != null || to != null)
          Pressable(onTap: onClear, child: Padding(padding: const EdgeInsets.all(4),
            child: Text(tr('مسح'), style: cairo(12, w: FontWeight.w700, color: C.textSecondary)))),
      ]),
      // A legacy free-text value can't be shown on the wheels — surface it so
      // the holder knows what's currently saved before replacing it.
      if (from == null && to == null && fallback.trim().isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 2),
          child: Text(trf('الحالي: {v}', {'v': fallback.trim()}), style: noto(11.5, color: C.textTertiary))),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _slot(context, tr('من'), from, onFrom)),
        const SizedBox(width: 10),
        Expanded(child: _slot(context, tr('إلى'), to, onTo)),
      ]),
    ]);
  }

  Widget _slot(BuildContext context, String cap, TimeOfDay? v, ValueChanged<TimeOfDay> set) => Pressable(
        pressedScale: 0.98,
        onTap: () async {
          final picked = await showTimeWheelSheet(context, title: cap, initial: v ?? const TimeOfDay(hour: 8, minute: 0));
          if (picked != null) set(picked);
        },
        child: Container(
          height: 52, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.cardBorder, width: 1.4)),
          child: Row(children: [
            mi('schedule', size: 19, color: C.green),
            const SizedBox(width: 8),
            // Both lines are pinned to ONE line and shrink to fit. In a narrow
            // slot (two side by side on a small phone, or a longer translated
            // caption) they used to wrap, which broke "08:00" across lines and
            // read as a hyphenated time.
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cap, style: noto(10.5, color: C.textTertiary), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(v == null ? '--:--' : _hhmm(v), maxLines: 1, softWrap: false,
                    style: cairo(15, w: FontWeight.w800, color: v == null ? C.textTertiary : C.ink),
                    textDirection: TextDirection.ltr),
              ),
            ])),
            mi('expand_more', size: 20, color: C.textTertiary),
          ]),
        ),
      );
}

/// Bottom sheet with an hour wheel and a minute wheel (5-minute steps). Always
/// 24-hour, whatever the phone's locale says.
Future<TimeOfDay?> showTimeWheelSheet(BuildContext context, {required String title, required TimeOfDay initial}) {
  int hour = initial.hour;
  int minute = (initial.minute ~/ 5) * 5;
  final hCtrl = FixedExtentScrollController(initialItem: hour);
  final mCtrl = FixedExtentScrollController(initialItem: minute ~/ 5);

  Widget wheel(FixedExtentScrollController c, int count, int step, ValueChanged<int> onChange) => SizedBox(
        width: 84, height: 180,
        child: ListWheelScrollView.useDelegate(
          controller: c,
          itemExtent: 44,
          perspective: 0.004,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChange,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (_, i) => Center(child: Text((i * step).toString().padLeft(2, '0'),
                style: cairo(24, w: FontWeight.w800, color: C.forest), textDirection: TextDirection.ltr)),
          ),
        ),
      );

  return showModalBottomSheet<TimeOfDay>(
    context: context, backgroundColor: C.sand,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sctx) => Directionality(
      textDirection: appDirection,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 16, 22, 22 + MediaQuery.of(sctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 14),
          Text(title, style: cairo(17, w: FontWeight.w800, color: C.forest)),
          const SizedBox(height: 6),
          // The wheels are always laid out LTR so hour sits left of minute,
          // matching the HH:MM value they produce even in Arabic.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(alignment: Alignment.center, children: [
              Container(height: 46, decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(12))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                wheel(hCtrl, 24, 1, (i) => hour = i),
                Text(':', style: cairo(24, w: FontWeight.w800, color: C.forest)),
                wheel(mCtrl, 12, 5, (i) => minute = i * 5),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          GradientButton(label: tr('تم'), height: 50, onTap: () => Navigator.pop(sctx, TimeOfDay(hour: hour, minute: minute))),
        ]),
      ),
    ),
  );
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
