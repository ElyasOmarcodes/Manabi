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
  String get errGeminiQuota =>
      'بلغ استعمال Gemini حدَّه اليومي. أعد المحاولة بعد ساعات، أو فعّل الفوترة للمفتاح في Google AI Studio.';

  @override
  String get errGeminiUnavailable =>
      'لم تستجب خدمة الذكاء الاصطناعي في الوقت المحدد. تحقّق من الاتصال وأعد المحاولة.';

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

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get previous7Days => 'الأيام السبعة الماضية';

  @override
  String get earlier => 'أقدم';

  @override
  String get libraryHeroTitle => 'مكتبة تراث';

  @override
  String get libraryHeroBody =>
      'كتب التفسير والحديث والفقه والعقيدة والتاريخ واللغة — للبحث والنقل والإحالة.';

  @override
  String get browseCategories => 'تصفّح التصنيفات';

  @override
  String get browseCategoriesSub => 'العلوم وكتبها';

  @override
  String get fullTextSub => 'ابحث داخل نصوص الكتب كلها';

  @override
  String get allBooks => 'كل الكتب';

  @override
  String get settingsApp => 'التطبيق';

  @override
  String get settingsAnswersGroup => 'الإجابات والبحث';

  @override
  String get settingsInfo => 'معلومات ومساعدة';

  @override
  String get aiStyle => 'أسلوب الذكاء الاصطناعي';

  @override
  String get dataStorage => 'البيانات والتخزين';

  @override
  String get help => 'المساعدة';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get aboutUs => 'من نحن';

  @override
  String get licenses => 'تراخيص المصادر المفتوحة';

  @override
  String get resetSettings => 'إعادة ضبط الإعدادات';

  @override
  String get resetSettingsConfirm =>
      'ستعود كل الإعدادات (ومنها المفتاح) إلى وضعها الأصلي. تبقى محادثاتك.';

  @override
  String get textSize => 'حجم النص';

  @override
  String get textSizeSample =>
      'يجيب «منابع» عن أسئلتك جوابًا موثّقًا من كتب التراث.';

  @override
  String get researchDepth => 'عمق البحث';

  @override
  String get depthQuick => 'سريع';

  @override
  String get depthStandard => 'متوسط';

  @override
  String get depthDeep => 'معمّق';

  @override
  String get depthQuickInfo => 'يقرأ صفحات أقل ويجيب بسرعة — حتى ٦ مصادر.';

  @override
  String get depthStandardInfo =>
      'توازن بين السرعة والشمول — حتى ١٤ مصدرًا وجولة بحث إضافية.';

  @override
  String get depthDeepInfo =>
      'بحث واسع وكتب أكثر وجولتان إضافيتان — حتى ١٨ مصدرًا؛ يستغرق وقتًا أطول.';

  @override
  String get depthHint => 'كلما زاد العمق، بُحث في كتب أكثر وقُرئت صفحات أكثر.';

  @override
  String get chooseLanguage => 'اختر اللغة';

  @override
  String get openLibrary => 'فتح المكتبة';

  @override
  String get openLibrarySub => 'الكتب والمؤلفون والبحث في النص';

  @override
  String get helpHowTitle => 'كيف يعمل «منابع»';

  @override
  String get helpHowBody =>
      '١. يفهم سؤالك ويصوغ كلمات البحث بالعربية.\n٢. يبحث في آلاف كتب التراث، ومنها المذهب والكتاب اللذان تذكرهما.\n٣. يقرأ أقرب الصفحات صلةً ويختارها.\n٤. يكتب الجواب من هذه الصفحات وحدها.\n٥. يطابق كل نص منقول مع الكتاب الأصلي كلمةً كلمة، وما لا يوجد يُحذف.';

  @override
  String get helpTipsTitle => 'نصائح لسؤال جيد';

  @override
  String get helpTipsBody =>
      '• اكتب سؤالك واضحًا محددًا.\n• إن أردت قول مذهب فاذكر اسمه (حنفي، شافعي، مالكي، حنبلي).\n• اذكر اسم الكتاب، أو حدّد النطاق بكتاب أو مؤلف أو تصنيف عبر زر +.\n• للمسائل الدقيقة والخلافية اختر البحث «المعمّق».';

  @override
  String get helpSourcesTitle => 'المصادر والإحالات';

  @override
  String get helpSourcesBody =>
      'يعرض زر «المصادر» تحت كل جواب جميع الإحالات: اسم الكتاب والمؤلف والجزء والصفحة والنص العربي الأصلي ورابطًا مباشرًا في تراث. وتشير الأرقام الصغيرة مثل [١] في النص إلى ذلك المصدر.';

  @override
  String get helpLimitsTitle => 'الحدود';

  @override
  String get helpLimitsBody =>
      '«منابع» ليس مفتيًا؛ إنما ينقل ما تقوله الكتب، وإن لم يجد جوابًا موثّقًا صرّح بذلك. وللحكم في حالتك الخاصة استشر عالمًا موثوقًا.';

  @override
  String get privacyStoredTitle => 'ما الذي يُحفظ';

  @override
  String get privacyStoredBody =>
      'تُحفظ محادثاتك والإجابات المحفوظة والإعدادات على جهازك وحده. لا يطلب «منابع» حسابًا ولا يجمع بيانات شخصية.';

  @override
  String get privacySentTitle => 'ما الذي يُرسل';

  @override
  String get privacySentBody =>
      'عند السؤال يُرسل نص السؤال وملخص الإجابات الأخيرة إلى خادم «منابع» (أو إلى Google Gemini في الوضع المباشر) لإعداد الجواب، وتُرسل كلمات البحث إلى turath.io. لا يحفظ الخادم الأسئلة؛ وإنما يُبقي الجواب في الذاكرة حتى ٢٠ دقيقة ليُستعاد إن انقطع الاتصال.';

  @override
  String get privacyKeyTitle => 'مفتاحك';

  @override
  String get privacyKeyBody =>
      'إذا استعملت مفتاح Gemini الخاص بك، يُحفظ في التخزين الآمن للجهاز (Keychain / Keystore) ولا يُرسل إلا إلى Google.';

  @override
  String get privacyDeleteTitle => 'الحذف';

  @override
  String get privacyDeleteBody =>
      'يمكنك حذف كل المحادثات والإعدادات في أي وقت من قسم «البيانات والتخزين».';

  @override
  String get aboutMission =>
      'غايتنا: وصول ميسَّر أمين موثَّق إلى المصادر الأصلية للعلوم الإسلامية — بالبشتو والدرية والعربية والإنجليزية.';

  @override
  String get aboutCredits => 'شكرًا لمكتبة تراث (turath.io) ولـ Nusus SDK.';

  @override
  String get sourceCode => 'الشيفرة المصدرية';

  @override
  String get dataCatalog => 'الفهرس دون اتصال';

  @override
  String get pageExcerpt =>
      'مقتطف من الصفحة — أُحيل إليه في الجواب (ليس نقلًا حرفيًا)';

  @override
  String get searchInBook => 'البحث في الكتاب';

  @override
  String get searchInBookHint => 'ابحث في هذا الكتاب';

  @override
  String get goToPage => 'انتقال إلى صفحة';

  @override
  String get printedPage => 'الصفحة المطبوعة';

  @override
  String get go => 'انتقال';

  @override
  String pageOf(int page, int total) {
    return '$page من $total';
  }

  @override
  String get bookmarkPage => 'حفظ الصفحة';

  @override
  String get removeBookmark => 'إزالة العلامة';

  @override
  String get bookmarks => 'الصفحات المحفوظة';

  @override
  String get copyPage => 'نسخ نص الصفحة';

  @override
  String get sharePage => 'مشاركة الصفحة';

  @override
  String get copyCitation => 'نسخ الإحالة';

  @override
  String get readerDisplay => 'إعدادات القراءة';

  @override
  String get lineSpacing => 'تباعد الأسطر';

  @override
  String get paperTheme => 'لون الصفحة';

  @override
  String get paperWarm => 'ورقي';

  @override
  String get paperPlain => 'عادي';

  @override
  String get paperNight => 'ليلي';

  @override
  String get continueReading => 'متابعة القراءة';

  @override
  String get recentlyRead => 'قُرئ مؤخرًا';

  @override
  String get footnotes => 'الحواشي';

  @override
  String get filters => 'التصفية';

  @override
  String get sortBy => 'الترتيب';

  @override
  String get sortRelevance => 'الأنسب';

  @override
  String get sortTitle => 'اسم الكتاب';

  @override
  String get sortAuthor => 'المؤلف';

  @override
  String get anyAuthor => 'كل المؤلفين';

  @override
  String get anyCategory => 'كل التصنيفات';

  @override
  String get anyBook => 'كل الكتب';

  @override
  String get clearFilters => 'مسح التصفية';

  @override
  String get readBook => 'قراءة الكتاب';

  @override
  String get volumeShort => 'الجزء';

  @override
  String pagesCount(int count) {
    return '$count صفحة';
  }

  @override
  String get noMatchesInBook => 'لا نتائج في هذا الكتاب.';

  @override
  String get readerTools => 'أدوات القراءة';

  @override
  String get moreReadingSettings => 'المزيد من إعدادات القراءة';

  @override
  String get readingSettings => 'القراءة والمكتبة';

  @override
  String get readingSettingsSub => 'القارئ والخطوط والتظليل والمكتبة';

  @override
  String get readingMode => 'طريقة العرض';

  @override
  String get modeScroll => 'متصل';

  @override
  String get modePages => 'صفحة صفحة';

  @override
  String get modeScrollInfo => 'تتوالى الصفحات تحت بعضها كما في تراث.';

  @override
  String get modePagesInfo => 'اسحب لتقليب كل صفحة كالكتاب المطبوع.';

  @override
  String get bookFont => 'خط الكتاب';

  @override
  String get fontNaskh => 'نسخ';

  @override
  String get fontModern => 'حديث';

  @override
  String get justifyText => 'ضبط النص';

  @override
  String get hideDiacritics => 'إخفاء الحركات';

  @override
  String get showFootnotes => 'إظهار الحواشي';

  @override
  String get keepScreenOn => 'إبقاء الشاشة مضاءة';

  @override
  String get numberStyle => 'شكل الأرقام';

  @override
  String get highlightColor => 'لون التظليل';

  @override
  String get highlights => 'التظليلات';

  @override
  String get highlight => 'تظليل';

  @override
  String get highlightSaved => 'تم التظليل';

  @override
  String get removeHighlight => 'إزالة التظليل';

  @override
  String get noHighlights => 'حدّد نصًا في الكتاب واختر «تظليل».';

  @override
  String get copyWithCitation => 'نسخ مع التوثيق';

  @override
  String get tabFavorites => 'المفضلة';

  @override
  String get addFavorite => 'إضافة إلى المفضلة';

  @override
  String get removeFavorite => 'إزالة من المفضلة';

  @override
  String get noFavoriteBooks => 'ضع نجمة على كتاب ليظهر هنا.';

  @override
  String get bookInfo => 'عن الكتاب';

  @override
  String get visitedPages => 'السجل';

  @override
  String get noVisited => 'تظهر هنا الصفحات التي تفتحها.';

  @override
  String get noBookmarksYet => 'لا علامات في هذا الكتاب بعد.';

  @override
  String get searchHeadings => 'ابحث في العناوين…';

  @override
  String get fullScreen => 'ملء الشاشة';

  @override
  String get exitFullScreen => 'الخروج من ملء الشاشة';

  @override
  String get paperSepia => 'أصفر';

  @override
  String get clearReadingHistory => 'مسح سجل القراءة';

  @override
  String get clearReadingHistoryConfirm =>
      'نسيان موضع توقفك في كل كتاب؟ تبقى العلامات والتظليلات والمفضلة.';

  @override
  String get clearReadingData => 'حذف كل بيانات القراءة';

  @override
  String get clearReadingDataConfirm =>
      'حذف كل العلامات والتظليلات والمفضلة والسجل من هذا الجهاز؟';

  @override
  String get resetReader => 'استعادة إعدادات القارئ';

  @override
  String get libraryStartTab => 'تفتح المكتبة على';

  @override
  String get readingData => 'بيانات قراءتك';

  @override
  String get smaller => 'أصغر';

  @override
  String get larger => 'أكبر';

  @override
  String get readerPreview => 'معاينة';

  @override
  String get pageText => 'الصفحة';

  @override
  String get reader => 'القارئ';

  @override
  String get shortcutsHint => 'الأسهم تقلّب الصفحات · Ctrl+F للبحث في الكتاب';

  @override
  String actPlan(int count) {
    return 'خُطّط لـ $count عمليات بحث';
  }

  @override
  String actSearch(String query, String where, int hits) {
    return 'بُحث عن «$query»$where — $hits نتيجة';
  }

  @override
  String actIn(String book) {
    return ' في $book';
  }

  @override
  String actFound(int count, int total) {
    return 'جُمعت $count مقاطع من $total نتيجة';
  }

  @override
  String actRank(int count) {
    return 'قراءة $count مقاطع وتقييمها';
  }

  @override
  String actRanked(int count, String coverage) {
    return 'أُبقي $count مقاطع · التغطية: $coverage';
  }

  @override
  String get coverageFull => 'كاملة';

  @override
  String get coveragePartial => 'جزئية';

  @override
  String get coverageNone => 'لا شيء';

  @override
  String actFollowup(String queries) {
    return 'بحث إضافي: $queries';
  }

  @override
  String actRead(int pages, int books) {
    return 'فُتحت $pages صفحات من $books كتب';
  }

  @override
  String actCompose(int count) {
    return 'كتابة الجواب من $count صفحات';
  }

  @override
  String get actVerify => 'مطابقة كل اقتباس مع الكتب';

  @override
  String get actResumed => 'استُكمل من خطوة منجزة';

  @override
  String actRetry(int count) {
    return 'انقطع الاتصال — إعادة المحاولة ($count)';
  }

  @override
  String reconnectingIn(int seconds) {
    return 'إعادة الاتصال خلال $seconds ث…';
  }

  @override
  String get showSteps => 'إظهار الخطوات';

  @override
  String get hideSteps => 'إخفاء الخطوات';

  @override
  String get writingDraft => 'مسودة — تُراجع الاقتباسات عند الانتهاء';

  @override
  String tokensCount(String count) {
    return '$count رمزًا';
  }

  @override
  String get tokenUsage => 'استهلاك الرموز';

  @override
  String get tokensInput => 'المدخلات';

  @override
  String get tokensOutput => 'المخرجات';

  @override
  String get tokensThinking => 'التفكير';

  @override
  String get tokensTotal => 'المجموع';

  @override
  String get modelCalls => 'استدعاءات النموذج';

  @override
  String get answerTime => 'الوقت';

  @override
  String get thisAnswer => 'هذا الجواب';

  @override
  String get thisQuestion => 'هذا السؤال';

  @override
  String get thisChat => 'هذه المحادثة';

  @override
  String get chatDetails => 'تفاصيل المحادثة';

  @override
  String get contextWindow => 'نافذة السياق';

  @override
  String contextWindowInfo(String used, String limit) {
    return 'أكبر طلب في هذه المحادثة: $used من $limit رمز';
  }

  @override
  String get questionsCount => 'الأسئلة';

  @override
  String get noUsageYet => 'تظهر أعداد الرموز للأجوبة المنشأة بهذا الإصدار.';

  @override
  String get copyQuestion => 'نسخ السؤال';

  @override
  String get askAgain => 'اسأل مجددًا';

  @override
  String get keepAliveText => 'يُعدّ جوابك من المصادر…';

  @override
  String get pdfBook => 'PDF';

  @override
  String get openPdf => 'فتح نسخة PDF المصورة';

  @override
  String get noPdf => 'لا توجد نسخة PDF لهذا الكتاب في تراث.';

  @override
  String get onTurath => 'المزيد في تراث';

  @override
  String get onTurathInfo => 'كتب ليست في القائمة المحلية، وُجدت في تراث';

  @override
  String get searchingTurath => 'البحث في تراث…';

  @override
  String get fontAmiri => 'الأميري (نسخ كلاسيكي)';

  @override
  String get fontScheherazade => 'شهرزاد';

  @override
  String get fontPlex => 'IBM Plex Sans Arabic';

  @override
  String get fontNotoNaskh => 'نوتو نسخ';

  @override
  String get fontVazir => 'وزير متن';
}
