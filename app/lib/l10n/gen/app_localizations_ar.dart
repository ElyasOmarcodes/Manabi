// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'منابع';

  @override
  String get tagline => 'أجوبة من كتب التراث — مع مصادرها';

  @override
  String get navChat => 'المحادثة';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get navFavorites => 'المحفوظات';

  @override
  String get navHistory => 'السجل';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get newChat => 'محادثة جديدة';

  @override
  String get chats => 'المحادثات';

  @override
  String get searchChats => 'البحث في المحادثات';

  @override
  String get noChats => 'لا توجد محادثات بعد. اطرح سؤالك الأول.';

  @override
  String get pinned => 'المثبتة';

  @override
  String get recent => 'الأخيرة';

  @override
  String get askPlaceholder => 'اسأل عن القرآن والحديث والفقه…';

  @override
  String get send => 'إرسال';

  @override
  String get stop => 'إيقاف';

  @override
  String get scopeAll => 'المكتبة كلها';

  @override
  String get scopeBook => 'كتاب';

  @override
  String get scopeAuthor => 'مؤلف';

  @override
  String get scopeCategory => 'تصنيف';

  @override
  String get scopeTitle => 'نطاق البحث';

  @override
  String get chooseBook => 'اختر كتابًا';

  @override
  String get chooseAuthor => 'اختر مؤلفًا';

  @override
  String get chooseCategory => 'اختر تصنيفًا';

  @override
  String get clearScope => 'إلغاء النطاق';

  @override
  String get answerLanguage => 'لغة الجواب';

  @override
  String get langAuto => 'بلغة السؤال';

  @override
  String get welcomeTitle => 'السلام عليكم';

  @override
  String get welcomeBody =>
      'اسأل بالبشتو أو الدرية أو العربية أو الإنجليزية. يبحث «منابع» في كتب التراث ولا يجيب إلا مما يجده فيها، مع اسم الكتاب والمؤلف والجزء والصفحة والنص العربي الأصلي.';

  @override
  String get suggestion1 => 'من روى حديث «إنما الأعمال بالنيات»؟';

  @override
  String get suggestion2 => 'ماذا تقول كتب الفقه في مس الذكر ونقض الوضوء؟';

  @override
  String get suggestion3 => 'ما معنى الإحسان في حديث جبريل؟';

  @override
  String get suggestion4 => 'ماذا قال العلماء في فضل طلب العلم؟';

  @override
  String get stagePlanning => 'فهم السؤال';

  @override
  String get stageSearching => 'البحث في مكتبة تراث';

  @override
  String get stageComposing => 'كتابة الجواب من المصادر';

  @override
  String get stageVerifying => 'مطابقة كل نص مع الكتاب';

  @override
  String foundSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'وُجدت $count صفحة',
      few: 'وُجدت $count صفحات',
      two: 'وُجدت صفحتان',
      one: 'وُجدت صفحة واحدة',
      zero: 'لم توجد صفحات',
    );
    return '$_temp0';
  }

  @override
  String get searchedFor => 'عبارات البحث';

  @override
  String get statusAnswered => 'جواب موثق';

  @override
  String get statusPartial => 'موثق جزئيًا';

  @override
  String get statusInsufficient => 'لم يوجد جواب موثق';

  @override
  String get sources => 'المصادر';

  @override
  String sourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مصدرًا',
      few: '$count مصادر',
      two: 'مصدران',
      one: 'مصدر واحد',
    );
    return '$_temp0';
  }

  @override
  String get viewSource => 'قراءة الصفحة';

  @override
  String get openLink => 'فتح في تراث';

  @override
  String get openShamela => 'فتح في الشاملة';

  @override
  String get copy => 'نسخ';

  @override
  String get copied => 'تم النسخ';

  @override
  String get share => 'مشاركة';

  @override
  String get save => 'حفظ';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get unsave => 'إزالة من المحفوظات';

  @override
  String get export => 'تصدير';

  @override
  String get exportPdf => 'مستند PDF';

  @override
  String get exportMarkdown => 'Markdown';

  @override
  String get exportText => 'نص عادي';

  @override
  String get exportChat => 'تصدير المحادثة';

  @override
  String get exported => 'تم التصدير';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get pin => 'تثبيت';

  @override
  String get unpin => 'إلغاء التثبيت';

  @override
  String get ok => 'حسنًا';

  @override
  String get deleteChatConfirm => 'حذف هذه المحادثة؟ لا يمكن التراجع.';

  @override
  String get volume => 'ج';

  @override
  String get page => 'ص';

  @override
  String get turathPage => 'صفحة تراث';

  @override
  String get author => 'المؤلف';

  @override
  String get book => 'الكتاب';

  @override
  String get category => 'التصنيف';

  @override
  String get quoteVerified => 'طوبق حرفيًا مع نص الكتاب';

  @override
  String get quoteClose => 'مطابقة قريبة — معروض كما في الكتاب تمامًا';

  @override
  String get originalText => 'النص الأصلي';

  @override
  String get opinions => 'أقوال العلماء في المصادر';

  @override
  String get notes => 'ملاحظات';

  @override
  String get relatedSources => 'صفحات بُحث فيها (ليست أدلة)';

  @override
  String get disclaimer =>
      '«منابع» ينقل ما في الكتب، وليس فتوى. للحكم الشخصي راجع عالمًا مؤهلًا.';

  @override
  String get errNetwork => 'تعذر الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get errServerNotConfigured =>
      'لم يُحدَّد خادم منابع. أضف عنوان الخادم في الإعدادات.';

  @override
  String get errNoApiKey =>
      'أضف مفتاح Gemini في الإعدادات لاستخدام الوضع المباشر.';

  @override
  String get errDirectNotOnWeb =>
      'الوضع المباشر غير متاح في المتصفح. استخدم خادم منابع.';

  @override
  String get errGeminiAuth => 'مفتاح Gemini مفقود أو غير صالح.';

  @override
  String get errGeminiQuota => 'بلغ استخدام Gemini حده. حاول لاحقًا.';

  @override
  String get errGeminiUnavailable =>
      'خدمة الذكاء الاصطناعي لا تستجيب الآن. حاول مرة أخرى.';

  @override
  String get errTurathUnavailable =>
      'تعذر الوصول إلى مكتبة تراث الآن. حاول مرة أخرى.';

  @override
  String get errRateLimited => 'أسئلة كثيرة في وقت قصير. انتظر قليلًا.';

  @override
  String get errUnauthorized => 'رفض الخادم رمز الوصول.';

  @override
  String get errInterrupted => 'انقطع هذا الجواب.';

  @override
  String get errCancelled => 'أُوقف.';

  @override
  String get errNotFound => 'غير موجود.';

  @override
  String get errGeneric => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get library => 'المكتبة';

  @override
  String get books => 'الكتب';

  @override
  String get authors => 'المؤلفون';

  @override
  String get categories => 'التصنيفات';

  @override
  String get searchBooks => 'ابحث في عناوين الكتب';

  @override
  String get searchAuthors => 'ابحث عن مؤلف';

  @override
  String booksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كتابًا',
      few: '$count كتب',
      two: 'كتابان',
      one: 'كتاب واحد',
    );
    return '$_temp0';
  }

  @override
  String get noResults => 'لا نتائج';

  @override
  String get askInThisBook => 'اسأل في هذا الكتاب';

  @override
  String get askThisAuthor => 'اسأل في مصنفات هذا المؤلف';

  @override
  String get askInCategory => 'اسأل في هذا التصنيف';

  @override
  String get tableOfContents => 'الفهرس';

  @override
  String get description => 'عن الكتاب';

  @override
  String get biography => 'الترجمة';

  @override
  String get authorBooks => 'مصنفاته في المكتبة';

  @override
  String get fullTextSearch => 'البحث في النصوص';

  @override
  String get searchInText => 'ابحث في نصوص الكتب';

  @override
  String matches(int count) {
    return '$count نتيجة';
  }

  @override
  String get readPage => 'قراءة';

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get nextPage => 'الصفحة التالية';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get loadMore => 'المزيد';

  @override
  String get noFavorites => 'تظهر هنا الأجوبة التي تحفظها.';

  @override
  String get history => 'سجل الأسئلة';

  @override
  String get searchHistory => 'ابحث في أسئلتك';

  @override
  String get noHistory => 'لا أسئلة بعد.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get interfaceLanguage => 'لغة التطبيق';

  @override
  String get defaultAnswerLanguage => 'لغة الجواب الافتراضية';

  @override
  String get arabicTextSize => 'حجم النص العربي';

  @override
  String get answers => 'الأجوبة';

  @override
  String get maxSources => 'عدد الصفحات المراجَعة لكل سؤال';

  @override
  String get connection => 'الاتصال';

  @override
  String get modeServer => 'خادم منابع';

  @override
  String get modeServerInfo =>
      'موصى به. يبقى مفتاح Gemini على الخادم ويعمل التطبيق على كل المنصات بما فيها الويب.';

  @override
  String get modeDirect => 'مباشر (مفتاحك)';

  @override
  String get modeDirectInfo =>
      'يتصل التطبيق بتراث و Gemini بنفسه باستخدام مفتاح Gemini الخاص بك المحفوظ بأمان على هذا الجهاز. غير متاح على الويب.';

  @override
  String get serverUrl => 'عنوان الخادم';

  @override
  String get accessToken => 'رمز الوصول (اختياري)';

  @override
  String get geminiKey => 'مفتاح Gemini API';

  @override
  String get geminiKeyHint => 'يُحفظ في التخزين الآمن للجهاز';

  @override
  String get modelOverride => 'نموذج Gemini (اختياري)';

  @override
  String get modelOverrideHint => 'فارغ = أحدث نموذج Flash متاح';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String connectionOk(String model) {
    return 'متصل · $model';
  }

  @override
  String get data => 'البيانات';

  @override
  String get clearHistory => 'حذف كل المحادثات';

  @override
  String get clearHistoryConfirm =>
      'حذف كل المحادثات والأجوبة المحفوظة من هذا الجهاز؟';

  @override
  String get about => 'حول';

  @override
  String get aboutBody =>
      'يبحث «منابع» في مكتبة تراث (turath.io) عبر حزمة Nusus مفتوحة المصدر، ويستعمل Gemini فقط لتخطيط البحث وترتيب الجواب من الصفحات المسترجعة. ويُطابَق كل نص مع الكتاب قبل عرضه.';

  @override
  String catalogInfo(int books, int authors, String date) {
    return 'الفهرس دون اتصال: $books كتابًا · $authors مؤلفًا ($date)';
  }

  @override
  String version(String v) {
    return 'الإصدار $v';
  }

  @override
  String get chatWith => 'اسأل منابع';

  @override
  String get question => 'السؤال';

  @override
  String get answer => 'الجواب';

  @override
  String get generatedBy => 'أنشأه «منابع» من مصادر تراث';

  @override
  String get notConfiguredTitle => 'إعداد الاتصال';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get allCategories => 'كل التصنيفات';

  @override
  String get stageReading => 'قراءة الصفحات وانتقاء الأنسب';

  @override
  String get welcomeQuestion => 'عمّ تريد أن تبحث اليوم؟';

  @override
  String get options => 'خيارات البحث';
}
