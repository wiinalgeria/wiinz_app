import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens taken directly from the WIIN redesign handoff.
class C {
  // brand greens
  static const green = Color(0xFF49A839);
  static const greenMid = Color(0xFF34801f);
  static const greenBtnEnd = Color(0xFF3c8a2b);
  static const forest = Color(0xFF1B4332);
  static const forestDeep = Color(0xFF123024);

  // gold (reserved for Wz points)
  static const gold = Color(0xFFF5A623);
  static const goldText = Color(0xFFB7791F);
  static const goldLight = Color(0xFFF7C065);

  // surfaces & neutrals
  static const sand = Color(0xFFFAF3E8);
  static const ink = Color(0xFF2B2620);
  static const textSecondary = Color(0xFF8A8278);
  static const textTertiary = Color(0xFFA79E8D);
  static const cardBorder = Color(0xFFF0E5CF);
  static const inputBorder = Color(0xFFEADFC9);
  static const divider = Color(0xFFEFE7D6);

  // light green tints
  static const tint1 = Color(0xFFEAF6EF);
  static const tint2 = Color(0xFFE6F4EC);
  static const tint3 = Color(0xFFDCEFE4);
  static const tint4 = Color(0xFFCDE6D8);

  // accent
  static const teal1 = Color(0xFF0E7C86);
  static const teal2 = Color(0xFF16A0AB);
  static const locationBlue = Color(0xFF2A6FDB);
  static const danger = Color(0xFFD64545);

  // gradients
  static const greenCard = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [Color(0xFF57c243), green, Color(0xFF2f7d22)],
  );
  static const greenButton = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [green, greenBtnEnd],
  );
  static const forestGrad = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [forest, greenMid],
  );
  static const goldGrad = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [Color(0xFFF7B84B), gold],
  );
  static const silverCard = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [Color(0xFFAEB7C2), Color(0xFF7C8794), Color(0xFF5A6470)],
  );
  static const goldCard = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [Color(0xFFC9A227), Color(0xFFA67C1E), Color(0xFF7A5A12)],
  );
  static const tealCard = LinearGradient(
    begin: Alignment.topRight, end: Alignment.bottomLeft,
    colors: [teal1, teal2],
  );
  static const avatarGrad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [green, greenMid],
  );

  // shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF785A14).withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> greenBtnShadow = [
    BoxShadow(color: const Color(0xFF40916C).withValues(alpha: 0.7), blurRadius: 26, offset: const Offset(0, 14)),
  ];
}

TextStyle cairo(double size, {FontWeight w = FontWeight.w700, Color color = C.ink, double? height, double? spacing}) =>
    GoogleFonts.cairo(fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing);

TextStyle noto(double size, {FontWeight w = FontWeight.w400, Color color = C.ink, double? height}) =>
    GoogleFonts.notoSansArabic(fontSize: size, fontWeight: w, color: color, height: height);

final appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: C.sand,
  colorScheme: ColorScheme.fromSeed(seedColor: C.green, primary: C.green),
  textTheme: GoogleFonts.notoSansArabicTextTheme(),
  splashFactory: InkRipple.splashFactory,
);
