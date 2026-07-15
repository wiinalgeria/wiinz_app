import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/scan/scan_screen.dart';
import 'screens/perks/perks_screen.dart';
import 'screens/gifts/gifts_screen.dart';
import 'screens/more/more_screen.dart';
import 'widgets/notification_host.dart';
import 'core/local_notify.dart';
import 'core/push.dart';
import 'core/i18n.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocale(); // restore the saved language before the first frame
  await initLocalNotifications();
  await initPush(); // Firebase Cloud Messaging (out-of-app notifications)
  runApp(const ProviderScope(child: WiinzApp()));
}

Page<void> _fade(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
    );

// On non-home screens the phone back button returns to Home instead of exiting the app.
Widget _homeBack(Widget child) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _router.go('/home'); },
      child: child,
    );

final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (c, s) => const AuthScreen()),
    GoRoute(path: '/signup', builder: (c, s) => const AuthScreen(initialSignup: true)),
    GoRoute(path: '/home', pageBuilder: (c, s) => _fade(const HomeScreen())),
    GoRoute(path: '/map', pageBuilder: (c, s) => _fade(_homeBack(const MapScreen()))),
    GoRoute(path: '/scan', pageBuilder: (c, s) => _fade(_homeBack(const ScanScreen()))),
    GoRoute(path: '/perks', pageBuilder: (c, s) => _fade(_homeBack(const PerksScreen()))),
    GoRoute(path: '/gifts', pageBuilder: (c, s) => _fade(_homeBack(const GiftsScreen()))),
    GoRoute(path: '/more', pageBuilder: (c, s) => _fade(_homeBack(const MoreScreen()))),
  ],
);

class WiinzApp extends ConsumerWidget {
  const WiinzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider); // rebuild the app when language changes
    return MaterialApp.router(
      title: 'WIINZ',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: appDirection, // RTL for Arabic, LTR for French/English
        child: NotificationHost(navigatorKey: rootNavigatorKey, child: child!),
      ),
      routerConfig: _router,
    );
  }
}
