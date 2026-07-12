import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../../widgets/headers.dart';
import '../../widgets/bottom_nav.dart';

// OpenStreetMap-based free vector tiles (no API key required).
const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const _algiers = LatLng(36.7538, 3.0588);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _map;
  List<CollectionPoint> _points = [];
  final Map<String, CollectionPoint> _symbolPoints = {};
  bool _styleReady = false;
  bool _symbolsAdded = false;
  LatLng? _lastUser;
  bool _locationGranted = false;
  bool _locationDenied = false;
  bool _loading = true;
  bool _listExpanded = true; // collapse the point list to give the map more room
  StreamSubscription<Position>? _posSub;

  // Fraction of the screen the point list occupies when expanded.
  static const double _listFraction = 0.34;
  double get _listHeight =>
      _listExpanded ? MediaQuery.of(context).size.height * _listFraction : 96.0;

  // Shift a camera target south so the pin sits centered in the VISIBLE map area
  // (the part not covered by the bottom list), instead of behind the list.
  LatLng _biasTarget(LatLng t, double zoom) {
    if (!_listExpanded) return t;
    final coveredPx = MediaQuery.of(context).size.height * _listFraction;
    // MapLibre uses 512px tiles, so meters/logical-pixel = 156543.03*cos(lat)/2^(zoom+1).
    final metersPerPx = 156543.03392 * math.cos(t.latitude * math.pi / 180) / math.pow(2, zoom + 1);
    final offsetDeg = (metersPerPx * (coveredPx / 2)) / 111320.0;
    return LatLng(t.latitude - offsetDeg, t.longitude);
  }

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskLocation());
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pts = await ref.read(apiClientProvider).collectionPoints();
      setState(() { _points = pts; _loading = false; });
      _addSymbols();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // First-time entry: a prominent dialog asking to approve location.
  Future<void> _maybeAskLocation() async {
    final perm = await Geolocator.checkPermission();
    final on = await Geolocator.isLocationServiceEnabled();
    if ((perm == LocationPermission.always || perm == LocationPermission.whileInUse) && on) {
      _initLocation();
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 76, height: 76, decoration: const BoxDecoration(color: Color(0xFFEAF6EF), shape: BoxShape.circle), child: mi('my_location', size: 38, color: C.green)),
            const SizedBox(height: 16),
            Text('تفعيل الموقع', style: cairo(19, w: FontWeight.w800, color: C.forest)),
            const SizedBox(height: 8),
            Text('نحتاج إذن الوصول إلى موقعك لعرض أقرب نقاط الجمع إليك وحساب المسافات. الرجاء الموافقة للمتابعة.',
                textAlign: TextAlign.center, style: noto(13.5, color: C.textSecondary, height: 1.6)),
          ]),
          actions: [
            SizedBox(width: double.infinity, child: GestureDetector(
              onTap: () { Navigator.pop(dctx); _initLocation(); },
              child: Container(height: 52, alignment: Alignment.center,
                decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(15)),
                child: Text('السماح بالوصول إلى الموقع', style: cairo(15, w: FontWeight.w800, color: Colors.white))),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _initLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever || !serviceOn) {
      setState(() { _locationGranted = false; _locationDenied = true; });
      return;
    }
    setState(() { _locationGranted = true; _locationDenied = false; });
    try {
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 6));
      _onNewPosition(pos);
      _recenterOnUser();
    } catch (_) {}
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen(_onNewPosition);
  }

  void _onNewPosition(Position pos) {
    _lastUser = LatLng(pos.latitude, pos.longitude);
    for (final p in _points) {
      p.distanceM = Geolocator.distanceBetween(pos.latitude, pos.longitude, p.lat, p.lng);
    }
    _points.sort((a, b) => (a.distanceM ?? 1e12).compareTo(b.distanceM ?? 1e12));
    if (mounted) setState(() {});
  }

  void _recenterOnUser() {
    if (_map != null && _lastUser != null) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(_biasTarget(_lastUser!, 14), 14));
    }
  }

  // Approximate centers so we can jump to the user's registered wilaya before GPS resolves.
  static const Map<String, LatLng> _wilayaCenters = {
    'الجزائر': LatLng(36.7538, 3.0588),
    'وهران': LatLng(35.6971, -0.6308),
    'مستغانم': LatLng(35.9315, 0.0892),
    'قسنطينة': LatLng(36.3650, 6.6147),
    'عنابة': LatLng(36.9000, 7.7667),
    'سطيف': LatLng(36.1900, 5.4100),
    'تلمسان': LatLng(34.8828, -1.3167),
    'البليدة': LatLng(36.4703, 2.8277),
    'باتنة': LatLng(35.5559, 6.1741),
    'بجاية': LatLng(36.7509, 5.0567),
  };

  void _centerOnWilaya() {
    if (_map == null || _lastUser != null) return;
    final w = ref.read(sessionProvider).user?.wilaya;
    final c = _wilayaCenters[w];
    if (c != null) _map!.animateCamera(CameraUpdate.newLatLngZoom(_biasTarget(c, 11), 11));
  }

  // Tapped "أظهر مكاني": ensure we have a location, then jump to it.
  Future<void> _showMyLocation() async {
    if (_lastUser != null) { _recenterOnUser(); return; }
    if (!_locationGranted) {
      await _initLocation();
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 6));
        _onNewPosition(pos);
      } catch (_) {}
    }
    _recenterOnUser();
  }

  Future<void> _openDirections(CollectionPoint p) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showToast(context, 'تعذّر فتح خرائط Google');
    }
  }

  Future<void> _enableLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    _initLocation();
  }

  void _onMapCreated(MapLibreMapController c) {
    _map = c;
    c.onSymbolTapped.add(_onSymbolTapped);
    _recenterOnUser(); // if we already have the user's location, jump straight to it
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    try { await _map!.addImage('wiinz-pin', await _markerBytes()); } catch (_) {}
    await _addSymbols();
    // center on the user's GPS if we have it, else on their registered wilaya
    if (_lastUser != null) { _recenterOnUser(); } else { _centerOnWilaya(); }
  }

  // Native map symbols keep the pins locked to their exact coordinates while panning/zooming.
  Future<void> _addSymbols() async {
    if (_map == null || !_styleReady || _points.isEmpty || _symbolsAdded) return;
    _symbolsAdded = true;
    final opts = _points.map((p) => SymbolOptions(
      geometry: LatLng(p.lat, p.lng),
      iconImage: 'wiinz-pin',
      iconSize: 0.6,
      iconAnchor: 'bottom',
    )).toList();
    try {
      final syms = await _map!.addSymbols(opts);
      for (var i = 0; i < syms.length && i < _points.length; i++) {
        _symbolPoints[syms[i].id] = _points[i];
      }
    } catch (_) { _symbolsAdded = false; }
  }

  void _onSymbolTapped(Symbol s) {
    final p = _symbolPoints[s.id];
    if (p != null) _showPinSheet(p);
  }

  // Draw a green map-pin with a white disc and the recycle glyph, as a PNG for MapLibre.
  Future<Uint8List> _markerBytes() async {
    const size = 130;
    const green = Color(0xFF34801f);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cx = size / 2.0;
    final r = size * 0.34;
    final cy = r + 6;
    final paint = Paint()..color = green..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    final tail = Path()
      ..moveTo(cx - r * 0.55, cy + r * 0.55)
      ..lineTo(cx, size - 4.0)
      ..lineTo(cx + r * 0.55, cy + r * 0.55)
      ..close();
    canvas.drawPath(tail, paint);
    canvas.drawCircle(Offset(cx, cy), r * 0.64, Paint()..color = Colors.white..isAntiAlias = true);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    const icon = Symbols.recycling;
    tp.text = TextSpan(text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: r * 0.9, fontFamily: icon.fontFamily, package: icon.fontPackage, color: green));
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    final img = await recorder.endRecording().toImage(size, size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PlainHeader('الخريطة'),
            Expanded(
              child: Stack(
                children: [
                  MapLibreMap(
                    styleString: _styleUrl,
                    initialCameraPosition: const CameraPosition(target: _algiers, zoom: 12.5),
                    myLocationEnabled: _locationGranted,
                    myLocationTrackingMode: MyLocationTrackingMode.none,
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    compassEnabled: false,
                  ),
                  // floating header pill
                  Positioned(top: 12, right: 16, left: 16, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('نقاط الجمع القريبة', style: cairo(16, w: FontWeight.w800, color: C.forest)),
                      Row(children: [mi('my_location', size: 16, color: C.green), const SizedBox(width: 5), Text('${_points.length} نقاط', style: cairo(12, w: FontWeight.w700, color: C.green))]),
                    ]),
                  )),
                  // location-denied banner
                  if (_locationDenied) Positioned(top: 66, right: 16, left: 16, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF6E6), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF0D9A8))),
                    child: Row(children: [
                      mi('location_on', size: 20, color: C.gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text('فعّل الموقع لعرض أقرب نقاط الجمع وحساب المسافات', style: noto(11.5, color: const Color(0xFF8A6A1E)))),
                      const SizedBox(width: 6),
                      GestureDetector(onTap: _enableLocation, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(10)),
                        child: Text('تفعيل', style: cairo(12, w: FontWeight.w700, color: Colors.white)))),
                    ]),
                  )),
                  // "show my location" control — always visible, sits just above the list
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    right: 16,
                    bottom: _listHeight + 14,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Pressable(
                        onTap: _showMyLocation,
                        child: Container(
                          height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(gradient: C.greenButton, borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: const Color(0xFF3D7C32).withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))]),
                          child: Row(children: [
                            mi('my_location', size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('أظهر مكاني', style: cairo(14.5, w: FontWeight.w800, color: Colors.white)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  // bottom list sheet
                  Align(alignment: Alignment.bottomCenter, child: _bottomList()),
                ],
              ),
            ),
            const WiinzBottomNav(current: 'map'),
          ],
        ),
      ),
    );
  }

  Widget _bottomList() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: _listHeight,
      decoration: BoxDecoration(color: C.sand, borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, -12))]),
      child: Column(children: [
        // Tap the handle/header to collapse the list (more map) or expand it back.
        Pressable(
          haptic: false,
          onTap: () => setState(() => _listExpanded = !_listExpanded),
          child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Column(children: [
            Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Text('أقرب نقاط الجمع', style: cairo(16, w: FontWeight.w800, color: C.forest)),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(9)),
                  child: Text('${_points.length}', style: cairo(11.5, w: FontWeight.w800, color: C.greenBtnEnd))),
              ]),
              Row(children: [
                mi('sort', size: 16, color: C.green), const SizedBox(width: 4),
                Text(_locationGranted ? 'الأقرب أولاً' : 'كل النقاط', style: noto(12, color: C.textSecondary)),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _listExpanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: mi('expand_more', size: 22, color: C.forest),
                ),
              ]),
            ]),
          ])),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                itemCount: _points.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _pointCard(_points[i]),
              )),
      ]),
    );
  }

  Widget _pointCard(CollectionPoint p) {
    return Pressable(
      pressedScale: 0.98,
      onTap: () => _showPinSheet(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.cardBorder),
          boxShadow: [BoxShadow(color: const Color(0xFF785A14).withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Row(children: [
          p.logo.isNotEmpty
            ? storeLogo(p.logo, 52, fallbackIcon: 'recycling')
            : Container(width: 52, height: 52, decoration: BoxDecoration(gradient: C.avatarGrad, borderRadius: BorderRadius.circular(15)), child: mi('recycling', size: 26, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: cairo(15, w: FontWeight.w700, color: C.ink), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [mi('location_on', size: 14, color: C.textTertiary), const SizedBox(width: 4), Expanded(child: Text(p.address, style: noto(12, color: C.textSecondary), overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 4),
            Row(children: [
              mi('star', size: 14, color: C.gold, fill: true), const SizedBox(width: 2),
              Text('${p.rating}', style: cairo(12, w: FontWeight.w700, color: C.goldText)),
              const SizedBox(width: 10),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: p.open ? C.greenBtnEnd : C.danger, shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Text(p.open ? 'مفتوح' : 'مغلق', style: cairo(11.5, w: FontWeight.w700, color: p.open ? C.greenBtnEnd : C.danger)),
              const SizedBox(width: 8),
              Text(p.hours, style: noto(11.5, color: C.textTertiary)),
            ]),
          ])),
          const SizedBox(width: 8),
          Column(children: [
            if (p.distanceLabel.isNotEmpty)
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(11)),
                child: Text(p.distanceLabel, style: cairo(13, w: FontWeight.w800, color: C.greenBtnEnd))),
            const SizedBox(height: 6),
            Transform.flip(flipX: true, child: mi('chevron_right', size: 20, color: const Color(0xFFC7BCA8))),
          ]),
        ]),
      ),
    );
  }

  void _showPinSheet(CollectionPoint p) {
    final navInset = MediaQuery.of(context).padding.bottom;
    showModalBottomSheet(
      context: context, backgroundColor: C.sand, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(child: Padding(
        padding: EdgeInsets.fromLTRB(22, 20, 22, 30 + navInset),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: const Color(0xFFE0D5BF), borderRadius: BorderRadius.circular(3)))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            p.logo.isNotEmpty
              ? storeLogo(p.logo, 56, fallbackIcon: 'recycling')
              : Container(width: 56, height: 56, decoration: BoxDecoration(gradient: C.avatarGrad, borderRadius: BorderRadius.circular(16)), child: mi('recycling', size: 28, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: cairo(18, w: FontWeight.w800, color: C.forest)),
              Text(p.area, style: noto(13, color: C.textSecondary)),
            ])),
            if (p.distanceLabel.isNotEmpty)
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [Text(p.distanceLabel, style: cairo(15, w: FontWeight.w800, color: C.greenBtnEnd)), Text('من موقعك', style: noto(10, color: const Color(0xFF6B7F73)))])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _infoBox('schedule', 'ساعات العمل', p.hours)),
            const SizedBox(width: 10),
            Expanded(child: _infoBox('recycling', 'يقبل', p.accepts)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.cardBorder)),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: C.tint1, borderRadius: BorderRadius.circular(10)), child: mi('call', size: 20, color: C.green)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('رقم الهاتف', style: noto(11, color: C.textSecondary)),
                Text(p.phone, style: cairo(15, w: FontWeight.w700, color: C.ink), textDirection: TextDirection.ltr),
              ])),
              Text('اتصل', style: cairo(12, w: FontWeight.w700, color: C.green)),
            ]),
          ),
          const SizedBox(height: 16),
          // open Google Maps turn-by-turn directions to this point — big, branded button
          GestureDetector(
            onTap: () => _openDirections(p),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE3EA), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))]),
              child: Row(children: [
                // Google-colored map-pin badge
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(12)),
                  child: mi('location_on', size: 24, color: const Color(0xFFEA4335)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: const [
                    TextSpan(text: 'الاتجاهات عبر ', style: TextStyle()),
                    TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                    TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                    TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                    TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                    TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                    TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
                    TextSpan(text: ' Maps', style: TextStyle(color: Color(0xFF5F6368))),
                  ], style: cairo(15.5, w: FontWeight.w800)), textDirection: TextDirection.rtl),
                  Text('افتح الملاحة خطوة بخطوة', style: noto(11, color: C.textTertiary)),
                ])),
                Transform.flip(flipX: true, child: mi('chevron_right', size: 22, color: const Color(0xFF1A73E8))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(label: 'امسح هنا واكسب النقاط', icon: 'qr_code_scanner', height: 56, onTap: () { Navigator.pop(context); context.go('/scan'); }),
          const SizedBox(height: 6),
        ]),
      )))),
    );
  }

  Widget _infoBox(String icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.cardBorder)),
    child: Row(children: [
      mi(icon, size: 20, color: C.green),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: noto(11, color: C.textSecondary)),
        Text(value, style: cairo(13, w: FontWeight.w700, color: C.ink), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}
