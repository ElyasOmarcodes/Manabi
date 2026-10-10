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
      'سقف استفاده از Gemini پر شد. بعداً دوباره تلاش کنید.';

  @override
  String get errGeminiUnavailable =>
      'سرویس هوش مصنوعی اکنون پاسخ نمی‌دهد. دوباره تلاش کنید.';

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
      'برنامه خودش با کلید Gemini شما که به‌طور امن روی همین دستگاه نگه‌داری می‌شود، با تراث و Gemini ارتباط می‌گیرد. در وب در دسترس نیست.';

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
  String get allCategories => 'همهٔ دسته‌ها';

  @override
  String get stageReading => 'خواندن و گزینش صفحه‌ها';

  @override
  String get welcomeQuestion => 'امروز دربارهٔ چه می‌خواهید پژوهش کنید؟';

  @override
  String get options => 'گزینه‌های جست‌وجو';
}
