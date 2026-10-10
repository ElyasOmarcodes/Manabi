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
      'Gemini usage limit reached. Please try again later.';

  @override
  String get errGeminiUnavailable =>
      'The AI service is not responding right now. Please try again.';

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
      'The app talks to Turath and Gemini itself using your own Gemini API key, stored securely on this device. Not available on the web.';

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
}
