import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/language_selector.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialSignup;
  const AuthScreen({super.key, this.initialSignup = false});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool signup = widget.initialSignup;
  String gender = 'male';
  String? wilaya;
  String? commune;
  int? _bDay, _bMonth, _bYear; // birthdate parts (month is 1-12)
  String? error;

  // Algerian month names (Jan → Dec), used in the birthdate month dropdown.
  static const _monthNames = ['جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', 'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

  // Assembled ISO birthdate (yyyy-mm-dd) once all three parts are chosen.
  String get _birthdateIso {
    if (_bDay == null || _bMonth == null || _bYear == null) return '';
    return DateTime(_bYear!, _bMonth!, _bDay!).toIso8601String().split('T').first;
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  List<String> _wilayas = ['الجزائر'];
  Map<String, List<String>> _communesByWilaya = {'الجزائر': ['بلكور', 'باب الوادي', 'حسين داي']};
  List<String> get _communes => _communesByWilaya[wilaya] ?? const [];

  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final invite = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _showErrors = false; // turns on field-level red validation after a submit attempt

  @override
  void initState() {
    super.initState();
    _loadLocations();
    // live-refresh so the password red/green state, email validity and
    // required-field borders update as the user types
    for (final c in [name, phone, email, password, confirmPassword]) {
      c.addListener(() { if (mounted) setState(() {}); });
    }
  }

  // ---- signup field validation helpers ----
  bool get _pwValid => password.text.length >= 8;

  Color? _reqBorder(TextEditingController c) => (_showErrors && c.text.trim().isEmpty) ? C.danger : null;
  Widget? _reqFooter(TextEditingController c) =>
      (_showErrors && c.text.trim().isEmpty) ? Text(tr('هذا الحقل مطلوب'), style: cairo(11.5, w: FontWeight.w700, color: C.danger)) : null;

  Color? _pwBorder() {
    if (password.text.isEmpty && !_showErrors) return null;
    return _pwValid ? C.green : C.danger;
  }
  Widget _pwFooter() {
    final neutral = password.text.isEmpty && !_showErrors;
    final color = _pwValid ? C.green : (neutral ? C.textTertiary : C.danger);
    return Text(_pwValid ? tr('✓ كلمة مرور جيدة') : tr('يجب أن تكون كلمة المرور 8 أحرف على الأقل'),
        style: cairo(11.5, w: FontWeight.w700, color: color));
  }

  // Email is optional; when the user has typed something that isn't a valid
  // address we warn softly in orange (not the hard red used for required fields).
  static const _emailWarn = Color(0xFFE8890C);
  bool get _emailValid => _emailRe.hasMatch(email.text.trim());
  Color? _emailBorder() {
    if (email.text.trim().isEmpty) return null;
    return _emailValid ? C.green : _emailWarn;
  }
  Widget? _emailFooter() {
    if (email.text.trim().isEmpty || _emailValid) return null;
    return Text(tr('الإيمايل غير صالح'), style: cairo(11.5, w: FontWeight.w700, color: _emailWarn));
  }

  Color? _confBorder() {
    if (confirmPassword.text.isNotEmpty) return confirmPassword.text == password.text ? C.green : C.danger;
    if (_showErrors) return C.danger;
    return null;
  }
  Widget? _confFooter() {
    if (confirmPassword.text.isNotEmpty && confirmPassword.text != password.text) {
      return Text(tr('كلمتا المرور غير متطابقتين'), style: cairo(11.5, w: FontWeight.w700, color: C.danger));
    }
    if (confirmPassword.text.isEmpty && _showErrors) {
      return Text(tr('هذا الحقل مطلوب'), style: cairo(11.5, w: FontWeight.w700, color: C.danger));
    }
    return null;
  }

  Future<void> _loadLocations() async {
    try {
      final (w, cbw) = await ref.read(apiClientProvider).locations();
      if (mounted && w.isNotEmpty) {
        setState(() {
          _wilayas = w;
          _communesByWilaya = cbw;
          wilaya = w.first;
          commune = (cbw[w.first] ?? const []).isNotEmpty ? cbw[w.first]!.first : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => error = null);
    final notifier = ref.read(sessionProvider.notifier);
    if (signup) {
      setState(() => _showErrors = true);
      if (name.text.trim().isEmpty || phone.text.trim().isEmpty || password.text.isEmpty || confirmPassword.text.isEmpty) {
        setState(() => error = tr('يرجى ملء جميع الحقول الإلزامية المطلوبة'));
        return;
      }
      if (password.text.length < 8) {
        setState(() => error = tr('كلمة المرور قصيرة (8 أحرف على الأقل)'));
        return;
      }
      if (password.text != confirmPassword.text) {
        setState(() => error = tr('كلمتا المرور غير متطابقتين'));
        return;
      }
      // Email is optional, but if the user typed one it must be a valid address.
      if (email.text.trim().isNotEmpty && !_emailRe.hasMatch(email.text.trim())) {
        setState(() => error = tr('البريد الإلكتروني غير صالح (مثال: test@domain.com)'));
        return;
      }
      final err = await notifier.signup({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'wilaya': wilaya ?? _wilayas.first,
        'commune': commune ?? _communes.first,
        'gender': gender,
        'birthdate': _birthdateIso,
        'inviteCode': invite.text.trim(),
      });
      if (!mounted) return;
      if (err == null) { context.go('/home'); } else { setState(() => error = err); }
    } else {
      final ex = await notifier.login(email.text.trim(), password.text);
      if (!mounted) return;
      if (ex == null) { context.go('/home'); } else { _showLoginError(ex); }
    }
  }

  void _showLoginError(ApiException ex) {
    final badPassword = ex.code == 'bad_password';
    showDialog<void>(
      context: context,
      builder: (dctx) => Directionality(
        textDirection: appDirection,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFFCEBEA), shape: BoxShape.circle),
              child: mi(badPassword ? 'lock' : 'person_off', size: 28, color: C.danger)),
            const SizedBox(height: 14),
            Text(ex.message, textAlign: TextAlign.center, style: cairo(15, w: FontWeight.w700, color: C.danger, height: 1.5)),
          ]),
          actions: [
            if (badPassword)
              TextButton(onPressed: () { Navigator.pop(dctx); _forgotPassword(); },
                child: Text(tr('نسيت كلمة المرور؟'), style: cairo(14, w: FontWeight.w800, color: C.green))),
            TextButton(onPressed: () => Navigator.pop(dctx),
              child: Text(tr('حسناً'), style: cairo(14, w: FontWeight.w800, color: C.textSecondary))),
          ],
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: email.text.trim());
    bool sending = false;
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => Directionality(
          textDirection: appDirection,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(tr('استعادة كلمة المرور'), style: cairo(18, w: FontWeight.w800, color: C.forest)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('أدخل رقم هاتفك أو بريدك الإلكتروني. سيتواصل معك فريق WIINZ لإعادة تعيين كلمة مرورك.'),
                  style: noto(13, color: C.textSecondary, height: 1.5)),
              const SizedBox(height: 14),
              Container(
                height: 52, padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.inputBorder, width: 1.5)),
                child: Row(children: [
                  mi('person', size: 20, color: C.green), const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: controller, textDirection: TextDirection.ltr, textAlign: TextAlign.right,
                    decoration: InputDecoration(hintText: tr('الهاتف أو البريد'), border: InputBorder.none, isDense: true, hintStyle: noto(14, color: C.textTertiary)),
                    style: noto(15, color: C.ink),
                  )),
                ]),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: Text(tr('إلغاء'), style: cairo(14, w: FontWeight.w700, color: C.textSecondary))),
              TextButton(
                onPressed: sending ? null : () async {
                  final contact = controller.text.trim();
                  if (contact.isEmpty) return;
                  setD(() => sending = true);
                  try {
                    await ref.read(apiClientProvider).requestPasswordReset(contact);
                  } catch (_) {}
                  if (!dctx.mounted) return;
                  Navigator.pop(dctx);
                  if (mounted) showToast(context, 'تم إرسال طلبك ✓ سيتواصل معك الفريق قريباً');
                },
                child: Text(sending ? '...' : 'إرسال الطلب', style: cairo(14, w: FontWeight.w800, color: C.green)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Birthdate via three dropdowns: Day · Month (Algerian names) · Year.
  Widget _birthdateField() {
    final now = DateTime.now();
    final days = List.generate(31, (i) => i + 1);
    final months = List.generate(12, (i) => i + 1); // stored 1-12
    final years = List.generate(now.year - 1940 + 1, (i) => now.year - i); // newest first
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('تاريخ الميلاد'), style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 5, child: _dateDropdown<int>(hint: tr('اليوم'), icon: 'cake', value: _bDay, items: days, label: (d) => '$d', onChanged: (v) => setState(() => _bDay = v))),
          const SizedBox(width: 8),
          Expanded(flex: 7, child: _dateDropdown<int>(hint: tr('الشهر'), value: _bMonth, items: months, label: (m) => _monthNames[m - 1], onChanged: (v) => setState(() => _bMonth = v))),
          const SizedBox(width: 8),
          Expanded(flex: 6, child: _dateDropdown<int>(hint: tr('السنة'), value: _bYear, items: years, label: (y) => '$y', onChanged: (v) => setState(() => _bYear = v))),
        ]),
      ],
    );
  }

  Widget _dateDropdown<T>({required String hint, String? icon, required T? value, required List<T> items, required String Function(T) label, required ValueChanged<T> onChanged}) {
    return Container(
      height: 56,
      padding: EdgeInsets.only(right: icon != null ? 12 : 10, left: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
      child: Row(children: [
        if (icon != null) ...[mi(icon, size: 18, color: C.green), const SizedBox(width: 6)],
        Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<T>(
          value: value, isExpanded: true, isDense: true,
          hint: Text(hint, style: noto(14, color: C.textTertiary), overflow: TextOverflow.ellipsis),
          icon: mi('expand_more', size: 18, color: C.textTertiary),
          menuMaxHeight: 280, // short, scrollable popup instead of a full-height list
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(label(e), style: noto(15, color: C.ink), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final loading = ref.watch(sessionProvider).loading;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // full-bleed green header (extends under the status bar, edge to edge)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24, bottom: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF63c24e), C.green, Color(0xFF3c8a2b)]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(alignment: AlignmentDirectional.centerStart, child: LanguagePill(textColor: Colors.white)),
                  ),
                  const SizedBox(height: 6),
                  Image.asset('assets/images/wiin-logo-white.png', width: 158),
                  const SizedBox(height: 14),
                  // The FR/EN slogans are far longer than the Arabic and wrap to
                  // two lines, so they need to stay centred under the logo rather
                  // than align to the text-direction start.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(tr('اجمع القارورات وحافظ على بيئتك'),
                      textAlign: TextAlign.center,
                      style: noto(13, w: FontWeight.w600, color: Colors.white.withValues(alpha: 0.92), height: 1.5)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr(signup ? 'أنشئ حسابك' : 'مرحباً بعودتك'), style: cairo(23, w: FontWeight.w800, color: C.forest)),
                  const SizedBox(height: 4),
                  Text(tr(signup ? 'ابدأ رحلتك في إعادة التدوير' : 'سجّل الدخول لمتابعة كسب النقاط'), style: noto(14, color: C.textSecondary)),
                  const SizedBox(height: 24),

                  if (signup) ...[
                    _field('الاسم الكامل', name, 'person', hint: tr('اكتب اسمك'), borderColor: _reqBorder(name), footer: _reqFooter(name)),
                    _field('رقم الهاتف', phone, 'phone', hint: '05 00 00 00 00', ltr: true, keyboard: TextInputType.phone, maxLength: 10, digitsOnly: true,
                        borderColor: _reqBorder(phone), footer: _reqFooter(phone)),
                    Row(children: [
                      Expanded(child: _dropdown('الولاية', wilaya ?? _wilayas.first, _wilayas, (v) => setState(() {
                        wilaya = v;
                        commune = _communes.isNotEmpty ? _communes.first : null; // reset commune to the new wilaya's first
                      }), 'map')),
                      const SizedBox(width: 10),
                      Expanded(child: _dropdown('البلدية', commune ?? (_communes.isNotEmpty ? _communes.first : ''), _communes, (v) => setState(() => commune = v), null)),
                    ]),
                    const SizedBox(height: 14),
                    _birthdateField(),
                    const SizedBox(height: 14),
                    _genderPicker(),
                    const SizedBox(height: 14),
                    _field('رمز الدعوة (اختياري)', invite, 'confirmation_number', hint: 'WIIN-U-000', ltr: true),
                  ],

                  _field(signup ? 'البريد الإلكتروني (غير إلزامي)' : 'البريد الإلكتروني أو رقم الهاتف',
                      email, 'mail',
                      hint: signup ? 'exemple@domain.com' : 'name@wiinz.com أو 05 00 00 00 00',
                      ltr: true, keyboard: signup ? TextInputType.emailAddress : TextInputType.text,
                      borderColor: signup ? _emailBorder() : null, footer: signup ? _emailFooter() : null),
                  _field('كلمة المرور', password, 'lock', obscure: true, ltr: true, hint: '••••••••',
                      visible: _showPassword, onToggleVisible: () => setState(() => _showPassword = !_showPassword),
                      borderColor: signup ? _pwBorder() : null, footer: signup ? _pwFooter() : null),
                  if (signup)
                    _field('تأكيد كلمة المرور', confirmPassword, 'lock', obscure: true, ltr: true, hint: '••••••••',
                        visible: _showConfirm, onToggleVisible: () => setState(() => _showConfirm = !_showConfirm),
                        borderColor: _confBorder(), footer: _confFooter()),
                  const SizedBox(height: 8),

                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFFCEBEA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3C6C1))),
                        child: Row(children: [
                          mi('info', size: 20, color: C.danger),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error!, style: cairo(13, w: FontWeight.w700, color: C.danger))),
                        ]),
                      ),
                    ),

                  GradientButton(
                    label: signup ? 'إنشاء الحساب' : 'تسجيل الدخول',
                    leading: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Transform.flip(flipX: true, child: mi('arrow_forward', color: Colors.white, size: 22)),
                    onTap: loading ? () {} : _submit,
                  ),

                  if (!signup)
                    Center(
                      child: Pressable(
                        pressedScale: 0.97,
                        onTap: _forgotPassword,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          child: Text(tr('نسيت كلمة المرور؟'), textAlign: TextAlign.center, style: cairo(16, w: FontWeight.w800, color: const Color(0xFF3c8a2b))),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Row(children: [
                      const Expanded(child: Divider(color: C.inputBorder)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(tr('أو'), style: noto(12, color: C.textTertiary))),
                      const Expanded(child: Divider(color: C.inputBorder)),
                    ]),
                  ),

                  // large tappable toggle (bordered button)
                  Pressable(
                    pressedScale: 0.98,
                    onTap: () => setState(() { signup = !signup; error = null; _showErrors = false; }),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8EF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3c8a2b), width: 1.6),
                      ),
                      child: Text.rich(TextSpan(
                        text: signup ? 'لديك حساب بالفعل؟ ' : 'ليس لديك حساب؟ ',
                        style: noto(15, w: FontWeight.w600, color: const Color(0xFF4A463E)),
                        children: [TextSpan(text: signup ? 'سجّل الدخول' : 'أنشئ حساباً', style: cairo(17, w: FontWeight.w800, color: const Color(0xFF3c8a2b)))],
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, String icon,
      {String? hint, bool obscure = false, bool ltr = false, TextInputType? keyboard, int? maxLength, bool digitsOnly = false,
      bool? visible, VoidCallback? onToggleVisible, Color? borderColor, Widget? footer}) {
    final formatters = <TextInputFormatter>[
      if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
    ];
    final hasEye = obscure && onToggleVisible != null;
    final hidden = obscure && !(visible ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(label), style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: EdgeInsets.only(right: 16, left: hasEye ? 4 : 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor ?? C.inputBorder, width: borderColor != null ? 1.8 : 1.5)),
            child: Row(children: [
              mi(icon, size: 22, color: borderColor ?? C.green),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: c, obscureText: hidden, keyboardType: keyboard,
                inputFormatters: formatters.isEmpty ? null : formatters,
                textDirection: ltr ? TextDirection.ltr : null,
                textAlign: TextAlign.right,
                decoration: InputDecoration(hintText: hint == null ? null : tr(hint), border: InputBorder.none, isDense: true, hintStyle: noto(15, color: C.textTertiary)),
                style: noto(16, color: C.ink),
              )),
              if (hasEye)
                IconButton(
                  onPressed: onToggleVisible,
                  visualDensity: VisualDensity.compact,
                  icon: mi((visible ?? false) ? 'visibility_off' : 'visibility', size: 22, color: C.textTertiary),
                ),
            ]),
          ),
          if (footer != null) Padding(padding: const EdgeInsets.only(top: 6, right: 4), child: footer),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged, String? icon) {
    final safeValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(label), style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
          child: Row(children: [
            if (icon != null) ...[mi(icon, size: 20, color: C.green), const SizedBox(width: 8)],
            Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: safeValue, isExpanded: true, icon: mi('expand_more', size: 20, color: C.textTertiary),
              menuMaxHeight: 320, // short, scrollable popup instead of a full-height list
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: noto(15, color: C.ink), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ))),
          ]),
        ),
      ],
    );
  }

  Widget _genderPicker() {
    Widget btn(String key, String label, String icon) {
      final on = gender == key;
      return Expanded(child: Pressable(
        pressedScale: 0.95,
        onTap: () => setState(() => gender = key),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11),
            boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))] : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            mi(icon, size: 18, color: on ? C.forest : C.textSecondary),
            const SizedBox(width: 4),
            Text(tr(label), style: cairo(14, w: FontWeight.w700, color: on ? C.forest : C.textSecondary)),
          ]),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('الجنس'), style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
        const SizedBox(height: 8),
        Container(
          height: 56, padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: const Color(0xFFF5EFE2), borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [btn('male', 'ذكر', 'male'), const SizedBox(width: 6), btn('female', 'أنثى', 'female')]),
        ),
      ],
    );
  }
}
