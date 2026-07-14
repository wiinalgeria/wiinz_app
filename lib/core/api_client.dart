import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  // True when the failure is a connectivity/timeout problem (not a server 4xx/5xx
  // with a real body). Callers use this to avoid destructive actions like logout.
  final bool network;
  ApiException(this.message, {this.code, this.network = false});
  @override
  String toString() => message;
}

class ApiClient {
  // Backend base URL.
  // - Real phone on the same Wi-Fi as the dev PC: use the PC's LAN IP.
  // - Android emulator only: use http://10.0.2.2:4000/api instead.
  static const baseUrl = 'https://wiinz-server.onrender.com/api';

  // Every request is bounded by this. The Render free tier sleeps after ~15 min
  // idle and can take up to ~40s to wake, so this must be generous enough to
  // survive a cold start, but finite so the UI can never hang forever.
  static const Duration _timeout = Duration(seconds: 35);

  String? token;

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String p) => Uri.parse('$baseUrl$p');

  // Fire-and-forget wake-up ping. Call it as early as possible (splash) so the
  // sleeping Render instance starts booting while the user reads the splash,
  // making the first real request feel fast.
  void warmUp() {
    final health = Uri.parse(baseUrl).replace(path: '/health');
    http.get(health).timeout(_timeout).then((_) {}, onError: (_) {});
  }

  Future<Map<String, dynamic>> _handle(http.Response r) async {
    final body = r.body.isNotEmpty ? jsonDecode(r.body) as Map<String, dynamic> : <String, dynamic>{};
    if (r.statusCode >= 400) {
      throw ApiException(body['message'] ?? body['error'] ?? 'حدث خطأ، حاول مجدداً',
          code: body['error'] is String ? body['error'] as String : null);
    }
    return body;
  }

  // Central request runner: applies the timeout and converts every kind of
  // connectivity failure into a friendly, non-hanging ApiException.
  Future<Map<String, dynamic>> _send(Future<http.Response> Function() run) async {
    http.Response r;
    try {
      r = await run().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('تعذّر الاتصال بالخادم، قد يكون بطيئاً الآن. حاول مجدداً بعد لحظات.',
          code: 'timeout', network: true);
    } on SocketException {
      throw ApiException('لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مجدداً.',
          code: 'offline', network: true);
    } on http.ClientException {
      throw ApiException('تعذّر الاتصال بالخادم. حاول مجدداً.', code: 'network', network: true);
    } on HandshakeException {
      throw ApiException('تعذّر الاتصال الآمن بالخادم. حاول مجدداً.', code: 'tls', network: true);
    }
    return _handle(r);
  }

  Future<Map<String, dynamic>> _get(String p) => _send(() => http.get(_u(p), headers: _h));
  Future<Map<String, dynamic>> _post(String p, [Object? body]) =>
      _send(() => http.post(_u(p), headers: _h, body: body == null ? null : jsonEncode(body)));
  Future<Map<String, dynamic>> _put(String p, [Object? body]) =>
      _send(() => http.put(_u(p), headers: _h, body: body == null ? null : jsonEncode(body)));

  // auth
  Future<Map<String, dynamic>> signup(Map<String, dynamic> data) => _post('/auth/signup', data);
  Future<Map<String, dynamic>> login(String identifier, String password) =>
      _post('/auth/login', {'identifier': identifier, 'password': password});
  Future<void> changePassword(String currentPassword, String newPassword) async =>
      _post('/auth/change-password', {'currentPassword': currentPassword, 'newPassword': newPassword});
  Future<void> requestPasswordReset(String contact) async => _post('/auth/reset-request', {'contact': contact});
  Future<Map<String, dynamic>> me() => _get('/me');

  // push device tokens (best-effort: never surface an error to the user)
  Future<void> registerPushToken(String token) async {
    try { await _post('/push/register', {'token': token}); } catch (_) {}
  }
  Future<void> unregisterPushToken(String token) async {
    try { await _post('/push/unregister', {'token': token}); } catch (_) {}
  }
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> patch) => _put('/me', patch);

  // catalog
  Future<List<CollectionPoint>> collectionPoints() async {
    final b = await _get('/collection-points');
    return (b['collectionPoints'] as List).map((e) => CollectionPoint.fromJson(e)).toList();
  }

  Future<List<Coupon>> coupons() async {
    final b = await _get('/coupons');
    return (b['coupons'] as List).map((e) => Coupon.fromJson(e)).toList();
  }

  Future<(List<Gift>, HeroGift?)> gifts() async {
    final b = await _get('/gifts');
    final gifts = (b['gifts'] as List).map((e) => Gift.fromJson(e)).toList();
    final hero = b['heroGift'] != null ? HeroGift.fromJson(b['heroGift']) : null;
    return (gifts, hero);
  }

  Future<(List<String>, Map<String, List<String>>)> locations() async {
    final b = await _get('/locations');
    final wilayas = (b['wilayas'] as List).map((e) => '$e').toList();
    final raw = (b['communesByWilaya'] as Map?) ?? {};
    final map = <String, List<String>>{};
    raw.forEach((k, v) => map['$k'] = (v as List).map((e) => '$e').toList());
    return (wilayas, map);
  }

  Future<void> submitSupport(String subject, String details) async =>
      _post('/support', {'subject': subject, 'details': details});

  Future<Map<String, dynamic>> validateScan(String code) => _post('/scan/validate', {'code': code});

  Future<Map<String, dynamic>> refundGift(String redemptionId) => _post('/my-gifts/$redemptionId/refund');

  Future<AppConfig> config() async {
    try {
      final b = await _get('/config');
      return AppConfig.fromJson(b['config']);
    } catch (_) {
      return AppConfig.fallback();
    }
  }

  // All active home ads (rendered as a stacked list). Empty on any failure.
  Future<List<AdBanner>> homeAds() async {
    try {
      final b = await _get('/ads?placement=home');
      return (b['ads'] as List).map((e) => AdBanner.fromJson(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> ratePoint(String code, int rating) async {
    try { await _post('/points/rate', {'code': code, 'rating': rating}); } catch (_) {}
  }

  Future<Promo?> getPromo() async {
    try {
      final b = await _get('/promo');
      if (b['promo'] == null) return null;
      final promo = Promo.fromJson(b['promo']);
      return promo.slides.isEmpty ? null : promo;
    } catch (_) {
      return null;
    }
  }
  // [slide] is the slide's index in the admin's list, so clicks are attributed per slide.
  Future<void> promoClick({int? slide}) async {
    try { await _post('/promo/click', {'slide': slide}); } catch (_) {}
  }

  Future<List<AppNotification>> notifications() async {
    final b = await _get('/notifications');
    return (b['notifications'] as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  // earn / spend
  Future<Map<String, dynamic>> scan(String code, {int bottles = 0}) => _post('/scan', {'code': code, 'bottles': bottles});
  Future<Map<String, dynamic>> watchVideo() => _post('/watch-video');
  Future<Map<String, dynamic>> redeemCoupon(String id) => _post('/coupons/$id/redeem');
  Future<Map<String, dynamic>> claimGift(String id) => _post('/gifts/$id/claim');

  Future<List<MyGift>> myGifts() async {
    final b = await _get('/my-gifts');
    return (b['myGifts'] as List).map((e) => MyGift.fromJson(e)).toList();
  }

  // stats / social
  Future<List<HistoryItem>> history() async {
    final b = await _get('/history');
    return (b['history'] as List).map((e) => HistoryItem.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> stats() => _get('/stats');

  Future<Map<String, dynamic>> leaderboard() => _get('/leaderboard');

  Future<List<Referral>> referrals() async {
    final b = await _get('/referrals');
    return (b['referrals'] as List).map((e) => Referral.fromJson(e)).toList();
  }
}
