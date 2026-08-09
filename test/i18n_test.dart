import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiinz_app/core/i18n.dart';
import 'package:wiinz_app/core/place_names.dart';

/// Switch the app language the same way the real app does at startup.
Future<void> useLang(String lang) async {
  SharedPreferences.setMockInitialValues({'wiinz_lang': lang});
  await initLocale();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('trHistoryTitle', () {
    test('translates a prefix and keeps the point name verbatim', () async {
      await useLang('fr');
      expect(trHistoryTitle('مسح في نقطة الجمع'), 'Scan à نقطة الجمع');
      await useLang('en');
      expect(trHistoryTitle('مسح في نقطة الجمع'), 'Scan at نقطة الجمع');
    });

    test('translates the bottle-count suffix', () async {
      await useLang('en');
      expect(trHistoryTitle('مسح في Oran Centre (12 قارورة)'), 'Scan at Oran Centre (12 bottles)');
      await useLang('fr');
      expect(trHistoryTitle('مسح في Oran Centre (12 قارورة)'), 'Scan à Oran Centre (12 bouteilles)');
    });

    test('translates whole-string titles that carry no user data', () async {
      await useLang('fr');
      expect(trHistoryTitle('مكافأة دعوة صديق'), 'Récompense de parrainage');
      expect(trHistoryTitle('المكافأة اليومية'), 'Bonus quotidien');
      await useLang('en');
      expect(trHistoryTitle('تعديل إداري'), 'Admin adjustment');
    });

    test('handles the colon-style prefixes', () async {
      await useLang('en');
      expect(trHistoryTitle('هدية: Casque Bluetooth'), 'Gift: Casque Bluetooth');
      expect(trHistoryTitle('استرجاع نقاط: Casque'), 'Points refunded: Casque');
    });

    test('leaves Arabic untouched and never drops unknown text', () async {
      await useLang('ar');
      expect(trHistoryTitle('مسح في نقطة'), 'مسح في نقطة');
      await useLang('en');
      // An unrecognised title must survive rather than render empty.
      expect(trHistoryTitle('عنوان غير معروف'), 'عنوان غير معروف');
    });
  });

  group('trWhen', () {
    test('اليوم means Today here, NOT the birthdate label Day', () async {
      // 'اليوم' is also a shared-dictionary key meaning "Day"/"Jour" for the
      // birthdate field. trWhen must not pick that sense up.
      await useLang('en');
      expect(trWhen('اليوم'), 'Today');
      expect(trWhen('اليوم'), isNot('Day'));
      await useLang('fr');
      expect(trWhen('اليوم'), "Aujourd'hui");
      expect(trWhen('اليوم'), isNot('Jour'));
    });

    test('handles the other three server forms', () async {
      await useLang('en');
      expect(trWhen('أمس'), 'yesterday');
      expect(trWhen('قبل أسبوع'), 'A week ago');
      expect(trWhen('قبل 3 أيام'), '3 days ago');
      await useLang('fr');
      expect(trWhen('قبل 5 أيام'), 'il y a 5 jours');
    });

    test('passes Arabic through and tolerates an unknown format', () async {
      await useLang('ar');
      expect(trWhen('قبل 3 أيام'), 'قبل 3 أيام');
      await useLang('en');
      expect(trWhen('صيغة غريبة'), 'صيغة غريبة');
    });
  });

  group('month names', () {
    test('translate via tr() in both Latin locales', () async {
      await useLang('fr');
      expect(tr('جانفي'), 'Janvier');
      expect(tr('ديسمبر'), 'Décembre');
      await useLang('en');
      expect(tr('جانفي'), 'January');
      expect(tr('أوت'), 'August');
      await useLang('ar');
      expect(tr('جانفي'), 'جانفي');
    });
  });

  group('timeAgo labels', () {
    test('الآن and أمس are translated, not left in Arabic', () async {
      await useLang('fr');
      expect(tr('الآن'), "à l'instant");
      expect(tr('أمس'), 'hier');
      await useLang('en');
      expect(tr('الآن'), 'just now');
      expect(tr('أمس'), 'yesterday');
    });
  });

  group('placeName', () {
    test('transliterates wilayas and dashboard communes', () async {
      await useLang('fr');
      expect(placeName('وهران'), 'Oran');
      expect(placeName('مستغانم'), 'Mostaganem');
      expect(placeName('بئر الجير'), 'Bir El Djir');
      expect(placeName('قديل'), 'Gdyel');
      expect(placeName('عين تادلس'), 'Aïn Tédelès');
    });

    test('keeps Arabic in the Arabic UI and falls back safely', () async {
      await useLang('ar');
      expect(placeName('وهران'), 'وهران');
      await useLang('en');
      expect(placeName('بلدية غير معروفة'), 'بلدية غير معروفة');
    });
  });

  group('tier names', () {
    test('فضي and ذهبي translate for the next-tier label', () async {
      await useLang('fr');
      expect(tr('فضي'), 'Argent');
      expect(tr('ذهبي'), 'Or');
      await useLang('en');
      expect(tr('فضي'), 'Silver');
      expect(tr('ذهبي'), 'Gold');
      expect(tr('ذهبي+'), 'Gold+');
    });
  });
}
