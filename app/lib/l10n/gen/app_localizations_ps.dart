// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Pushto Pashto (`ps`).
class AppLocalizationsPs extends AppLocalizations {
  AppLocalizationsPs([String locale = 'ps']) : super(locale);

  @override
  String get appName => 'منابع';

  @override
  String get tagline => 'د تراث له کتابونو ځوابونه — د هغوی له مآخذو سره';

  @override
  String get navChat => 'چټ';

  @override
  String get navLibrary => 'کتابتون';

  @override
  String get navFavorites => 'خوندي';

  @override
  String get navHistory => 'تاریخچه';

  @override
  String get navSettings => 'تنظیمات';

  @override
  String get newChat => 'نوی چټ';

  @override
  String get chats => 'چټونه';

  @override
  String get searchChats => 'په چټونو کې لټون';

  @override
  String get noChats => 'تر اوسه کوم چټ نشته. لومړۍ پوښتنه مو وکړئ.';

  @override
  String get pinned => 'ټاکل شوي';

  @override
  String get recent => 'وروستي';

  @override
  String get askPlaceholder => 'د قرآن، حدیث، فقهې… په اړه پوښتنه وکړئ';

  @override
  String get send => 'لېږل';

  @override
  String get stop => 'درول';

  @override
  String get scopeAll => 'ټول کتابتون';

  @override
  String get scopeBook => 'کتاب';

  @override
  String get scopeAuthor => 'مؤلف';

  @override
  String get scopeCategory => 'ډله';

  @override
  String get scopeTitle => 'د لټون ساحه';

  @override
  String get chooseBook => 'یو کتاب وټاکئ';

  @override
  String get chooseAuthor => 'یو مؤلف وټاکئ';

  @override
  String get chooseCategory => 'یوه ډله وټاکئ';

  @override
  String get clearScope => 'ساحه پاکول';

  @override
  String get answerLanguage => 'د ځواب ژبه';

  @override
  String get langAuto => 'د پوښتنې په ژبه';

  @override
  String get welcomeTitle => 'السلام علیکم';

  @override
  String get welcomeBody =>
      'په پښتو، دري، عربي یا انګلیسي پوښتنه وکړئ. منابع د تراث په کلاسیکو کتابونو کې لټون کوي او یوازې د موندل شویو متنونو له مخې ځواب ورکوي — د کتاب، مؤلف، جلد، مخ او اصلي عربي عبارت سره.';

  @override
  String get suggestion1 => 'د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟';

  @override
  String get suggestion2 =>
      'د فقهې کتابونه د عورت لمسولو او اودس په اړه څه وايي؟';

  @override
  String get suggestion3 => 'د جبرئیل په حدیث کې د احسان مانا څه ده؟';

  @override
  String get suggestion4 => 'علماوو د علم د طلب د فضیلت په اړه څه ویلي دي؟';

  @override
  String get stagePlanning => 'د پوښتنې پوهېدل';

  @override
  String get stageSearching => 'د تراث په کتابتون کې لټون';

  @override
  String get stageComposing => 'له منابعو د ځواب لیکل';

  @override
  String get stageVerifying => 'د هر عبارت له کتاب سره تایید';

  @override
  String foundSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مخونه وموندل شول',
      one: '۱ مخ وموندل شو',
      zero: 'هېڅ مخ ونه موندل شو',
    );
    return '$_temp0';
  }

  @override
  String get searchedFor => 'لټول شوي ټکي';

  @override
  String get statusAnswered => 'مستند ځواب';

  @override
  String get statusPartial => 'په نیمګړي ډول مستند';

  @override
  String get statusInsufficient => 'مستند ځواب ونه موندل شو';

  @override
  String get sources => 'منابع';

  @override
  String sourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سرچینې',
      one: '۱ سرچینه',
    );
    return '$_temp0';
  }

  @override
  String get viewSource => 'مخ لوستل';

  @override
  String get openLink => 'په تراث کې پرانیستل';

  @override
  String get openShamela => 'په شامله کې پرانیستل';

  @override
  String get copy => 'کاپي';

  @override
  String get copied => 'کاپي شو';

  @override
  String get share => 'شریکول';

  @override
  String get save => 'خوندي کول';

  @override
  String get saved => 'خوندي شو';

  @override
  String get unsave => 'له خوندي شویو لرې کول';

  @override
  String get export => 'صادرول';

  @override
  String get exportPdf => 'PDF سند';

  @override
  String get exportMarkdown => 'Markdown';

  @override
  String get exportText => 'ساده متن';

  @override
  String get exportChat => 'د چټ صادرول';

  @override
  String get exported => 'صادر شو';

  @override
  String get retry => 'بیا هڅه';

  @override
  String get cancel => 'لغوه';

  @override
  String get delete => 'ړنګول';

  @override
  String get rename => 'نوم بدلول';

  @override
  String get pin => 'ټاکل';

  @override
  String get unpin => 'له ټاکلو لرې کول';

  @override
  String get ok => 'سمه ده';

  @override
  String get deleteChatConfirm => 'دا چټ ړنګ شي؟ بېرته نه راګرځي.';

  @override
  String get volume => 'ج';

  @override
  String get page => 'مخ';

  @override
  String get turathPage => 'د تراث مخ';

  @override
  String get author => 'مؤلف';

  @override
  String get book => 'کتاب';

  @override
  String get category => 'ډله';

  @override
  String get quoteVerified => 'له کتاب سره کلمه په کلمه تایید شوی';

  @override
  String get quoteClose => 'نږدې سمون — لکه څنګه چې په کتاب کې دی ښودل شوی';

  @override
  String get originalText => 'اصلي عبارت';

  @override
  String get opinions => 'په منابعو کې د علماوو نظرونه';

  @override
  String get notes => 'یادونې';

  @override
  String get relatedSources => 'هغه مخونه چې ولټول شول (دلیل نه دي)';

  @override
  String get disclaimer =>
      'منابع هغه څه نقلوي چې کتابونه یې وايي؛ دا فتوا نه ده. د شخصي حکم لپاره له یو وړ عالم سره مشوره وکړئ.';

  @override
  String get errNetwork => 'اړیکه ونه شوه. خپل انټرنېټ وګورئ او بیا هڅه وکړئ.';

  @override
  String get errServerNotConfigured =>
      'د منابع سرور نه دی ټاکل شوی. په تنظیماتو کې د سرور پته ولیکئ.';

  @override
  String get errNoApiKey =>
      'د مستقیم حالت لپاره په تنظیماتو کې خپله Gemini کیلي ولیکئ.';

  @override
  String get errDirectNotOnWeb =>
      'مستقیم حالت په براوزر کې نشته. د منابع سرور وکاروئ.';

  @override
  String get errGeminiAuth => 'د Gemini کیلي نشته یا ناسمه ده.';

  @override
  String get errGeminiQuota =>
      'د Gemini د کارونې حد پوره شو. وروسته بیا هڅه وکړئ.';

  @override
  String get errGeminiUnavailable =>
      'د AI خدمت اوس ځواب نه ورکوي. بیا هڅه وکړئ.';

  @override
  String get errTurathUnavailable =>
      'د تراث کتابتون ته اوس لاسرسی نشته. بیا هڅه وکړئ.';

  @override
  String get errRateLimited => 'په لنډ وخت کې ډېرې پوښتنې. لږ صبر وکړئ.';

  @override
  String get errUnauthorized => 'سرور د لاسرسي ټوکن رد کړ.';

  @override
  String get errInterrupted => 'دا ځواب نیمګړی پاتې شو.';

  @override
  String get errCancelled => 'ودرول شو.';

  @override
  String get errNotFound => 'ونه موندل شو.';

  @override
  String get errGeneric => 'یوه ستونزه پېښه شوه. بیا هڅه وکړئ.';

  @override
  String get library => 'کتابتون';

  @override
  String get books => 'کتابونه';

  @override
  String get authors => 'مؤلفین';

  @override
  String get categories => 'ډلې';

  @override
  String get searchBooks => 'د کتاب نوم ولټوئ';

  @override
  String get searchAuthors => 'مؤلف ولټوئ';

  @override
  String booksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کتابونه',
      one: '۱ کتاب',
    );
    return '$_temp0';
  }

  @override
  String get noResults => 'هېڅ پایله نشته';

  @override
  String get askInThisBook => 'په دې کتاب کې پوښتنه';

  @override
  String get askThisAuthor => 'د دې مؤلف په تصنیفاتو کې پوښتنه';

  @override
  String get askInCategory => 'په دې ډله کې پوښتنه';

  @override
  String get tableOfContents => 'فهرست';

  @override
  String get description => 'د کتاب په اړه';

  @override
  String get biography => 'ژوندلیک';

  @override
  String get authorBooks => 'په کتابتون کې یې آثار';

  @override
  String get fullTextSearch => 'د متن لټون';

  @override
  String get searchInText => 'د کتابونو په متن کې لټون (عربي)';

  @override
  String matches(int count) {
    return '$count پایلې';
  }

  @override
  String get readPage => 'لوستل';

  @override
  String get previousPage => 'مخکینی مخ';

  @override
  String get nextPage => 'بل مخ';

  @override
  String get loading => 'پورته کېږي…';

  @override
  String get loadMore => 'نور';

  @override
  String get noFavorites => 'هغه ځوابونه چې خوندي یې کړئ دلته ښکاري.';

  @override
  String get history => 'د پوښتنو تاریخچه';

  @override
  String get searchHistory => 'په خپلو پوښتنو کې لټون';

  @override
  String get noHistory => 'تر اوسه پوښتنه نشته.';

  @override
  String get settings => 'تنظیمات';

  @override
  String get appearance => 'بڼه';

  @override
  String get theme => 'رنګ';

  @override
  String get themeSystem => 'د سیسټم';

  @override
  String get themeLight => 'روښانه';

  @override
  String get themeDark => 'تیاره';

  @override
  String get interfaceLanguage => 'د اپلیکیشن ژبه';

  @override
  String get defaultAnswerLanguage => 'د ځواب اصلي ژبه';

  @override
  String get arabicTextSize => 'د عربي متن اندازه';

  @override
  String get answers => 'ځوابونه';

  @override
  String get maxSources => 'د هرې پوښتنې لپاره د کتل شویو مخونو شمېر';

  @override
  String get connection => 'اړیکه';

  @override
  String get modeServer => 'د منابع سرور';

  @override
  String get modeServerInfo =>
      'سپارښتل شوی. د Gemini کیلي په سرور کې خوندي پاتې کېږي او اپلیکیشن په ټولو پلېټفارمونو، حتی ویب کې کار کوي.';

  @override
  String get modeDirect => 'مستقیم (خپله کیلي)';

  @override
  String get modeDirectInfo =>
      'اپلیکیشن په خپله له تراث او Gemini سره د ستاسو د Gemini کیلي په مرسته اړیکه نیسي، چې په دې وسیله کې په خوندي ډول ساتل کېږي. په ویب کې نشته.';

  @override
  String get serverUrl => 'د سرور پته';

  @override
  String get accessToken => 'د لاسرسي ټوکن (اختیاري)';

  @override
  String get geminiKey => 'د Gemini API کیلي';

  @override
  String get geminiKeyHint => 'د وسیلې په خوندي زېرمه کې ساتل کېږي';

  @override
  String get modelOverride => 'د Gemini ماډل (اختیاري)';

  @override
  String get modelOverrideHint => 'خالي = تر ټولو نوی Flash ماډل';

  @override
  String get testConnection => 'د اړیکې ازموینه';

  @override
  String connectionOk(String model) {
    return 'وصل دی · $model';
  }

  @override
  String get data => 'معلومات';

  @override
  String get clearHistory => 'ټول چټونه ړنګول';

  @override
  String get clearHistoryConfirm =>
      'ټول چټونه او خوندي ځوابونه له دې وسیلې ړنګ شي؟';

  @override
  String get about => 'په اړه';

  @override
  String get aboutBody =>
      'منابع د خلاصې سرچینې Nusus SDK له لارې د تراث (turath.io) کتابتون لټوي او Gemini یوازې د لټون د پلان او د موندل شویو مخونو له مخې د ځواب د ترتیب لپاره کاروي. هر عبارت له ښودلو مخکې د کتاب له متن سره تاییدېږي.';

  @override
  String catalogInfo(int books, int authors, String date) {
    return 'آفلاین فهرست: $books کتابونه · $authors مؤلفین ($date)';
  }

  @override
  String version(String v) {
    return 'نسخه $v';
  }

  @override
  String get chatWith => 'له منابع پوښتنه';

  @override
  String get question => 'پوښتنه';

  @override
  String get answer => 'ځواب';

  @override
  String get generatedBy => 'د منابع له خوا د تراث له منابعو جوړ شوی';

  @override
  String get notConfiguredTitle => 'اړیکه تنظیم کړئ';

  @override
  String get openSettings => 'تنظیمات پرانیستل';

  @override
  String get allCategories => 'ټولې ډلې';

  @override
  String get stageReading => 'د مخونو لوستل او غوره کول';

  @override
  String get welcomeQuestion => 'نن د څه په اړه څېړنه کوئ؟';

  @override
  String get options => 'د لټون اختیارونه';

  @override
  String get today => 'نن';

  @override
  String get yesterday => 'پرون';

  @override
  String get previous7Days => 'تېره اونۍ';

  @override
  String get earlier => 'مخکې';

  @override
  String get libraryHeroTitle => 'د تراث کتابتون';

  @override
  String get libraryHeroBody =>
      'د تفسیر، حدیث، فقهې، عقیدې، تاریخ او ژبې کلاسیک کتابونه — د لټون او حوالې وړ.';

  @override
  String get browseCategories => 'ډلې وګورئ';

  @override
  String get browseCategoriesSub => 'علوم او د هغوی کتابونه';

  @override
  String get fullTextSub => 'د ټولو کتابونو په متن کې لټون';

  @override
  String get allBooks => 'ټول کتابونه';
}
