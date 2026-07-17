import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// A three-screen "how the app works" walkthrough, opened from Settings. Each
/// screen is one step of the core loop; the user swipes (or taps Next) through
/// them. Swipe direction follows the app language automatically (RTL vs LTR)
/// because the whole thing is wrapped in [appDirection].
class _Step {
  final String icon, title, body;
  const _Step(this.icon, this.title, this.body);
}

const _steps = <_Step>[
  _Step('water_bottle', 'اجمع القارورات',
      'اجمع القارورات البلاستيكية الفارغة في المنزل بدل رميها.'),
  _Step('location_on', 'أودعها في نقطة الجمع',
      'اعثر على أقرب نقطة جمع على الخريطة وأودع قاروراتك هناك.'),
  _Step('qr_code_scanner', 'امسح واكسب النقاط',
      'امسح رمز QR الخاص بنقطة الجمع لتكسب نقاط Wz، واستبدلها بهدايا ومكافآت.'),
];

Future<void> showAppTutorial(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'tutorial',
    barrierColor: const Color(0xFF0C140E),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim, secondary) => const _TutorialView(),
    transitionBuilder: (context, anim, secondary, child) => FadeTransition(opacity: anim, child: child),
  );
}

class _TutorialView extends StatefulWidget {
  const _TutorialView();
  @override
  State<_TutorialView> createState() => _TutorialViewState();
}

class _TutorialViewState extends State<_TutorialView> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return Directionality(
      textDirection: appDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C140E),
        body: SafeArea(
          child: Column(children: [
            // Skip — top, at the text-direction end
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(tr('تخطّي'), style: cairo(14, w: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _steps.length,
                itemBuilder: (_, i) {
                  final s = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 132, height: 132,
                        decoration: BoxDecoration(color: C.green.withValues(alpha: 0.16), shape: BoxShape.circle),
                        child: mi(s.icon, size: 62, color: const Color(0xFF7BD86A)),
                      ),
                      const SizedBox(height: 12),
                      // step number chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                        child: Text(trf('الخطوة {n} من {t}', {'n': '${i + 1}', 't': '${_steps.length}'}),
                          style: cairo(11.5, w: FontWeight.w700, color: const Color(0xFF7BD86A))),
                      ),
                      const SizedBox(height: 22),
                      Text(tr(s.title), textAlign: TextAlign.center, style: cairo(24, w: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 14),
                      Text(tr(s.body), textAlign: TextAlign.center, style: noto(15, color: Colors.white.withValues(alpha: 0.82), height: 1.7)),
                    ]),
                  );
                },
              ),
            ),
            // dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_steps.length, (i) {
              final on = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 22 : 8, height: 8,
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF7BD86A) : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            })),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: GradientButton(label: last ? tr('ابدأ') : tr('التالي'), height: 54, onTap: _next),
            ),
          ]),
        ),
      ),
    );
  }
}
