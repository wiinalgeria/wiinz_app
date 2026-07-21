import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App languages. Arabic is the source language (RTL); French + English are LTR.
/// Translation tables are keyed by the Arabic source string, so wrapping a UI
/// literal is just `tr('...')` and Arabic needs no table entry.
const supportedLangs = ['ar', 'fr', 'en'];
const langNames = {'ar': 'العربية', 'fr': 'Français', 'en': 'English'};
const langFlags = {'ar': '🇩🇿', 'fr': '🇫🇷', 'en': '🇬🇧'};

String _lang = 'ar';
String get currentLang => _lang;
bool get isRtl => _lang == 'ar';
TextDirection get appDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;

const _prefsKey = 'wiinz_lang';

/// Load the saved language before runApp so there's no flash of the wrong one.
Future<void> initLocale() async {
  try {
    final p = await SharedPreferences.getInstance();
    final l = p.getString(_prefsKey);
    if (l != null && supportedLangs.contains(l)) _lang = l;
  } catch (_) {}
}

/// Translate an Arabic source string to the current language.
String tr(String ar) {
  if (_lang == 'ar') return ar;
  final m = _lang == 'fr' ? _fr : _en;
  return m[ar] ?? ar;
}

/// Translate a template with `{name}` placeholders, e.g.
/// `trf('باقٍ {n} Wz', {'n': '$left'})`.
String trf(String ar, Map<String, String> args) {
  var s = tr(ar);
  args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

/// Relative "when" label for a past timestamp, in the current language.
/// Clock skew (a timestamp slightly in the future) reads as "now" rather than
/// a negative age.
String timeAgo(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inSeconds < 45) return tr('الآن');
  if (d.inMinutes < 60) return trf('قبل {n} دقيقة', {'n': '${d.inMinutes}'});
  if (d.inHours < 24) return trf('قبل {n} ساعة', {'n': '${d.inHours}'});
  if (d.inDays == 1) return tr('أمس');
  if (d.inDays < 7) return trf('قبل {n} أيام', {'n': '${d.inDays}'});
  if (d.inDays < 30) return trf('قبل {n} أسابيع', {'n': '${d.inDays ~/ 7}'});
  if (d.inDays < 365) return trf('قبل {n} أشهر', {'n': '${d.inDays ~/ 30}'});
  return trf('قبل {n} سنة', {'n': '${d.inDays ~/ 365}'});
}

class LocaleNotifier extends Notifier<String> {
  @override
  String build() => _lang;

  Future<void> setLang(String l) async {
    if (!supportedLangs.contains(l) || l == _lang) return;
    _lang = l;
    state = l;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, l);
    } catch (_) {}
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

// ===========================================================================
// French
// ===========================================================================
final Map<String, String> _fr = {
  // auth / welcome
  'مرحباً بك في WIIN': 'Bienvenue sur WIIN',
  'اجمع القارورات وحافظ على بيئتك': 'Collectez les bouteilles et préservez votre environnement',
  'إنشاء حساب': 'Créer un compte',
  'تسجيل الدخول': 'Se connecter',
  'أنشئ حسابك': 'Créez votre compte',
  'ابدأ رحلتك في إعادة التدوير': 'Commencez votre parcours de recyclage',
  'مرحباً بعودتك': 'Bon retour',
  'سجّل الدخول لمتابعة كسب النقاط': 'Connectez-vous pour continuer à gagner des points',
  'الاسم الكامل': 'Nom complet',
  'اكتب اسمك': 'Écrivez votre nom',
  'رقم الهاتف': 'Numéro de téléphone',
  'الولاية': 'Wilaya',
  'البلدية': 'Commune',
  'تاريخ الميلاد': 'Date de naissance',
  'اليوم': 'Jour',
  'الشهر': 'Mois',
  'السنة': 'Année',
  'الجنس': 'Sexe',
  'ذكر': 'Homme',
  'أنثى': 'Femme',
  'رمز الدعوة (اختياري)': 'Code de parrainage (optionnel)',
  'البريد الإلكتروني (غير إلزامي)': 'E-mail (facultatif)',
  'البريد الإلكتروني أو رقم الهاتف': 'E-mail ou numéro de téléphone',
  'الإيمايل غير صالح': 'E-mail invalide',
  'البريد الإلكتروني غير صالح (مثال: test@domain.com)': 'E-mail invalide (ex : test@domain.com)',
  'كلمة المرور': 'Mot de passe',
  'تأكيد كلمة المرور': 'Confirmer le mot de passe',
  'إنشاء الحساب': 'Créer le compte',
  'نسيت كلمة المرور؟': 'Mot de passe oublié ?',
  'أو': 'ou',
  'ليس لديك حساب؟ ': 'Pas de compte ? ',
  'لديك حساب بالفعل؟ ': 'Vous avez déjà un compte ? ',
  'أنشئ حساباً': 'Créer un compte',
  'سجّل الدخول': 'Se connecter',
  'هذا الحقل مطلوب': 'Ce champ est requis',
  'يرجى ملء جميع الحقول الإلزامية المطلوبة': 'Veuillez remplir tous les champs obligatoires',
  'كلمة المرور قصيرة (8 أحرف على الأقل)': 'Mot de passe trop court (8 caractères min.)',
  'يجب أن تكون كلمة المرور 8 أحرف على الأقل': 'Le mot de passe doit contenir au moins 8 caractères',
  '✓ كلمة مرور جيدة': '✓ Bon mot de passe',
  'كلمتا المرور غير متطابقتين': 'Les mots de passe ne correspondent pas',
  'استعادة كلمة المرور': 'Réinitialiser le mot de passe',
  'أدخل رقم هاتفك أو بريدك الإلكتروني. سيتواصل معك فريق WIIN لإعادة تعيين كلمة مرورك.':
      'Saisissez votre téléphone ou e-mail. L\'équipe WIIN vous contactera pour réinitialiser votre mot de passe.',
  'الهاتف أو البريد': 'Téléphone ou e-mail',
  'إرسال الطلب': 'Envoyer la demande',
  'تم إرسال طلبك ✓ سيتواصل معك الفريق قريباً': 'Demande envoyée ✓ L\'équipe vous contactera bientôt',
  'ابدأ الآن': 'Commencer',

  // months
  'جانفي': 'Janvier', 'فيفري': 'Février', 'مارس': 'Mars', 'أفريل': 'Avril',
  'ماي': 'Mai', 'جوان': 'Juin', 'جويلية': 'Juillet', 'أوت': 'Août',
  'سبتمبر': 'Septembre', 'أكتوبر': 'Octobre', 'نوفمبر': 'Novembre', 'ديسمبر': 'Décembre',

  // bottom nav
  'الرئيسية': 'Accueil', 'خريطة': 'Carte', 'مكافأتي': 'Récompenses', 'الهدايا': 'Cadeaux', 'امسح': 'Scanner',

  // home
  'مرحباً، ': 'Bonjour, ',
  'أخضر': 'Vert', 'فضية': 'Argent', 'ذهبية': 'Or', 'فضي': 'Argent', 'ذهبي': 'Or', 'ذهبي+': 'Or+',
  'ستتوفر قريباً': 'Bientôt disponible',
  'اضغط على البطاقة لعرض رمز QR · اسحب للبطاقات الأخرى': 'Touchez la carte pour le QR · glissez pour les autres',
  'اضغط للعودة إلى الرصيد': 'Touchez pour revenir au solde',
  'مسح رمز QR لكسب النقاط': 'Scanner un QR pour gagner des points',
  'اكتشف نقاط الجمع القريبة': 'Trouver les points de collecte proches',
  'إعلان': 'Publicité',
  'إنترنت أسرع مع شريكنا': 'Internet plus rapide avec notre partenaire',
  'عرض حصري لمستخدمي WIIN': 'Offre exclusive pour les utilisateurs WIIN',
  'اكتشف المزيد': 'En savoir plus',
  'الكود الشخصي': 'Code personnel',
  'اعرض هذا الرمز لموظف نقطة الجمع ليضيف نقاطك': 'Montrez ce code à l\'agent du point de collecte pour créditer vos points',

  // onboarding
  'ابحث عن نقطة الجمع': 'Trouvez un point de collecte',
  'افتح الخريطة لتجد أقرب نقطة جمع إليك بسهولة': 'Ouvrez la carte pour trouver facilement le point le plus proche',
  'أودِع القارورات': 'Déposez les bouteilles',
  'توجّه إلى النقطة وامسح رمز QR لإيداع القارورات': 'Rendez-vous au point et scannez le QR pour déposer les bouteilles',
  'اكسب واربح': 'Gagnez et remportez',
  'استلم نقاطك مباشرةً واستبدلها بهدايا رائعة': 'Recevez vos points et échangez-les contre de superbes cadeaux',
  'اجمع القارورات، اكسب النقاط، واربح الهدايا': 'Collectez, gagnez des points et remportez des cadeaux',
  'التالي': 'Suivant', 'السابق': 'Précédent',

  // notifications / permissions
  'الإشعارات': 'Notifications',
  'لا توجد إشعارات': 'Aucune notification',
  'فعّل الإشعارات': 'Activer les notifications',
  'الإشعارات معطّلة. فعّلها لتصلك التنبيهات عن الهدايا والنقاط الجديدة حتى وأنت خارج التطبيق.':
      'Notifications désactivées. Activez-les pour être alerté des cadeaux et points, même hors de l\'application.',
  'فتح الإعدادات': 'Ouvrir les paramètres',
  'لاحقاً': 'Plus tard',
  'كلمة مرور مؤقتة': 'Mot de passe temporaire',
  'تم تعيين كلمة مرور مؤقتة لحسابك. غيّرها الآن.': 'Un mot de passe temporaire a été défini. Changez-le maintenant.',
  'تم تعيين كلمة مرور مؤقتة لحسابك من قِبل الإدارة. هل تريد تغييرها الآن إلى كلمة مرور خاصة بك؟':
      'L\'administration a défini un mot de passe temporaire. Voulez-vous le remplacer par le vôtre maintenant ?',
  'تخطّي': 'Ignorer',

  // map
  'الخريطة': 'Carte',
  'نقاط الجمع القريبة': 'Points de collecte proches',
  'أقرب نقاط الجمع': 'Points les plus proches',
  'الأقرب أولاً': 'Les plus proches',
  'كل النقاط': 'Tous les points',
  'أظهر مكاني': 'Ma position',
  'تفعيل الموقع': 'Activer la localisation',
  'تفعيل': 'Activer',
  'الموقع مطلوب للخريطة': 'Localisation requise pour la carte',
  'لعرض أقرب نقاط الجمع إليك وحساب المسافات، يجب تفعيل الموقع. لا يمكن استخدام الخريطة بدون تفعيل الموقع.':
      'Pour afficher les points proches et calculer les distances, la localisation doit être activée. La carte est inutilisable sans elle.',
  'فعّل الموقع لعرض أقرب نقاط الجمع وحساب المسافات': 'Activez la localisation pour voir les points proches et les distances',
  'ساعات العمل': 'Horaires',
  'يقبل': 'Accepte',
  'مفتوح': 'Ouvert', 'مغلق': 'Fermé',
  'من موقعك': 'De votre position',
  'الاتجاهات عبر ': 'Itinéraire via ',
  'افتح الملاحة خطوة بخطوة': 'Ouvrir la navigation étape par étape',
  'امسح هنا واكسب النقاط': 'Scannez ici et gagnez des points',
  'اتصل': 'Appeler',
  'تعذّر فتح خرائط Google': 'Impossible d\'ouvrir Google Maps',
  'موقع المتجر على الخريطة': 'Emplacement du magasin sur la carte',

  // scan
  'مسح رمز QR': 'Scanner un QR',
  'وجّه الكاميرا نحو رمز QR الموجود على نقطة الجمع': 'Dirigez la caméra vers le QR du point de collecte',
  'لا تعرف أين توجد نقاط الجمع؟': 'Vous ne savez pas où sont les points de collecte ?',
  'اعرض نقاط الجمع على الخريطة': 'Voir les points sur la carte',
  'يحتاج التطبيق إلى إذن الكاميرا لمسح الرموز': 'L\'application a besoin de la caméra pour scanner les codes',
  'قيّم نقطة الجمع': 'Évaluez le point de collecte',
  'كيف كانت تجربتك في هذه النقطة؟': 'Comment était votre expérience ?',
  'إرسال التقييم': 'Envoyer l\'avis',
  'شكراً لتقييمك ⭐': 'Merci pour votre avis ⭐',
  'كم عدد القارورات التي جمعتها؟': 'Combien de bouteilles avez-vous collectées ?',
  'تأكيد الإيداع': 'Confirmer le dépôt',
  'تمت إضافة نقاطك!': 'Vos points ont été ajoutés !',
  'رائع، تم': 'Parfait',
  'شكراً لمساهمتك في إعادة التدوير ♻️': 'Merci pour votre contribution au recyclage ♻️',

  // gifts
  'مكافآت خاصة ومحدودة — متوفرة لفترة قصيرة فقط ✨': 'Récompenses spéciales et limitées — pour une durée limitée ✨',
  'لا توجد هدايا في هذه الفئة حالياً': 'Aucun cadeau dans cette catégorie',
  'الكل': 'Tous', 'مطاعم': 'Restaurants', 'رياضة': 'Sport', 'عامة': 'Général',
  'مقاهي': 'Cafés', 'محلات': 'Boutiques', 'منتجات': 'Produits', 'اخرى': 'Autres',
  'استلام': 'Obtenir', 'تأكيد الاستلام': 'Confirmer', 'تأكيد': 'Confirmer', 'مجاناً': 'Gratuit', 'محدود': 'Limité',

  // perks / rewards
  'رصيدك الحالي': 'Votre solde actuel',
  'ترتيبك المحلي': 'Votre classement local',
  'هداياي': 'Mes cadeaux',
  'اعرض الكود لموظف المتجر ليمسحه ويسلّمك هديتك': 'Montrez le code au magasin pour recevoir votre cadeau',
  'لا توجد مكافآت بعد': 'Aucune récompense pour le moment',
  'اختر هدية من صفحة «الهدايا» لتظهر هنا': 'Choisissez un cadeau depuis « Cadeaux » pour le voir ici',
  'عرض الكود': 'Voir le code', 'رد النقاط': 'Rembourser',
  'استرجاع نقاط {title}؟': 'Rembourser {title} ?',
  'ستُعاد {n} Wz إلى رصيدك وتُحذف الهدية من «مكافأتي».': '{n} Wz seront recrédités et le cadeau retiré de « Récompenses ».',
  'ستُحذف الهدية من «مكافأتي».': 'Le cadeau sera retiré de « Récompenses ».',
  'نعم، استرجع': 'Oui, rembourser',
  'تم استرجاع {n} Wz': '{n} Wz remboursés',
  'تمت الإزالة': 'Retiré',
  'يتحقق المتجر من الكود يدوياً أو بمسح رمز QR لتسليمك هديتك': 'Le magasin vérifie le code manuellement ou par QR pour vous remettre le cadeau',
  'استلام {title}؟': 'Obtenir {title} ?',
  'سيتم خصم {cost} Wz وتُضاف الهدية إلى «مكافأتي».': '{cost} Wz seront déduits et le cadeau ajouté à « Récompenses ».',
  'ستُضاف الهدية مجاناً إلى «مكافأتي».': 'Le cadeau sera ajouté gratuitement à « Récompenses ».',
  'تمت إضافة الهدية إلى «مكافأتي» 🎁': 'Cadeau ajouté à « Récompenses » 🎁',
  'مجموع المكتسب': 'Total gagné', 'عملية مسح': 'Scans', 'استبدال': 'Échanges',
  'سجل النقاط': 'Historique des points', 'لا توجد حركات بعد': 'Aucune activité pour le moment',
  'هذا الأسبوع': 'Cette semaine', 'في الصدارة! 🏆': 'En tête ! 🏆',

  // more / settings
  'المزيد': 'Plus', 'اختصارات': 'Raccourcis', 'الإعدادات': 'Paramètres', 'نقاط الجمع': 'Points de collecte',
  'تعديل الملف الشخصي': 'Modifier le profil',
  'تغيير الصورة': 'Changer la photo',
  'صورة الملف الشخصي': 'Photo de profil',
  'التقاط صورة': 'Prendre une photo', 'من المعرض': 'Depuis la galerie',
  'الصورة كبيرة جداً، اختر صورة أصغر': 'Image trop grande, choisissez-en une plus petite',
  'تم تحديث صورتك ✓': 'Photo mise à jour ✓',
  'تعذّر اختيار الصورة': 'Impossible de choisir l\'image',
  'العنوان': 'Adresse',
  'حفظ التغييرات': 'Enregistrer', 'إلغاء': 'Annuler', 'حفظ': 'Enregistrer',
  'تم حفظ التغييرات ✓': 'Modifications enregistrées ✓',
  'شاهد الفيديوهات واربح النقاط': 'Regardez des vidéos et gagnez des points',
  'شاهد إعلاناً قصيراً واكسب حتى 5 Wz يومياً': 'Regardez une courte pub et gagnez jusqu\'à 5 Wz/jour',
  'شاهد الآن': 'Regarder', 'ستتوفر هذه الميزة قريباً ⏳': 'Fonctionnalité bientôt disponible ⏳',
  'رمز الدعوة الخاص بك': 'Votre code de parrainage',
  'شارك رمزك واحصل على 20 Wz لكل صديق ينضم 🎉': 'Partagez votre code et gagnez 20 Wz par ami inscrit 🎉',
  'تم نسخ رمز الدعوة ✓': 'Code copié ✓',
  'أصدقاء انضموا برمزك': 'Amis inscrits avec votre code',
  'لم ينضم أحد بعد — شارك رمزك لتبدأ الربح': 'Personne encore — partagez votre code pour commencer',
  'تغيير كلمة المرور': 'Changer le mot de passe',
  'المساعدة والدعم': 'Aide et support',
  'عن التطبيق': 'À propos',
  'تسجيل الخروج': 'Se déconnecter',
  'صف مشكلتك أو اقتراحك وسيتواصل معك فريق WIIN.': 'Décrivez votre problème ou suggestion, l\'équipe WIIN vous répondra.',
  'عنوان المشكلة / الاقتراح': 'Objet du problème / suggestion',
  'التفاصيل': 'Détails', 'اكتب التفاصيل هنا…': 'Écrivez les détails ici…',
  'أدخل عنوان المشكلة': 'Saisissez l\'objet du problème',
  'إرسال': 'Envoyer',
  'تم إرسال رسالتك ✓ سنتواصل معك قريباً': 'Message envoyé ✓ Nous vous répondrons bientôt',
  'تعذّر الإرسال، حاول مجدداً': 'Échec de l\'envoi, réessayez',
  'شركة ناشئة في تسيير النفايات وإعادة التدوير': 'Startup de gestion des déchets et du recyclage',
  'طُوّر ونُشر بواسطة WIIN ALGERIA': 'Développé et publié par WIIN ALGERIA',
  'انضم إلى WIIN': 'Rejoignez WIIN',

  // change password
  'كلمة المرور الحالية': 'Mot de passe actuel',
  'كلمة المرور الجديدة': 'Nouveau mot de passe',
  'تأكيد كلمة المرور الجديدة': 'Confirmer le nouveau mot de passe',
  'كلمة المرور الجديدة قصيرة (8 أحرف على الأقل)': 'Nouveau mot de passe trop court (8 caractères min.)',
  'تم تغيير كلمة المرور ✓': 'Mot de passe changé ✓',
  'هل تريد تغيير كلمة مرورك؟': 'Voulez-vous changer votre mot de passe ?',

  // common / network
  'حسناً': 'OK', 'تم': 'Terminé', 'حدث خطأ، حاول مجدداً': 'Une erreur est survenue, réessayez',
  'تعذّر الاتصال بالخادم، قد يكون بطيئاً الآن. حاول مجدداً بعد لحظات.':
      'Connexion au serveur impossible, il est peut-être lent. Réessayez dans un instant.',
  'لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مجدداً.': 'Pas de connexion Internet. Vérifiez et réessayez.',
  'تعذّر الاتصال بالخادم. حاول مجدداً.': 'Connexion au serveur impossible. Réessayez.',
  'تعذّر الاتصال الآمن بالخادم. حاول مجدداً.': 'Connexion sécurisée impossible. Réessayez.',

  // tier cards + rich-text fragments
  'البطاقة الفضية': 'Carte Argent', 'البطاقة الذهبية': 'Carte Or',
  'باقٍ ': 'Reste ', ' للوصول إلى ': ' pour atteindre ',
  'أنت في المركز ': 'Vous êtes classé ', 'رصيدك الآن ': 'Votre solde : ',
  'المستوى: {name}': 'Niveau : {name}',
  'تحتاج {n} Wz للتقدم': 'Il vous faut {n} Wz pour progresser',
  'رصيدك الآن {n} Wz': 'Votre solde est de {n} Wz',
  'من أصل {n} في {zone}': 'sur {n} à {zone}',
  'لوحة الصدارة · {zone}': 'Classement · {zone}',
  '{n} نقاط': '{n} points',
  'المستوى: ': 'Niveau : ',
  'باقٍ {n} Wz': 'Reste {n} Wz',

  'انضم إلى تطبيق WIIN ♻️ وابدأ بجمع القارورات وكسب النقاط والفوز بالهدايا! 🎁':
      'Rejoignez WIIN ♻️ et commencez à collecter des bouteilles, gagner des points et remporter des cadeaux ! 🎁',
  'استخدم رمز دعوتي عند التسجيل:': 'Utilisez mon code de parrainage à l\'inscription :',
  'حمّل التطبيق الآن وابدأ الربح معنا.': 'Téléchargez l\'application et commencez à gagner avec nous.',

  // language
  'تغيير اللغة': 'Changer la langue', 'اللغة': 'Langue',

  // deposit limits + scanner guide
  'الحد الأقصى {n} قارورة في الإيداع الواحد': 'Maximum {n} bouteilles par dépôt',
  'انتظر قبل الإيداع التالي': 'Attendez avant le prochain dépôt',
  'يمكنك إيداع قارورات جديدة بعد': 'Vous pourrez déposer de nouvelles bouteilles dans',
  'يمكنك الإيداع الآن': 'Vous pouvez déposer maintenant',
  'انتهى وقت الانتظار، يمكنك مسح رمز QR وإيداع قارورات جديدة':
      'Le temps d\'attente est écoulé : scannez un code QR pour déposer de nouvelles bouteilles',
  'إيداع الآن': 'Déposer maintenant',
  'دقيقة': 'min', 'ثانية': 'sec',
  // notifications
  'قبل {n} دقيقة': 'il y a {n} min', 'قبل {n} ساعة': 'il y a {n} h',
  'قبل {n} أيام': 'il y a {n} jours', 'قبل {n} أسابيع': 'il y a {n} sem.',
  'قبل {n} أشهر': 'il y a {n} mois', 'قبل {n} سنة': 'il y a {n} an(s)',
  'رسالة موجّهة إليك': 'Message qui vous est adressé',
  'إشعار عام': 'Notification générale',
  'إغلاق': 'Fermer',

  // tutorial / settings
  'كيفية استخدام التطبيق': 'Comment utiliser l\'application',
  'الخطوة {n} من {t}': 'Étape {n} sur {t}',
  'ابدأ': 'Commencer',
  'اجمع القارورات': 'Collectez les bouteilles',
  'اجمع القارورات البلاستيكية الفارغة في المنزل بدل رميها.':
      'Rassemblez vos bouteilles en plastique vides à la maison au lieu de les jeter.',
  'أودعها في نقطة الجمع': 'Déposez-les au point de collecte',
  'اعثر على أقرب نقطة جمع على الخريطة وأودع قاروراتك هناك.':
      'Trouvez le point de collecte le plus proche sur la carte et déposez-y vos bouteilles.',
  'امسح واكسب النقاط': 'Scannez et gagnez des points',
  'امسح رمز QR الخاص بنقطة الجمع لتكسب نقاط Wz، واستبدلها بهدايا ومكافآت.':
      'Scannez le code QR du point de collecte pour gagner des points Wz, puis échangez-les contre des cadeaux et récompenses.',

  // daily bonus
  'المكافأة اليومية': 'Bonus quotidien',
  'مكافأتك اليومية': 'Votre bonus quotidien',
  'استلم نقاطك المجانية لهذا اليوم': 'Récupérez vos points gratuits du jour',
  'استلم المكافأة': 'Récupérer le bonus',
  'استلم': 'Récupérer',
  'تم استلام مكافأتك!': 'Bonus récupéré !',
  'عُد غداً لمكافأة جديدة 🎁': 'Revenez demain pour un nouveau bonus 🎁',
  'استلم {n} Wz مجاناً اليوم': 'Récupérez {n} Wz gratuits aujourd\'hui',
  'المكافأة القادمة بعد {t}': 'Prochain bonus dans {t}',
  'مكافأتك اليومية بانتظارك 🎁': 'Votre bonus quotidien vous attend 🎁',

  // auth screen — account switch prompts (the verbs already exist above)
  'لديك حساب بالفعل؟': 'Vous avez déjà un compte ?',
  'ليس لديك حساب؟': 'Pas encore de compte ?',
  // profile — phone is read-only
  'لا يمكن تغيير رقم الهاتف. تواصل مع الدعم لتعديله.': 'Le numéro de téléphone ne peut pas être modifié. Contactez le support.',

  // holder: edit point + bag full
  'تعديل معلومات النقطة': 'Modifier les infos du point',
  'يُرسل التعديل كطلب للإدارة، ولا يُطبّق إلا بعد الموافقة. لا يمكن تغيير موقع النقطة على الخريطة.': 'La modification est envoyée à l\'administration et ne s\'applique qu\'après approbation. L\'emplacement sur la carte ne peut pas être modifié.',
  'اسم النقطة': 'Nom du point',
  'المنطقة': 'Zone',
  'الهاتف': 'Téléphone',
  'تفاصيل إضافية': 'Détails supplémentaires',
  'من': 'De',
  'إلى': 'À',
  'مسح': 'Effacer',
  'الحالي: {v}': 'Actuel : {v}',
  'هل تريد إرسال طلب التعديل إلى الإدارة؟': 'Envoyer la demande de modification à l\'administration ?',
  'تأكيد الإرسال': 'Confirmer l\'envoi',
  'الإبلاغ عن امتلاء الحاوية': 'Signaler le conteneur plein',
  'سيصل التنبيه إلى الإدارة وإلى موظف الميدان لتفريغ الحاوية. هل تؤكد؟': 'L\'alerte sera envoyée à l\'administration et à l\'agent de terrain pour vider le conteneur. Confirmer ?',
  'نعم، الحاوية ممتلئة': 'Oui, le conteneur est plein',
  'تم إرسال تنبيه الامتلاء ✓': 'Alerte de conteneur plein envoyée ✓',
  // map: point types
  'نقطة جمع خاصة': 'Point de collecte privé',
  'هذه النقطة (باللون الأصفر) مخصّصة لأعضاء المكان فقط (مثل نادٍ رياضي أو مؤسسة)، وليست متاحة لعامة المستخدمين للإيداع.': 'Ce point (en jaune) est réservé aux membres du lieu (salle de sport, établissement…) et n\'est pas ouvert au dépôt public.',
  'عرض التفاصيل': 'Voir les détails',
  'أنواع نقاط الجمع': 'Types de points de collecte',
  'النقاط الخضراء: متاحة لكل المستخدمين لإيداع القارورات.': 'Points verts : ouverts à tous pour déposer les bouteilles.',
  'النقاط الصفراء: خاصة بأعضاء المكان فقط (نادٍ، مؤسسة…).': 'Points jaunes : réservés aux membres du lieu (club, établissement…).',
  'فهمت': 'Compris',

  // user profile + achievements
  'تعذّر تحميل الملف الشخصي': 'Impossible de charger le profil',
  'المركز {n} من {m}': 'Rang {n} sur {m}',
  'انضم {t}': 'Inscrit {t}',
  'قارورة': 'Bouteilles',
  'عملية إيداع': 'Dépôts',
  'الإنجازات': 'Réalisations',
  'أول إيداع': 'Premier dépôt',
  'أودعت قاروراتك الأولى': 'Vous avez déposé vos premières bouteilles',
  'جامع مبتدئ': 'Collecteur débutant',
  'أودعت 10 قارورات': 'Vous avez déposé 10 bouteilles',
  'جامع نشيط': 'Collecteur actif',
  'أودعت 50 قارورة': 'Vous avez déposé 50 bouteilles',
  'بطل التدوير': 'Champion du recyclage',
  'أودعت 100 قارورة': 'Vous avez déposé 100 bouteilles',
  'أسطورة القارورات': 'Légende des bouteilles',
  'أودعت 500 قارورة': 'Vous avez déposé 500 bouteilles',
  'المستوى الفضي': 'Niveau argent',
  'وصلت إلى المستوى الفضي': 'Vous avez atteint le niveau argent',
  'المستوى الذهبي': 'Niveau or',
  'وصلت إلى المستوى الذهبي': 'Vous avez atteint le niveau or',
  'صديق البيئة': 'Ami de l\'environnement',
  'دعوت صديقاً واحداً': 'Vous avez parrainé un ami',
  'سفير WIIN': 'Ambassadeur WIIN',
  'دعوت 5 أصدقاء': 'Vous avez parrainé 5 amis',
  'في القمة': 'Au sommet',
  'ضمن أفضل 3 في ولايتك': 'Dans le top 3 de votre wilaya',

  'كيف تودع قاروراتك؟': 'Comment déposer vos bouteilles ?',
  'اجمع القارورات الفارغة': 'Collectez vos bouteilles vides',
  'أودعها في أقرب نقطة جمع إليك': 'Déposez-les au point de collecte le plus proche',
  'امسح رمز QR الخاص بنقطة الجمع واكسب نقاطك': 'Scannez le code QR du point de collecte et gagnez vos points',
  'فهمت، لنبدأ': 'J\'ai compris, commençons',
};

// ===========================================================================
// English
// ===========================================================================
final Map<String, String> _en = {
  'مرحباً بك في WIIN': 'Welcome to WIIN',
  'اجمع القارورات وحافظ على بيئتك': 'Collect bottles and protect your environment',
  'إنشاء حساب': 'Create account',
  'تسجيل الدخول': 'Log in',
  'أنشئ حسابك': 'Create your account',
  'ابدأ رحلتك في إعادة التدوير': 'Start your recycling journey',
  'مرحباً بعودتك': 'Welcome back',
  'سجّل الدخول لمتابعة كسب النقاط': 'Log in to keep earning points',
  'الاسم الكامل': 'Full name',
  'اكتب اسمك': 'Enter your name',
  'رقم الهاتف': 'Phone number',
  'الولاية': 'Wilaya',
  'البلدية': 'Commune',
  'تاريخ الميلاد': 'Date of birth',
  'اليوم': 'Day', 'الشهر': 'Month', 'السنة': 'Year',
  'الجنس': 'Gender', 'ذكر': 'Male', 'أنثى': 'Female',
  'رمز الدعوة (اختياري)': 'Invite code (optional)',
  'البريد الإلكتروني (غير إلزامي)': 'Email (optional)',
  'البريد الإلكتروني أو رقم الهاتف': 'Email or phone number',
  'الإيمايل غير صالح': 'Invalid email',
  'البريد الإلكتروني غير صالح (مثال: test@domain.com)': 'Invalid email (e.g. test@domain.com)',
  'كلمة المرور': 'Password',
  'تأكيد كلمة المرور': 'Confirm password',
  'إنشاء الحساب': 'Create account',
  'نسيت كلمة المرور؟': 'Forgot password?',
  'أو': 'or',
  'ليس لديك حساب؟ ': 'No account? ',
  'لديك حساب بالفعل؟ ': 'Already have an account? ',
  'أنشئ حساباً': 'Sign up',
  'سجّل الدخول': 'Log in',
  'هذا الحقل مطلوب': 'This field is required',
  'يرجى ملء جميع الحقول الإلزامية المطلوبة': 'Please fill in all required fields',
  'كلمة المرور قصيرة (8 أحرف على الأقل)': 'Password too short (min. 8 characters)',
  'يجب أن تكون كلمة المرور 8 أحرف على الأقل': 'Password must be at least 8 characters',
  '✓ كلمة مرور جيدة': '✓ Good password',
  'كلمتا المرور غير متطابقتين': 'Passwords do not match',
  'استعادة كلمة المرور': 'Reset password',
  'أدخل رقم هاتفك أو بريدك الإلكتروني. سيتواصل معك فريق WIIN لإعادة تعيين كلمة مرورك.':
      'Enter your phone or email. The WIIN team will contact you to reset your password.',
  'الهاتف أو البريد': 'Phone or email',
  'إرسال الطلب': 'Send request',
  'تم إرسال طلبك ✓ سيتواصل معك الفريق قريباً': 'Request sent ✓ The team will contact you soon',
  'ابدأ الآن': 'Get started',

  'جانفي': 'January', 'فيفري': 'February', 'مارس': 'March', 'أفريل': 'April',
  'ماي': 'May', 'جوان': 'June', 'جويلية': 'July', 'أوت': 'August',
  'سبتمبر': 'September', 'أكتوبر': 'October', 'نوفمبر': 'November', 'ديسمبر': 'December',

  'الرئيسية': 'Home', 'خريطة': 'Map', 'مكافأتي': 'Rewards', 'الهدايا': 'Gifts', 'امسح': 'Scan',

  'مرحباً، ': 'Hi, ',
  'أخضر': 'Green', 'فضية': 'Silver', 'ذهبية': 'Gold', 'فضي': 'Silver', 'ذهبي': 'Gold', 'ذهبي+': 'Gold+',
  'ستتوفر قريباً': 'Coming soon',
  'اضغط على البطاقة لعرض رمز QR · اسحب للبطاقات الأخرى': 'Tap the card for QR · swipe for other cards',
  'اضغط للعودة إلى الرصيد': 'Tap to return to balance',
  'مسح رمز QR لكسب النقاط': 'Scan a QR to earn points',
  'اكتشف نقاط الجمع القريبة': 'Discover nearby collection points',
  'إعلان': 'Ad',
  'إنترنت أسرع مع شريكنا': 'Faster internet with our partner',
  'عرض حصري لمستخدمي WIIN': 'Exclusive offer for WIIN users',
  'اكتشف المزيد': 'Learn more',
  'الكود الشخصي': 'Personal code',
  'اعرض هذا الرمز لموظف نقطة الجمع ليضيف نقاطك': 'Show this code to the collection agent to credit your points',

  'ابحث عن نقطة الجمع': 'Find a collection point',
  'افتح الخريطة لتجد أقرب نقطة جمع إليك بسهولة': 'Open the map to easily find the nearest point',
  'أودِع القارورات': 'Deposit the bottles',
  'توجّه إلى النقطة وامسح رمز QR لإيداع القارورات': 'Go to the point and scan the QR to deposit bottles',
  'اكسب واربح': 'Earn and win',
  'استلم نقاطك مباشرةً واستبدلها بهدايا رائعة': 'Get your points and redeem them for great gifts',
  'اجمع القارورات، اكسب النقاط، واربح الهدايا': 'Collect bottles, earn points, win gifts',
  'التالي': 'Next', 'السابق': 'Back',

  'الإشعارات': 'Notifications',
  'لا توجد إشعارات': 'No notifications',
  'فعّل الإشعارات': 'Enable notifications',
  'الإشعارات معطّلة. فعّلها لتصلك التنبيهات عن الهدايا والنقاط الجديدة حتى وأنت خارج التطبيق.':
      'Notifications are off. Enable them to get alerts about gifts and points, even outside the app.',
  'فتح الإعدادات': 'Open settings',
  'لاحقاً': 'Later',
  'كلمة مرور مؤقتة': 'Temporary password',
  'تم تعيين كلمة مرور مؤقتة لحسابك. غيّرها الآن.': 'A temporary password was set. Change it now.',
  'تم تعيين كلمة مرور مؤقتة لحسابك من قِبل الإدارة. هل تريد تغييرها الآن إلى كلمة مرور خاصة بك؟':
      'The admin set a temporary password. Do you want to change it to your own now?',
  'تخطّي': 'Skip',

  'الخريطة': 'Map',
  'نقاط الجمع القريبة': 'Nearby collection points',
  'أقرب نقاط الجمع': 'Nearest points',
  'الأقرب أولاً': 'Nearest first',
  'كل النقاط': 'All points',
  'أظهر مكاني': 'My location',
  'تفعيل الموقع': 'Enable location',
  'تفعيل': 'Enable',
  'الموقع مطلوب للخريطة': 'Location required for the map',
  'لعرض أقرب نقاط الجمع إليك وحساب المسافات، يجب تفعيل الموقع. لا يمكن استخدام الخريطة بدون تفعيل الموقع.':
      'To show nearby points and distances, location must be enabled. The map cannot be used without it.',
  'فعّل الموقع لعرض أقرب نقاط الجمع وحساب المسافات': 'Enable location to see nearby points and distances',
  'ساعات العمل': 'Opening hours',
  'يقبل': 'Accepts',
  'مفتوح': 'Open', 'مغلق': 'Closed',
  'من موقعك': 'From you',
  'الاتجاهات عبر ': 'Directions via ',
  'افتح الملاحة خطوة بخطوة': 'Open turn-by-turn navigation',
  'امسح هنا واكسب النقاط': 'Scan here and earn points',
  'اتصل': 'Call',
  'تعذّر فتح خرائط Google': 'Could not open Google Maps',
  'موقع المتجر على الخريطة': 'Store location on the map',

  'مسح رمز QR': 'Scan QR',
  'وجّه الكاميرا نحو رمز QR الموجود على نقطة الجمع': 'Point the camera at the QR on the collection point',
  'لا تعرف أين توجد نقاط الجمع؟': 'Don\'t know where the collection points are?',
  'اعرض نقاط الجمع على الخريطة': 'Show collection points on the map',
  'يحتاج التطبيق إلى إذن الكاميرا لمسح الرموز': 'The app needs camera permission to scan codes',
  'قيّم نقطة الجمع': 'Rate the collection point',
  'كيف كانت تجربتك في هذه النقطة؟': 'How was your experience here?',
  'إرسال التقييم': 'Submit rating',
  'شكراً لتقييمك ⭐': 'Thanks for your rating ⭐',
  'كم عدد القارورات التي جمعتها؟': 'How many bottles did you collect?',
  'تأكيد الإيداع': 'Confirm deposit',
  'تمت إضافة نقاطك!': 'Your points were added!',
  'رائع، تم': 'Great',
  'شكراً لمساهمتك في إعادة التدوير ♻️': 'Thanks for helping recycle ♻️',

  'مكافآت خاصة ومحدودة — متوفرة لفترة قصيرة فقط ✨': 'Special limited rewards — available for a short time ✨',
  'لا توجد هدايا في هذه الفئة حالياً': 'No gifts in this category yet',
  'الكل': 'All', 'مطاعم': 'Restaurants', 'رياضة': 'Sports', 'عامة': 'General',
  'مقاهي': 'Cafés', 'محلات': 'Shops', 'منتجات': 'Products', 'اخرى': 'Other',
  'استلام': 'Claim', 'تأكيد الاستلام': 'Confirm', 'تأكيد': 'Confirm', 'مجاناً': 'Free', 'محدود': 'Limited',

  'رصيدك الحالي': 'Your current balance',
  'ترتيبك المحلي': 'Your local rank',
  'هداياي': 'My gifts',
  'اعرض الكود لموظف المتجر ليمسحه ويسلّمك هديتك': 'Show the code to the store to receive your gift',
  'لا توجد مكافآت بعد': 'No rewards yet',
  'اختر هدية من صفحة «الهدايا» لتظهر هنا': 'Pick a gift from "Gifts" to see it here',
  'عرض الكود': 'Show code', 'رد النقاط': 'Refund',
  'استرجاع نقاط {title}؟': 'Refund {title}?',
  'ستُعاد {n} Wz إلى رصيدك وتُحذف الهدية من «مكافأتي».': '{n} Wz will be refunded and the gift removed from "Rewards".',
  'ستُحذف الهدية من «مكافأتي».': 'The gift will be removed from "Rewards".',
  'نعم، استرجع': 'Yes, refund',
  'تم استرجاع {n} Wz': '{n} Wz refunded',
  'تمت الإزالة': 'Removed',
  'يتحقق المتجر من الكود يدوياً أو بمسح رمز QR لتسليمك هديتك': 'The store verifies the code manually or by QR to hand you the gift',
  'استلام {title}؟': 'Claim {title}?',
  'سيتم خصم {cost} Wz وتُضاف الهدية إلى «مكافأتي».': '{cost} Wz will be deducted and the gift added to "Rewards".',
  'ستُضاف الهدية مجاناً إلى «مكافأتي».': 'The gift will be added free to "Rewards".',
  'تمت إضافة الهدية إلى «مكافأتي» 🎁': 'Gift added to "Rewards" 🎁',
  'مجموع المكتسب': 'Total earned', 'عملية مسح': 'Scans', 'استبدال': 'Redemptions',
  'سجل النقاط': 'Points history', 'لا توجد حركات بعد': 'No activity yet',
  'هذا الأسبوع': 'This week', 'في الصدارة! 🏆': 'In the lead! 🏆',

  'المزيد': 'More', 'اختصارات': 'Shortcuts', 'الإعدادات': 'Settings', 'نقاط الجمع': 'Collection points',
  'تعديل الملف الشخصي': 'Edit profile',
  'تغيير الصورة': 'Change photo',
  'صورة الملف الشخصي': 'Profile picture',
  'التقاط صورة': 'Take a photo', 'من المعرض': 'From gallery',
  'الصورة كبيرة جداً، اختر صورة أصغر': 'Image too large, choose a smaller one',
  'تم تحديث صورتك ✓': 'Photo updated ✓',
  'تعذّر اختيار الصورة': 'Could not pick the image',
  'العنوان': 'Address',
  'حفظ التغييرات': 'Save changes', 'إلغاء': 'Cancel', 'حفظ': 'Save',
  'تم حفظ التغييرات ✓': 'Changes saved ✓',
  'شاهد الفيديوهات واربح النقاط': 'Watch videos and earn points',
  'شاهد إعلاناً قصيراً واكسب حتى 5 Wz يومياً': 'Watch a short ad and earn up to 5 Wz/day',
  'شاهد الآن': 'Watch now', 'ستتوفر هذه الميزة قريباً ⏳': 'This feature is coming soon ⏳',
  'رمز الدعوة الخاص بك': 'Your invite code',
  'شارك رمزك واحصل على 20 Wz لكل صديق ينضم 🎉': 'Share your code and earn 20 Wz per friend who joins 🎉',
  'تم نسخ رمز الدعوة ✓': 'Invite code copied ✓',
  'أصدقاء انضموا برمزك': 'Friends who joined with your code',
  'لم ينضم أحد بعد — شارك رمزك لتبدأ الربح': 'No one yet — share your code to start earning',
  'تغيير كلمة المرور': 'Change password',
  'المساعدة والدعم': 'Help & support',
  'عن التطبيق': 'About',
  'تسجيل الخروج': 'Log out',
  'صف مشكلتك أو اقتراحك وسيتواصل معك فريق WIIN.': 'Describe your issue or suggestion and the WIIN team will reply.',
  'عنوان المشكلة / الاقتراح': 'Issue / suggestion subject',
  'التفاصيل': 'Details', 'اكتب التفاصيل هنا…': 'Write the details here…',
  'أدخل عنوان المشكلة': 'Enter the issue subject',
  'إرسال': 'Send',
  'تم إرسال رسالتك ✓ سنتواصل معك قريباً': 'Message sent ✓ We\'ll reply soon',
  'تعذّر الإرسال، حاول مجدداً': 'Sending failed, try again',
  'شركة ناشئة في تسيير النفايات وإعادة التدوير': 'A startup in waste management and recycling',
  'طُوّر ونُشر بواسطة WIIN ALGERIA': 'Developed and published by WIIN ALGERIA',
  'انضم إلى WIIN': 'Join WIIN',

  'كلمة المرور الحالية': 'Current password',
  'كلمة المرور الجديدة': 'New password',
  'تأكيد كلمة المرور الجديدة': 'Confirm new password',
  'كلمة المرور الجديدة قصيرة (8 أحرف على الأقل)': 'New password too short (min. 8 characters)',
  'تم تغيير كلمة المرور ✓': 'Password changed ✓',
  'هل تريد تغيير كلمة مرورك؟': 'Do you want to change your password?',

  'حسناً': 'OK', 'تم': 'Done', 'حدث خطأ، حاول مجدداً': 'Something went wrong, try again',
  'تعذّر الاتصال بالخادم، قد يكون بطيئاً الآن. حاول مجدداً بعد لحظات.':
      'Could not reach the server, it may be slow now. Try again shortly.',
  'لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مجدداً.': 'No internet connection. Check it and try again.',
  'تعذّر الاتصال بالخادم. حاول مجدداً.': 'Could not reach the server. Try again.',
  'تعذّر الاتصال الآمن بالخادم. حاول مجدداً.': 'Secure connection failed. Try again.',

  'البطاقة الفضية': 'Silver Card', 'البطاقة الذهبية': 'Gold Card',
  'باقٍ ': 'Left ', ' للوصول إلى ': ' to reach ',
  'أنت في المركز ': 'You are ranked ', 'رصيدك الآن ': 'Your balance: ',
  'المستوى: {name}': 'Level: {name}',
  'تحتاج {n} Wz للتقدم': 'You need {n} Wz to move up',
  'رصيدك الآن {n} Wz': 'Your balance is {n} Wz',
  'من أصل {n} في {zone}': 'of {n} in {zone}',
  'لوحة الصدارة · {zone}': 'Leaderboard · {zone}',
  '{n} نقاط': '{n} points',
  'المستوى: ': 'Level: ',
  'باقٍ {n} Wz': 'Left {n} Wz',

  'انضم إلى تطبيق WIIN ♻️ وابدأ بجمع القارورات وكسب النقاط والفوز بالهدايا! 🎁':
      'Join WIIN ♻️ and start collecting bottles, earning points and winning gifts! 🎁',
  'استخدم رمز دعوتي عند التسجيل:': 'Use my invite code when you sign up:',
  'حمّل التطبيق الآن وابدأ الربح معنا.': 'Download the app now and start earning with us.',

  'تغيير اللغة': 'Change language', 'اللغة': 'Language',

  // deposit limits + scanner guide
  'الحد الأقصى {n} قارورة في الإيداع الواحد': 'Maximum {n} bottles per deposit',
  'انتظر قبل الإيداع التالي': 'Wait before your next deposit',
  'يمكنك إيداع قارورات جديدة بعد': 'You can deposit new bottles in',
  'يمكنك الإيداع الآن': 'You can deposit now',
  'انتهى وقت الانتظار، يمكنك مسح رمز QR وإيداع قارورات جديدة':
      'The wait is over — scan a QR code to deposit new bottles',
  'إيداع الآن': 'Deposit now',
  'دقيقة': 'min', 'ثانية': 'sec',
  // notifications
  'قبل {n} دقيقة': '{n} min ago', 'قبل {n} ساعة': '{n} h ago',
  'قبل {n} أيام': '{n} days ago', 'قبل {n} أسابيع': '{n} weeks ago',
  'قبل {n} أشهر': '{n} months ago', 'قبل {n} سنة': '{n} year(s) ago',
  'رسالة موجّهة إليك': 'Sent to you personally',
  'إشعار عام': 'General notification',
  'إغلاق': 'Close',

  // tutorial / settings
  'كيفية استخدام التطبيق': 'How to use the app',
  'الخطوة {n} من {t}': 'Step {n} of {t}',
  'ابدأ': 'Get started',
  'اجمع القارورات': 'Collect bottles',
  'اجمع القارورات البلاستيكية الفارغة في المنزل بدل رميها.':
      'Gather your empty plastic bottles at home instead of throwing them away.',
  'أودعها في نقطة الجمع': 'Drop them at a collection point',
  'اعثر على أقرب نقطة جمع على الخريطة وأودع قاروراتك هناك.':
      'Find the nearest collection point on the map and drop your bottles there.',
  'امسح واكسب النقاط': 'Scan and earn points',
  'امسح رمز QR الخاص بنقطة الجمع لتكسب نقاط Wz، واستبدلها بهدايا ومكافآت.':
      'Scan the collection point QR code to earn Wz points, then redeem them for gifts and rewards.',

  // daily bonus
  'المكافأة اليومية': 'Daily bonus',
  'مكافأتك اليومية': 'Your daily bonus',
  'استلم نقاطك المجانية لهذا اليوم': 'Claim your free points for today',
  'استلم المكافأة': 'Claim bonus',
  'استلم': 'Claim',
  'تم استلام مكافأتك!': 'Bonus claimed!',
  'عُد غداً لمكافأة جديدة 🎁': 'Come back tomorrow for a new bonus 🎁',
  'استلم {n} Wz مجاناً اليوم': 'Claim {n} Wz free today',
  'المكافأة القادمة بعد {t}': 'Next bonus in {t}',
  'مكافأتك اليومية بانتظارك 🎁': 'Your daily bonus is waiting 🎁',

  // auth screen — account switch prompts (the verbs already exist above)
  'لديك حساب بالفعل؟': 'Already have an account?',
  'ليس لديك حساب؟': 'Don\'t have an account?',
  // profile — phone is read-only
  'لا يمكن تغيير رقم الهاتف. تواصل مع الدعم لتعديله.': 'Your phone number can\'t be changed. Contact support to update it.',

  // holder: edit point + bag full
  'تعديل معلومات النقطة': 'Edit point info',
  'يُرسل التعديل كطلب للإدارة، ولا يُطبّق إلا بعد الموافقة. لا يمكن تغيير موقع النقطة على الخريطة.': 'The change is sent to the admin and only applies after approval. The map location can\'t be changed.',
  'اسم النقطة': 'Point name',
  'المنطقة': 'Area',
  'الهاتف': 'Phone',
  'تفاصيل إضافية': 'Extra details',
  'من': 'From',
  'إلى': 'To',
  'مسح': 'Clear',
  'الحالي: {v}': 'Current: {v}',
  'هل تريد إرسال طلب التعديل إلى الإدارة؟': 'Send the edit request to the admin?',
  'تأكيد الإرسال': 'Confirm send',
  'الإبلاغ عن امتلاء الحاوية': 'Report container full',
  'سيصل التنبيه إلى الإدارة وإلى موظف الميدان لتفريغ الحاوية. هل تؤكد؟': 'The alert goes to the admin and the field agent to empty the container. Confirm?',
  'نعم، الحاوية ممتلئة': 'Yes, the container is full',
  'تم إرسال تنبيه الامتلاء ✓': 'Full-container alert sent ✓',
  // map: point types
  'نقطة جمع خاصة': 'Private collection point',
  'هذه النقطة (باللون الأصفر) مخصّصة لأعضاء المكان فقط (مثل نادٍ رياضي أو مؤسسة)، وليست متاحة لعامة المستخدمين للإيداع.': 'This point (in yellow) is for the venue\'s members only (e.g. a gym or an institution) and isn\'t open for public deposits.',
  'عرض التفاصيل': 'View details',
  'أنواع نقاط الجمع': 'Collection point types',
  'النقاط الخضراء: متاحة لكل المستخدمين لإيداع القارورات.': 'Green points: open to all users for depositing bottles.',
  'النقاط الصفراء: خاصة بأعضاء المكان فقط (نادٍ، مؤسسة…).': 'Yellow points: reserved for the venue\'s members only (club, institution…).',
  'فهمت': 'Got it',

  // user profile + achievements
  'تعذّر تحميل الملف الشخصي': 'Couldn\'t load profile',
  'المركز {n} من {m}': 'Rank {n} of {m}',
  'انضم {t}': 'Joined {t}',
  'قارورة': 'Bottles',
  'عملية إيداع': 'Deposits',
  'الإنجازات': 'Achievements',
  'أول إيداع': 'First deposit',
  'أودعت قاروراتك الأولى': 'Deposited your first bottles',
  'جامع مبتدئ': 'Beginner collector',
  'أودعت 10 قارورات': 'Deposited 10 bottles',
  'جامع نشيط': 'Active collector',
  'أودعت 50 قارورة': 'Deposited 50 bottles',
  'بطل التدوير': 'Recycling champion',
  'أودعت 100 قارورة': 'Deposited 100 bottles',
  'أسطورة القارورات': 'Bottle legend',
  'أودعت 500 قارورة': 'Deposited 500 bottles',
  'المستوى الفضي': 'Silver tier',
  'وصلت إلى المستوى الفضي': 'Reached the silver tier',
  'المستوى الذهبي': 'Gold tier',
  'وصلت إلى المستوى الذهبي': 'Reached the gold tier',
  'صديق البيئة': 'Eco friend',
  'دعوت صديقاً واحداً': 'Referred one friend',
  'سفير WIIN': 'WIIN ambassador',
  'دعوت 5 أصدقاء': 'Referred 5 friends',
  'في القمة': 'At the top',
  'ضمن أفضل 3 في ولايتك': 'Top 3 in your wilaya',

  'كيف تودع قاروراتك؟': 'How to deposit your bottles',
  'اجمع القارورات الفارغة': 'Collect your empty bottles',
  'أودعها في أقرب نقطة جمع إليك': 'Drop them at your nearest collection point',
  'امسح رمز QR الخاص بنقطة الجمع واكسب نقاطك': 'Scan the collection point QR code and earn your points',
  'فهمت، لنبدأ': 'Got it, let\'s start',
};
