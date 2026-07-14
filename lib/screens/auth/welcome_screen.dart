import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// First-run screen: a warm intro with two clear choices —
/// «تسجيل الدخول» (green outline) and «إنشاء حساب» (green filled).
/// Shown only the first time the app is opened (tracked in the session).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  void _go(WidgetRef ref, BuildContext context, String route) {
    ref.read(sessionProvider.notifier).markWelcomeSeen();
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF63c24e), C.green, Color(0xFF2f7d22)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Image.asset('assets/images/wiin-logo-white.png', width: 190),
                const SizedBox(height: 22),
                Text('مرحباً بك في WIINZ', textAlign: TextAlign.center,
                    style: cairo(26, w: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 12),
                Text('اجمع القارورات، اكسب النقاط، واربح الهدايا — وحافظ على بيئتك.',
                    textAlign: TextAlign.center,
                    style: noto(15, color: Colors.white.withValues(alpha: 0.92), height: 1.7)),
                const Spacer(flex: 4),
                // إنشاء حساب — filled white/green primary
                Pressable(
                  onTap: () => _go(ref, context, '/signup'),
                  child: Container(
                    height: 58, width: double.infinity, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12))],
                    ),
                    child: Text('إنشاء حساب', style: cairo(18, w: FontWeight.w800, color: const Color(0xFF2f7d22))),
                  ),
                ),
                const SizedBox(height: 14),
                // تسجيل الدخول — green outline
                Pressable(
                  onTap: () => _go(ref, context, '/login'),
                  child: Container(
                    height: 58, width: double.infinity, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text('تسجيل الدخول', style: cairo(18, w: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
