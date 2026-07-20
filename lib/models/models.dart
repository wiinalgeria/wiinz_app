import '../core/i18n.dart' show timeAgo;

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
double _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

class WiinzUser {
  final String id, name, email, phone, wilaya, commune, address, gender, tier, qrCode, inviteCode, cardCode, avatar;
  final int points;
  final int videosLeft;
  final bool tempPassword;
  /// Collect-point holder ("star" member): runs a collection point, so they
  /// carry a SECOND QR (the point's) and can credit other users' deposits.
  final bool isHolder;
  final HolderPoint? holderPoint;

  WiinzUser({
    required this.id, required this.name, required this.email, required this.phone,
    required this.wilaya, required this.commune, required this.address, required this.gender,
    required this.tier, required this.qrCode, required this.inviteCode, required this.cardCode,
    required this.points, required this.videosLeft, this.tempPassword = false, this.avatar = '',
    this.isHolder = false, this.holderPoint,
  });

  factory WiinzUser.fromJson(Map<String, dynamic> j) => WiinzUser(
        id: j['id'] ?? '', name: j['name'] ?? '', email: j['email'] ?? '', phone: j['phone'] ?? '',
        wilaya: j['wilaya'] ?? '', commune: j['commune'] ?? '', address: j['address'] ?? '',
        gender: j['gender'] ?? 'male', tier: j['tier'] ?? 'أخضر',
        qrCode: j['qrCode'] ?? j['cardCode'] ?? '', inviteCode: j['inviteCode'] ?? '', cardCode: j['cardCode'] ?? '',
        points: _int(j['points']), videosLeft: _int(j['videosLeft']), tempPassword: j['tempPassword'] == true,
        avatar: j['avatar'] ?? '',
        isHolder: j['isHolder'] == true,
        holderPoint: j['holderPoint'] == null ? null : HolderPoint.fromJson(j['holderPoint']),
      );

  WiinzUser copyWith({int? points, int? videosLeft, String? name, String? phone, String? address, String? commune, String? wilaya, String? tier, bool? tempPassword, String? avatar}) => WiinzUser(
        id: id, name: name ?? this.name, email: email, phone: phone ?? this.phone,
        wilaya: wilaya ?? this.wilaya, commune: commune ?? this.commune, address: address ?? this.address,
        gender: gender, tier: tier ?? this.tier, qrCode: qrCode, inviteCode: inviteCode, cardCode: cardCode,
        points: points ?? this.points, videosLeft: videosLeft ?? this.videosLeft, tempPassword: tempPassword ?? this.tempPassword,
        avatar: avatar ?? this.avatar, isHolder: isHolder, holderPoint: holderPoint,
      );
}

/// The collection point a holder runs (their second QR code).
class HolderPoint {
  final String id, code, name, wilaya, address, hours;
  HolderPoint({required this.id, required this.code, required this.name, this.wilaya = '', this.address = '', this.hours = ''});
  factory HolderPoint.fromJson(Map<String, dynamic> j) => HolderPoint(
        id: j['id'] ?? '', code: j['code'] ?? '', name: j['name'] ?? '',
        wilaya: j['wilaya'] ?? '', address: j['address'] ?? '', hours: j['hours'] ?? '',
      );
}

class MyGift {
  final String id, code, title, icon, iconBg, iconColor;
  final int cost;
  final Store store;
  MyGift({required this.id, required this.code, required this.title, required this.icon, required this.iconBg, required this.iconColor, required this.cost, required this.store});
  factory MyGift.fromJson(Map<String, dynamic> j) => MyGift(
        id: j['id'] ?? '', code: j['code'] ?? '', title: j['title'] ?? '', icon: j['icon'] ?? 'redeem',
        iconBg: j['iconBg'] ?? '#EAF6EF', iconColor: j['iconColor'] ?? '#34801f', cost: _int(j['cost']),
        store: Store.from(j));
}

class CollectionPoint {
  final String id, name, area, address, phone, hours, accepts, code, logo, details;
  final double rating, lat, lng;
  final bool open;
  double? distanceM; // filled client-side when user location is known

  CollectionPoint({
    required this.id, required this.name, required this.area, required this.address,
    required this.phone, required this.hours, required this.accepts, required this.code,
    required this.rating, required this.lat, required this.lng, required this.open, this.distanceM, this.logo = '', this.details = '',
  });

  factory CollectionPoint.fromJson(Map<String, dynamic> j) => CollectionPoint(
        id: j['id'] ?? '', name: j['name'] ?? '', area: j['area'] ?? '', address: j['address'] ?? '',
        phone: j['phone'] ?? '', hours: j['hours'] ?? '', accepts: j['accepts'] ?? '', code: j['code'] ?? '',
        rating: _dbl(j['rating']), lat: _dbl(j['lat']), lng: _dbl(j['lng']), open: j['open'] == true,
        logo: j['logo'] ?? '', details: j['details'] ?? '',
      );

  bool get hasLocation => lat != 0 || lng != 0;
  String get directionsUrl => 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

  String get distanceLabel {
    if (distanceM == null) return '';
    if (distanceM! < 1000) return '${distanceM!.round()} م';
    return '${(distanceM! / 1000).toStringAsFixed(1)} كم';
  }
}

class Coupon {
  final String id, title, desc, icon;
  final int cost;
  Coupon({required this.id, required this.title, required this.desc, required this.icon, required this.cost});
  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: j['id'] ?? '', title: j['title'] ?? '', desc: j['desc'] ?? '', icon: j['icon'] ?? 'confirmation_number',
        cost: _int(j['cost']),
      );
}

class Store {
  final String name, address, phone, logo;
  final double lat, lng;
  const Store({this.name = '', this.address = '', this.phone = '', this.logo = '', this.lat = 0, this.lng = 0});
  factory Store.from(Map<String, dynamic> j) => Store(
        name: j['storeName'] ?? '', address: j['storeAddress'] ?? '', phone: j['storePhone'] ?? '',
        logo: j['logo'] ?? '', lat: _dbl(j['storeLat']), lng: _dbl(j['storeLng']),
      );
  bool get hasLocation => lat != 0 && lng != 0;
}

class Gift {
  final String id, cat, title, badge, left, priceLabel, icon, iconBg, iconColor;
  final int cost;
  final Store store;
  Gift({required this.id, required this.cat, required this.title, required this.badge, required this.left,
    required this.priceLabel, required this.icon, required this.iconBg, required this.iconColor, required this.cost, required this.store});
  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
        id: j['id'] ?? '', cat: j['cat'] ?? '', title: j['title'] ?? '', badge: j['badge'] ?? '',
        left: j['left'] ?? '', priceLabel: j['priceLabel'] ?? '', icon: j['icon'] ?? 'redeem',
        iconBg: j['iconBg'] ?? '#EAF6EF', iconColor: j['iconColor'] ?? '#34801f', cost: _int(j['cost']),
        store: Store.from(j),
      );
}

class HeroGift {
  final String id, title, desc, ends, left, cta, logo;
  final int cost;
  final Store store;
  HeroGift({required this.id, required this.title, required this.desc, required this.ends, required this.left, required this.cta, required this.cost, this.logo = '', this.store = const Store()});
  factory HeroGift.fromJson(Map<String, dynamic> j) => HeroGift(
        id: j['id'] ?? '', title: j['title'] ?? '', desc: j['desc'] ?? '', ends: j['ends'] ?? '',
        left: j['left'] ?? '', cta: j['cta'] ?? '', cost: _int(j['cost']),
        logo: j['logo'] ?? '', store: Store.from(j),
      );
}

class AppNotification {
  final String id, icon, bg, color, title, body, time;
  /// Real send time. Null on notifications that predate the server sending it —
  /// those fall back to the legacy [time] label.
  final DateTime? at;
  /// 'targeted' when the admin aimed this at a subset/one user, else 'all'.
  final String audience;
  /// Whether the admin chose to reveal [audience] to the user.
  final bool showAudience;
  final String ctaText, ctaUrl;
  /// In-app screen the button opens ('gifts', 'map', …). Takes precedence over
  /// [ctaUrl] so "new gift available" can jump straight to the Gifts tab.
  final String ctaScreen;

  AppNotification({
    required this.id, required this.icon, required this.bg, required this.color,
    required this.title, required this.body, required this.time,
    this.at, this.audience = 'all', this.showAudience = false,
    this.ctaText = '', this.ctaUrl = '', this.ctaScreen = '',
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? '', icon: j['icon'] ?? 'notifications', bg: j['bg'] ?? '#E6F4EC', color: j['color'] ?? '#34801f',
        title: j['title'] ?? '', body: j['body'] ?? '', time: j['time'] ?? '',
        at: j['at'] == null ? null : DateTime.tryParse('${j['at']}')?.toLocal(),
        audience: j['audience'] ?? 'all',
        showAudience: j['showAudience'] == true,
        ctaText: j['ctaText'] ?? '', ctaUrl: j['ctaUrl'] ?? '', ctaScreen: j['ctaScreen'] ?? '',
      );

  bool get targeted => audience == 'targeted';
  bool get hasCta => ctaText.trim().isNotEmpty && (ctaUrl.trim().isNotEmpty || ctaScreen.trim().isNotEmpty);
  /// Internal navigation wins over an external link when both are set.
  bool get opensScreen => ctaScreen.trim().isNotEmpty;

  /// Localized "when", from the real timestamp when we have one.
  String get whenLabel => at != null ? timeAgo(at!) : time;
}

class Referral {
  final String id, initial, name, when;
  final int reward;
  Referral({required this.id, required this.initial, required this.name, required this.when, required this.reward});
  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        id: j['id'] ?? '', initial: j['initial'] ?? '', name: j['name'] ?? '', when: j['when'] ?? '', reward: _int(j['reward']));
}

class HistoryItem {
  final String id, icon, title, when, amount;
  final bool positive;
  HistoryItem({required this.id, required this.icon, required this.title, required this.when, required this.amount, required this.positive});
  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] ?? '', icon: j['icon'] ?? 'toll', title: j['title'] ?? '', when: j['when'] ?? '',
        amount: j['amount'] ?? '', positive: j['positive'] == true);
}

class LeaderRow {
  final String id, initial, name, prize, avatar;
  final int score, rank;
  final bool isMe, isHolder;
  LeaderRow({required this.id, required this.initial, required this.name, required this.score, required this.rank, required this.isMe, this.prize = '', this.avatar = '', this.isHolder = false});
  factory LeaderRow.fromJson(Map<String, dynamic> j) => LeaderRow(
        id: '${j['id']}', initial: j['initial'] ?? '', name: j['name'] ?? '', score: _int(j['score']),
        rank: _int(j['rank']), isMe: j['isMe'] == true, prize: j['prize'] ?? '', avatar: j['avatar'] ?? '',
        isHolder: j['isHolder'] == true);
}

class AppConfig {
  final int pointsPerScan, silverGoal, goldGoal, referralReward, videoReward, videosPerDay;
  AppConfig({required this.pointsPerScan, required this.silverGoal, required this.goldGoal,
    required this.referralReward, required this.videoReward, required this.videosPerDay});
  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        pointsPerScan: _int(j['pointsPerScan']), silverGoal: _int(j['silverGoal']), goldGoal: _int(j['goldGoal']),
        referralReward: _int(j['referralReward']), videoReward: _int(j['videoReward']), videosPerDay: _int(j['videosPerDay']));
  static AppConfig fallback() => AppConfig(pointsPerScan: 15, silverGoal: 500, goldGoal: 2000, referralReward: 20, videoReward: 5, videosPerDay: 3);
}

class AdBanner {
  final String id, title, subtitle, image, ctaText, ctaUrl;
  AdBanner({required this.id, required this.title, required this.subtitle, this.image = '', this.ctaText = '', this.ctaUrl = ''});
  factory AdBanner.fromJson(Map<String, dynamic> j) => AdBanner(
        id: j['id'] ?? '', title: j['title'] ?? '', subtitle: j['subtitle'] ?? '', image: j['image'] ?? '',
        ctaText: j['ctaText'] ?? '', ctaUrl: j['ctaUrl'] ?? '');
}

// One slide of the full-screen promotional popup. The popup can hold several
// slides that auto-advance; [seconds] is how long this slide stays before the
// next one slides up.
class PromoSlide {
  final String title, subtitle, image, ctaText, ctaUrl;
  final int seconds;
  final int idx; // position in the admin's slide list — used to attribute clicks
  PromoSlide({this.title = '', this.subtitle = '', this.image = '', this.ctaText = '', this.ctaUrl = '', this.seconds = 5, this.idx = 0});
  factory PromoSlide.fromJson(Map<String, dynamic> j) => PromoSlide(
        title: j['title'] ?? '', subtitle: j['subtitle'] ?? '', image: j['image'] ?? '',
        ctaText: j['ctaText'] ?? '', ctaUrl: j['ctaUrl'] ?? '',
        seconds: _int(j['seconds']) < 2 ? 5 : _int(j['seconds']),
        idx: _int(j['idx']));
}

class Promo {
  final List<PromoSlide> slides;
  Promo({required this.slides});
  factory Promo.fromJson(Map<String, dynamic> j) =>
      Promo(slides: ((j['slides'] as List?) ?? const []).map((e) => PromoSlide.fromJson(e as Map<String, dynamic>)).toList());
}
