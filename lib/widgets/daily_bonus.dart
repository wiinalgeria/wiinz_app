import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/i18n.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Formats a remaining-seconds count as HH:MM:SS for the reset timer.
String bonusClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(sec)}';
}

/// The claim popup: shown on app entry when a bonus is available, and again
/// (as a success state) right after claiming. Returns true if the user claimed.
Future<bool> showDailyBonusDialog(BuildContext context, WidgetRef ref, {required int points}) async {
  bool claimed = false;
  // These MUST live outside the StatefulBuilder's builder. They used to be
  // declared inside it, so every setD() rebuild reset them to false: the first
  // tap set busy=true, the rebuild immediately cleared it, and the success
  // state could never render either — the dialog just sat there looking
  // untouched, which is why claiming appeared to need a second tap. (The first
  // tap did reach the server; the second then failed as "already claimed".)
  bool busy = false, done = false;
  int newBalance = 0;
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0xB80C140E),
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setD) {
        return _BonusDialogBody(
          points: points,
          onClaim: () async {
            if (busy) return;
            setD(() => busy = true);
            try {
              final res = await ref.read(apiClientProvider).claimDailyBonus();
              newBalance = (res['newBalance'] as num?)?.toInt() ?? 0;
              ref.read(sessionProvider.notifier).setPoints(newBalance);
              claimed = true;
              setD(() { busy = false; done = true; });
            } on ApiException catch (e) {
              setD(() => busy = false);
              if (dctx.mounted) { Navigator.pop(dctx); showToast(context, e.message); }
            } catch (_) {
              setD(() => busy = false);
            }
          },
          busy: busy, done: done, newBalance: newBalance,
        );
      },
    ),
  );
  return claimed;
}

class _BonusDialogBody extends StatelessWidget {
  final int points, newBalance;
  final bool busy, done;
  final VoidCallback onClaim;
  const _BonusDialogBody({required this.points, required this.onClaim, required this.busy, required this.done, required this.newBalance});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: appDirection,
      child: Dialog(
        backgroundColor: C.sand, insetPadding: const EdgeInsets.all(28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(gradient: C.avatarGrad, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: C.greenMid.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 16))]),
              child: mi(done ? 'check_circle' : 'card_giftcard', size: 52, color: Colors.white, fill: true),
            ),
            const SizedBox(height: 18),
            Text(done ? tr('تم استلام مكافأتك!') : tr('مكافأتك اليومية'),
              style: cairo(23, w: FontWeight.w800, color: C.forest), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(done ? tr('عُد غداً لمكافأة جديدة 🎁') : tr('استلم نقاطك المجانية لهذا اليوم'),
              style: noto(14, color: C.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFFFF6E6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF3E1BC))),
              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('+$points', style: cairo(44, w: FontWeight.w900, color: C.gold)),
                const SizedBox(width: 8),
                Text('Wz', style: cairo(20, w: FontWeight.w800, color: C.goldText)),
              ]),
            ),
            if (done) ...[
              const SizedBox(height: 12),
              Text.rich(TextSpan(text: tr('رصيدك الآن '), style: noto(13, color: const Color(0xFF6B6459)), children: [
                TextSpan(text: '$newBalance Wz', style: cairo(13, w: FontWeight.w800, color: C.goldText)),
              ])),
            ],
            const SizedBox(height: 20),
            done
              ? GradientButton(label: tr('رائع، تم'), height: 54, onTap: () => Navigator.pop(context))
              : GradientButton(label: busy ? '...' : tr('استلم المكافأة'), height: 54, loading: busy, onTap: busy ? () {} : onClaim),
          ]),
        ),
      ),
    );
  }
}

/// The rectangle card shown on the Settings screen: a claim button when the
/// bonus is ready, or a live countdown to the next reset when it isn't. Polls
/// its own status and ticks the timer down each second.
class DailyBonusCard extends ConsumerStatefulWidget {
  const DailyBonusCard({super.key});
  @override
  ConsumerState<DailyBonusCard> createState() => _DailyBonusCardState();
}

class _DailyBonusCardState extends ConsumerState<DailyBonusCard> {
  bool _loading = true, _enabled = false, _available = false, _claiming = false;
  int _points = 0, _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await ref.read(apiClientProvider).dailyBonus();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _enabled = s['enabled'] == true;
      _available = s['available'] == true;
      _points = (s['points'] as num?)?.toInt() ?? 0;
      _secondsLeft = (s['secondsLeft'] as num?)?.toInt() ?? 0;
    });
    _startTicking();
  }

  void _startTicking() {
    _timer?.cancel();
    if (_available || !_enabled) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) { t.cancel(); _load(); } // window elapsed → refetch
    });
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final ok = await showDailyBonusDialog(context, ref, points: _points);
    if (!mounted) return;
    setState(() => _claiming = false);
    if (ok) _load(); // claimed → flip to the countdown
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    if (_loading || !_enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Pressable(
        pressedScale: _available ? 0.98 : 1.0,
        onTap: _available ? _claim : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _available ? C.forestGrad : const LinearGradient(colors: [C.tint1, C.tint3]),
            borderRadius: BorderRadius.circular(20),
            border: _available ? null : Border.all(color: C.tint4),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _available ? Colors.white.withValues(alpha: 0.18) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: mi('card_giftcard', size: 28, color: _available ? Colors.white : C.greenMid),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('المكافأة اليومية'), style: cairo(16, w: FontWeight.w800, color: _available ? Colors.white : C.forest)),
              const SizedBox(height: 2),
              if (_available)
                Text(trf('استلم {n} Wz مجاناً اليوم', {'n': '$_points'}), style: noto(12.5, color: Colors.white.withValues(alpha: 0.9)))
              else
                Row(children: [
                  mi('timer', size: 14, color: C.greenMid),
                  const SizedBox(width: 5),
                  Text(trf('المكافأة القادمة بعد {t}', {'t': bonusClock(_secondsLeft)}),
                    style: cairo(12.5, w: FontWeight.w700, color: C.greenMid), textDirection: TextDirection.ltr),
                ]),
            ])),
            if (_available)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(999)),
                child: Text(_claiming ? '...' : tr('استلم'), style: cairo(13, w: FontWeight.w800, color: C.forest)),
              ),
          ]),
        ),
      ),
    );
  }
}
