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
      'د Gemini د نن ورځې د کارونې حد پوره شوی. څو ساعته وروسته بیا هڅه وکړئ، یا د کیلي لپاره په Google AI Studio کې billing فعال کړئ.';

  @override
  String get errGeminiUnavailable =>
      'د AI خدمت په ټاکلي وخت کې ځواب ورنه کړ. انټرنېټ وګورئ او بیا هڅه وکړئ.';

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

  @override
  String get settingsApp => 'اپلیکیشن';

  @override
  String get settingsAnswersGroup => 'ځوابونه او څېړنه';

  @override
  String get settingsInfo => 'معلومات او مرسته';

  @override
  String get aiStyle => 'د AI سبک';

  @override
  String get dataStorage => 'معلومات او زېرمه';

  @override
  String get help => 'مرسته';

  @override
  String get privacyPolicy => 'د محرمیت پالیسي';

  @override
  String get aboutUs => 'زموږ په اړه';

  @override
  String get licenses => 'د خلاصې سرچینې جوازونه';

  @override
  String get resetSettings => 'تنظیمات اصلي حالت ته راګرځول';

  @override
  String get resetSettingsConfirm =>
      'ټول تنظیمات (د کیلي په ګډون) اصلي حالت ته راګرځي. چټونه مو پاتې کېږي.';

  @override
  String get textSize => 'د متن اندازه';

  @override
  String get textSizeSample =>
      'منابع ستاسو پوښتنو ته د تراث له کتابونو مستند ځواب درکوي.';

  @override
  String get researchDepth => 'د څېړنې کچه';

  @override
  String get depthQuick => 'چټکه';

  @override
  String get depthStandard => 'منځنۍ';

  @override
  String get depthDeep => 'ژوره';

  @override
  String get depthQuickInfo =>
      'لږ مخونه لولي او ژر ځواب درکوي — تر ۶ منابعو پورې.';

  @override
  String get depthStandardInfo =>
      'د چټکتیا او پراخوالي توازن — تر ۱۴ منابعو او یو اضافي لټون.';

  @override
  String get depthDeepInfo =>
      'پراخه لټون، ډېر کتابونه او دوه اضافي پړاوونه — تر ۱۸ منابعو؛ ډېر وخت نیسي.';

  @override
  String get depthHint =>
      'څومره چې ژوره وي، هومره ډېر کتابونه لټول او لوستل کېږي.';

  @override
  String get chooseLanguage => 'ژبه وټاکئ';

  @override
  String get openLibrary => 'کتابتون پرانیستل';

  @override
  String get openLibrarySub => 'کتابونه، مؤلفین او د متن لټون';

  @override
  String get helpHowTitle => 'منابع څنګه کار کوي';

  @override
  String get helpHowBody =>
      '۱. پوښتنه مو پوهېږي او په عربي د لټون ټکي جوړوي.\n۲. د تراث په زرګونو کتابونو کې لټون کوي، د مذهب او کتاب په ګډون چې تاسو یې یادوئ.\n۳. تر ټولو اړوند مخونه لولي او غوره کوي.\n۴. یوازې له همدې مخونو ځواب لیکي.\n۵. هر نقل شوی عبارت له اصلي کتاب سره کلمه په کلمه پرتله کوي؛ که ونه موندل شي، لرې کېږي.';

  @override
  String get helpTipsTitle => 'د ښې پوښتنې لارښوونې';

  @override
  String get helpTipsBody =>
      '• پوښتنه روښانه او ځانګړې ولیکئ.\n• که د یوه مذهب نظر غواړئ، د مذهب نوم ولیکئ (حنفي، شافعي، مالکي، حنبلي).\n• د کتاب نوم یاد کړئ، یا د + له لارې ساحه یو کتاب، مؤلف یا ډلې ته محدوده کړئ.\n• د سختو او اختلافي مسلو لپاره «ژوره» څېړنه وټاکئ.';

  @override
  String get helpSourcesTitle => 'منابع او حوالې';

  @override
  String get helpSourcesBody =>
      'د هر ځواب لاندې د «منابع» تڼۍ ټولې حوالې ښيي: د کتاب نوم، مؤلف، ټوک، مخ، اصلي عربي متن او په تراث کې مستقیم لینک. په متن کې کوچنۍ شمېرې لکه [۱] هغې سرچینې ته اشاره کوي.';

  @override
  String get helpLimitsTitle => 'حدود';

  @override
  String get helpLimitsBody =>
      'منابع مفتي نه دی؛ هغه څه نقلوي چې کتابونه یې وايي. که مستند ځواب ونه موندل شي، په ښکاره یې وايي. د شخصي حکم لپاره له باوري عالم سره مشوره وکړئ.';

  @override
  String get privacyStoredTitle => 'څه ساتل کېږي';

  @override
  String get privacyStoredBody =>
      'ستاسو چټونه، خوندي ځوابونه او تنظیمات یوازې ستاسو په وسیله کې ساتل کېږي. منابع حساب نه غواړي او شخصي معلومات نه راټولوي.';

  @override
  String get privacySentTitle => 'څه لېږل کېږي';

  @override
  String get privacySentBody =>
      'کله چې پوښتنه کوئ، د پوښتنې متن او د وروستیو ځوابونو لنډیز د ځواب جوړولو لپاره د منابع سرور (یا په مستقیم حالت کې Google Gemini) ته لېږل کېږي، او د لټون ټکي turath.io ته. سرور پوښتنې نه ساتي؛ یوازې د قطع شوي ځواب د بېرته ترلاسه کولو لپاره یې تر ۲۰ دقیقو پورې په حافظه کې ساتي.';

  @override
  String get privacyKeyTitle => 'ستاسو کیلي';

  @override
  String get privacyKeyBody =>
      'که خپله Gemini کیلي وکاروئ، د وسیلې په خوندي زېرمه (Keychain / Keystore) کې ساتل کېږي او یوازې Google ته لېږل کېږي.';

  @override
  String get privacyDeleteTitle => 'ړنګول';

  @override
  String get privacyDeleteBody =>
      'د «معلومات او زېرمه» له برخې ټول چټونه او تنظیمات هر وخت ړنګولی شئ.';

  @override
  String get aboutMission =>
      'زموږ موخه: د اسلامي علومو اصلي سرچینو ته اسانه، امانتداره او مستنده لاسرسی — په پښتو، دري، عربي او انګلیسي.';

  @override
  String get aboutCredits =>
      'له تراث کتابتون (turath.io) او Nusus SDK څخه مننه.';

  @override
  String get sourceCode => 'سرچینې کوډ';

  @override
  String get dataCatalog => 'آفلاین فهرست';

  @override
  String get pageExcerpt =>
      'د مخ برخه — دا ځای په ځواب کې یاد شوی (کلمه په کلمه نقل نه دی)';

  @override
  String get searchInBook => 'په کتاب کې لټون';

  @override
  String get searchInBookHint => 'په دې کتاب کې ولټوئ (عربي)';

  @override
  String get goToPage => 'مخ ته تګ';

  @override
  String get printedPage => 'چاپي مخ';

  @override
  String get go => 'ورشه';

  @override
  String pageOf(int page, int total) {
    return '$page له $total';
  }

  @override
  String get bookmarkPage => 'مخ نښه کول';

  @override
  String get removeBookmark => 'نښه لرې کول';

  @override
  String get bookmarks => 'نښه شوي مخونه';

  @override
  String get copyPage => 'د مخ متن کاپي';

  @override
  String get sharePage => 'مخ شریکول';

  @override
  String get copyCitation => 'حواله کاپي';

  @override
  String get readerDisplay => 'د لوستلو بڼه';

  @override
  String get lineSpacing => 'د کرښو واټن';

  @override
  String get paperTheme => 'د پاڼې رنګ';

  @override
  String get paperWarm => 'کاغذي';

  @override
  String get paperPlain => 'ساده';

  @override
  String get paperNight => 'شپه';

  @override
  String get continueReading => 'لوستل دوام کړئ';

  @override
  String get recentlyRead => 'وروستي لوستل شوي';

  @override
  String get footnotes => 'حاشیې';

  @override
  String get filters => 'فلټرونه';

  @override
  String get sortBy => 'ترتیب';

  @override
  String get sortRelevance => 'مناسب‌ترین';

  @override
  String get sortTitle => 'د کتاب نوم';

  @override
  String get sortAuthor => 'مؤلف';

  @override
  String get anyAuthor => 'هر مؤلف';

  @override
  String get anyCategory => 'هره ډله';

  @override
  String get anyBook => 'هر کتاب';

  @override
  String get clearFilters => 'فلټرونه پاکول';

  @override
  String get readBook => 'کتاب لوستل';

  @override
  String get volumeShort => 'ټوک';

  @override
  String pagesCount(int count) {
    return '$count مخونه';
  }

  @override
  String get noMatchesInBook => 'په دې کتاب کې پایله ونه موندل شوه.';

  @override
  String get readerTools => 'د لوستلو وسایل';

  @override
  String get moreReadingSettings => 'د لوستلو نور تنظیمات';

  @override
  String get readingSettings => 'لوستل او کتابتون';

  @override
  String get readingSettingsSub => 'لوستونکی، لیکبڼې، نښې او کتابتون';

  @override
  String get readingMode => 'د لوستلو بڼه';

  @override
  String get modeScroll => 'پرله‌پسې';

  @override
  String get modePages => 'مخ په مخ';

  @override
  String get modeScrollInfo => 'مخونه یو د بل پسې راځي، لکه تراث.';

  @override
  String get modePagesInfo => 'د هر مخ اړولو لپاره ګوته ښوروئ، لکه چاپي کتاب.';

  @override
  String get bookFont => 'د کتاب لیکبڼه';

  @override
  String get fontNaskh => 'نسخ';

  @override
  String get fontModern => 'عصري';

  @override
  String get justifyText => 'کرښې برابرې کړئ';

  @override
  String get hideDiacritics => 'حرکات پټ کړئ';

  @override
  String get showFootnotes => 'حاشیې ښکاره کړئ';

  @override
  String get keepScreenOn => 'پرده روښانه وساتئ';

  @override
  String get numberStyle => 'د شمېرو بڼه';

  @override
  String get highlightColor => 'د نښه کولو رنګ';

  @override
  String get highlights => 'نښه شوي متنونه';

  @override
  String get highlight => 'نښه کول';

  @override
  String get highlightSaved => 'نښه شو';

  @override
  String get removeHighlight => 'نښه لرې کول';

  @override
  String get noHighlights => 'په کتاب کې متن وټاکئ او «نښه کول» غوره کړئ.';

  @override
  String get copyWithCitation => 'د حوالې سره کاپي';

  @override
  String get tabFavorites => 'غوره';

  @override
  String get addFavorite => 'غوره کې ورزیات کړئ';

  @override
  String get removeFavorite => 'له غوره څخه لرې کړئ';

  @override
  String get noFavoriteBooks => 'کتاب ته ستوری ورکړئ چې دلته پاتې شي.';

  @override
  String get bookInfo => 'د کتاب په اړه';

  @override
  String get visitedPages => 'تاریخچه';

  @override
  String get noVisited => 'هغه مخونه چې خلاصوئ دلته ښکاري.';

  @override
  String get noBookmarksYet => 'په دې کتاب کې لا نښه نشته.';

  @override
  String get searchHeadings => 'په سرلیکونو کې لټون…';

  @override
  String get fullScreen => 'بشپړه پرده';

  @override
  String get exitFullScreen => 'له بشپړې پردې وتل';

  @override
  String get paperSepia => 'ژېړ';

  @override
  String get clearReadingHistory => 'د لوستلو تاریخچه پاکول';

  @override
  String get clearReadingHistoryConfirm =>
      'په ټولو کتابونو کې ستاسو د درېدو ځای هېر شي؟ نښې، نښه شوي متنونه او غوره کتابونه پاتې کیږي.';

  @override
  String get clearReadingData => 'د لوستلو ټول معلومات ړنګول';

  @override
  String get clearReadingDataConfirm =>
      'په دې وسیله کې ټولې نښې، نښه شوي متنونه، غوره کتابونه او تاریخچه ړنګ شي؟';

  @override
  String get resetReader => 'د لوستونکي تنظیمات اصلي حالت ته';

  @override
  String get libraryStartTab => 'کتابتون په دې خلاصیږي';

  @override
  String get readingData => 'ستاسو د لوستلو معلومات';

  @override
  String get smaller => 'کوچنی';

  @override
  String get larger => 'لوی';

  @override
  String get readerPreview => 'مخکتنه';

  @override
  String get pageText => 'مخ';

  @override
  String get reader => 'لوستونکی';

  @override
  String get shortcutsHint =>
      'د غشي تڼۍ مخونه اړوي · Ctrl+F په کتاب کې لټون کوي';

  @override
  String actPlan(int count) {
    return '$count لټونونه پلان شول';
  }

  @override
  String actSearch(String query, String where, int hits) {
    return '«$query» ولټول شو$where — $hits پایلې';
  }

  @override
  String actIn(String book) {
    return ' په $book کې';
  }

  @override
  String actFound(int count, int total) {
    return 'له $total پایلو $count برخې راټولې شوې';
  }

  @override
  String actRank(int count) {
    return '$count برخې لوستل او ارزول کیږي';
  }

  @override
  String actRanked(int count, String coverage) {
    return '$count برخې وساتل شوې · پوښښ: $coverage';
  }

  @override
  String get coverageFull => 'بشپړ';

  @override
  String get coveragePartial => 'نیمګړی';

  @override
  String get coverageNone => 'هیڅ';

  @override
  String actFollowup(String queries) {
    return 'نور لټون: $queries';
  }

  @override
  String actRead(int pages, int books) {
    return 'له $books کتابونو $pages مخونه خلاص شول';
  }

  @override
  String actCompose(int count) {
    return 'له $count مخونو ځواب لیکل کیږي';
  }

  @override
  String get actVerify => 'هر نقل‌قول له کتابونو سره پرتله کیږي';

  @override
  String get actResumed => 'له بشپړ شوي پړاو څخه دوام ورکړل شو';

  @override
  String actRetry(int count) {
    return 'اړیکه پرې شوه — بیا هڅه ($count)';
  }

  @override
  String reconnectingIn(int seconds) {
    return 'په $seconds ثانیو کې بیا نښلېږي…';
  }

  @override
  String get showSteps => 'پړاوونه ښکاره کړه';

  @override
  String get hideSteps => 'پړاوونه پټ کړه';

  @override
  String get writingDraft => 'مسوده — نقل‌قولونه د بشپړېدو وروسته کتل کیږي';

  @override
  String tokensCount(String count) {
    return '$count ټوکنونه';
  }

  @override
  String get tokenUsage => 'د ټوکنونو مصرف';

  @override
  String get tokensInput => 'انپوټ';

  @override
  String get tokensOutput => 'اوټپوټ';

  @override
  String get tokensThinking => 'فکر کول';

  @override
  String get tokensTotal => 'ټول';

  @override
  String get modelCalls => 'د ماډل غوښتنې';

  @override
  String get answerTime => 'وخت';

  @override
  String get thisAnswer => 'دا ځواب';

  @override
  String get thisQuestion => 'دا پوښتنه';

  @override
  String get thisChat => 'دا چټ';

  @override
  String get chatDetails => 'د چټ جزئیات';

  @override
  String get contextWindow => 'د کنټیکس کړکۍ';

  @override
  String contextWindowInfo(String used, String limit) {
    return 'په دې چټ کې تر ټولو لویه غوښتنه: $used له $limit ټوکنونو';
  }

  @override
  String get questionsCount => 'پوښتنې';

  @override
  String get noUsageYet => 'د ټوکنونو شمېر د دې نسخې ځوابونو لپاره ښکاري.';

  @override
  String get copyQuestion => 'پوښتنه کاپي کړه';

  @override
  String get askAgain => 'بیا وپوښته';

  @override
  String get keepAliveText => 'ستاسو ځواب له سرچینو چمتو کیږي…';

  @override
  String get pdfBook => 'PDF';

  @override
  String get openPdf => 'چاپي PDF خلاص کړه';

  @override
  String get noPdf => 'دا کتاب په تراث کې PDF نه لري.';

  @override
  String get onTurath => 'په تراث کې نور';

  @override
  String get onTurathInfo =>
      'هغه کتابونه چې په آفلاین لیست کې نه وو او په تراث کې وموندل شول';

  @override
  String get searchingTurath => 'په تراث کې لټون…';

  @override
  String get fontAmiri => 'امیري (کلاسیک نسخ)';

  @override
  String get fontScheherazade => 'شهرزاد';

  @override
  String get fontPlex => 'IBM Plex Sans Arabic';

  @override
  String get fontNotoNaskh => 'نوټو نسخ';

  @override
  String get fontVazir => 'وزیر متن';

  @override
  String get moreActions => 'نور';

  @override
  String get matnSection => 'متن او شرح';

  @override
  String get matnSeparate => 'په دې کتاب کې متن جلا کړه';

  @override
  String get matnMarkersLabel => 'متن د دې نښو ترمنځ دی';

  @override
  String get bracesVerses => 'منحني قوسونه قرآني آیتونه لري';

  @override
  String get detectAuto => 'پېژندنه';

  @override
  String get detectAi => 'د AI پېژندنه';

  @override
  String get detecting => 'مخونه لوستل کیږي…';

  @override
  String get detectedNone => 'په دې مخونو کې د متن نښې ونه موندل شوې';

  @override
  String get layersSourceAuto => 'له مخونو وپېژندل شو';

  @override
  String get layersSourceAi => 'د AI له لارې وپېژندل شو';

  @override
  String get quranSection => 'قرآني آیتونه';

  @override
  String get styleQuran => 'آیتونه په قرآني بڼه ښکاره کړه';

  @override
  String get quranFontLabel => 'د آیتونو لیکبڼه';

  @override
  String get fontAmiriQuran => 'امیري قرآن';

  @override
  String get fontBookFace => 'د کتاب لیکبڼه';

  @override
  String get quranColorLabel => 'د آیتونو رنګ';

  @override
  String get matnColorLabel => 'د متن رنګ';

  @override
  String get matnBoldLabel => 'متن غټ';

  @override
  String get textFormatting => 'د متن بڼه';

  @override
  String get textFormattingSub => 'آیتونه، متن او شرح';

  @override
  String get libSearchHint => 'کتابونه او مؤلفین ولټوئ…';

  @override
  String get narrators => 'راویان';

  @override
  String get tabDownloaded => 'ښکته شوي';

  @override
  String get noDownloads =>
      'کتاب د هغه د معلوماتو پاڼې یا د لوستونکي له منو څخه ښکته کړئ چې پرته له انټرنیټه یې ولولئ.';

  @override
  String get saveOffline => 'د آفلاین لپاره ښکته کړه';

  @override
  String savingOffline(int percent) {
    return 'ښکته کیږي… $percent%';
  }

  @override
  String get savedOffline => 'په دې وسیله کې ساتل شوی';

  @override
  String get removeDownload => 'له وسیلې لرې کړه';

  @override
  String get stopDownload => 'ودروه';

  @override
  String downloadsSize(String size) {
    return '$size په دې وسیله کې';
  }

  @override
  String get deleteAllDownloads => 'ټول ښکته شوي کتابونه ړنګ کړه';

  @override
  String get deleteAllDownloadsConfirm =>
      'په دې وسیله کې ټول ساتل شوي کتابونه ړنګ شي؟';

  @override
  String searchInTextsFor(String query) {
    return 'په متنونو کې «$query» ولټوئ';
  }

  @override
  String seeAll(int count) {
    return 'ټول وګورئ ($count)';
  }

  @override
  String narratorsCount(String count) {
    return '$count راویان';
  }

  @override
  String get searchNarrators => 'راویان ولټوئ…';

  @override
  String get narratorRank => 'درجه';

  @override
  String get narratorDeath => 'وفات';

  @override
  String get findInTexts => 'په متنونو کې یې ومومئ';

  @override
  String get librarySections => 'برخې';

  @override
  String pagesShort(int count) {
    return '$count مخ';
  }
}
