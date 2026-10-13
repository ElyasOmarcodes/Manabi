// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appName => 'منابع';

  @override
  String get tagline => 'پاسخ از کتاب‌های تراث — همراه با منابع آن';

  @override
  String get navChat => 'گفتگو';

  @override
  String get navLibrary => 'کتابخانه';

  @override
  String get navFavorites => 'ذخیره‌ها';

  @override
  String get navHistory => 'تاریخچه';

  @override
  String get navSettings => 'تنظیمات';

  @override
  String get newChat => 'گفتگوی تازه';

  @override
  String get chats => 'گفتگوها';

  @override
  String get searchChats => 'جست‌وجو در گفتگوها';

  @override
  String get noChats => 'هنوز گفتگویی نیست. نخستین پرسش خود را بپرسید.';

  @override
  String get pinned => 'سنجاق‌شده';

  @override
  String get recent => 'اخیر';

  @override
  String get askPlaceholder => 'دربارهٔ قرآن، حدیث، فقه… بپرسید';

  @override
  String get send => 'ارسال';

  @override
  String get stop => 'توقف';

  @override
  String get scopeAll => 'کل کتابخانه';

  @override
  String get scopeBook => 'کتاب';

  @override
  String get scopeAuthor => 'مؤلف';

  @override
  String get scopeCategory => 'دسته';

  @override
  String get scopeTitle => 'دامنهٔ جست‌وجو';

  @override
  String get chooseBook => 'یک کتاب انتخاب کنید';

  @override
  String get chooseAuthor => 'یک مؤلف انتخاب کنید';

  @override
  String get chooseCategory => 'یک دسته انتخاب کنید';

  @override
  String get clearScope => 'پاک کردن دامنه';

  @override
  String get answerLanguage => 'زبان پاسخ';

  @override
  String get langAuto => 'به زبان پرسش';

  @override
  String get welcomeTitle => 'السلام علیکم';

  @override
  String get welcomeBody =>
      'به پښتو، دری، عربی یا انگلیسی بپرسید. منابع در کتاب‌های کلاسیک تراث جست‌وجو می‌کند و تنها از روی آنچه می‌یابد پاسخ می‌دهد — با نام کتاب، مؤلف، جلد، صفحه و متن اصلی عربی.';

  @override
  String get suggestion1 =>
      'حدیث «إنما الأعمال بالنيات» را چه کسی روایت کرده است؟';

  @override
  String get suggestion2 => 'کتاب‌های فقه دربارهٔ لمس عورت و وضو چه می‌گویند؟';

  @override
  String get suggestion3 => 'معنای احسان در حدیث جبرئیل چیست؟';

  @override
  String get suggestion4 => 'علما دربارهٔ فضیلت طلب علم چه گفته‌اند؟';

  @override
  String get stagePlanning => 'فهم پرسش';

  @override
  String get stageSearching => 'جست‌وجو در کتابخانهٔ تراث';

  @override
  String get stageComposing => 'نوشتن پاسخ از روی منابع';

  @override
  String get stageVerifying => 'تطبیق هر نقل‌قول با کتاب';

  @override
  String foundSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صفحه یافت شد',
      one: '۱ صفحه یافت شد',
      zero: 'صفحه‌ای یافت نشد',
    );
    return '$_temp0';
  }

  @override
  String get searchedFor => 'عبارت‌های جست‌وجو';

  @override
  String get statusAnswered => 'پاسخ مستند';

  @override
  String get statusPartial => 'تا اندازه‌ای مستند';

  @override
  String get statusInsufficient => 'پاسخ مستندی یافت نشد';

  @override
  String get sources => 'منابع';

  @override
  String sourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منبع',
      one: '۱ منبع',
    );
    return '$_temp0';
  }

  @override
  String get viewSource => 'خواندن صفحه';

  @override
  String get openLink => 'باز کردن در تراث';

  @override
  String get openShamela => 'باز کردن در شامله';

  @override
  String get copy => 'رونوشت';

  @override
  String get copied => 'رونوشت شد';

  @override
  String get share => 'اشتراک';

  @override
  String get save => 'ذخیره';

  @override
  String get saved => 'ذخیره شد';

  @override
  String get unsave => 'حذف از ذخیره‌ها';

  @override
  String get export => 'خروجی';

  @override
  String get exportPdf => 'سند PDF';

  @override
  String get exportMarkdown => 'Markdown';

  @override
  String get exportText => 'متن ساده';

  @override
  String get exportChat => 'خروجی گفتگو';

  @override
  String get exported => 'خروجی گرفته شد';

  @override
  String get retry => 'تلاش دوباره';

  @override
  String get cancel => 'لغو';

  @override
  String get delete => 'حذف';

  @override
  String get rename => 'تغییر نام';

  @override
  String get pin => 'سنجاق';

  @override
  String get unpin => 'برداشتن سنجاق';

  @override
  String get ok => 'باشه';

  @override
  String get deleteChatConfirm => 'این گفتگو حذف شود؟ این کار برگشت‌پذیر نیست.';

  @override
  String get volume => 'ج';

  @override
  String get page => 'ص';

  @override
  String get turathPage => 'صفحهٔ تراث';

  @override
  String get author => 'مؤلف';

  @override
  String get book => 'کتاب';

  @override
  String get category => 'دسته';

  @override
  String get quoteVerified => 'واژه به واژه با کتاب تطبیق داده شد';

  @override
  String get quoteClose => 'تطبیق نزدیک — دقیقاً مانند متن کتاب نشان داده شده';

  @override
  String get originalText => 'متن اصلی';

  @override
  String get opinions => 'دیدگاه‌های علما در منابع';

  @override
  String get notes => 'یادداشت‌ها';

  @override
  String get relatedSources => 'صفحه‌هایی که جست‌وجو شدند (دلیل نیستند)';

  @override
  String get disclaimer =>
      'منابع آنچه را کتاب‌ها می‌گویند نقل می‌کند؛ فتوا نیست. برای حکم شخصی با عالمی شایسته مشورت کنید.';

  @override
  String get errNetwork =>
      'اتصال برقرار نشد. اینترنت خود را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get errServerNotConfigured =>
      'سرور منابع تنظیم نشده است. نشانی سرور را در تنظیمات وارد کنید.';

  @override
  String get errNoApiKey =>
      'برای حالت مستقیم کلید Gemini خود را در تنظیمات وارد کنید.';

  @override
  String get errDirectNotOnWeb =>
      'حالت مستقیم در مرورگر در دسترس نیست. از سرور منابع استفاده کنید.';

  @override
  String get errGeminiAuth => 'کلید Gemini وجود ندارد یا نادرست است.';

  @override
  String get errGeminiQuota =>
      'سقف استفادهٔ امروز Gemini پر شده است. چند ساعت بعد دوباره تلاش کنید، یا برای کلید در Google AI Studio صورت‌حساب را فعال کنید.';

  @override
  String get errGeminiUnavailable =>
      'سرویس هوش مصنوعی در زمان مقرر پاسخ نداد. اینترنت را بررسی و دوباره تلاش کنید.';

  @override
  String get errTurathUnavailable =>
      'اکنون به کتابخانهٔ تراث دسترسی نیست. دوباره تلاش کنید.';

  @override
  String get errRateLimited => 'پرسش‌های زیاد در زمان کوتاه. کمی صبر کنید.';

  @override
  String get errUnauthorized => 'سرور توکن دسترسی را نپذیرفت.';

  @override
  String get errInterrupted => 'این پاسخ نیمه‌کاره ماند.';

  @override
  String get errCancelled => 'متوقف شد.';

  @override
  String get errNotFound => 'یافت نشد.';

  @override
  String get errGeneric => 'مشکلی پیش آمد. دوباره تلاش کنید.';

  @override
  String get library => 'کتابخانه';

  @override
  String get books => 'کتاب‌ها';

  @override
  String get authors => 'مؤلفان';

  @override
  String get categories => 'دسته‌ها';

  @override
  String get searchBooks => 'جست‌وجوی نام کتاب';

  @override
  String get searchAuthors => 'جست‌وجوی مؤلف';

  @override
  String booksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کتاب',
      one: '۱ کتاب',
    );
    return '$_temp0';
  }

  @override
  String get noResults => 'نتیجه‌ای نیست';

  @override
  String get askInThisBook => 'پرسش در این کتاب';

  @override
  String get askThisAuthor => 'پرسش در آثار این مؤلف';

  @override
  String get askInCategory => 'پرسش در این دسته';

  @override
  String get tableOfContents => 'فهرست';

  @override
  String get description => 'دربارهٔ کتاب';

  @override
  String get biography => 'زندگی‌نامه';

  @override
  String get authorBooks => 'آثار در کتابخانه';

  @override
  String get fullTextSearch => 'جست‌وجوی متن';

  @override
  String get searchInText => 'جست‌وجو در متن کتاب‌ها (عربی)';

  @override
  String matches(int count) {
    return '$count نتیجه';
  }

  @override
  String get readPage => 'خواندن';

  @override
  String get previousPage => 'صفحهٔ قبل';

  @override
  String get nextPage => 'صفحهٔ بعد';

  @override
  String get loading => 'در حال بارگذاری…';

  @override
  String get loadMore => 'بیشتر';

  @override
  String get noFavorites => 'پاسخ‌هایی که ذخیره کنید اینجا نمایش داده می‌شوند.';

  @override
  String get history => 'تاریخچهٔ پرسش‌ها';

  @override
  String get searchHistory => 'جست‌وجو در پرسش‌های شما';

  @override
  String get noHistory => 'هنوز پرسشی نیست.';

  @override
  String get settings => 'تنظیمات';

  @override
  String get appearance => 'ظاهر';

  @override
  String get theme => 'پوسته';

  @override
  String get themeSystem => 'سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String get interfaceLanguage => 'زبان برنامه';

  @override
  String get defaultAnswerLanguage => 'زبان پیش‌فرض پاسخ';

  @override
  String get arabicTextSize => 'اندازهٔ متن عربی';

  @override
  String get answers => 'پاسخ‌ها';

  @override
  String get maxSources => 'شمار صفحه‌های بررسی‌شده برای هر پرسش';

  @override
  String get connection => 'اتصال';

  @override
  String get modeServer => 'سرور منابع';

  @override
  String get modeServerInfo =>
      'پیشنهادی. کلید Gemini روی سرور می‌ماند و برنامه روی همهٔ سکوها، حتی وب، کار می‌کند.';

  @override
  String get modeDirect => 'مستقیم (کلید شخصی)';

  @override
  String get modeDirectInfo =>
      'برنامه خودش با کلید Gemini شما که به‌طور امن روی همین دستگاه نگه‌داری می‌شود، با تراث و Gemini ارتباط می‌گیرد. کتاب‌ها بدون کلید هم باز می‌شوند؛ فقط پاسخ‌های هوش مصنوعی به آن نیاز دارند.';

  @override
  String get serverUrl => 'نشانی سرور';

  @override
  String get accessToken => 'توکن دسترسی (اختیاری)';

  @override
  String get geminiKey => 'کلید API جمنای';

  @override
  String get geminiKeyHint => 'در حافظهٔ امن دستگاه نگه‌داری می‌شود';

  @override
  String get modelOverride => 'مدل Gemini (اختیاری)';

  @override
  String get modelOverrideHint => 'خالی = تازه‌ترین مدل Flash';

  @override
  String get testConnection => 'آزمایش اتصال';

  @override
  String connectionOk(String model) {
    return 'وصل است · $model';
  }

  @override
  String get data => 'داده‌ها';

  @override
  String get clearHistory => 'حذف همهٔ گفتگوها';

  @override
  String get clearHistoryConfirm =>
      'همهٔ گفتگوها و پاسخ‌های ذخیره‌شده از این دستگاه حذف شوند؟';

  @override
  String get about => 'درباره';

  @override
  String get aboutBody =>
      'منابع از راه کیت متن‌باز Nusus در کتابخانهٔ تراث (turath.io) جست‌وجو می‌کند و Gemini را تنها برای برنامه‌ریزی جست‌وجو و چیدن پاسخ از روی صفحه‌های یافته‌شده به کار می‌برد. هر نقل‌قول پیش از نمایش با متن کتاب تطبیق داده می‌شود.';

  @override
  String catalogInfo(int books, int authors, String date) {
    return 'فهرست آفلاین: $books کتاب · $authors مؤلف ($date)';
  }

  @override
  String version(String v) {
    return 'نسخهٔ $v';
  }

  @override
  String get chatWith => 'از منابع بپرسید';

  @override
  String get question => 'پرسش';

  @override
  String get answer => 'پاسخ';

  @override
  String get generatedBy => 'ساخته‌شده توسط منابع از منابع تراث';

  @override
  String get notConfiguredTitle => 'اتصال را تنظیم کنید';

  @override
  String get openSettings => 'باز کردن تنظیمات';

  @override
  String get allCategories => 'همه دسته‌ها';

  @override
  String get stageReading => 'خواندن و گزینش صفحه‌ها';

  @override
  String get welcomeQuestion => 'امروز دربارهٔ چه می‌خواهید پژوهش کنید؟';

  @override
  String get options => 'گزینه‌های جست‌وجو';

  @override
  String get today => 'امروز';

  @override
  String get yesterday => 'دیروز';

  @override
  String get previous7Days => 'هفتهٔ گذشته';

  @override
  String get earlier => 'پیش‌تر';

  @override
  String get libraryHeroTitle => 'کتابخانهٔ تراث';

  @override
  String get libraryHeroBody =>
      'کتاب‌های کلاسیک تفسیر، حدیث، فقه، عقیده، تاریخ و زبان — قابل جست‌وجو و استناد.';

  @override
  String get browseCategories => 'مرور دسته‌ها';

  @override
  String get browseCategoriesSub => 'علوم و کتاب‌هایشان';

  @override
  String get fullTextSub => 'جست‌وجو در متن همهٔ کتاب‌ها';

  @override
  String get allBooks => 'همه کتاب‌ها';

  @override
  String get settingsApp => 'برنامه';

  @override
  String get settingsAnswersGroup => 'پاسخ‌ها و پژوهش';

  @override
  String get settingsInfo => 'اطلاعات و راهنما';

  @override
  String get aiStyle => 'سبک هوش مصنوعی';

  @override
  String get dataStorage => 'داده‌ها و حافظه';

  @override
  String get help => 'راهنما';

  @override
  String get privacyPolicy => 'سیاست حریم خصوصی';

  @override
  String get aboutUs => 'درباره ما';

  @override
  String get licenses => 'مجوزهای متن‌باز';

  @override
  String get resetSettings => 'بازنشانی تنظیمات';

  @override
  String get resetSettingsConfirm =>
      'همه تنظیمات (از جمله کلید) بازنشانی می‌شوند. گفتگوهای شما باقی می‌مانند.';

  @override
  String get textSize => 'اندازه متن';

  @override
  String get textSizeSample =>
      'منابع از کتاب‌های تراث به پرسش‌های شما پاسخ مستند می‌دهد.';

  @override
  String get researchDepth => 'سطح پژوهش';

  @override
  String get depthQuick => 'سریع';

  @override
  String get depthStandard => 'متوسط';

  @override
  String get depthDeep => 'عمیق';

  @override
  String get depthQuickInfo =>
      'صفحه‌های کمتری می‌خواند و زود پاسخ می‌دهد — تا ۶ منبع.';

  @override
  String get depthStandardInfo =>
      'توازن سرعت و گستردگی — تا ۱۴ منبع و یک جست‌وجوی تکمیلی.';

  @override
  String get depthDeepInfo =>
      'جست‌وجوی گسترده، کتاب‌های بیشتر و دو دور تکمیلی — تا ۱۸ منبع؛ زمان بیشتری می‌برد.';

  @override
  String get depthHint =>
      'هرچه عمیق‌تر باشد، کتاب‌های بیشتری جست‌وجو و خوانده می‌شود.';

  @override
  String get chooseLanguage => 'زبان را انتخاب کنید';

  @override
  String get openLibrary => 'باز کردن کتابخانه';

  @override
  String get openLibrarySub => 'کتاب‌ها، مؤلفان و جست‌وجوی متن';

  @override
  String get helpHowTitle => 'منابع چگونه کار می‌کند';

  @override
  String get helpHowBody =>
      '۱. پرسش شما را می‌فهمد و واژه‌های جست‌وجو را به عربی می‌سازد.\n۲. در هزاران کتاب تراث جست‌وجو می‌کند، از جمله مذهب و کتابی که نام می‌برید.\n۳. مرتبط‌ترین صفحه‌ها را می‌خواند و برمی‌گزیند.\n۴. فقط از همین صفحه‌ها پاسخ می‌نویسد.\n۵. هر عبارت نقل‌شده را کلمه به کلمه با کتاب اصلی مقایسه می‌کند؛ اگر پیدا نشود، حذف می‌شود.';

  @override
  String get helpTipsTitle => 'راهنمای پرسش خوب';

  @override
  String get helpTipsBody =>
      '• پرسش را روشن و مشخص بنویسید.\n• اگر نظر یک مذهب را می‌خواهید، نام مذهب را بنویسید (حنفی، شافعی، مالکی، حنبلی).\n• نام کتاب را بیاورید، یا با + دامنه را به یک کتاب، مؤلف یا دسته محدود کنید.\n• برای مسائل دشوار و اختلافی پژوهش «عمیق» را انتخاب کنید.';

  @override
  String get helpSourcesTitle => 'منابع و ارجاع‌ها';

  @override
  String get helpSourcesBody =>
      'دکمه «منابع» زیر هر پاسخ همه ارجاع‌ها را نشان می‌دهد: نام کتاب، مؤلف، جلد، صفحه، متن اصلی عربی و پیوند مستقیم در تراث. شماره‌های کوچک مانند [۱] در متن به همان منبع اشاره دارند.';

  @override
  String get helpLimitsTitle => 'محدودیت‌ها';

  @override
  String get helpLimitsBody =>
      'منابع مفتی نیست؛ آنچه کتاب‌ها می‌گویند را نقل می‌کند. اگر پاسخ مستندی پیدا نشود، آشکارا می‌گوید. برای حکم شخصی با عالمی معتمد مشورت کنید.';

  @override
  String get privacyStoredTitle => 'چه چیزی ذخیره می‌شود';

  @override
  String get privacyStoredBody =>
      'گفتگوها، پاسخ‌های ذخیره‌شده و تنظیمات شما فقط روی دستگاه خودتان نگه داشته می‌شوند. منابع حساب کاربری نمی‌خواهد و اطلاعات شخصی جمع نمی‌کند.';

  @override
  String get privacySentTitle => 'چه چیزی ارسال می‌شود';

  @override
  String get privacySentBody =>
      'هنگام پرسش، متن پرسش و خلاصهٔ پاسخ‌های اخیر برای ساختن پاسخ به سرور منابع (یا در حالت مستقیم به Google Gemini) و واژه‌های جست‌وجو به turath.io فرستاده می‌شود. سرور پرسش‌ها را ذخیره نمی‌کند؛ فقط برای بازیابی پاسخ قطع‌شده تا ۲۰ دقیقه در حافظه نگه می‌دارد.';

  @override
  String get privacyKeyTitle => 'کلید شما';

  @override
  String get privacyKeyBody =>
      'اگر کلید Gemini خود را به کار ببرید، در حافظهٔ امن دستگاه (Keychain / Keystore) نگه داشته و فقط به Google فرستاده می‌شود.';

  @override
  String get privacyDeleteTitle => 'حذف';

  @override
  String get privacyDeleteBody =>
      'از بخش «داده‌ها و حافظه» هر زمان می‌توانید همهٔ گفتگوها و تنظیمات را حذف کنید.';

  @override
  String get aboutMission =>
      'هدف ما: دسترسی آسان، امانت‌دارانه و مستند به منابع اصلی علوم اسلامی — به پشتو، دری، عربی و انگلیسی.';

  @override
  String get aboutCredits =>
      'با سپاس از کتابخانهٔ تراث (turath.io) و Nusus SDK.';

  @override
  String get sourceCode => 'کد منبع';

  @override
  String get dataCatalog => 'فهرست آفلاین';

  @override
  String get pageExcerpt =>
      'بخشی از صفحه — در پاسخ به آن ارجاع شده (نقل کلمه به کلمه نیست)';

  @override
  String get searchInBook => 'جست‌وجو در کتاب';

  @override
  String get searchInBookHint => 'در این کتاب جست‌وجو کنید (عربی)';

  @override
  String get goToPage => 'رفتن به صفحه';

  @override
  String get printedPage => 'صفحهٔ چاپی';

  @override
  String get go => 'برو';

  @override
  String pageOf(int page, int total) {
    return '$page از $total';
  }

  @override
  String get bookmarkPage => 'نشانه‌گذاری صفحه';

  @override
  String get removeBookmark => 'حذف نشانه';

  @override
  String get bookmarks => 'صفحه‌های نشانه‌گذاری‌شده';

  @override
  String get copyPage => 'رونوشت متن صفحه';

  @override
  String get sharePage => 'اشتراک صفحه';

  @override
  String get copyCitation => 'رونوشت ارجاع';

  @override
  String get readerDisplay => 'نمای خواندن';

  @override
  String get lineSpacing => 'فاصلهٔ خطوط';

  @override
  String get paperTheme => 'رنگ صفحه';

  @override
  String get paperWarm => 'کاغذی';

  @override
  String get paperPlain => 'ساده';

  @override
  String get paperNight => 'شب';

  @override
  String get continueReading => 'ادامهٔ خواندن';

  @override
  String get recentlyRead => 'اخیراً خوانده‌شده';

  @override
  String get footnotes => 'پاورقی‌ها';

  @override
  String get filters => 'فیلترها';

  @override
  String get sortBy => 'مرتب‌سازی';

  @override
  String get sortRelevance => 'مرتبط‌ترین';

  @override
  String get sortTitle => 'نام کتاب';

  @override
  String get sortAuthor => 'مؤلف';

  @override
  String get anyAuthor => 'هر مؤلف';

  @override
  String get anyCategory => 'هر دسته';

  @override
  String get anyBook => 'هر کتاب';

  @override
  String get clearFilters => 'پاک کردن فیلترها';

  @override
  String get readBook => 'خواندن کتاب';

  @override
  String get volumeShort => 'جلد';

  @override
  String pagesCount(int count) {
    return '$count صفحه';
  }

  @override
  String get noMatchesInBook => 'در این کتاب نتیجه‌ای پیدا نشد.';

  @override
  String get readerTools => 'ابزار مطالعه';

  @override
  String get moreReadingSettings => 'تنظیمات بیشتر مطالعه';

  @override
  String get readingSettings => 'مطالعه و کتابخانه';

  @override
  String get readingSettingsSub => 'خواننده، قلم‌ها، هایلایت و کتابخانه';

  @override
  String get readingMode => 'حالت مطالعه';

  @override
  String get modeScroll => 'پیوسته';

  @override
  String get modePages => 'صفحه به صفحه';

  @override
  String get modeScrollInfo => 'صفحه‌ها پشت سر هم می‌آیند، مانند تراث.';

  @override
  String get modePagesInfo => 'برای ورق زدن هر صفحه بکشید، مانند کتاب چاپی.';

  @override
  String get bookFont => 'قلم کتاب';

  @override
  String get fontNaskh => 'نسخ';

  @override
  String get fontModern => 'مدرن';

  @override
  String get justifyText => 'تراز کردن سطرها';

  @override
  String get hideDiacritics => 'پنهان کردن اعراب';

  @override
  String get showFootnotes => 'نمایش پاورقی‌ها';

  @override
  String get keepScreenOn => 'روشن ماندن صفحه';

  @override
  String get numberStyle => 'شکل اعداد';

  @override
  String get highlightColor => 'رنگ هایلایت';

  @override
  String get highlights => 'هایلایت‌ها';

  @override
  String get highlight => 'هایلایت';

  @override
  String get highlightSaved => 'هایلایت شد';

  @override
  String get removeHighlight => 'حذف برجسته‌سازی';

  @override
  String get noHighlights => 'متنی را در کتاب انتخاب و «هایلایت» را بزنید.';

  @override
  String get copyWithCitation => 'کپی با ارجاع';

  @override
  String get tabFavorites => 'برگزیده';

  @override
  String get addFavorite => 'افزودن به برگزیده‌ها';

  @override
  String get removeFavorite => 'حذف از برگزیده‌ها';

  @override
  String get noFavoriteBooks => 'به کتابی ستاره بدهید تا اینجا بماند.';

  @override
  String get bookInfo => 'درباره کتاب';

  @override
  String get visitedPages => 'تاریخچه';

  @override
  String get noVisited => 'صفحه‌هایی که باز می‌کنید اینجا می‌آیند.';

  @override
  String get noBookmarksYet => 'هنوز نشانکی در این کتاب نیست.';

  @override
  String get searchHeadings => 'جستجو در عنوان‌ها…';

  @override
  String get fullScreen => 'تمام صفحه';

  @override
  String get exitFullScreen => 'خروج از تمام صفحه';

  @override
  String get paperSepia => 'زرد';

  @override
  String get clearReadingHistory => 'پاک کردن تاریخچه مطالعه';

  @override
  String get clearReadingHistoryConfirm =>
      'محل توقف شما در همه کتاب‌ها فراموش شود؟ نشانک‌ها، هایلایت‌ها و برگزیده‌ها می‌مانند.';

  @override
  String get clearReadingData => 'حذف همه داده‌های مطالعه';

  @override
  String get clearReadingDataConfirm =>
      'همه نشانک‌ها، هایلایت‌ها، برگزیده‌ها و تاریخچه از این دستگاه حذف شوند؟';

  @override
  String get resetReader => 'بازنشانی تنظیمات خواننده';

  @override
  String get libraryStartTab => 'کتابخانه با این باز شود';

  @override
  String get readingData => 'داده‌های مطالعه شما';

  @override
  String get smaller => 'کوچک‌تر';

  @override
  String get larger => 'بزرگ‌تر';

  @override
  String get readerPreview => 'پیش‌نمایش';

  @override
  String get pageText => 'صفحه';

  @override
  String get reader => 'خواننده';

  @override
  String get shortcutsHint =>
      'کلیدهای جهت صفحه را ورق می‌زنند · Ctrl+F جستجو در کتاب';

  @override
  String actPlan(int count) {
    return '$count جستجو برنامه‌ریزی شد';
  }

  @override
  String actSearch(String query, String where, int hits) {
    return '«$query» جستجو شد$where — $hits نتیجه';
  }

  @override
  String actIn(String book) {
    return ' در $book';
  }

  @override
  String actFound(int count, int total) {
    return '$count بخش از $total نتیجه جمع شد';
  }

  @override
  String actRank(int count) {
    return 'خواندن و سنجیدن $count بخش';
  }

  @override
  String actRanked(int count, String coverage) {
    return '$count بخش نگه داشته شد · پوشش: $coverage';
  }

  @override
  String get coverageFull => 'کامل';

  @override
  String get coveragePartial => 'جزئی';

  @override
  String get coverageNone => 'هیچ';

  @override
  String actFollowup(String queries) {
    return 'جستجوی بیشتر: $queries';
  }

  @override
  String actRead(int pages, int books) {
    return '$pages صفحه از $books کتاب باز شد';
  }

  @override
  String actCompose(int count) {
    return 'نوشتن پاسخ از $count صفحه';
  }

  @override
  String get actVerify => 'تطبیق هر نقل‌قول با کتاب‌ها';

  @override
  String get actResumed => 'از مرحلهٔ تمام‌شده ادامه یافت';

  @override
  String actRetry(int count) {
    return 'اتصال قطع شد — تلاش دوباره ($count)';
  }

  @override
  String reconnectingIn(int seconds) {
    return 'اتصال دوباره تا $seconds ثانیه…';
  }

  @override
  String get showSteps => 'نمایش مراحل';

  @override
  String get hideSteps => 'پنهان کردن مراحل';

  @override
  String get writingDraft => 'پیش‌نویس — نقل‌قول‌ها پس از پایان بررسی می‌شوند';

  @override
  String tokensCount(String count) {
    return '$count توکن';
  }

  @override
  String get tokenUsage => 'مصرف توکن';

  @override
  String get tokensInput => 'ورودی';

  @override
  String get tokensOutput => 'خروجی';

  @override
  String get tokensThinking => 'تفکر';

  @override
  String get tokensTotal => 'مجموع';

  @override
  String get modelCalls => 'فراخوانی مدل';

  @override
  String get answerTime => 'زمان';

  @override
  String get thisAnswer => 'این پاسخ';

  @override
  String get thisQuestion => 'این پرسش';

  @override
  String get thisChat => 'این گفتگو';

  @override
  String get chatDetails => 'جزئیات گفتگو';

  @override
  String get contextWindow => 'پنجرهٔ زمینه';

  @override
  String contextWindowInfo(String used, String limit) {
    return 'بزرگ‌ترین درخواست این گفتگو: $used از $limit توکن';
  }

  @override
  String get questionsCount => 'پرسش‌ها';

  @override
  String get noUsageYet =>
      'شمار توکن برای پاسخ‌های این نسخه نمایش داده می‌شود.';

  @override
  String get copyQuestion => 'کپی پرسش';

  @override
  String get askAgain => 'دوباره بپرس';

  @override
  String get keepAliveText => 'پاسخ شما از منابع آماده می‌شود…';

  @override
  String get pdfBook => 'PDF';

  @override
  String get openPdf => 'باز کردن PDF چاپی';

  @override
  String get noPdf => 'این کتاب در تراث PDF ندارد.';

  @override
  String get onTurath => 'بیشتر در تراث';

  @override
  String get onTurathInfo =>
      'کتاب‌هایی که در فهرست آفلاین نبودند و در تراث یافت شدند';

  @override
  String get searchingTurath => 'جستجو در تراث…';

  @override
  String get fontAmiri => 'امیری (نسخ کلاسیک)';

  @override
  String get fontScheherazade => 'شهرزاد';

  @override
  String get fontPlex => 'IBM Plex Sans Arabic';

  @override
  String get fontNotoNaskh => 'نوتو نسخ';

  @override
  String get fontVazir => 'وزیرمتن';

  @override
  String get moreActions => 'بیشتر';

  @override
  String get matnSection => 'متن و شرح';

  @override
  String get matnSeparate => 'متن را در این کتاب جدا کن';

  @override
  String get matnMarkersLabel => 'متن میان این نشانه‌هاست';

  @override
  String get bracesVerses => 'آکولادها برای آیات قرآن است';

  @override
  String get detectAuto => 'تشخیص';

  @override
  String get detectAi => 'تشخیص با هوش مصنوعی';

  @override
  String get detecting => 'خواندن صفحه‌ها…';

  @override
  String get detectedNone => 'در این صفحه‌ها نشانهٔ متن یافت نشد';

  @override
  String get layersSourceAuto => 'از صفحه‌ها تشخیص داده شد';

  @override
  String get layersSourceAi => 'با هوش مصنوعی تشخیص داده شد';

  @override
  String get quranSection => 'آیات قرآن';

  @override
  String get styleQuran => 'نمایش آیات به سبک مصحف';

  @override
  String get quranFontLabel => 'قلم آیات';

  @override
  String get fontAmiriQuran => 'امیری قرآن';

  @override
  String get fontBookFace => 'قلم کتاب';

  @override
  String get quranColorLabel => 'رنگ آیات';

  @override
  String get matnColorLabel => 'رنگ متن';

  @override
  String get matnBoldLabel => 'متن پررنگ';

  @override
  String get textFormatting => 'قالب‌بندی متن';

  @override
  String get textFormattingSub => 'آیات، متن و شرح';

  @override
  String get libSearchHint => 'جستجوی کتاب‌ها و مؤلفان…';

  @override
  String get narrators => 'راویان';

  @override
  String get tabDownloaded => 'ذخیره‌شده';

  @override
  String get noDownloads =>
      'کتاب را از برگهٔ اطلاعات یا منوی خواننده ذخیره کنید تا بدون اینترنت بخوانید.';

  @override
  String get saveOffline => 'ذخیره برای آفلاین';

  @override
  String savingOffline(int percent) {
    return 'در حال ذخیره… $percent%';
  }

  @override
  String get savedOffline => 'روی این دستگاه ذخیره شده';

  @override
  String get removeDownload => 'حذف از دستگاه';

  @override
  String get stopDownload => 'توقف';

  @override
  String downloadsSize(String size) {
    return '$size روی این دستگاه';
  }

  @override
  String get deleteAllDownloads => 'حذف همهٔ کتاب‌های ذخیره‌شده';

  @override
  String get deleteAllDownloadsConfirm =>
      'همهٔ کتاب‌های ذخیره‌شده روی این دستگاه حذف شوند؟';

  @override
  String searchInTextsFor(String query) {
    return 'جستجوی «$query» در متن‌ها';
  }

  @override
  String seeAll(int count) {
    return 'دیدن همه ($count)';
  }

  @override
  String narratorsCount(String count) {
    return '$count راوی';
  }

  @override
  String get searchNarrators => 'جستجوی راویان…';

  @override
  String get narratorRank => 'رتبه';

  @override
  String get narratorDeath => 'وفات';

  @override
  String get findInTexts => 'یافتن در متن‌ها';

  @override
  String get librarySections => 'بخش‌ها';

  @override
  String pagesShort(int count) {
    return '$count ص';
  }

  @override
  String get pdfView => 'PDF';

  @override
  String get textView => 'متن';

  @override
  String get showPdf => 'نمایش PDF چاپی';

  @override
  String get showText => 'بازگشت به متن';

  @override
  String get pdfAlign => 'هم‌ترازی با متن';

  @override
  String get pdfAlignHint =>
      'اگر صفحهٔ PDF با متن نمی‌خواند، از اینجا جابه‌جا کنید؛ برای این کتاب ذخیره می‌شود.';

  @override
  String pdfPage(String page) {
    return 'صفحهٔ PDF $page';
  }

  @override
  String get pdfOpenOutside => 'باز کردن در مرورگر';

  @override
  String get pdfPartFailed => 'بخشی از این PDF بارگیری نشد.';

  @override
  String pdfLoadingBytes(String size) {
    return 'در حال بارگذاری PDF… $size';
  }

  @override
  String get matnBlockRule => 'متنِ بالای خط در سر هر صفحه، متن است';

  @override
  String get matnBlockShort => 'متن چاپ‌شده در بالای صفحه';

  @override
  String get markerAlwaysShort => 'همیشه متن';

  @override
  String get markerVerifiedShort => 'متن، اگر از متن نقل شده باشد';

  @override
  String get markersHint =>
      'روی نشانه بزنید: خاموش ← همیشه متن ← فقط وقتی کلماتش در متن باشد.';

  @override
  String get aiPagesLabel => 'دقیق: هوش مصنوعی هر صفحه را علامت می‌زند';

  @override
  String get aiPagesSub =>
      'دقیق‌ترین حالت. برای هر صفحه‌ای که باز می‌کنید یک بار از هوش مصنوعی استفاده می‌کند؛ نتیجه روی همین دستگاه می‌ماند.';

  @override
  String layersAgreement(int percent) {
    return 'در $percent٪ صفحات نمونه با هوش مصنوعی یکی است';
  }

  @override
  String get layersAutoNote => 'به‌طور خودکار از ساختار کتاب تنظیم شد';

  @override
  String get fineTune => 'تنظیم دقیق';

  @override
  String get matnRulesTitle => 'این کتاب چگونه خوانده می‌شود';

  @override
  String get noMatnRules => 'هنوز قاعده‌ای نیست — «تشخیص» را بزنید.';

  @override
  String get moreSuggestions => 'پرسش‌های دیگر';

  @override
  String get appFont => 'قلم برنامه';

  @override
  String get appFontSample => 'پاسخ فقط از منابع می‌آید';

  @override
  String get showWholePage => 'نمایش کل صفحه';

  @override
  String get showLess => 'نمایش کمتر';

  @override
  String get searchOptions => 'گزینه‌های جست‌وجو';

  @override
  String get precisionLabel => 'دقت';

  @override
  String get precisionSome => 'برخی واژه‌ها';

  @override
  String get precisionAll => 'همه واژه‌ها';

  @override
  String get precisionOrder => 'همه واژه‌ها به ترتیب';

  @override
  String get extendedSearch => 'جست‌وجوی گسترده';

  @override
  String get extendedSearchSub => 'شکل‌های دیگر واژه‌ها هم (پیشوندها، جمع‌ها…)';

  @override
  String get searchNotes => 'پانوشت‌ها و مقدمه‌ها';

  @override
  String get searchNotesSub => 'در پانوشت‌ها و مقدمه‌های محققان هم';

  @override
  String get searchSavedOnly => 'فقط کتاب‌های ذخیره‌شده روی این دستگاه';

  @override
  String get searchSavedOnlySub => 'بدون اینترنت کار می‌کند';

  @override
  String get showFullResults => 'نمایش کامل هر نتیجه';

  @override
  String get hideDiacriticsResults => 'پنهان کردن حرکات در نتایج';

  @override
  String get searchToc => 'جست‌وجو در فهرست‌ها';

  @override
  String get searchTocSub => 'عنوان باب‌ها و فصل‌ها به‌جای متن';

  @override
  String get logicLabel => 'چند عبارت («و» / «یا»)';

  @override
  String get logicAnd => 'و';

  @override
  String get logicOr => 'یا';

  @override
  String get addPhrase => 'افزودن عبارت';

  @override
  String phraseN(int n) {
    return 'عبارت $n';
  }

  @override
  String get pinnedFilters => 'فیلترهای ذخیره‌شده';

  @override
  String get savePinned => 'ذخیره فیلترهای کنونی';

  @override
  String get pinnedName => 'نام';

  @override
  String get noPinned => 'هنوز فیلتری ذخیره نشده';

  @override
  String savedBooksCount(int count) {
    return 'در $count کتاب ذخیره‌شده';
  }

  @override
  String get logicHint =>
      '«و»: صفحه‌هایی که همه عبارت‌ها را دارند. «یا»: که یکی را دارند.';

  @override
  String get answerModel => 'مدل پاسخ';

  @override
  String get modelAuto => 'خودکار';

  @override
  String modelAutoSub(String name) {
    return 'بهترین مدل موجود: $name';
  }

  @override
  String get modelAutoInfo =>
      'مدل خودکار انتخاب می‌شود؛ اگر سهمیه تمام شود به مدل دیگر می‌رود.';

  @override
  String get modelPickerNote =>
      'مدل انتخاب‌شده پاسخ را می‌نویسد؛ گام‌های سریع جست‌وجو با Flash-Lite می‌مانند. اگر مدل کار نکند، مدل خودکار جای آن را می‌گیرد.';

  @override
  String get costLow => 'توکن کم';

  @override
  String get costMedium => 'توکن متوسط';

  @override
  String get costHigh => 'توکن زیاد';

  @override
  String get modelsLoadFailed => 'فهرست مدل‌ها دریافت نشد';

  @override
  String get modelsFromKey => 'مدل‌های فعال کلید شما';

  @override
  String get modelsFromServer => 'مدل‌های فعال کلید سرور';

  @override
  String get fillIn => 'در کادر بگذار';

  @override
  String get forget => 'فراموش کن';

  @override
  String get addComment => 'یادداشت بنویسید';

  @override
  String get comment => 'یادداشت';

  @override
  String get commentHint => 'یادداشت خود را درباره این متن بنویسید…';

  @override
  String get commentSaved => 'یادداشت ذخیره شد';

  @override
  String get editComment => 'ویرایش یادداشت';

  @override
  String get deleteComment => 'حذف یادداشت';

  @override
  String get reportError => 'گزارش خطای متن';

  @override
  String get reportErrorInfo =>
      'متن انتخاب‌شده و جای آن همراه گزارش می‌رود. خطا را کوتاه بنویسید.';

  @override
  String get selectedText => 'متن انتخاب‌شده';

  @override
  String get errorDescription => 'شرح خطا';

  @override
  String get errorDescriptionHint =>
      'مثلاً: کلمه‌ای اشتباه چاپ شده، درستش «…» است';

  @override
  String get sendWhatsApp => 'WhatsApp';

  @override
  String get sendEmail => 'Gmail / ایمیل';

  @override
  String get reportSubject => 'خطای متن — منابع';

  @override
  String get reportLocation => 'مکان';

  @override
  String get couldNotOpen => 'باز نشد';

  @override
  String get allAuthors => 'همه مؤلفان';

  @override
  String get pickMany => 'چند مورد انتخاب کنید';

  @override
  String doneCount(String n) {
    return 'تأیید ($n)';
  }

  @override
  String get scopeHow =>
      'هر کتاب انتخاب‌شده، و کتاب‌های هر مؤلف انتخاب‌شده در دسته‌های انتخاب‌شده جست‌وجو می‌شود.';

  @override
  String scopeTooMany(String n) {
    return 'حداکثر $n جست‌وجو هم‌زمان';
  }

  @override
  String get setupTitle => 'کتابخانه آماده می‌شود';

  @override
  String get setupSub =>
      'فقط بار نخست: فهرست کتاب‌ها روی دستگاه شما ساخته می‌شود تا جست‌وجو و خواندن سریع و آفلاین باشد.';

  @override
  String get setupStorage => 'محل ذخیره';

  @override
  String get setupCatalog => 'کتاب‌ها، مؤلفان و دسته‌ها';

  @override
  String get setupExtra => 'کتاب‌های تازه تراث';

  @override
  String get setupPdf => 'فهرست کتاب‌های دارای PDF';

  @override
  String get setupOfflineNote =>
      'برخی بخش‌ها بدون اینترنت ماند؛ بعداً خودکار کامل می‌شود.';

  @override
  String get setupContinue => 'شروع';

  @override
  String get librarySync => 'به‌روزرسانی کتابخانه';

  @override
  String get librarySyncSub => 'کتاب‌های تازه و فهرست PDF؛ هر روز خودکار';

  @override
  String readCacheInfo(String n) {
    return '$n صفحه خوانده‌شده آفلاین نگه داشته شده';
  }

  @override
  String get clearReadCache => 'پاک کردن صفحه‌های خوانده‌شده';

  @override
  String get splitView => 'نمای دوبخشی';

  @override
  String get splitPdf => 'متن و PDF همین صفحه';

  @override
  String get splitSameBook => 'همین کتاب، صفحه‌ای دیگر';

  @override
  String get splitOtherBook => 'مقایسه با کتابی دیگر';

  @override
  String get splitClose => 'بستن نمای دوبخشی';

  @override
  String get bookCard => 'شناسنامهٔ کتاب';

  @override
  String get readMore => 'بیشتر بخوانید';

  @override
  String actChapter(String book, String chapter, String pages) {
    return 'فصل «$chapter» از «$book» خوانده شد ($pages صفحه)';
  }

  @override
  String get memory => 'حافظه';

  @override
  String get memorySub => 'آنچه دستیار دربارهٔ پاسخ‌های دلخواه شما به یاد دارد';

  @override
  String get memoryOn => 'به یاد سپردن و به کار بردن';

  @override
  String get memoryOnSub =>
      'وقتی بگویید پاسخ‌ها را چگونه می‌خواهید («کوتاه پاسخ بده»، «من حنفی هستم»)، اینجا نگه داشته می‌شود و در گفت‌وگوهای بعدی رعایت می‌شود. فقط روی همین دستگاه نگه داشته می‌شود.';

  @override
  String get memoryEmpty => 'هنوز چیزی به یاد سپرده نشده است.';

  @override
  String get memoryAdd => 'افزودن به حافظه';

  @override
  String get memoryHint => 'مثلاً: کوتاه پاسخ بده، اول نظر حنفی‌ها';

  @override
  String get memoryClear => 'فراموش کردن همه';

  @override
  String get memoryClearConfirm => 'همهٔ آنچه دستیار به یاد دارد فراموش شود؟';

  @override
  String get memorySaved => 'حافظه به‌روز شد';
}
