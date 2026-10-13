// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Manabi';

  @override
  String get tagline => 'Answers from the books of Turath — with their sources';

  @override
  String get navChat => 'Chat';

  @override
  String get navLibrary => 'Library';

  @override
  String get navFavorites => 'Saved';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get newChat => 'New chat';

  @override
  String get chats => 'Chats';

  @override
  String get searchChats => 'Search chats';

  @override
  String get noChats => 'No chats yet. Ask your first question.';

  @override
  String get pinned => 'Pinned';

  @override
  String get recent => 'Recent';

  @override
  String get askPlaceholder => 'Ask about Quran, hadith, fiqh…';

  @override
  String get send => 'Send';

  @override
  String get stop => 'Stop';

  @override
  String get scopeAll => 'Whole library';

  @override
  String get scopeBook => 'Book';

  @override
  String get scopeAuthor => 'Author';

  @override
  String get scopeCategory => 'Category';

  @override
  String get scopeTitle => 'Search scope';

  @override
  String get chooseBook => 'Choose a book';

  @override
  String get chooseAuthor => 'Choose an author';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String get clearScope => 'Clear scope';

  @override
  String get answerLanguage => 'Answer language';

  @override
  String get langAuto => 'Same as question';

  @override
  String get welcomeTitle => 'Assalamu alaikum';

  @override
  String get welcomeBody =>
      'Ask in Pashto, Dari, Arabic or English. Manabi searches the classical books of Turath and answers only from what it finds, with the book, author, volume, page and original Arabic text.';

  @override
  String get suggestion1 => 'Who narrated the hadith «إنما الأعمال بالنيات»?';

  @override
  String get suggestion2 =>
      'What do the fiqh books say about touching the private part and wudu?';

  @override
  String get suggestion3 =>
      'What is the meaning of Ihsan in the hadith of Jibril?';

  @override
  String get suggestion4 =>
      'What did the scholars say about the virtue of seeking knowledge?';

  @override
  String get stagePlanning => 'Understanding the question';

  @override
  String get stageSearching => 'Searching the Turath library';

  @override
  String get stageComposing => 'Writing the answer from the sources';

  @override
  String get stageVerifying => 'Verifying every quote against the books';

  @override
  String foundSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages found',
      one: '1 page found',
      zero: 'No pages found',
    );
    return '$_temp0';
  }

  @override
  String get searchedFor => 'Searched for';

  @override
  String get statusAnswered => 'Documented answer';

  @override
  String get statusPartial => 'Partly documented';

  @override
  String get statusInsufficient => 'No documented answer found';

  @override
  String get sources => 'Sources';

  @override
  String sourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources',
      one: '1 source',
    );
    return '$_temp0';
  }

  @override
  String get viewSource => 'Read page';

  @override
  String get openLink => 'Open in Turath';

  @override
  String get openShamela => 'Open in Shamela';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get unsave => 'Remove from saved';

  @override
  String get export => 'Export';

  @override
  String get exportPdf => 'PDF document';

  @override
  String get exportMarkdown => 'Markdown';

  @override
  String get exportText => 'Plain text';

  @override
  String get exportChat => 'Export chat';

  @override
  String get exported => 'Exported';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get ok => 'OK';

  @override
  String get deleteChatConfirm => 'Delete this chat? This cannot be undone.';

  @override
  String get volume => 'Vol.';

  @override
  String get page => 'p.';

  @override
  String get turathPage => 'Turath page';

  @override
  String get author => 'Author';

  @override
  String get book => 'Book';

  @override
  String get category => 'Category';

  @override
  String get quoteVerified => 'Verified word-for-word against the book';

  @override
  String get quoteClose => 'Matched closely — shown exactly as in the book';

  @override
  String get originalText => 'Original text';

  @override
  String get opinions => 'Scholarly views in the sources';

  @override
  String get notes => 'Notes';

  @override
  String get relatedSources => 'Pages that were searched (not evidence)';

  @override
  String get disclaimer =>
      'Manabi reports what the books say; it is not a fatwa. For personal rulings consult a qualified scholar.';

  @override
  String get errNetwork =>
      'Could not connect. Check your internet connection and try again.';

  @override
  String get errServerNotConfigured =>
      'No Manabi server is set. Add the server address in Settings.';

  @override
  String get errNoApiKey =>
      'Add your Gemini API key in Settings to use direct mode.';

  @override
  String get errDirectNotOnWeb =>
      'Direct mode is not available in the browser. Use a Manabi server.';

  @override
  String get errGeminiAuth => 'The Gemini API key is missing or invalid.';

  @override
  String get errGeminiQuota =>
      'Today\'s Gemini usage limit has been reached. Try again in a few hours, or enable billing for the key in Google AI Studio.';

  @override
  String get errGeminiUnavailable =>
      'The AI service did not respond in time. Check your connection and try again.';

  @override
  String get errTurathUnavailable =>
      'The Turath library cannot be reached right now. Please try again.';

  @override
  String get errRateLimited =>
      'Too many questions in a short time. Please wait a moment.';

  @override
  String get errUnauthorized => 'The server rejected the access token.';

  @override
  String get errInterrupted => 'This answer was interrupted.';

  @override
  String get errCancelled => 'Stopped.';

  @override
  String get errNotFound => 'Not found.';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get library => 'Library';

  @override
  String get books => 'Books';

  @override
  String get authors => 'Authors';

  @override
  String get categories => 'Categories';

  @override
  String get searchBooks => 'Search book titles';

  @override
  String get searchAuthors => 'Search authors';

  @override
  String booksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String get noResults => 'No results';

  @override
  String get askInThisBook => 'Ask within this book';

  @override
  String get askThisAuthor => 'Ask within this author\'s works';

  @override
  String get askInCategory => 'Ask within this category';

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get description => 'About the book';

  @override
  String get biography => 'Biography';

  @override
  String get authorBooks => 'Works in the library';

  @override
  String get fullTextSearch => 'Full-text search';

  @override
  String get searchInText => 'Search the text of the books (Arabic)';

  @override
  String matches(int count) {
    return '$count matches';
  }

  @override
  String get readPage => 'Read';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get loading => 'Loading…';

  @override
  String get loadMore => 'Load more';

  @override
  String get noFavorites => 'Answers you save will appear here.';

  @override
  String get history => 'Question history';

  @override
  String get searchHistory => 'Search your questions';

  @override
  String get noHistory => 'No questions yet.';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get interfaceLanguage => 'App language';

  @override
  String get defaultAnswerLanguage => 'Default answer language';

  @override
  String get arabicTextSize => 'Arabic text size';

  @override
  String get answers => 'Answers';

  @override
  String get maxSources => 'Pages to consult per question';

  @override
  String get connection => 'Connection';

  @override
  String get modeServer => 'Manabi server';

  @override
  String get modeServerInfo =>
      'Recommended. The Gemini key stays on the server and the app works on every platform, including the web.';

  @override
  String get modeDirect => 'Direct (own key)';

  @override
  String get modeDirectInfo =>
      'The app talks to Turath and Gemini itself using your own Gemini API key, stored securely on this device. Books open without a key; only the AI answers need it.';

  @override
  String get serverUrl => 'Server address';

  @override
  String get accessToken => 'Access token (optional)';

  @override
  String get geminiKey => 'Gemini API key';

  @override
  String get geminiKeyHint => 'Stored in the device\'s secure storage';

  @override
  String get modelOverride => 'Gemini model (optional)';

  @override
  String get modelOverrideHint => 'Empty = newest available Flash model';

  @override
  String get testConnection => 'Test connection';

  @override
  String connectionOk(String model) {
    return 'Connected · $model';
  }

  @override
  String get data => 'Data';

  @override
  String get clearHistory => 'Delete all chats';

  @override
  String get clearHistoryConfirm =>
      'Delete all chats and saved answers from this device?';

  @override
  String get about => 'About';

  @override
  String get aboutBody =>
      'Manabi searches the Turath library (turath.io) through the open-source Nusus SDK and uses Gemini only to plan searches and to arrange answers from the retrieved pages. Every quote is checked against the book text before it is shown.';

  @override
  String catalogInfo(int books, int authors, String date) {
    return 'Offline catalog: $books books · $authors authors (snapshot $date)';
  }

  @override
  String version(String v) {
    return 'Version $v';
  }

  @override
  String get chatWith => 'Ask Manabi';

  @override
  String get question => 'Question';

  @override
  String get answer => 'Answer';

  @override
  String get generatedBy => 'Generated by Manabi from Turath sources';

  @override
  String get notConfiguredTitle => 'Set up a connection';

  @override
  String get openSettings => 'Open settings';

  @override
  String get allCategories => 'All categories';

  @override
  String get stageReading => 'Reading and ranking the pages';

  @override
  String get welcomeQuestion => 'What would you like to research today?';

  @override
  String get options => 'Search options';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get previous7Days => 'Previous 7 days';

  @override
  String get earlier => 'Earlier';

  @override
  String get libraryHeroTitle => 'The Turath library';

  @override
  String get libraryHeroBody =>
      'Classical books of tafsir, hadith, fiqh, creed, history and language – searchable and quotable.';

  @override
  String get browseCategories => 'Browse categories';

  @override
  String get browseCategoriesSub => 'Sciences and their books';

  @override
  String get fullTextSub => 'Search inside the text of every book';

  @override
  String get allBooks => 'All books';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsAnswersGroup => 'Answers & research';

  @override
  String get settingsInfo => 'Info & help';

  @override
  String get aiStyle => 'AI style';

  @override
  String get dataStorage => 'Data & storage';

  @override
  String get help => 'Help';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get aboutUs => 'About us';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get resetSettings => 'Reset settings';

  @override
  String get resetSettingsConfirm =>
      'All settings (including your key) return to their defaults. Your chats are kept.';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeSample =>
      'Manabi answers your questions with sources from the books of Turath.';

  @override
  String get researchDepth => 'Research depth';

  @override
  String get depthQuick => 'Quick';

  @override
  String get depthStandard => 'Standard';

  @override
  String get depthDeep => 'Deep';

  @override
  String get depthQuickInfo =>
      'Reads fewer pages and answers fast — up to 6 sources.';

  @override
  String get depthStandardInfo =>
      'Balances speed and breadth — up to 14 sources and one follow-up search.';

  @override
  String get depthDeepInfo =>
      'Wide search, more books and two follow-up rounds — up to 18 sources; takes longer.';

  @override
  String get depthHint =>
      'The deeper it goes, the more books are searched and read.';

  @override
  String get chooseLanguage => 'Choose a language';

  @override
  String get openLibrary => 'Open the library';

  @override
  String get openLibrarySub => 'Books, authors and full-text search';

  @override
  String get helpHowTitle => 'How Manabi works';

  @override
  String get helpHowBody =>
      '1. It understands your question and writes Arabic search terms.\n2. It searches thousands of Turath books, including any school or book you name.\n3. It reads the most relevant pages and picks the best ones.\n4. It writes the answer from those pages only.\n5. Every quoted passage is matched word for word against the book; anything not found is removed.';

  @override
  String get helpTipsTitle => 'Tips for a good question';

  @override
  String get helpTipsBody =>
      '• Ask a clear, specific question.\n• If you want a school\'s view, name it (Hanafi, Shafi\'i, Maliki, Hanbali).\n• Name a book, or use + to limit the search to a book, author or category.\n• Choose Deep research for difficult or disputed questions.';

  @override
  String get helpSourcesTitle => 'Sources and citations';

  @override
  String get helpSourcesBody =>
      'The Sources button under every answer lists each citation: book, author, volume, page, the original Arabic text and a direct link on Turath. Small numbers like [1] in the text point to that source.';

  @override
  String get helpLimitsTitle => 'Limits';

  @override
  String get helpLimitsBody =>
      'Manabi is not a mufti; it reports what the books say, and says so plainly when it finds no documented answer. For a ruling on your own situation, consult a trusted scholar.';

  @override
  String get privacyStoredTitle => 'What is stored';

  @override
  String get privacyStoredBody =>
      'Your chats, saved answers and settings are kept on your device only. Manabi needs no account and collects no personal data.';

  @override
  String get privacySentTitle => 'What is sent';

  @override
  String get privacySentBody =>
      'When you ask, the question and a short summary of recent answers are sent to the Manabi server (or to Google Gemini in direct mode) to build the answer, and search terms are sent to turath.io. The server does not store questions; it keeps an answer in memory for up to 20 minutes so an interrupted answer can be recovered.';

  @override
  String get privacyKeyTitle => 'Your key';

  @override
  String get privacyKeyBody =>
      'If you use your own Gemini key, it is kept in the device\'s secure storage (Keychain / Keystore) and sent only to Google.';

  @override
  String get privacyDeleteTitle => 'Deleting';

  @override
  String get privacyDeleteBody =>
      'You can delete all chats and settings at any time under Data & storage.';

  @override
  String get aboutMission =>
      'Our aim: easy, faithful and documented access to the original sources of the Islamic sciences — in Pashto, Dari, Arabic and English.';

  @override
  String get aboutCredits =>
      'With thanks to the Turath library (turath.io) and the Nusus SDK.';

  @override
  String get sourceCode => 'Source code';

  @override
  String get dataCatalog => 'Offline catalog';

  @override
  String get pageExcerpt =>
      'Page excerpt — cited in the answer (not a word-for-word quote)';

  @override
  String get searchInBook => 'Search in book';

  @override
  String get searchInBookHint => 'Search this book (Arabic)';

  @override
  String get goToPage => 'Go to page';

  @override
  String get printedPage => 'Printed page';

  @override
  String get go => 'Go';

  @override
  String pageOf(int page, int total) {
    return '$page of $total';
  }

  @override
  String get bookmarkPage => 'Bookmark page';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get copyPage => 'Copy page text';

  @override
  String get sharePage => 'Share page';

  @override
  String get copyCitation => 'Copy citation';

  @override
  String get readerDisplay => 'Reading display';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get paperTheme => 'Page colour';

  @override
  String get paperWarm => 'Paper';

  @override
  String get paperPlain => 'Plain';

  @override
  String get paperNight => 'Night';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get recentlyRead => 'Recently read';

  @override
  String get footnotes => 'Footnotes';

  @override
  String get filters => 'Filters';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortRelevance => 'Best match';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAuthor => 'Author';

  @override
  String get anyAuthor => 'Any author';

  @override
  String get anyCategory => 'Any category';

  @override
  String get anyBook => 'Any book';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get readBook => 'Read the book';

  @override
  String get volumeShort => 'Vol.';

  @override
  String pagesCount(int count) {
    return '$count pages';
  }

  @override
  String get noMatchesInBook => 'No matches in this book.';

  @override
  String get readerTools => 'Reading tools';

  @override
  String get moreReadingSettings => 'More reading settings';

  @override
  String get readingSettings => 'Reading & library';

  @override
  String get readingSettingsSub => 'Reader, fonts, highlights and library';

  @override
  String get readingMode => 'Reading mode';

  @override
  String get modeScroll => 'Continuous';

  @override
  String get modePages => 'Page by page';

  @override
  String get modeScrollInfo => 'Pages flow one after another, like Turath.';

  @override
  String get modePagesInfo => 'Swipe to turn each page, like a printed book.';

  @override
  String get bookFont => 'Book font';

  @override
  String get fontNaskh => 'Naskh';

  @override
  String get fontModern => 'Modern';

  @override
  String get justifyText => 'Justify lines';

  @override
  String get hideDiacritics => 'Hide diacritics';

  @override
  String get showFootnotes => 'Show footnotes';

  @override
  String get keepScreenOn => 'Keep screen on';

  @override
  String get numberStyle => 'Number style';

  @override
  String get highlightColor => 'Highlight colour';

  @override
  String get highlights => 'Highlights';

  @override
  String get highlight => 'Highlight';

  @override
  String get highlightSaved => 'Highlighted';

  @override
  String get removeHighlight => 'Remove highlight';

  @override
  String get noHighlights => 'Select text in a book and choose Highlight.';

  @override
  String get copyWithCitation => 'Copy with citation';

  @override
  String get tabFavorites => 'Favourites';

  @override
  String get addFavorite => 'Add to favourites';

  @override
  String get removeFavorite => 'Remove from favourites';

  @override
  String get noFavoriteBooks => 'Star a book to keep it here.';

  @override
  String get bookInfo => 'About the book';

  @override
  String get visitedPages => 'History';

  @override
  String get noVisited => 'Pages you open appear here.';

  @override
  String get noBookmarksYet => 'No bookmarks in this book yet.';

  @override
  String get searchHeadings => 'Search headings…';

  @override
  String get fullScreen => 'Full screen';

  @override
  String get exitFullScreen => 'Exit full screen';

  @override
  String get paperSepia => 'Yellow';

  @override
  String get clearReadingHistory => 'Clear reading history';

  @override
  String get clearReadingHistoryConfirm =>
      'Forget where you stopped in every book? Bookmarks, highlights and favourites stay.';

  @override
  String get clearReadingData => 'Delete all reading data';

  @override
  String get clearReadingDataConfirm =>
      'Delete all bookmarks, highlights, favourites and history on this device?';

  @override
  String get resetReader => 'Reset reader settings';

  @override
  String get libraryStartTab => 'Library opens on';

  @override
  String get readingData => 'Your reading data';

  @override
  String get smaller => 'Smaller';

  @override
  String get larger => 'Larger';

  @override
  String get readerPreview => 'Preview';

  @override
  String get pageText => 'Page';

  @override
  String get reader => 'Reader';

  @override
  String get shortcutsHint =>
      'Arrow keys turn pages · Ctrl+F searches the book';

  @override
  String actPlan(int count) {
    return 'Planned $count searches';
  }

  @override
  String actSearch(String query, String where, int hits) {
    return 'Searched «$query»$where — $hits results';
  }

  @override
  String actIn(String book) {
    return ' in $book';
  }

  @override
  String actFound(int count, int total) {
    return 'Collected $count passages from $total matches';
  }

  @override
  String actRank(int count) {
    return 'Reading and weighing $count passages';
  }

  @override
  String actRanked(int count, String coverage) {
    return 'Kept $count passages · coverage: $coverage';
  }

  @override
  String get coverageFull => 'complete';

  @override
  String get coveragePartial => 'partial';

  @override
  String get coverageNone => 'none';

  @override
  String actFollowup(String queries) {
    return 'Looking further: $queries';
  }

  @override
  String actRead(int pages, int books) {
    return 'Opened $pages pages from $books books';
  }

  @override
  String actCompose(int count) {
    return 'Writing the answer from $count pages';
  }

  @override
  String get actVerify => 'Checking every quote against the books';

  @override
  String get actResumed => 'Continued from a finished step';

  @override
  String actRetry(int count) {
    return 'Connection dropped — trying again ($count)';
  }

  @override
  String reconnectingIn(int seconds) {
    return 'Reconnecting in ${seconds}s…';
  }

  @override
  String get showSteps => 'Show steps';

  @override
  String get hideSteps => 'Hide steps';

  @override
  String get writingDraft => 'Draft — quotes are checked when it is finished';

  @override
  String tokensCount(String count) {
    return '$count tokens';
  }

  @override
  String get tokenUsage => 'Token usage';

  @override
  String get tokensInput => 'Input';

  @override
  String get tokensOutput => 'Output';

  @override
  String get tokensThinking => 'Thinking';

  @override
  String get tokensTotal => 'Total';

  @override
  String get modelCalls => 'Model calls';

  @override
  String get answerTime => 'Time';

  @override
  String get thisAnswer => 'This answer';

  @override
  String get thisQuestion => 'This question';

  @override
  String get thisChat => 'This chat';

  @override
  String get chatDetails => 'Chat details';

  @override
  String get contextWindow => 'Context window';

  @override
  String contextWindowInfo(String used, String limit) {
    return 'Largest request in this chat: $used of $limit tokens';
  }

  @override
  String get questionsCount => 'Questions';

  @override
  String get noUsageYet =>
      'Token counts appear for answers made with this version.';

  @override
  String get copyQuestion => 'Copy question';

  @override
  String get askAgain => 'Ask again';

  @override
  String get keepAliveText => 'Preparing your answer from the sources…';

  @override
  String get pdfBook => 'PDF';

  @override
  String get openPdf => 'Open the printed PDF';

  @override
  String get noPdf => 'This book has no PDF on Turath.';

  @override
  String get onTurath => 'More on Turath';

  @override
  String get onTurathInfo => 'Books not in the offline list, found on Turath';

  @override
  String get searchingTurath => 'Searching Turath…';

  @override
  String get fontAmiri => 'Amiri (classic Naskh)';

  @override
  String get fontScheherazade => 'Scheherazade';

  @override
  String get fontPlex => 'IBM Plex Sans Arabic';

  @override
  String get fontNotoNaskh => 'Noto Naskh';

  @override
  String get fontVazir => 'Vazirmatn';

  @override
  String get moreActions => 'More';

  @override
  String get matnSection => 'Matn and commentary';

  @override
  String get matnSeparate => 'Set the matn apart in this book';

  @override
  String get matnMarkersLabel => 'The matn is between';

  @override
  String get bracesVerses => 'Curly braces hold Quran verses';

  @override
  String get detectAuto => 'Detect';

  @override
  String get detectAi => 'Detect with AI';

  @override
  String get detecting => 'Reading the pages…';

  @override
  String get detectedNone => 'No matn markers found on these pages';

  @override
  String get layersSourceAuto => 'Detected from the pages';

  @override
  String get layersSourceAi => 'Detected by AI';

  @override
  String get quranSection => 'Quran verses';

  @override
  String get styleQuran => 'Show verses in the Quran style';

  @override
  String get quranFontLabel => 'Verse font';

  @override
  String get fontAmiriQuran => 'Amiri Quran';

  @override
  String get fontBookFace => 'Book font';

  @override
  String get quranColorLabel => 'Verse colour';

  @override
  String get matnColorLabel => 'Matn colour';

  @override
  String get matnBoldLabel => 'Matn in bold';

  @override
  String get textFormatting => 'Text formatting';

  @override
  String get textFormattingSub => 'Verses, matn and commentary';

  @override
  String get libSearchHint => 'Search books and authors…';

  @override
  String get narrators => 'Narrators';

  @override
  String get tabDownloaded => 'Saved offline';

  @override
  String get noDownloads =>
      'Save a book from its info sheet or the reader menu to read it without internet.';

  @override
  String get saveOffline => 'Save for offline';

  @override
  String savingOffline(int percent) {
    return 'Saving… $percent%';
  }

  @override
  String get savedOffline => 'Saved on this device';

  @override
  String get removeDownload => 'Remove from device';

  @override
  String get stopDownload => 'Stop';

  @override
  String downloadsSize(String size) {
    return '$size on this device';
  }

  @override
  String get deleteAllDownloads => 'Delete all saved books';

  @override
  String get deleteAllDownloadsConfirm =>
      'Delete every book saved on this device?';

  @override
  String searchInTextsFor(String query) {
    return 'Search the texts for «$query»';
  }

  @override
  String seeAll(int count) {
    return 'See all ($count)';
  }

  @override
  String narratorsCount(String count) {
    return '$count narrators';
  }

  @override
  String get searchNarrators => 'Search narrators…';

  @override
  String get narratorRank => 'Grade';

  @override
  String get narratorDeath => 'Died';

  @override
  String get findInTexts => 'Find in the texts';

  @override
  String get librarySections => 'Sections';

  @override
  String pagesShort(int count) {
    return '$count p.';
  }

  @override
  String get pdfView => 'PDF';

  @override
  String get textView => 'Text';

  @override
  String get showPdf => 'Show the printed PDF';

  @override
  String get showText => 'Back to the text';

  @override
  String get pdfAlign => 'Align with the text';

  @override
  String get pdfAlignHint =>
      'If the PDF page does not match the text, shift it here; it is remembered for this book.';

  @override
  String pdfPage(String page) {
    return 'PDF page $page';
  }

  @override
  String get pdfOpenOutside => 'Open in the browser';

  @override
  String get pdfPartFailed => 'Part of this PDF did not load.';

  @override
  String pdfLoadingBytes(String size) {
    return 'Loading the PDF… $size';
  }

  @override
  String get matnBlockRule =>
      'The text above the line on top of each page is matn';

  @override
  String get matnBlockShort => 'Matn printed on top of the page';

  @override
  String get markerAlwaysShort => 'always matn';

  @override
  String get markerVerifiedShort => 'matn when quoted from the matn';

  @override
  String get markersHint =>
      'Tap a sign to switch: off → always matn → only when its words are in the matn.';

  @override
  String get aiPagesLabel => 'Precise: the AI marks every page';

  @override
  String get aiPagesSub =>
      'Most accurate. Uses the AI once for each page you open; the result is kept on this device.';

  @override
  String layersAgreement(int percent) {
    return 'Matches the AI on $percent% of the sample pages';
  }

  @override
  String get layersAutoNote => 'Set automatically from the book\'s layout';

  @override
  String get fineTune => 'Fine-tune';

  @override
  String get matnRulesTitle => 'How this book is read';

  @override
  String get noMatnRules => 'No matn rules yet — tap Detect.';

  @override
  String get moreSuggestions => 'Other questions';

  @override
  String get appFont => 'App font';

  @override
  String get appFontSample => 'The answer comes only from the sources';

  @override
  String get showWholePage => 'Show the whole page';

  @override
  String get showLess => 'Show less';

  @override
  String get searchOptions => 'Search options';

  @override
  String get precisionLabel => 'Match';

  @override
  String get precisionSome => 'Some of the words';

  @override
  String get precisionAll => 'All the words';

  @override
  String get precisionOrder => 'All the words, in order';

  @override
  String get extendedSearch => 'Extended search';

  @override
  String get extendedSearchSub =>
      'Other forms of the words too (prefixes, plurals…)';

  @override
  String get searchNotes => 'Footnotes and introductions';

  @override
  String get searchNotesSub =>
      'Also search editors\' footnotes and introductions';

  @override
  String get searchSavedOnly => 'Only books saved on this device';

  @override
  String get searchSavedOnlySub => 'Works offline';

  @override
  String get showFullResults => 'Show each result in full';

  @override
  String get hideDiacriticsResults => 'Hide diacritics in results';

  @override
  String get searchToc => 'Search the tables of contents';

  @override
  String get searchTocSub => 'Chapter and section titles instead of the text';

  @override
  String get logicLabel => 'Several phrases («and» / «or»)';

  @override
  String get logicAnd => 'and';

  @override
  String get logicOr => 'or';

  @override
  String get addPhrase => 'Add a phrase';

  @override
  String phraseN(int n) {
    return 'Phrase $n';
  }

  @override
  String get pinnedFilters => 'Saved filters';

  @override
  String get savePinned => 'Save the current filters';

  @override
  String get pinnedName => 'Name';

  @override
  String get noPinned => 'No saved filters yet';

  @override
  String savedBooksCount(int count) {
    return 'In $count saved books';
  }

  @override
  String get logicHint =>
      '«and»: pages with every phrase. «or»: pages with any of them.';

  @override
  String get answerModel => 'Answer model';

  @override
  String get modelAuto => 'Automatic';

  @override
  String modelAutoSub(String name) {
    return 'Best available model: $name';
  }

  @override
  String get modelAutoInfo =>
      'Picked for you; switches to another model when a quota runs out.';

  @override
  String get modelPickerNote =>
      'The chosen model writes the answer; quick search steps stay on Flash-Lite. If it fails, the automatic model takes over.';

  @override
  String get costLow => 'Low cost';

  @override
  String get costMedium => 'Medium cost';

  @override
  String get costHigh => 'High cost';

  @override
  String get modelsLoadFailed => 'Could not list the models';

  @override
  String get modelsFromKey => 'Models active for your key';

  @override
  String get modelsFromServer => 'Models active for the server\'s key';

  @override
  String get fillIn => 'Put in the field';

  @override
  String get forget => 'Forget';

  @override
  String get addComment => 'Add a comment';

  @override
  String get comment => 'Comment';

  @override
  String get commentHint => 'Write your note on this passage…';

  @override
  String get commentSaved => 'Comment saved';

  @override
  String get editComment => 'Edit comment';

  @override
  String get deleteComment => 'Delete comment';

  @override
  String get reportError => 'Report a text error';

  @override
  String get reportErrorInfo =>
      'The selected text and its place go with the report. Describe the error briefly.';

  @override
  String get selectedText => 'Selected text';

  @override
  String get errorDescription => 'What is wrong';

  @override
  String get errorDescriptionHint =>
      'e.g. a word is misprinted; it should be «…»';

  @override
  String get sendWhatsApp => 'WhatsApp';

  @override
  String get sendEmail => 'Gmail / email';

  @override
  String get reportSubject => 'Text error — Manabi';

  @override
  String get reportLocation => 'Location';

  @override
  String get couldNotOpen => 'Could not open it';

  @override
  String get allAuthors => 'All authors';

  @override
  String get pickMany => 'Pick one or more';

  @override
  String doneCount(String n) {
    return 'Done ($n)';
  }

  @override
  String get scopeHow =>
      'Each chosen book is searched, and each chosen author\'s books within the chosen categories.';

  @override
  String scopeTooMany(String n) {
    return 'Up to $n searches at once';
  }

  @override
  String get setupTitle => 'Preparing your library';

  @override
  String get setupSub =>
      'First launch only: the book list is built on your device so searching and reading are fast and work offline.';

  @override
  String get setupStorage => 'Storage folder';

  @override
  String get setupCatalog => 'Books, authors and categories';

  @override
  String get setupExtra => 'Newer Turath books';

  @override
  String get setupPdf => 'Books with a scanned PDF';

  @override
  String get setupOfflineNote =>
      'Some parts need the internet; they complete by themselves later.';

  @override
  String get setupContinue => 'Start';

  @override
  String get librarySync => 'Refresh the library';

  @override
  String get librarySyncSub => 'New books and the PDF list; daily by itself';

  @override
  String readCacheInfo(String n) {
    return '$n pages you read are kept offline';
  }

  @override
  String get clearReadCache => 'Clear read pages';

  @override
  String get splitView => 'Split view';

  @override
  String get splitPdf => 'Text and this page\'s PDF';

  @override
  String get splitSameBook => 'This book, another page';

  @override
  String get splitOtherBook => 'Compare with another book';

  @override
  String get splitClose => 'Close split view';

  @override
  String get bookCard => 'Book card';

  @override
  String get readMore => 'Read more';

  @override
  String actChapter(String book, String chapter, String pages) {
    return 'Read the chapter “$chapter” of $book ($pages pages)';
  }

  @override
  String get memory => 'Memory';

  @override
  String get memorySub =>
      'What the assistant remembers about how you like answers';

  @override
  String get memoryOn => 'Remember and use';

  @override
  String get memoryOnSub =>
      'When you say how you want answers (\"answer briefly\", \"I follow the Hanafi school\"), it is kept here and followed in later chats. Kept only on this device.';

  @override
  String get memoryEmpty => 'Nothing remembered yet.';

  @override
  String get memoryAdd => 'Add to memory';

  @override
  String get memoryHint => 'e.g. Answer briefly, with the Hanafi view first';

  @override
  String get memoryClear => 'Forget everything';

  @override
  String get memoryClearConfirm => 'Forget everything the assistant remembers?';

  @override
  String get memorySaved => 'Memory updated';
}
