import 'i18n.dart';

/// Latin names for Algerian places (wilayas + the seeded communes).
///
/// Wilaya/commune values are stored in Arabic everywhere — that Arabic string
/// is the KEY the backend filters on (points, gifts, leaderboards, admin
/// scoping). So we never translate the stored value; we only translate what's
/// DISPLAYED. [placeName] returns the Latin form in FR/EN and the original
/// Arabic in AR, falling back to Arabic for anything not listed (e.g. a commune
/// the admin added later) so a name is never blank.
const _latin = <String, String>{
  // ---- the 58 wilayas ----
  'أدرار': 'Adrar', 'الشلف': 'Chlef', 'الأغواط': 'Laghouat', 'أم البواقي': 'Oum El Bouaghi',
  'باتنة': 'Batna', 'بجاية': 'Béjaïa', 'بسكرة': 'Biskra', 'بشار': 'Béchar',
  'البليدة': 'Blida', 'البويرة': 'Bouira', 'تمنراست': 'Tamanrasset', 'تبسة': 'Tébessa',
  'تلمسان': 'Tlemcen', 'تيارت': 'Tiaret', 'تيزي وزو': 'Tizi Ouzou', 'الجزائر': 'Alger',
  'الجلفة': 'Djelfa', 'جيجل': 'Jijel', 'سطيف': 'Sétif', 'سعيدة': 'Saïda',
  'سكيكدة': 'Skikda', 'سيدي بلعباس': 'Sidi Bel Abbès', 'عنابة': 'Annaba', 'قالمة': 'Guelma',
  'قسنطينة': 'Constantine', 'المدية': 'Médéa', 'مستغانم': 'Mostaganem', 'المسيلة': "M'Sila",
  'معسكر': 'Mascara', 'ورقلة': 'Ouargla', 'وهران': 'Oran', 'البيض': 'El Bayadh',
  'إليزي': 'Illizi', 'برج بوعريريج': 'Bordj Bou Arréridj', 'بومرداس': 'Boumerdès', 'الطارف': 'El Tarf',
  'تندوف': 'Tindouf', 'تيسمسيلت': 'Tissemsilt', 'الوادي': 'El Oued', 'خنشلة': 'Khenchela',
  'سوق أهراس': 'Souk Ahras', 'تيبازة': 'Tipaza', 'ميلة': 'Mila', 'عين الدفلى': 'Aïn Defla',
  'النعامة': 'Naâma', 'عين تموشنت': 'Aïn Témouchent', 'غرداية': 'Ghardaïa', 'غليزان': 'Relizane',
  'تيميمون': 'Timimoun', 'برج باجي مختار': 'Bordj Badji Mokhtar', 'أولاد جلال': 'Ouled Djellal',
  'بني عباس': 'Béni Abbès', 'عين صالح': 'In Salah', 'عين قزام': 'In Guezzam',
  'تقرت': 'Touggourt', 'جانت': 'Djanet', 'المغير': "El M'Ghair", 'المنيعة': 'El Menia',

  // ---- communes shipped in the seed data ----
  'بلكور': 'Belcourt', 'باب الوادي': 'Bab El Oued', 'حسين داي': 'Hussein Dey',
  'بئر مراد رايس': 'Bir Mourad Raïs', 'الأبيار': 'El Biar', 'حيدرة': 'Hydra', 'بولوغين': 'Bologhine',
  'وهران المدينة': 'Oran Centre', 'بئر الجير': 'Bir El Djir', 'السانية': 'Es Sénia', 'عين الترك': 'Aïn El Turk',
  'قسنطينة المدينة': 'Constantine Centre', 'الخروب': 'El Khroub', 'عين السمارة': 'Aïn Smara',
  'عنابة المدينة': 'Annaba Centre', 'سيدي عمار': 'Sidi Amar', 'البوني': 'El Bouni',
  'البليدة المدينة': 'Blida Centre', 'بوفاريك': 'Boufarik', 'الأربعاء': 'Larbaâ',
};

/// Display form of a wilaya/commune for the current language.
/// NEVER use this for a value sent to the server — send the Arabic key.
String placeName(String arabic) {
  if (currentLang == 'ar') return arabic;
  return _latin[arabic] ?? arabic;
}
