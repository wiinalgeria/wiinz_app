import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/change_password.dart';
import '../../widgets/bottom_nav.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});
  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  List<Referral> _referrals = [];
  List<String> _wilayas = ['الجزائر'];
  // Communes keyed by wilaya, exactly as configured in the dashboard's قوائم التسجيل.
  Map<String, List<String>> _communesByWilaya = {'الجزائر': ['بلكور', 'باب الوادي', 'حسين داي']};
  List<String> _communesOf(String wilaya) => _communesByWilaya[wilaya] ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final r = await api.referrals();
      if (mounted) setState(() => _referrals = r);
    } catch (_) {}
    try {
      final (w, cbw) = await api.locations();
      if (mounted && w.isNotEmpty) setState(() { _wilayas = w; _communesByWilaya = cbw; });
    } catch (_) {}
  }

  // NOTE: the watch-video reward flow was removed with the feature marked
  // "coming soon" (see _watchCard); restore it from git history when it ships.
  Future<void> _changePassword() => showChangePasswordDialog(context, ref);

  // Let the user set/replace their profile picture — from the camera or gallery.
  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: C.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Text('صورة الملف الشخصي', style: cairo(17, w: FontWeight.w800, color: C.forest)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _sourceBtn('التقاط صورة', 'photo_camera', () => Navigator.pop(context, ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _sourceBtn('من المعرض', 'photo_library', () => Navigator.pop(context, ImageSource.gallery))),
          ]),
        ]),
      ))),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 70);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 500000) { if (mounted) showToast(context, 'الصورة كبيرة جداً، اختر صورة أصغر'); return; }
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final err = await ref.read(sessionProvider.notifier).saveProfile({'avatar': dataUri});
      if (mounted) showToast(context, err ?? 'تم تحديث صورتك ✓');
    } catch (_) {
      if (mounted) showToast(context, 'تعذّر اختيار الصورة');
    }
  }

  Widget _sourceBtn(String label, String icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder)),
      child: Column(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(14)), child: mi(icon, size: 26, color: C.greenMid)),
        const SizedBox(height: 8),
        Text(label, style: cairo(14, w: FontWeight.w700, color: C.ink)),
      ]),
    ),
  );

  Widget _avatar(WiinzUser user, double size) => avatarCircle(user.avatar, size);

  void _shareInvite(WiinzUser user) {
    final msg = 'انضم إلى تطبيق WIINZ ♻️ وابدأ بجمع القارورات وكسب النقاط والفوز بالهدايا! 🎁\n'
        'استخدم رمز دعوتي عند التسجيل: ${user.inviteCode}\n'
        'حمّل التطبيق الآن وابدأ الربح معنا.';
    SharePlus.instance.share(ShareParams(text: msg, subject: 'انضم إلى WIINZ'));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // more header (title + back)
          Container(height: 60, padding: const EdgeInsets.symmetric(horizontal: 20), color: C.sand,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('المزيد', style: cairo(22, w: FontWeight.w800, color: C.forest)),
              Pressable(pressedScale: 0.88, onTap: () => context.go('/home'), child: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.cardBorder)),
                child: Transform.flip(flipX: true, child: mi('arrow_forward', size: 22, color: C.forest)))),
            ])),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
            _profileHeader(user),
            const SizedBox(height: 12),
            _watchCard(user),
            const SizedBox(height: 22),
            _inviteCard(user),
            const SizedBox(height: 22),
            _referralsCard(),
            const SizedBox(height: 12),
            Text('اختصارات', style: cairo(13, w: FontWeight.w700, color: C.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              _shortcut('مكافأتي', 'confirmation_number', C.tint1, C.greenMid, () => context.go('/perks')),
              const SizedBox(width: 10),
              _shortcut('الهدايا', 'redeem', const Color(0xFFFCEBCB), C.goldText, () => context.go('/gifts')),
              const SizedBox(width: 10),
              _shortcut('نقاط الجمع', 'location_on', const Color(0xFFE3F0F7), const Color(0xFF1C7ED6), () => context.go('/map')),
            ]),
            const SizedBox(height: 24),
            Text('الإعدادات', style: cairo(13, w: FontWeight.w700, color: C.textSecondary)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.cardBorder)),
              child: Column(children: [
                _settingRow('تغيير كلمة المرور', 'lock', _changePassword),
                _settingRow('المساعدة والدعم', 'help', _openSupport),
                _settingRow('عن التطبيق', 'info', _openAbout, last: true),
              ]),
            ),
            const SizedBox(height: 12),
            Pressable(onTap: () async { await ref.read(sessionProvider.notifier).logout(); if (context.mounted) context.go('/login'); },
              child: Container(height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3D9D5), width: 1.5)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [mi('logout', size: 22, color: C.danger), const SizedBox(width: 8), Text('تسجيل الخروج', style: cairo(15, w: FontWeight.w700, color: C.danger))]))),
            const SizedBox(height: 22),
            Center(child: Text('WIINZ · الإصدار 2.0', style: noto(12, color: C.textTertiary))),
          ])),
          const WiinzBottomNav(current: null),
        ]),
      ),
    );
  }

  Widget _profileHeader(WiinzUser user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.tint1, C.tint3]), borderRadius: BorderRadius.circular(22), border: Border.all(color: C.tint4)),
      child: Column(children: [
        Row(children: [
          Stack(children: [
            _avatar(user, 66),
            Positioned(bottom: -2, left: -2, child: Pressable(pressedScale: 0.82, onTap: _pickAvatar, child: Container(width: 26, height: 26,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.tint4, width: 1.5)), child: mi('photo_camera', size: 16, color: C.greenMid)))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, style: cairo(19, w: FontWeight.w800, color: C.forest)),
            Row(children: [mi('phone', size: 15, color: const Color(0xFF6B7F73)), const SizedBox(width: 5), Text(user.phone.isEmpty ? '—' : user.phone, style: noto(13, color: const Color(0xFF6B7F73)), textDirection: TextDirection.ltr)]),
            Row(children: [mi('location_on', size: 15, color: const Color(0xFF6B7F73)), const SizedBox(width: 5), Flexible(child: Text(user.address.isEmpty ? user.commune : user.address, style: noto(13, color: const Color(0xFF6B7F73)), overflow: TextOverflow.ellipsis))]),
          ])),
        ]),
        const SizedBox(height: 14),
        Pressable(onTap: () => _editProfile(user), child: Container(height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: C.tint4, width: 1.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [mi('edit', size: 20, color: C.greenMid), const SizedBox(width: 8), Text('تعديل الملف الشخصي', style: cairo(14, w: FontWeight.w700, color: C.greenMid))]))),
      ]),
    );
  }

  Widget _watchCard(WiinzUser user) {
    return Pressable(
      pressedScale: 0.98,
      onTap: () => showToast(context, 'ستتوفر هذه الميزة قريباً ⏳'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: C.tealCard, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: C.teal1.withValues(alpha: 0.5), blurRadius: 26, offset: const Offset(0, 12))]),
        child: Column(children: [
          Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)), child: mi('smart_display', size: 30, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('شاهد الفيديوهات واربح النقاط', style: cairo(16, w: FontWeight.w800, color: Colors.white)),
              Text('شاهد إعلاناً قصيراً واكسب حتى 5 Wz يومياً', style: noto(12, color: Colors.white.withValues(alpha: 0.85))),
            ])),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [mi('schedule', size: 15, color: C.goldLight), const SizedBox(width: 6), Text('ستتوفر قريباً', style: cairo(12, w: FontWeight.w700, color: Colors.white))])),
            // button intentionally shown as disabled ("coming soon")
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text('شاهد الآن', style: cairo(13, w: FontWeight.w800, color: C.teal1.withValues(alpha: 0.55))), const SizedBox(width: 6), mi('lock', size: 16, color: C.teal1.withValues(alpha: 0.55))])),
          ]),
        ]),
      ),
    );
  }

  Widget _inviteCard(WiinzUser user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [mi('redeem', size: 20, color: const Color(0xFFCFF3E0)), const SizedBox(width: 8), Text('رمز الدعوة الخاص بك', style: cairo(14, w: FontWeight.w700, color: const Color(0xFFCFF3E0)))]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5)),
            alignment: Alignment.center, child: Text(user.inviteCode, style: cairo(20, w: FontWeight.w900, color: Colors.white, spacing: 2), textDirection: TextDirection.ltr))),
          const SizedBox(width: 10),
          Pressable(pressedScale: 0.88, onTap: () { Clipboard.setData(ClipboardData(text: user.inviteCode)); showToast(context, 'تم نسخ رمز الدعوة ✓'); },
            child: Container(width: 48, height: 48, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(13)), child: mi('content_copy', size: 22, color: Colors.white))),
          const SizedBox(width: 8),
          Pressable(pressedScale: 0.88, onTap: () => _shareInvite(user),
            child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)), child: mi('ios_share', size: 22, color: Colors.white))),
        ]),
        const SizedBox(height: 10),
        Text('شارك رمزك واحصل على 20 Wz لكل صديق ينضم 🎉', style: noto(11.5, color: Colors.white.withValues(alpha: 0.6))),
      ]),
    );
  }

  Widget _referralsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.cardBorder)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(12)), child: mi('group', size: 22, color: C.greenMid)),
            const SizedBox(width: 12),
            Text('أصدقاء انضموا برمزك', style: cairo(15, w: FontWeight.w700, color: C.ink)),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(10)),
            child: Text('${_referrals.length}', style: cairo(15, w: FontWeight.w800, color: C.greenMid))),
        ]),
        if (_referrals.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('لم ينضم أحد بعد — شارك رمزك لتبدأ الربح', style: noto(12.5, color: C.textTertiary)))
        else
          ..._referrals.map((r) => Container(
            margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF5EFE2)))),
            child: Row(children: [
              Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: C.tint3, shape: BoxShape.circle), child: Text(r.initial, style: cairo(14, w: FontWeight.w800, color: C.greenMid))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: cairo(14, w: FontWeight.w700, color: C.ink)), Text(r.when, style: noto(11.5, color: C.textTertiary))])),
              Text('+${r.reward} Wz', style: cairo(13, w: FontWeight.w800, color: C.goldText)),
            ]),
          )),
      ]),
    );
  }

  Widget _shortcut(String label, String icon, Color bg, Color color, VoidCallback onTap) {
    return Expanded(child: Pressable(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.cardBorder)),
      child: Column(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), child: mi(icon, size: 24, color: color)),
        const SizedBox(height: 8),
        Text(label, style: cairo(13, w: FontWeight.w700, color: C.ink)),
      ]),
    )));
  }

  Widget _settingRow(String label, String icon, VoidCallback onTap, {bool last = false}) {
    return Pressable(pressedScale: 0.98, onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF5EFE2)))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF1EEE6), borderRadius: BorderRadius.circular(12)), child: mi(icon, size: 22, color: const Color(0xFF6B6459))),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: cairo(15, w: FontWeight.w700, color: C.ink))),
        Transform.flip(flipX: true, child: mi('chevron_right', size: 22, color: const Color(0xFFC7BCA8))),
      ]),
    ));
  }

  void _editProfile(WiinzUser user) {
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    final address = TextEditingController(text: user.address);
    String wilaya = _wilayas.contains(user.wilaya) ? user.wilaya : _wilayas.first;
    final startCommunes = _communesOf(wilaya);
    String commune = startCommunes.contains(user.commune)
        ? user.commune
        : (startCommunes.isNotEmpty ? startCommunes.first : '');
    showModalBottomSheet(
      context: context, backgroundColor: C.sand, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: StatefulBuilder(
        builder: (context, setSheet) => Padding(
          // keyboard inset + the Android gesture/nav bar, so the buttons never
          // sit under the system bar
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(child: Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 30 + MediaQuery.of(context).padding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 16),
              Text('تعديل الملف الشخصي', style: cairo(19, w: FontWeight.w800, color: C.forest)),
              const SizedBox(height: 16),
              // profile picture — tap to change (camera / gallery)
              Pressable(
                onTap: () async { await _pickAvatar(); setSheet(() {}); },
                child: Column(children: [
                  Stack(children: [
                    _avatar(ref.read(sessionProvider).user ?? user, 84),
                    Positioned(bottom: 0, left: 0, child: Container(width: 30, height: 30,
                      decoration: BoxDecoration(color: C.green, shape: BoxShape.circle, border: Border.all(color: C.sand, width: 2)),
                      child: mi('photo_camera', size: 17, color: Colors.white))),
                  ]),
                  const SizedBox(height: 8),
                  Text('تغيير الصورة', style: cairo(13, w: FontWeight.w700, color: C.greenMid)),
                ]),
              ),
              const SizedBox(height: 18),
              _editField('الاسم الكامل', name, 'person'),
              _editField('رقم الهاتف', phone, 'phone', ltr: true),
              _editField('العنوان', address, 'location_on'),
              Row(children: [
                // Changing the wilaya resets the commune to that wilaya's first,
                // so the commune list always belongs to the chosen wilaya.
                Expanded(child: _editDropdown('الولاية', wilaya, _wilayas, 'map', (v) => setSheet(() {
                  wilaya = v;
                  final list = _communesOf(v);
                  commune = list.isNotEmpty ? list.first : '';
                }))),
                const SizedBox(width: 10),
                Expanded(child: _editDropdown('البلدية', commune, _communesOf(wilaya), null, (v) => setSheet(() => commune = v))),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Pressable(onTap: () => Navigator.pop(context), child: Container(width: 100, height: 54, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
                  child: Text('إلغاء', style: cairo(15, w: FontWeight.w700, color: const Color(0xFF6B6459))))),
                const SizedBox(width: 10),
                Expanded(child: GradientButton(label: 'حفظ التغييرات', height: 54, onTap: () async {
                  await ref.read(sessionProvider.notifier).saveProfile({'name': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(), 'wilaya': wilaya, 'commune': commune});
                  if (context.mounted) { Navigator.pop(context); showToast(context, 'تم حفظ التغييرات ✓'); }
                })),
              ]),
            ]),
          )),
        ),
      )),
    );
  }

  Widget _editDropdown(String label, String value, List<String> items, String? icon, ValueChanged<String> onChanged) {
    final safe = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
      const SizedBox(height: 8),
      Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
        child: Row(children: [
          if (icon != null) ...[mi(icon, size: 20, color: C.green), const SizedBox(width: 8)],
          Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: safe, isExpanded: true, icon: mi('expand_more', size: 20, color: C.textTertiary),
            menuMaxHeight: 320, // keep the popup compact + scrollable, not full-screen
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: noto(15, color: C.ink), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ))),
        ])),
    ]));
  }

  Widget _editField(String label, TextEditingController c, String icon, {bool ltr = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
      const SizedBox(height: 8),
      Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
        child: Row(children: [mi(icon, size: 22, color: C.green), const SizedBox(width: 10),
          Expanded(child: TextField(controller: c, textDirection: ltr ? TextDirection.ltr : null, textAlign: TextAlign.right,
            decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: noto(16, color: C.ink)))])),
    ]));
  }

  // ---- Help & Support: submit a ticket to the dashboard ----
  void _openSupport() {
    final subject = TextEditingController();
    final details = TextEditingController();
    bool sending = false;
    showModalBottomSheet(
      context: context, backgroundColor: C.sand, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(child: Padding(
            // + the Android nav-bar inset so the send/cancel row clears it
            padding: EdgeInsets.fromLTRB(22, 20, 22, 30 + MediaQuery.of(context).padding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 16),
              Row(children: [mi('support_agent', size: 24, color: C.green), const SizedBox(width: 8), Text('المساعدة والدعم', style: cairo(19, w: FontWeight.w800, color: C.forest))]),
              const SizedBox(height: 4),
              Text('صف مشكلتك أو اقتراحك وسيتواصل معك فريق WIINZ.', style: noto(13, color: C.textSecondary)),
              const SizedBox(height: 18),
              _editField('عنوان المشكلة / الاقتراح', subject, 'help'),
              Text('التفاصيل', style: cairo(13, w: FontWeight.w600, color: const Color(0xFF4A463E))),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
                child: TextField(controller: details, maxLines: 4, textAlign: TextAlign.right,
                  decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'اكتب التفاصيل هنا…', hintStyle: noto(14, color: C.textTertiary)), style: noto(15, color: C.ink))),
              const SizedBox(height: 18),
              Row(children: [
                Pressable(onTap: () => Navigator.pop(context), child: Container(width: 100, height: 54, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.inputBorder, width: 1.5)),
                  child: Text('إلغاء', style: cairo(15, w: FontWeight.w700, color: const Color(0xFF6B6459))))),
                const SizedBox(width: 10),
                Expanded(child: GradientButton(
                  label: sending ? '' : 'إرسال', icon: sending ? null : 'ios_share', height: 54,
                  leading: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : null,
                  onTap: () async {
                    if (subject.text.trim().isEmpty) { showToast(context, 'أدخل عنوان المشكلة'); return; }
                    setSheet(() => sending = true);
                    try {
                      await ref.read(apiClientProvider).submitSupport(subject.text.trim(), details.text.trim());
                      if (context.mounted) { Navigator.pop(context); showToast(context, 'تم إرسال رسالتك ✓ سنتواصل معك قريباً'); }
                    } catch (_) {
                      setSheet(() => sending = false);
                      if (context.mounted) showToast(context, 'تعذّر الإرسال، حاول مجدداً');
                    }
                  })),
              ]),
            ]),
          )),
        ),
      )),
    );
  }

  // ---- About the app ----
  void _openAbout() {
    Widget social(FaIconData icon, Color color, String url) => Pressable(
      pressedScale: 0.85,
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Center(child: FaIcon(icon, size: 20, color: color))),
    );
    showModalBottomSheet(
      context: context, backgroundColor: C.sand,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 34 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 20),
          Image.asset('assets/images/wiin-logo-green.png', width: 120),
          const SizedBox(height: 16),
          Text('WIIN ALGERIA', style: cairo(20, w: FontWeight.w900, color: C.forest)),
          const SizedBox(height: 4),
          Text('شركة ناشئة في تسيير النفايات وإعادة التدوير', style: noto(13.5, color: C.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('طُوّر ونُشر بواسطة WIIN ALGERIA', style: noto(12, color: C.textTertiary), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            social(FontAwesomeIcons.facebookF, const Color(0xFF1877F2), 'https://www.facebook.com/wiin.algeria/'),
            const SizedBox(width: 12),
            social(FontAwesomeIcons.instagram, const Color(0xFFE4405F), 'https://www.instagram.com/wiin.algeria/'),
            const SizedBox(width: 12),
            social(FontAwesomeIcons.youtube, const Color(0xFFFF0000), 'https://www.youtube.com/@wiin.algeria'),
            const SizedBox(width: 12),
            social(FontAwesomeIcons.linkedinIn, const Color(0xFF0A66C2), 'https://www.linkedin.com/company/wiinalgeria/'),
            const SizedBox(width: 12),
            social(FontAwesomeIcons.tiktok, C.ink, 'https://www.tiktok.com/@wiinalgeria0'),
          ]),
          const SizedBox(height: 20),
          Text('WIINZ · الإصدار 2.0', style: noto(12, color: C.textTertiary)),
        ]),
      )),
    );
  }
}
