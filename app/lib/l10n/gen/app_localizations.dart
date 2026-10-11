import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_ps.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fa'),
    Locale('ps'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Manabi'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Answers from the books of Turath — with their sources'**
  String get tagline;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navFavorites;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get searchChats;

  /// No description provided for @noChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet. Ask your first question.'**
  String get noChats;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @askPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask about Quran, hadith, fiqh…'**
  String get askPlaceholder;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @scopeAll.
  ///
  /// In en, this message translates to:
  /// **'Whole library'**
  String get scopeAll;

  /// No description provided for @scopeBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get scopeBook;

  /// No description provided for @scopeAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get scopeAuthor;

  /// No description provided for @scopeCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get scopeCategory;

  /// No description provided for @scopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Search scope'**
  String get scopeTitle;

  /// No description provided for @chooseBook.
  ///
  /// In en, this message translates to:
  /// **'Choose a book'**
  String get chooseBook;

  /// No description provided for @chooseAuthor.
  ///
  /// In en, this message translates to:
  /// **'Choose an author'**
  String get chooseAuthor;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get chooseCategory;

  /// No description provided for @clearScope.
  ///
  /// In en, this message translates to:
  /// **'Clear scope'**
  String get clearScope;

  /// No description provided for @answerLanguage.
  ///
  /// In en, this message translates to:
  /// **'Answer language'**
  String get answerLanguage;

  /// No description provided for @langAuto.
  ///
  /// In en, this message translates to:
  /// **'Same as question'**
  String get langAuto;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Assalamu alaikum'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Ask in Pashto, Dari, Arabic or English. Manabi searches the classical books of Turath and answers only from what it finds, with the book, author, volume, page and original Arabic text.'**
  String get welcomeBody;

  /// No description provided for @suggestion1.
  ///
  /// In en, this message translates to:
  /// **'Who narrated the hadith «إنما الأعمال بالنيات»?'**
  String get suggestion1;

  /// No description provided for @suggestion2.
  ///
  /// In en, this message translates to:
  /// **'What do the fiqh books say about touching the private part and wudu?'**
  String get suggestion2;

  /// No description provided for @suggestion3.
  ///
  /// In en, this message translates to:
  /// **'What is the meaning of Ihsan in the hadith of Jibril?'**
  String get suggestion3;

  /// No description provided for @suggestion4.
  ///
  /// In en, this message translates to:
  /// **'What did the scholars say about the virtue of seeking knowledge?'**
  String get suggestion4;

  /// No description provided for @stagePlanning.
  ///
  /// In en, this message translates to:
  /// **'Understanding the question'**
  String get stagePlanning;

  /// No description provided for @stageSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching the Turath library'**
  String get stageSearching;

  /// No description provided for @stageComposing.
  ///
  /// In en, this message translates to:
  /// **'Writing the answer from the sources'**
  String get stageComposing;

  /// No description provided for @stageVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying every quote against the books'**
  String get stageVerifying;

  /// No description provided for @foundSources.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pages found} =1{1 page found} other{{count} pages found}}'**
  String foundSources(int count);

  /// No description provided for @searchedFor.
  ///
  /// In en, this message translates to:
  /// **'Searched for'**
  String get searchedFor;

  /// No description provided for @statusAnswered.
  ///
  /// In en, this message translates to:
  /// **'Documented answer'**
  String get statusAnswered;

  /// No description provided for @statusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partly documented'**
  String get statusPartial;

  /// No description provided for @statusInsufficient.
  ///
  /// In en, this message translates to:
  /// **'No documented answer found'**
  String get statusInsufficient;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @sourceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source} other{{count} sources}}'**
  String sourceCount(int count);

  /// No description provided for @viewSource.
  ///
  /// In en, this message translates to:
  /// **'Read page'**
  String get viewSource;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open in Turath'**
  String get openLink;

  /// No description provided for @openShamela.
  ///
  /// In en, this message translates to:
  /// **'Open in Shamela'**
  String get openShamela;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @unsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get unsave;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF document'**
  String get exportPdf;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get exportMarkdown;

  /// No description provided for @exportText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get exportText;

  /// No description provided for @exportChat.
  ///
  /// In en, this message translates to:
  /// **'Export chat'**
  String get exportChat;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get exported;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @deleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat? This cannot be undone.'**
  String get deleteChatConfirm;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Vol.'**
  String get volume;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'p.'**
  String get page;

  /// No description provided for @turathPage.
  ///
  /// In en, this message translates to:
  /// **'Turath page'**
  String get turathPage;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @quoteVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified word-for-word against the book'**
  String get quoteVerified;

  /// No description provided for @quoteClose.
  ///
  /// In en, this message translates to:
  /// **'Matched closely — shown exactly as in the book'**
  String get quoteClose;

  /// No description provided for @originalText.
  ///
  /// In en, this message translates to:
  /// **'Original text'**
  String get originalText;

  /// No description provided for @opinions.
  ///
  /// In en, this message translates to:
  /// **'Scholarly views in the sources'**
  String get opinions;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @relatedSources.
  ///
  /// In en, this message translates to:
  /// **'Pages that were searched (not evidence)'**
  String get relatedSources;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Manabi reports what the books say; it is not a fatwa. For personal rulings consult a qualified scholar.'**
  String get disclaimer;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your internet connection and try again.'**
  String get errNetwork;

  /// No description provided for @errServerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No Manabi server is set. Add the server address in Settings.'**
  String get errServerNotConfigured;

  /// No description provided for @errNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'Add your Gemini API key in Settings to use direct mode.'**
  String get errNoApiKey;

  /// No description provided for @errDirectNotOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Direct mode is not available in the browser. Use a Manabi server.'**
  String get errDirectNotOnWeb;

  /// No description provided for @errGeminiAuth.
  ///
  /// In en, this message translates to:
  /// **'The Gemini API key is missing or invalid.'**
  String get errGeminiAuth;

  /// No description provided for @errGeminiQuota.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Gemini usage limit has been reached. Try again in a few hours, or enable billing for the key in Google AI Studio.'**
  String get errGeminiQuota;

  /// No description provided for @errGeminiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI service did not respond in time. Check your connection and try again.'**
  String get errGeminiUnavailable;

  /// No description provided for @errTurathUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Turath library cannot be reached right now. Please try again.'**
  String get errTurathUnavailable;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many questions in a short time. Please wait a moment.'**
  String get errRateLimited;

  /// No description provided for @errUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the access token.'**
  String get errUnauthorized;

  /// No description provided for @errInterrupted.
  ///
  /// In en, this message translates to:
  /// **'This answer was interrupted.'**
  String get errInterrupted;

  /// No description provided for @errCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get errCancelled;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errNotFound;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get books;

  /// No description provided for @authors.
  ///
  /// In en, this message translates to:
  /// **'Authors'**
  String get authors;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @searchBooks.
  ///
  /// In en, this message translates to:
  /// **'Search book titles'**
  String get searchBooks;

  /// No description provided for @searchAuthors.
  ///
  /// In en, this message translates to:
  /// **'Search authors'**
  String get searchAuthors;

  /// No description provided for @booksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 book} other{{count} books}}'**
  String booksCount(int count);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @askInThisBook.
  ///
  /// In en, this message translates to:
  /// **'Ask within this book'**
  String get askInThisBook;

  /// No description provided for @askThisAuthor.
  ///
  /// In en, this message translates to:
  /// **'Ask within this author\'s works'**
  String get askThisAuthor;

  /// No description provided for @askInCategory.
  ///
  /// In en, this message translates to:
  /// **'Ask within this category'**
  String get askInCategory;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get tableOfContents;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'About the book'**
  String get description;

  /// No description provided for @biography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get biography;

  /// No description provided for @authorBooks.
  ///
  /// In en, this message translates to:
  /// **'Works in the library'**
  String get authorBooks;

  /// No description provided for @fullTextSearch.
  ///
  /// In en, this message translates to:
  /// **'Full-text search'**
  String get fullTextSearch;

  /// No description provided for @searchInText.
  ///
  /// In en, this message translates to:
  /// **'Search the text of the books (Arabic)'**
  String get searchInText;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String matches(int count);

  /// No description provided for @readPage.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readPage;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'Answers you save will appear here.'**
  String get noFavorites;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'Question history'**
  String get history;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search your questions'**
  String get searchHistory;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No questions yet.'**
  String get noHistory;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get interfaceLanguage;

  /// No description provided for @defaultAnswerLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default answer language'**
  String get defaultAnswerLanguage;

  /// No description provided for @arabicTextSize.
  ///
  /// In en, this message translates to:
  /// **'Arabic text size'**
  String get arabicTextSize;

  /// No description provided for @answers.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get answers;

  /// No description provided for @maxSources.
  ///
  /// In en, this message translates to:
  /// **'Pages to consult per question'**
  String get maxSources;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @modeServer.
  ///
  /// In en, this message translates to:
  /// **'Manabi server'**
  String get modeServer;

  /// No description provided for @modeServerInfo.
  ///
  /// In en, this message translates to:
  /// **'Recommended. The Gemini key stays on the server and the app works on every platform, including the web.'**
  String get modeServerInfo;

  /// No description provided for @modeDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct (own key)'**
  String get modeDirect;

  /// No description provided for @modeDirectInfo.
  ///
  /// In en, this message translates to:
  /// **'The app talks to Turath and Gemini itself using your own Gemini API key, stored securely on this device. Not available on the web.'**
  String get modeDirectInfo;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverUrl;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token (optional)'**
  String get accessToken;

  /// No description provided for @geminiKey.
  ///
  /// In en, this message translates to:
  /// **'Gemini API key'**
  String get geminiKey;

  /// No description provided for @geminiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Stored in the device\'s secure storage'**
  String get geminiKeyHint;

  /// No description provided for @modelOverride.
  ///
  /// In en, this message translates to:
  /// **'Gemini model (optional)'**
  String get modelOverride;

  /// No description provided for @modelOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'Empty = newest available Flash model'**
  String get modelOverrideHint;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @connectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connected · {model}'**
  String connectionOk(String model);

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Delete all chats'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all chats and saved answers from this device?'**
  String get clearHistoryConfirm;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Manabi searches the Turath library (turath.io) through the open-source Nusus SDK and uses Gemini only to plan searches and to arrange answers from the retrieved pages. Every quote is checked against the book text before it is shown.'**
  String get aboutBody;

  /// No description provided for @catalogInfo.
  ///
  /// In en, this message translates to:
  /// **'Offline catalog: {books} books · {authors} authors (snapshot {date})'**
  String catalogInfo(int books, int authors, String date);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {v}'**
  String version(String v);

  /// No description provided for @chatWith.
  ///
  /// In en, this message translates to:
  /// **'Ask Manabi'**
  String get chatWith;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @generatedBy.
  ///
  /// In en, this message translates to:
  /// **'Generated by Manabi from Turath sources'**
  String get generatedBy;

  /// No description provided for @notConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up a connection'**
  String get notConfiguredTitle;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @stageReading.
  ///
  /// In en, this message translates to:
  /// **'Reading and ranking the pages'**
  String get stageReading;

  /// No description provided for @welcomeQuestion.
  ///
  /// In en, this message translates to:
  /// **'What would you like to research today?'**
  String get welcomeQuestion;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Search options'**
  String get options;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @previous7Days.
  ///
  /// In en, this message translates to:
  /// **'Previous 7 days'**
  String get previous7Days;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @libraryHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'The Turath library'**
  String get libraryHeroTitle;

  /// No description provided for @libraryHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Classical books of tafsir, hadith, fiqh, creed, history and language – searchable and quotable.'**
  String get libraryHeroBody;

  /// No description provided for @browseCategories.
  ///
  /// In en, this message translates to:
  /// **'Browse categories'**
  String get browseCategories;

  /// No description provided for @browseCategoriesSub.
  ///
  /// In en, this message translates to:
  /// **'Sciences and their books'**
  String get browseCategoriesSub;

  /// No description provided for @fullTextSub.
  ///
  /// In en, this message translates to:
  /// **'Search inside the text of every book'**
  String get fullTextSub;

  /// No description provided for @allBooks.
  ///
  /// In en, this message translates to:
  /// **'All books'**
  String get allBooks;

  /// No description provided for @settingsApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsApp;

  /// No description provided for @settingsAnswersGroup.
  ///
  /// In en, this message translates to:
  /// **'Answers & research'**
  String get settingsAnswersGroup;

  /// No description provided for @settingsInfo.
  ///
  /// In en, this message translates to:
  /// **'Info & help'**
  String get settingsInfo;

  /// No description provided for @aiStyle.
  ///
  /// In en, this message translates to:
  /// **'AI style'**
  String get aiStyle;

  /// No description provided for @dataStorage.
  ///
  /// In en, this message translates to:
  /// **'Data & storage'**
  String get dataStorage;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get aboutUs;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @resetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get resetSettings;

  /// No description provided for @resetSettingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'All settings (including your key) return to their defaults. Your chats are kept.'**
  String get resetSettingsConfirm;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeSample.
  ///
  /// In en, this message translates to:
  /// **'Manabi answers your questions with sources from the books of Turath.'**
  String get textSizeSample;

  /// No description provided for @researchDepth.
  ///
  /// In en, this message translates to:
  /// **'Research depth'**
  String get researchDepth;

  /// No description provided for @depthQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get depthQuick;

  /// No description provided for @depthStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get depthStandard;

  /// No description provided for @depthDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get depthDeep;

  /// No description provided for @depthQuickInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads fewer pages and answers fast — up to 6 sources.'**
  String get depthQuickInfo;

  /// No description provided for @depthStandardInfo.
  ///
  /// In en, this message translates to:
  /// **'Balances speed and breadth — up to 14 sources and one follow-up search.'**
  String get depthStandardInfo;

  /// No description provided for @depthDeepInfo.
  ///
  /// In en, this message translates to:
  /// **'Wide search, more books and two follow-up rounds — up to 18 sources; takes longer.'**
  String get depthDeepInfo;

  /// No description provided for @depthHint.
  ///
  /// In en, this message translates to:
  /// **'The deeper it goes, the more books are searched and read.'**
  String get depthHint;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get chooseLanguage;

  /// No description provided for @openLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open the library'**
  String get openLibrary;

  /// No description provided for @openLibrarySub.
  ///
  /// In en, this message translates to:
  /// **'Books, authors and full-text search'**
  String get openLibrarySub;

  /// No description provided for @helpHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How Manabi works'**
  String get helpHowTitle;

  /// No description provided for @helpHowBody.
  ///
  /// In en, this message translates to:
  /// **'1. It understands your question and writes Arabic search terms.\n2. It searches thousands of Turath books, including any school or book you name.\n3. It reads the most relevant pages and picks the best ones.\n4. It writes the answer from those pages only.\n5. Every quoted passage is matched word for word against the book; anything not found is removed.'**
  String get helpHowBody;

  /// No description provided for @helpTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips for a good question'**
  String get helpTipsTitle;

  /// No description provided for @helpTipsBody.
  ///
  /// In en, this message translates to:
  /// **'• Ask a clear, specific question.\n• If you want a school\'s view, name it (Hanafi, Shafi\'i, Maliki, Hanbali).\n• Name a book, or use + to limit the search to a book, author or category.\n• Choose Deep research for difficult or disputed questions.'**
  String get helpTipsBody;

  /// No description provided for @helpSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources and citations'**
  String get helpSourcesTitle;

  /// No description provided for @helpSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'The Sources button under every answer lists each citation: book, author, volume, page, the original Arabic text and a direct link on Turath. Small numbers like [1] in the text point to that source.'**
  String get helpSourcesBody;

  /// No description provided for @helpLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get helpLimitsTitle;

  /// No description provided for @helpLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'Manabi is not a mufti; it reports what the books say, and says so plainly when it finds no documented answer. For a ruling on your own situation, consult a trusted scholar.'**
  String get helpLimitsBody;

  /// No description provided for @privacyStoredTitle.
  ///
  /// In en, this message translates to:
  /// **'What is stored'**
  String get privacyStoredTitle;

  /// No description provided for @privacyStoredBody.
  ///
  /// In en, this message translates to:
  /// **'Your chats, saved answers and settings are kept on your device only. Manabi needs no account and collects no personal data.'**
  String get privacyStoredBody;

  /// No description provided for @privacySentTitle.
  ///
  /// In en, this message translates to:
  /// **'What is sent'**
  String get privacySentTitle;

  /// No description provided for @privacySentBody.
  ///
  /// In en, this message translates to:
  /// **'When you ask, the question and a short summary of recent answers are sent to the Manabi server (or to Google Gemini in direct mode) to build the answer, and search terms are sent to turath.io. The server does not store questions; it keeps an answer in memory for up to 20 minutes so an interrupted answer can be recovered.'**
  String get privacySentBody;

  /// No description provided for @privacyKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your key'**
  String get privacyKeyTitle;

  /// No description provided for @privacyKeyBody.
  ///
  /// In en, this message translates to:
  /// **'If you use your own Gemini key, it is kept in the device\'s secure storage (Keychain / Keystore) and sent only to Google.'**
  String get privacyKeyBody;

  /// No description provided for @privacyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get privacyDeleteTitle;

  /// No description provided for @privacyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'You can delete all chats and settings at any time under Data & storage.'**
  String get privacyDeleteBody;

  /// No description provided for @aboutMission.
  ///
  /// In en, this message translates to:
  /// **'Our aim: easy, faithful and documented access to the original sources of the Islamic sciences — in Pashto, Dari, Arabic and English.'**
  String get aboutMission;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'With thanks to the Turath library (turath.io) and the Nusus SDK.'**
  String get aboutCredits;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @dataCatalog.
  ///
  /// In en, this message translates to:
  /// **'Offline catalog'**
  String get dataCatalog;

  /// No description provided for @pageExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Page excerpt — cited in the answer (not a word-for-word quote)'**
  String get pageExcerpt;

  /// No description provided for @searchInBook.
  ///
  /// In en, this message translates to:
  /// **'Search in book'**
  String get searchInBook;

  /// No description provided for @searchInBookHint.
  ///
  /// In en, this message translates to:
  /// **'Search this book (Arabic)'**
  String get searchInBookHint;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @printedPage.
  ///
  /// In en, this message translates to:
  /// **'Printed page'**
  String get printedPage;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'{page} of {total}'**
  String pageOf(int page, int total);

  /// No description provided for @bookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark page'**
  String get bookmarkPage;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @copyPage.
  ///
  /// In en, this message translates to:
  /// **'Copy page text'**
  String get copyPage;

  /// No description provided for @sharePage.
  ///
  /// In en, this message translates to:
  /// **'Share page'**
  String get sharePage;

  /// No description provided for @copyCitation.
  ///
  /// In en, this message translates to:
  /// **'Copy citation'**
  String get copyCitation;

  /// No description provided for @readerDisplay.
  ///
  /// In en, this message translates to:
  /// **'Reading display'**
  String get readerDisplay;

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @paperTheme.
  ///
  /// In en, this message translates to:
  /// **'Page colour'**
  String get paperTheme;

  /// No description provided for @paperWarm.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paperWarm;

  /// No description provided for @paperPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get paperPlain;

  /// No description provided for @paperNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get paperNight;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @recentlyRead.
  ///
  /// In en, this message translates to:
  /// **'Recently read'**
  String get recentlyRead;

  /// No description provided for @footnotes.
  ///
  /// In en, this message translates to:
  /// **'Footnotes'**
  String get footnotes;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// No description provided for @sortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get sortRelevance;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get sortAuthor;

  /// No description provided for @anyAuthor.
  ///
  /// In en, this message translates to:
  /// **'Any author'**
  String get anyAuthor;

  /// No description provided for @anyCategory.
  ///
  /// In en, this message translates to:
  /// **'Any category'**
  String get anyCategory;

  /// No description provided for @anyBook.
  ///
  /// In en, this message translates to:
  /// **'Any book'**
  String get anyBook;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @readBook.
  ///
  /// In en, this message translates to:
  /// **'Read the book'**
  String get readBook;

  /// No description provided for @volumeShort.
  ///
  /// In en, this message translates to:
  /// **'Vol.'**
  String get volumeShort;

  /// No description provided for @pagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String pagesCount(int count);

  /// No description provided for @noMatchesInBook.
  ///
  /// In en, this message translates to:
  /// **'No matches in this book.'**
  String get noMatchesInBook;

  /// No description provided for @readerTools.
  ///
  /// In en, this message translates to:
  /// **'Reading tools'**
  String get readerTools;

  /// No description provided for @moreReadingSettings.
  ///
  /// In en, this message translates to:
  /// **'More reading settings'**
  String get moreReadingSettings;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading & library'**
  String get readingSettings;

  /// No description provided for @readingSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Reader, fonts, highlights and library'**
  String get readingSettingsSub;

  /// No description provided for @readingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readingMode;

  /// No description provided for @modeScroll.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get modeScroll;

  /// No description provided for @modePages.
  ///
  /// In en, this message translates to:
  /// **'Page by page'**
  String get modePages;

  /// No description provided for @modeScrollInfo.
  ///
  /// In en, this message translates to:
  /// **'Pages flow one after another, like Turath.'**
  String get modeScrollInfo;

  /// No description provided for @modePagesInfo.
  ///
  /// In en, this message translates to:
  /// **'Swipe to turn each page, like a printed book.'**
  String get modePagesInfo;

  /// No description provided for @bookFont.
  ///
  /// In en, this message translates to:
  /// **'Book font'**
  String get bookFont;

  /// No description provided for @fontNaskh.
  ///
  /// In en, this message translates to:
  /// **'Naskh'**
  String get fontNaskh;

  /// No description provided for @fontModern.
  ///
  /// In en, this message translates to:
  /// **'Modern'**
  String get fontModern;

  /// No description provided for @justifyText.
  ///
  /// In en, this message translates to:
  /// **'Justify lines'**
  String get justifyText;

  /// No description provided for @hideDiacritics.
  ///
  /// In en, this message translates to:
  /// **'Hide diacritics'**
  String get hideDiacritics;

  /// No description provided for @showFootnotes.
  ///
  /// In en, this message translates to:
  /// **'Show footnotes'**
  String get showFootnotes;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get keepScreenOn;

  /// No description provided for @numberStyle.
  ///
  /// In en, this message translates to:
  /// **'Number style'**
  String get numberStyle;

  /// No description provided for @highlightColor.
  ///
  /// In en, this message translates to:
  /// **'Highlight colour'**
  String get highlightColor;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @highlightSaved.
  ///
  /// In en, this message translates to:
  /// **'Highlighted'**
  String get highlightSaved;

  /// No description provided for @removeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove highlight'**
  String get removeHighlight;

  /// No description provided for @noHighlights.
  ///
  /// In en, this message translates to:
  /// **'Select text in a book and choose Highlight.'**
  String get noHighlights;

  /// No description provided for @copyWithCitation.
  ///
  /// In en, this message translates to:
  /// **'Copy with citation'**
  String get copyWithCitation;

  /// No description provided for @tabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get tabFavorites;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFavorite;

  /// No description provided for @noFavoriteBooks.
  ///
  /// In en, this message translates to:
  /// **'Star a book to keep it here.'**
  String get noFavoriteBooks;

  /// No description provided for @bookInfo.
  ///
  /// In en, this message translates to:
  /// **'About the book'**
  String get bookInfo;

  /// No description provided for @visitedPages.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get visitedPages;

  /// No description provided for @noVisited.
  ///
  /// In en, this message translates to:
  /// **'Pages you open appear here.'**
  String get noVisited;

  /// No description provided for @noBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks in this book yet.'**
  String get noBookmarksYet;

  /// No description provided for @searchHeadings.
  ///
  /// In en, this message translates to:
  /// **'Search headings…'**
  String get searchHeadings;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// No description provided for @exitFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get exitFullScreen;

  /// No description provided for @paperSepia.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get paperSepia;

  /// No description provided for @clearReadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear reading history'**
  String get clearReadingHistory;

  /// No description provided for @clearReadingHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Forget where you stopped in every book? Bookmarks, highlights and favourites stay.'**
  String get clearReadingHistoryConfirm;

  /// No description provided for @clearReadingData.
  ///
  /// In en, this message translates to:
  /// **'Delete all reading data'**
  String get clearReadingData;

  /// No description provided for @clearReadingDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all bookmarks, highlights, favourites and history on this device?'**
  String get clearReadingDataConfirm;

  /// No description provided for @resetReader.
  ///
  /// In en, this message translates to:
  /// **'Reset reader settings'**
  String get resetReader;

  /// No description provided for @libraryStartTab.
  ///
  /// In en, this message translates to:
  /// **'Library opens on'**
  String get libraryStartTab;

  /// No description provided for @readingData.
  ///
  /// In en, this message translates to:
  /// **'Your reading data'**
  String get readingData;

  /// No description provided for @smaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get smaller;

  /// No description provided for @larger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get larger;

  /// No description provided for @readerPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get readerPreview;

  /// No description provided for @pageText.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get pageText;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// No description provided for @shortcutsHint.
  ///
  /// In en, this message translates to:
  /// **'Arrow keys turn pages · Ctrl+F searches the book'**
  String get shortcutsHint;

  /// No description provided for @actPlan.
  ///
  /// In en, this message translates to:
  /// **'Planned {count} searches'**
  String actPlan(int count);

  /// No description provided for @actSearch.
  ///
  /// In en, this message translates to:
  /// **'Searched «{query}»{where} — {hits} results'**
  String actSearch(String query, String where, int hits);

  /// No description provided for @actIn.
  ///
  /// In en, this message translates to:
  /// **' in {book}'**
  String actIn(String book);

  /// No description provided for @actFound.
  ///
  /// In en, this message translates to:
  /// **'Collected {count} passages from {total} matches'**
  String actFound(int count, int total);

  /// No description provided for @actRank.
  ///
  /// In en, this message translates to:
  /// **'Reading and weighing {count} passages'**
  String actRank(int count);

  /// No description provided for @actRanked.
  ///
  /// In en, this message translates to:
  /// **'Kept {count} passages · coverage: {coverage}'**
  String actRanked(int count, String coverage);

  /// No description provided for @coverageFull.
  ///
  /// In en, this message translates to:
  /// **'complete'**
  String get coverageFull;

  /// No description provided for @coveragePartial.
  ///
  /// In en, this message translates to:
  /// **'partial'**
  String get coveragePartial;

  /// No description provided for @coverageNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get coverageNone;

  /// No description provided for @actFollowup.
  ///
  /// In en, this message translates to:
  /// **'Looking further: {queries}'**
  String actFollowup(String queries);

  /// No description provided for @actRead.
  ///
  /// In en, this message translates to:
  /// **'Opened {pages} pages from {books} books'**
  String actRead(int pages, int books);

  /// No description provided for @actCompose.
  ///
  /// In en, this message translates to:
  /// **'Writing the answer from {count} pages'**
  String actCompose(int count);

  /// No description provided for @actVerify.
  ///
  /// In en, this message translates to:
  /// **'Checking every quote against the books'**
  String get actVerify;

  /// No description provided for @actResumed.
  ///
  /// In en, this message translates to:
  /// **'Continued from a finished step'**
  String get actResumed;

  /// No description provided for @actRetry.
  ///
  /// In en, this message translates to:
  /// **'Connection dropped — trying again ({count})'**
  String actRetry(int count);

  /// No description provided for @reconnectingIn.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting in {seconds}s…'**
  String reconnectingIn(int seconds);

  /// No description provided for @showSteps.
  ///
  /// In en, this message translates to:
  /// **'Show steps'**
  String get showSteps;

  /// No description provided for @hideSteps.
  ///
  /// In en, this message translates to:
  /// **'Hide steps'**
  String get hideSteps;

  /// No description provided for @writingDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft — quotes are checked when it is finished'**
  String get writingDraft;

  /// No description provided for @tokensCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String tokensCount(String count);

  /// No description provided for @tokenUsage.
  ///
  /// In en, this message translates to:
  /// **'Token usage'**
  String get tokenUsage;

  /// No description provided for @tokensInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get tokensInput;

  /// No description provided for @tokensOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get tokensOutput;

  /// No description provided for @tokensThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get tokensThinking;

  /// No description provided for @tokensTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get tokensTotal;

  /// No description provided for @modelCalls.
  ///
  /// In en, this message translates to:
  /// **'Model calls'**
  String get modelCalls;

  /// No description provided for @answerTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get answerTime;

  /// No description provided for @thisAnswer.
  ///
  /// In en, this message translates to:
  /// **'This answer'**
  String get thisAnswer;

  /// No description provided for @thisQuestion.
  ///
  /// In en, this message translates to:
  /// **'This question'**
  String get thisQuestion;

  /// No description provided for @thisChat.
  ///
  /// In en, this message translates to:
  /// **'This chat'**
  String get thisChat;

  /// No description provided for @chatDetails.
  ///
  /// In en, this message translates to:
  /// **'Chat details'**
  String get chatDetails;

  /// No description provided for @contextWindow.
  ///
  /// In en, this message translates to:
  /// **'Context window'**
  String get contextWindow;

  /// No description provided for @contextWindowInfo.
  ///
  /// In en, this message translates to:
  /// **'Largest request in this chat: {used} of {limit} tokens'**
  String contextWindowInfo(String used, String limit);

  /// No description provided for @questionsCount.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questionsCount;

  /// No description provided for @noUsageYet.
  ///
  /// In en, this message translates to:
  /// **'Token counts appear for answers made with this version.'**
  String get noUsageYet;

  /// No description provided for @copyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Copy question'**
  String get copyQuestion;

  /// No description provided for @askAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get askAgain;

  /// No description provided for @keepAliveText.
  ///
  /// In en, this message translates to:
  /// **'Preparing your answer from the sources…'**
  String get keepAliveText;

  /// No description provided for @pdfBook.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdfBook;

  /// No description provided for @openPdf.
  ///
  /// In en, this message translates to:
  /// **'Open the printed PDF'**
  String get openPdf;

  /// No description provided for @noPdf.
  ///
  /// In en, this message translates to:
  /// **'This book has no PDF on Turath.'**
  String get noPdf;

  /// No description provided for @onTurath.
  ///
  /// In en, this message translates to:
  /// **'More on Turath'**
  String get onTurath;

  /// No description provided for @onTurathInfo.
  ///
  /// In en, this message translates to:
  /// **'Books not in the offline list, found on Turath'**
  String get onTurathInfo;

  /// No description provided for @searchingTurath.
  ///
  /// In en, this message translates to:
  /// **'Searching Turath…'**
  String get searchingTurath;

  /// No description provided for @fontAmiri.
  ///
  /// In en, this message translates to:
  /// **'Amiri (classic Naskh)'**
  String get fontAmiri;

  /// No description provided for @fontScheherazade.
  ///
  /// In en, this message translates to:
  /// **'Scheherazade'**
  String get fontScheherazade;

  /// No description provided for @fontPlex.
  ///
  /// In en, this message translates to:
  /// **'IBM Plex Sans Arabic'**
  String get fontPlex;

  /// No description provided for @fontNotoNaskh.
  ///
  /// In en, this message translates to:
  /// **'Noto Naskh'**
  String get fontNotoNaskh;

  /// No description provided for @fontVazir.
  ///
  /// In en, this message translates to:
  /// **'Vazirmatn'**
  String get fontVazir;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fa', 'ps'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'ps':
      return AppLocalizationsPs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
