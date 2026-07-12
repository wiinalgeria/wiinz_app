import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  ApiException(this.message, {this.code});
  @override
  String toString() => message;
}

class ApiClient {
  // Backend base URL.
  // - Real phone on the same Wi-Fi as the dev PC: use the PC's LAN IP.
  // - Android emulator only: use http://10.0.2.2:4000/api instead.
  static const baseUrl = 'https://wiinz-server.onrender.com/api';

  String? token;

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _handle(http.Response r) async {
    final body = r.body.isNotEmpty ? jsonDecode(r.body) as Map<String, dynamic> : <String, dynamic>{};
    if (r.statusCode >= 400) {
      throw ApiException(body['message'] ?? body['error'] ?? 'حدث خطأ، حاول مجدداً',
          code: body['error'] is String ? body['error'] as String : null);
    }
    return body;
  }

  Uri _u(String p) => Uri.parse('$baseUrl$p');

  // auth
  Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async =>
      _handle(await http.post(_u('/auth/signup'), headers: _h, body: jsonEncode(data)));
  Future<Map<String, dynamic>> login(String identifier, String password) async =>
      _handle(await http.post(_u('/auth/login'), headers: _h, body: jsonEncode({'identifier': identifier, 'password': password})));
  Future<void> changePassword(String currentPassword, String newPassword) async =>
      _handle(await http.post(_u('/auth/change-password'), headers: _h,
          body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword})));
  Future<void> requestPasswordReset(String contact) async =>
      _handle(await http.post(_u('/auth/reset-request'), headers: _h, body: jsonEncode({'contact': contact})));
  Future<Map<String, dynamic>> me() async => _handle(await http.get(_u('/me'), headers: _h));
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> patch) async =>
      _handle(await http.put(_u('/me'), headers: _h, body: jsonEncode(patch)));

  // catalog
  Future<List<CollectionPoint>> collectionPoints() async {
    final b = await _handle(await http.get(_u('/collection-points'), headers: _h));
    return (b['collectionPoints'] as List).map((e) => CollectionPoint.fromJson(e)).toList();
  }

  Future<List<Coupon>> coupons() async {
    final b = await _handle(await http.get(_u('/coupons'), headers: _h));
    return (b['coupons'] as List).map((e) => Coupon.fromJson(e)).toList();
  }

  Future<(List<Gift>, HeroGift?)> gifts() async {
    final b = await _handle(await http.get(_u('/gifts'), headers: _h));
    final gifts = (b['gifts'] as List).map((e) => Gift.fromJson(e)).toList();
    final hero = b['heroGift'] != null ? HeroGift.fromJson(b['heroGift']) : null;
    return (gifts, hero);
  }

  Future<(List<String>, Map<String, List<String>>)> locations() async {
    final b = await _handle(await http.get(_u('/locations'), headers: _h));
    final wilayas = (b['wilayas'] as List).map((e) => '$e').toList();
    final raw = (b['communesByWilaya'] as Map?) ?? {};
    final map = <String, List<String>>{};
    raw.forEach((k, v) => map['$k'] = (v as List).map((e) => '$e').toList());
    return (wilayas, map);
  }

  Future<void> submitSupport(String subject, String details) async =>
      _handle(await http.post(_u('/support'), headers: _h, body: jsonEncode({'subject': subject, 'details': details})));

  Future<Map<String, dynamic>> validateScan(String code) async =>
      _handle(await http.post(_u('/scan/validate'), headers: _h, body: jsonEncode({'code': code})));

  Future<Map<String, dynamic>> refundGift(String redemptionId) async =>
      _handle(await http.post(_u('/my-gifts/$redemptionId/refund'), headers: _h));

  Future<AppConfig> config() async {
    try {
      final b = await _handle(await http.get(_u('/config'), headers: _h));
      return AppConfig.fromJson(b['config']);
    } catch (_) {
      return AppConfig.fallback();
    }
  }

  Future<AdBanner?> homeAd() async {
    try {
      final b = await _handle(await http.get(_u('/ads?placement=home'), headers: _h));
      final ads = (b['ads'] as List);
      return ads.isNotEmpty ? AdBanner.fromJson(ads.first) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> ratePoint(String code, int rating) async {
    try { await _handle(await http.post(_u('/points/rate'), headers: _h, body: jsonEncode({'code': code, 'rating': rating}))); } catch (_) {}
  }

  Future<PromoAd?> getPromo() async {
    try {
      final b = await _handle(await http.get(_u('/promo'), headers: _h));
      return b['promo'] == null ? null : PromoAd.fromJson(b['promo']);
    } catch (_) {
      return null;
    }
  }
  Future<void> promoClick() async {
    try { await _handle(await http.post(_u('/promo/click'), headers: _h)); } catch (_) {}
  }

  Future<List<AppNotification>> notifications() async {
    final b = await _handle(await http.get(_u('/notifications'), headers: _h));
    return (b['notifications'] as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  // earn / spend
  Future<Map<String, dynamic>> scan(String code, {int bottles = 0}) async =>
      _handle(await http.post(_u('/scan'), headers: _h, body: jsonEncode({'code': code, 'bottles': bottles})));
  Future<Map<String, dynamic>> watchVideo() async => _handle(await http.post(_u('/watch-video'), headers: _h));
  Future<Map<String, dynamic>> redeemCoupon(String id) async => _handle(await http.post(_u('/coupons/$id/redeem'), headers: _h));
  Future<Map<String, dynamic>> claimGift(String id) async => _handle(await http.post(_u('/gifts/$id/claim'), headers: _h));

  Future<List<MyGift>> myGifts() async {
    final b = await _handle(await http.get(_u('/my-gifts'), headers: _h));
    return (b['myGifts'] as List).map((e) => MyGift.fromJson(e)).toList();
  }

  // stats / social
  Future<List<HistoryItem>> history() async {
    final b = await _handle(await http.get(_u('/history'), headers: _h));
    return (b['history'] as List).map((e) => HistoryItem.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> stats() async => _handle(await http.get(_u('/stats'), headers: _h));

  Future<Map<String, dynamic>> leaderboard() async => _handle(await http.get(_u('/leaderboard'), headers: _h));

  Future<List<Referral>> referrals() async {
    final b = await _handle(await http.get(_u('/referrals'), headers: _h));
    return (b['referrals'] as List).map((e) => Referral.fromJson(e)).toList();
  }
}
