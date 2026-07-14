import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  void _maybeAutoAdvance(SessionState s) {
    // Once the session check finishes: logged-in users skip the splash entirely.
    if (_navigated || s.checkingSession) return;
    if (s.isLoggedIn) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }
  }

  void _start(SessionState s) {
    if (_navigated || s.checkingSession) return;
    _navigated = true;
    // First-time users see the welcome screen; afterwards go straight to login.
    context.go(s.isLoggedIn ? '/home' : (s.seenWelcome ? '/login' : '/welcome'));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    _maybeAutoAdvance(session);

    return Scaffold(
      body: GestureDetector(
        onTap: () => _start(session),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/splash-screen.jpg', fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x1F49A839), Color(0x0D49A839), Color(0x8C346E28)],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            // While the session/config check runs (can be slow on a cold server),
            // show a gentle "connecting" hint so the screen never looks frozen.
            if (session.checkingSession)
              const Positioned(
                left: 0, right: 0, bottom: 72,
                child: Column(
                  children: [
                    SizedBox(
                      width: 26, height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    ),
                  ],
                ),
              ),
            // Only show the "start" button once we know the user is logged out.
            if (!session.checkingSession && !session.isLoggedIn)
              Positioned(
                left: 34, right: 34, bottom: 58,
                child: Pressable(
                  onTap: () => _start(session),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 34, offset: const Offset(0, 16))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ابدأ الآن', style: cairo(18, w: FontWeight.w800, color: const Color(0xFF2f7d22))),
                        const SizedBox(width: 8),
                        Transform.flip(flipX: true, child: mi('arrow_forward', size: 22, color: const Color(0xFF2f7d22))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
