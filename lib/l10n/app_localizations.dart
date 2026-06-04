import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('es'),
  ];

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @packNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Pack not loaded: {folder}'**
  String packNotLoaded(String folder);

  /// No description provided for @couldNotLoadBoard.
  ///
  /// In en, this message translates to:
  /// **'Could not load the default board.'**
  String get couldNotLoadBoard;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @sectionCrashLogs.
  ///
  /// In en, this message translates to:
  /// **'Crash logs'**
  String get sectionCrashLogs;

  /// No description provided for @viewCrashLogs.
  ///
  /// In en, this message translates to:
  /// **'View crash logs'**
  String get viewCrashLogs;

  /// No description provided for @viewCrashLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See exactly what would be sent before you send it'**
  String get viewCrashLogsSubtitle;

  /// No description provided for @shareCrashLogs.
  ///
  /// In en, this message translates to:
  /// **'Send crash logs'**
  String get shareCrashLogs;

  /// No description provided for @shareCrashLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opens your mail app to send the logs to KHF; you tap send'**
  String get shareCrashLogsSubtitle;

  /// No description provided for @sectionBoards.
  ///
  /// In en, this message translates to:
  /// **'Boards'**
  String get sectionBoards;

  /// No description provided for @importBoardPack.
  ///
  /// In en, this message translates to:
  /// **'Import a board pack'**
  String get importBoardPack;

  /// No description provided for @importBoardPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a board JSON file from this device'**
  String get importBoardPackSubtitle;

  /// No description provided for @sectionOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get sectionOnboarding;

  /// No description provided for @rerunOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Re-run the welcome'**
  String get rerunOnboarding;

  /// No description provided for @rerunOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the first-launch flow again'**
  String get rerunOnboardingSubtitle;

  /// No description provided for @sectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sectionAdvanced;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get advancedSettings;

  /// No description provided for @advancedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voice, glow, tap size, learning'**
  String get advancedSettingsSubtitle;

  /// No description provided for @sectionUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get sectionUpdates;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @aboutLighthouse.
  ///
  /// In en, this message translates to:
  /// **'About Lighthouse'**
  String get aboutLighthouse;

  /// No description provided for @aboutLighthouseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A free project of the Kinder Horizon Foundation'**
  String get aboutLighthouseSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How Lighthouse handles your data (opens in your browser)'**
  String get privacyPolicySubtitle;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get couldNotOpenLink;

  /// No description provided for @noCrashLogsToShare.
  ///
  /// In en, this message translates to:
  /// **'No crash logs to send.'**
  String get noCrashLogsToShare;

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse AAC crash logs'**
  String get shareSubject;

  /// No description provided for @crashEmailBody.
  ///
  /// In en, this message translates to:
  /// **'The attached crash logs are from Lighthouse AAC. Thank you for helping us fix the problem.'**
  String get crashEmailBody;

  /// No description provided for @shareBody.
  ///
  /// In en, this message translates to:
  /// **'Crash logs from Lighthouse AAC are attached. Please send them to bugs@kinderhorizon.org.'**
  String get shareBody;

  /// No description provided for @rerunOnboardingConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-run onboarding?'**
  String get rerunOnboardingConfirmTitle;

  /// No description provided for @rerunOnboardingConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will see the first-launch flow again. The board and your child\'s learned patterns are not affected.'**
  String get rerunOnboardingConfirmBody;

  /// No description provided for @rerun.
  ///
  /// In en, this message translates to:
  /// **'Re-run'**
  String get rerun;

  /// No description provided for @couldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the picked file.'**
  String get couldNotReadFile;

  /// No description provided for @importedBoard.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{board}\".'**
  String importedBoard(String board);

  /// No description provided for @couldNotImport.
  ///
  /// In en, this message translates to:
  /// **'Could not import: {error}'**
  String couldNotImport(String error);

  /// No description provided for @advancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedTitle;

  /// No description provided for @sectionVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get sectionVoice;

  /// No description provided for @sectionVisual.
  ///
  /// In en, this message translates to:
  /// **'How the board looks'**
  String get sectionVisual;

  /// No description provided for @sectionLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sectionLearning;

  /// No description provided for @resetLearnedState.
  ///
  /// In en, this message translates to:
  /// **'Reset what Lighthouse has learned'**
  String get resetLearnedState;

  /// No description provided for @resetLearnedStateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clears your child\'s word patterns. The board itself is not changed.'**
  String get resetLearnedStateSubtitle;

  /// No description provided for @resetLearnedStateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset learned state?'**
  String get resetLearnedStateConfirmTitle;

  /// No description provided for @resetLearnedStateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently erases the glow predictions your child has built up. It cannot be undone. The board, language, and other settings are not affected.\n\nUse this when handing the device to a different child, or if the glows no longer match how your child communicates.'**
  String get resetLearnedStateConfirmBody;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @learnedStateCleared.
  ///
  /// In en, this message translates to:
  /// **'Learned state cleared.'**
  String get learnedStateCleared;

  /// No description provided for @couldNotClearLearnedState.
  ///
  /// In en, this message translates to:
  /// **'Could not clear learned state. Try again.'**
  String get couldNotClearLearnedState;

  /// No description provided for @voiceOutput.
  ///
  /// In en, this message translates to:
  /// **'Voice output'**
  String get voiceOutput;

  /// No description provided for @ttsModeOn.
  ///
  /// In en, this message translates to:
  /// **'On (speak every tap)'**
  String get ttsModeOn;

  /// No description provided for @ttsModeOnRequest.
  ///
  /// In en, this message translates to:
  /// **'On-request (long-press to speak)'**
  String get ttsModeOnRequest;

  /// No description provided for @ttsModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off (no synthesized speech)'**
  String get ttsModeOff;

  /// No description provided for @ttsModeAls.
  ///
  /// In en, this message translates to:
  /// **'Show word large, no speech (ALS)'**
  String get ttsModeAls;

  /// No description provided for @glowStyle.
  ///
  /// In en, this message translates to:
  /// **'Glow style'**
  String get glowStyle;

  /// No description provided for @glowStyleHalo.
  ///
  /// In en, this message translates to:
  /// **'Soft halo'**
  String get glowStyleHalo;

  /// No description provided for @hitboxExpansion.
  ///
  /// In en, this message translates to:
  /// **'Tap size'**
  String get hitboxExpansion;

  /// No description provided for @hitboxNone.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get hitboxNone;

  /// No description provided for @hitboxSubtle.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get hitboxSubtle;

  /// No description provided for @hitboxMaximum.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get hitboxMaximum;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A free project of the Kinder Horizon Foundation.'**
  String get aboutTagline;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse helps non-speaking children communicate. It is free, has no ads, and keeps everything your child does on this device.'**
  String get aboutBody;

  /// No description provided for @visitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Visit kinderhorizon.org'**
  String get visitWebsite;

  /// No description provided for @visitWebsiteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opens our website in your browser'**
  String get visitWebsiteSubtitle;

  /// No description provided for @couldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser.'**
  String get couldNotOpenBrowser;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String versionLabel(String version, String build);

  /// No description provided for @mathGateError.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Try again.'**
  String get mathGateError;

  /// No description provided for @mathGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get mathGateTitle;

  /// No description provided for @mathGateBody.
  ///
  /// In en, this message translates to:
  /// **'These settings can disrupt how the app works for your child. Answer below to continue.'**
  String get mathGateBody;

  /// No description provided for @mathGateEquation.
  ///
  /// In en, this message translates to:
  /// **'{a} + {b} = ?'**
  String mathGateEquation(String a, String b);

  /// No description provided for @mathGateAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get mathGateAnswerLabel;

  /// No description provided for @crashLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash logs'**
  String get crashLogsTitle;

  /// No description provided for @noCrashLogsOnDevice.
  ///
  /// In en, this message translates to:
  /// **'No crash logs on this device. Nothing to share.'**
  String get noCrashLogsOnDevice;

  /// No description provided for @onboardingGridTitle.
  ///
  /// In en, this message translates to:
  /// **'This is the board your child will see.'**
  String get onboardingGridTitle;

  /// No description provided for @onboardingGridBody.
  ///
  /// In en, this message translates to:
  /// **'Tap any tile to hear how it sounds. Buttons never move; the layout your child learns today is the layout they will always have.'**
  String get onboardingGridBody;

  /// No description provided for @onboardingPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Where will your child use Lighthouse?'**
  String get onboardingPlaceTitle;

  /// No description provided for @onboardingPlaceBody.
  ///
  /// In en, this message translates to:
  /// **'We use this to label the place Lighthouse learns first. It does not change how the app behaves; you can skip it.'**
  String get onboardingPlaceBody;

  /// No description provided for @onboardingWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn words for each place'**
  String get onboardingWifiTitle;

  /// No description provided for @onboardingWifiBody.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse can use your Wi-Fi network name, scrambled on this device, to learn which words your child needs in different places like home and school. The name never leaves the tablet, and this is optional.'**
  String get onboardingWifiBody;

  /// No description provided for @onboardingWifiAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingWifiAllow;

  /// No description provided for @onboardingWifiGranted.
  ///
  /// In en, this message translates to:
  /// **'On. Lighthouse will learn words for each place.'**
  String get onboardingWifiGranted;

  /// No description provided for @onboardingWifiDenied.
  ///
  /// In en, this message translates to:
  /// **'Not now. You can turn this on later in Settings.'**
  String get onboardingWifiDenied;

  /// No description provided for @placeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get placeHome;

  /// No description provided for @placeSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get placeSchool;

  /// No description provided for @placeBoth.
  ///
  /// In en, this message translates to:
  /// **'Home and school'**
  String get placeBoth;

  /// No description provided for @placeOther.
  ///
  /// In en, this message translates to:
  /// **'Somewhere else'**
  String get placeOther;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyTooltip.
  ///
  /// In en, this message translates to:
  /// **'How we know this is true'**
  String get privacyTooltip;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'What you just told us, and everything your child taps next, stays here. Lighthouse has no account and never sends your child\'s words anywhere.'**
  String get privacyBody;

  /// No description provided for @howWeKnowTitle.
  ///
  /// In en, this message translates to:
  /// **'How we know'**
  String get howWeKnowTitle;

  /// No description provided for @howWeKnowBody1.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse does not connect to any cloud. There is no analytics SDK in the app. There is no automatic crash reporting. Data leaves the device only when you choose to send it: if you tap \"Send crash logs\", which opens your own mail app pre-addressed to us so you can review and tap send, or if you share a vocabulary board with another family, where you pick the destination. You stay in control either way; nothing is sent automatically.'**
  String get howWeKnowBody1;

  /// No description provided for @howWeKnowBody2.
  ///
  /// In en, this message translates to:
  /// **'You can verify this on the Settings screen, which lets you preview the exact crash log contents before you send. A crash log holds the device model, the OS version, and a technical error report (the error type, its message, and the code trace). The app is built not to record the words your child taps or your board content, and because you preview each log and choose whether to send it, you stay in control of what leaves the device.'**
  String get howWeKnowBody2;

  /// No description provided for @howWeKnowUpdates.
  ///
  /// In en, this message translates to:
  /// **'If you tap \"Check for updates\", the app sends only its version number to ask whether corrected words, pictures, or sounds are available. It sends nothing about your child or how the app is used.'**
  String get howWeKnowUpdates;

  /// No description provided for @howWeKnowFeedback.
  ///
  /// In en, this message translates to:
  /// **'If you tap \"Send feedback\", the app sends only the message you write, plus the app and system version. The message is not stored, and it carries nothing about your child or your boards.'**
  String get howWeKnowFeedback;

  /// Advanced settings: auto-return navigation control
  ///
  /// In en, this message translates to:
  /// **'Moving around'**
  String get sectionNavigation;

  /// Advanced settings: auto-return navigation control
  ///
  /// In en, this message translates to:
  /// **'Go home after a word'**
  String get autoReturnToHome;

  /// Advanced settings: auto-return navigation control
  ///
  /// In en, this message translates to:
  /// **'After a word inside a folder, return to the home board'**
  String get autoReturnToHomeSubtitle;

  /// Advanced settings: symbol-only mode toggle
  ///
  /// In en, this message translates to:
  /// **'Hide text on tiles'**
  String get hideTileText;

  /// Advanced settings: symbol-only mode toggle
  ///
  /// In en, this message translates to:
  /// **'Show pictures only, without the word under each tile'**
  String get hideTileTextSubtitle;

  /// Accessibility label for the sentence bar above the board
  ///
  /// In en, this message translates to:
  /// **'Sentence'**
  String get sentenceBarLabel;

  /// Placeholder shown in the empty sentence bar
  ///
  /// In en, this message translates to:
  /// **'Tap words to build a sentence'**
  String get sentenceBarHint;

  /// Scroll cue shown under the board on small screens where the board scrolls
  ///
  /// In en, this message translates to:
  /// **'more words'**
  String get boardScrollHint;

  /// Tooltip for the button that speaks the whole sentence
  ///
  /// In en, this message translates to:
  /// **'Speak sentence'**
  String get sentenceSpeak;

  /// Tooltip for the sentence-bar backspace button
  ///
  /// In en, this message translates to:
  /// **'Remove last word'**
  String get sentenceBackspace;

  /// Tooltip for the sentence-bar clear button
  ///
  /// In en, this message translates to:
  /// **'Clear sentence'**
  String get sentenceClear;

  /// Title of the parent custom-button editor
  ///
  /// In en, this message translates to:
  /// **'Your own buttons'**
  String get customButtonsTitle;

  /// Settings subtitle for the custom-button editor entry
  ///
  /// In en, this message translates to:
  /// **'Add pictures and words your child needs'**
  String get customButtonsSubtitle;

  /// No description provided for @imageRejected.
  ///
  /// In en, this message translates to:
  /// **'That image is too large or not a supported type. Please choose a smaller photo.'**
  String get imageRejected;

  /// Button that opens the add-custom-button dialog
  ///
  /// In en, this message translates to:
  /// **'Add a button'**
  String get customButtonsAdd;

  /// Label for the board picker in the add-custom-button dialog
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get customButtonsBoardLabel;

  /// Label for the word field in the add-custom-button dialog
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get customButtonsWordLabel;

  /// Button to pick an image for a custom button
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get customButtonsChoosePhoto;

  /// Shown when the selected board has no empty slot
  ///
  /// In en, this message translates to:
  /// **'This board is full. Choose another board.'**
  String get customButtonsNoFreeSlots;

  /// Tooltip for deleting a custom button
  ///
  /// In en, this message translates to:
  /// **'Delete button'**
  String get customButtonsDelete;

  /// Save action in the add-custom-button dialog
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get customButtonsSave;

  /// Title of the home favourites editor
  ///
  /// In en, this message translates to:
  /// **'Home favourites'**
  String get homeFavouritesTitle;

  /// Settings subtitle for the home favourites entry
  ///
  /// In en, this message translates to:
  /// **'Pin the words your child uses most to the home page'**
  String get homeFavouritesSubtitle;

  /// Intro text in the home favourites editor
  ///
  /// In en, this message translates to:
  /// **'Pinned words appear in a row on the home page, always in the same place.'**
  String get homeFavouritesIntro;

  /// Header for auto-detected suggestion chips
  ///
  /// In en, this message translates to:
  /// **'Used a lot'**
  String get homeFavouritesSuggested;

  /// Header for the full per-board word list
  ///
  /// In en, this message translates to:
  /// **'Add from a group'**
  String get homeFavouritesAllWords;

  /// Tooltip to pin a word
  ///
  /// In en, this message translates to:
  /// **'Pin to home'**
  String get homeFavouritesPin;

  /// Tooltip to unpin a word
  ///
  /// In en, this message translates to:
  /// **'Remove from home'**
  String get homeFavouritesUnpin;

  /// Shown when the favourites cap is reached
  ///
  /// In en, this message translates to:
  /// **'Home is full ({count} favourites). Remove one to add another.'**
  String homeFavouritesFull(int count);

  /// AppBar tooltip for entering the parent board-arrange mode
  ///
  /// In en, this message translates to:
  /// **'Arrange board'**
  String get editBoardTooltip;

  /// Title of the board-arrange (edit) screen
  ///
  /// In en, this message translates to:
  /// **'Arrange board'**
  String get editBoardTitle;

  /// One-line explainer at the top of the arrange screen
  ///
  /// In en, this message translates to:
  /// **'Tap a button to move it, pin it, or replace it. Drag to rearrange. Your child sees the new layout when you leave.'**
  String get editBoardHint;

  /// Action: start moving the selected button to another slot
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get editActionMove;

  /// Banner shown while waiting for the parent to tap a destination
  ///
  /// In en, this message translates to:
  /// **'Tap where to place it'**
  String get editMoveHint;

  /// Action: pin the selected button to the home favourites bar
  ///
  /// In en, this message translates to:
  /// **'Pin to favourites'**
  String get editActionPin;

  /// Action: unpin an already-pinned button
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get editActionUnpin;

  /// Action shown when tapping an empty slot in arrange mode
  ///
  /// In en, this message translates to:
  /// **'Add a button here'**
  String get editActionAddHere;

  /// Menu action: reset the current board to its default layout
  ///
  /// In en, this message translates to:
  /// **'Reset this board'**
  String get editResetBoard;

  /// Menu action: clear every board's layout overrides
  ///
  /// In en, this message translates to:
  /// **'Reset everything'**
  String get editResetAll;

  /// Confirm dialog body for per-board layout reset
  ///
  /// In en, this message translates to:
  /// **'Put this board back the way it came? Every change you made to it (tiles you moved, hid, re-pictured, re-recorded, or added) will be undone. Other boards are not affected.'**
  String get editResetBoardConfirm;

  /// Confirm dialog body for the global layout reset
  ///
  /// In en, this message translates to:
  /// **'Put every board back the way it came? All your changes on every board (moved, hidden, re-pictured, re-recorded, and added tiles) will be undone.'**
  String get editResetAllConfirm;

  /// Confirm button label for a layout reset
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get editResetConfirmButton;

  /// Leaves the arrange screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editDone;

  /// No description provided for @editArrangeHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a tile to move it. Tap a tile for more, or tap Select to change several at once.'**
  String get editArrangeHint;

  /// No description provided for @editSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap tiles to choose them, then pick an action below. Changes apply to all chosen tiles at once.'**
  String get editSelectHint;

  /// No description provided for @editSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get editSelect;

  /// No description provided for @editSelectTiles.
  ///
  /// In en, this message translates to:
  /// **'Select tiles'**
  String get editSelectTiles;

  /// Live count of selected tiles in the editor
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String editSelectedCount(int count);

  /// No description provided for @editSelectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get editSelectAll;

  /// No description provided for @editSelectNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get editSelectNone;

  /// No description provided for @editTileSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what to change'**
  String get editTileSheetSubtitle;

  /// No description provided for @editActionRecordVoice.
  ///
  /// In en, this message translates to:
  /// **'Record voice'**
  String get editActionRecordVoice;

  /// No description provided for @editActionRerecordVoice.
  ///
  /// In en, this message translates to:
  /// **'Re-record voice'**
  String get editActionRerecordVoice;

  /// No description provided for @editActionRecordVoiceSub.
  ///
  /// In en, this message translates to:
  /// **'Use your own voice'**
  String get editActionRecordVoiceSub;

  /// No description provided for @editActionVoiceSetSub.
  ///
  /// In en, this message translates to:
  /// **'Your voice is set'**
  String get editActionVoiceSetSub;

  /// No description provided for @editActionReplacePicture.
  ///
  /// In en, this message translates to:
  /// **'Replace picture'**
  String get editActionReplacePicture;

  /// No description provided for @editActionReplacePictureSub.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get editActionReplacePictureSub;

  /// No description provided for @editActionPinSub.
  ///
  /// In en, this message translates to:
  /// **'Show it in home favourites'**
  String get editActionPinSub;

  /// No description provided for @editActionHide.
  ///
  /// In en, this message translates to:
  /// **'Hide from the board'**
  String get editActionHide;

  /// No description provided for @editActionHideSub.
  ///
  /// In en, this message translates to:
  /// **'Your child will not see it'**
  String get editActionHideSub;

  /// No description provided for @editActionShow.
  ///
  /// In en, this message translates to:
  /// **'Show on the board'**
  String get editActionShow;

  /// No description provided for @editActionShowSub.
  ///
  /// In en, this message translates to:
  /// **'Your child can see it again'**
  String get editActionShowSub;

  /// No description provided for @editBatchHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get editBatchHide;

  /// No description provided for @editBatchShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get editBatchShow;

  /// Toast after a batch pin
  ///
  /// In en, this message translates to:
  /// **'{count} pinned to favourites'**
  String editToastPinned(int count);

  /// Toast after a batch unpin
  ///
  /// In en, this message translates to:
  /// **'{count} removed from favourites'**
  String editToastUnpinned(int count);

  /// Toast after a batch hide
  ///
  /// In en, this message translates to:
  /// **'{count} hidden from the board'**
  String editToastHidden(int count);

  /// Toast after a batch show
  ///
  /// In en, this message translates to:
  /// **'{count} shown on the board'**
  String editToastShown(int count);

  /// No description provided for @editToastPinnedOne.
  ///
  /// In en, this message translates to:
  /// **'Pinned to favourites'**
  String get editToastPinnedOne;

  /// No description provided for @editToastUnpinnedOne.
  ///
  /// In en, this message translates to:
  /// **'Removed from favourites'**
  String get editToastUnpinnedOne;

  /// No description provided for @editToastHiddenOne.
  ///
  /// In en, this message translates to:
  /// **'Hidden from the board'**
  String get editToastHiddenOne;

  /// No description provided for @editToastShownOne.
  ///
  /// In en, this message translates to:
  /// **'Shown on the board'**
  String get editToastShownOne;

  /// No description provided for @editToastPictureReplaced.
  ///
  /// In en, this message translates to:
  /// **'Picture replaced'**
  String get editToastPictureReplaced;

  /// No description provided for @editToastVoiceSaved.
  ///
  /// In en, this message translates to:
  /// **'Voice saved'**
  String get editToastVoiceSaved;

  /// No description provided for @editToastVoiceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recording deleted, using the built-in voice'**
  String get editToastVoiceDeleted;

  /// Title of the custom-voice recording sheet
  ///
  /// In en, this message translates to:
  /// **'Voice for \"{word}\"'**
  String editVoiceTitle(String word);

  /// No description provided for @editVoiceOverrideSub.
  ///
  /// In en, this message translates to:
  /// **'Your recording overrides the default'**
  String get editVoiceOverrideSub;

  /// Idle prompt in the voice recording sheet
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone and say \"{word}\". Your recording will play instead of the built-in voice for this tile.'**
  String editVoicePrompt(String word);

  /// No description provided for @editVoiceTapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get editVoiceTapToRecord;

  /// Shown while recording
  ///
  /// In en, this message translates to:
  /// **'Listening, say \"{word}\"'**
  String editVoiceListening(String word);

  /// No description provided for @editVoiceTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get editVoiceTapToStop;

  /// Review state after recording
  ///
  /// In en, this message translates to:
  /// **'Here is your recording for \"{word}\".'**
  String editVoiceReview(String word);

  /// No description provided for @editVoicePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get editVoicePlay;

  /// No description provided for @editVoiceRerecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get editVoiceRerecord;

  /// No description provided for @editVoiceUseRecording.
  ///
  /// In en, this message translates to:
  /// **'Use this recording'**
  String get editVoiceUseRecording;

  /// Saved state in the voice recording sheet
  ///
  /// In en, this message translates to:
  /// **'Your voice is set for \"{word}\". You can play, re-record, or delete it at any time. Deleting it brings back the built-in voice.'**
  String editVoiceSavedMsg(String word);

  /// No description provided for @editVoiceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editVoiceDelete;

  /// No description provided for @editVoiceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editVoiceDone;

  /// No description provided for @editVoiceMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Turn it on in Settings to record a voice.'**
  String get editVoiceMicDenied;

  /// Shown when trying to pin past the favourites cap
  ///
  /// In en, this message translates to:
  /// **'Favourites are full ({count} max)'**
  String editFavouritesFull(int count);

  /// No description provided for @editShareBoard.
  ///
  /// In en, this message translates to:
  /// **'Share this board'**
  String get editShareBoard;

  /// No description provided for @shareVocabTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this vocabulary?'**
  String get shareVocabTitle;

  /// No description provided for @shareVocabBody.
  ///
  /// In en, this message translates to:
  /// **'You will share the words you built on this board. On the other tablet it arrives as a new, separate board that starts learning fresh; it is not merged into their board. Nothing is shared automatically.'**
  String get shareVocabBody;

  /// Notice before sharing: photo-backed buttons degrade to text
  ///
  /// In en, this message translates to:
  /// **'{count} buttons use photos from this tablet. They will be shared as words only; the photos stay on your device.'**
  String shareVocabPhotos(int count);

  /// No description provided for @shareVocabConfirm.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareVocabConfirm;

  /// No description provided for @shareVocabFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare this board to share.'**
  String get shareVocabFailed;

  /// No description provided for @otaTitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get otaTitle;

  /// No description provided for @otaSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get the latest word, picture, and sound corrections'**
  String get otaSettingsSubtitle;

  /// No description provided for @otaBody.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse can check Kinder Horizon for corrections to words, translations, pictures, and sounds. It only checks when you tap below, and sends nothing about you or your child.'**
  String get otaBody;

  /// No description provided for @otaCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get otaCheckNow;

  /// No description provided for @otaChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get otaChecking;

  /// No description provided for @otaUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date.'**
  String get otaUpToDate;

  /// No description provided for @otaAvailable.
  ///
  /// In en, this message translates to:
  /// **'Corrections are available.'**
  String get otaAvailable;

  /// No description provided for @otaApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get otaApply;

  /// No description provided for @otaApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get otaApplying;

  /// No description provided for @otaApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied.'**
  String get otaApplied;

  /// No description provided for @otaShowNow.
  ///
  /// In en, this message translates to:
  /// **'Show the update now'**
  String get otaShowNow;

  /// No description provided for @otaApplyFallback.
  ///
  /// In en, this message translates to:
  /// **'Or it will be ready the next time you open Lighthouse.'**
  String get otaApplyFallback;

  /// No description provided for @otaIncompatible.
  ///
  /// In en, this message translates to:
  /// **'These corrections need a newer version of Lighthouse. Please update the app.'**
  String get otaIncompatible;

  /// No description provided for @otaError.
  ///
  /// In en, this message translates to:
  /// **'Could not check right now. Please try again later.'**
  String get otaError;

  /// No description provided for @sectionFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get sectionFeedback;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report a bug or suggest an improvement'**
  String get feedbackSettingsSubtitle;

  /// No description provided for @feedbackBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what is not working or what would help. We read every message.'**
  String get feedbackBody;

  /// No description provided for @feedbackCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'What is this about?'**
  String get feedbackCategoryLabel;

  /// No description provided for @feedbackCategoryBug.
  ///
  /// In en, this message translates to:
  /// **'A bug'**
  String get feedbackCategoryBug;

  /// No description provided for @feedbackCategorySuggestion.
  ///
  /// In en, this message translates to:
  /// **'A suggestion'**
  String get feedbackCategorySuggestion;

  /// No description provided for @feedbackCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get feedbackCategoryOther;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What happened, or what would help?'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Your email (optional)'**
  String get feedbackEmailLabel;

  /// No description provided for @feedbackEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Only if you would like a reply'**
  String get feedbackEmailHint;

  /// No description provided for @feedbackPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'We send only your message and the app version. Nothing about your child, your boards, or how the app is used.'**
  String get feedbackPrivacyNote;

  /// No description provided for @feedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSend;

  /// No description provided for @feedbackSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get feedbackSending;

  /// No description provided for @feedbackErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please write a message first.'**
  String get feedbackErrorEmpty;

  /// No description provided for @feedbackErrorEmail.
  ///
  /// In en, this message translates to:
  /// **'That email does not look right.'**
  String get feedbackErrorEmail;

  /// No description provided for @feedbackErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not send right now. Please try again later.'**
  String get feedbackErrorNetwork;

  /// No description provided for @feedbackErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'That message is too long. Please shorten it.'**
  String get feedbackErrorTooLong;

  /// No description provided for @sectionYourChildsBoard.
  ///
  /// In en, this message translates to:
  /// **'Your child\'s board'**
  String get sectionYourChildsBoard;

  /// No description provided for @sectionHowAppBehaves.
  ///
  /// In en, this message translates to:
  /// **'How the app behaves'**
  String get sectionHowAppBehaves;

  /// No description provided for @sectionUpdatesSupport.
  ///
  /// In en, this message translates to:
  /// **'Updates & support'**
  String get sectionUpdatesSupport;

  /// No description provided for @crashLogsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View what could be shared, then send it'**
  String get crashLogsRowSubtitle;

  /// No description provided for @crashEmptyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Nothing has gone wrong'**
  String get crashEmptyHeadline;

  /// No description provided for @crashEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'There are no crash logs on this device, so there is nothing to send. If the app ever closes unexpectedly, a log will appear here for you to review before sending.'**
  String get crashEmptyBody;

  /// No description provided for @glowStyleRing.
  ///
  /// In en, this message translates to:
  /// **'Inset ring'**
  String get glowStyleRing;

  /// No description provided for @glowStyleLift.
  ///
  /// In en, this message translates to:
  /// **'Lift and underline'**
  String get glowStyleLift;

  /// No description provided for @glowStyleDot.
  ///
  /// In en, this message translates to:
  /// **'Quiet corner dot'**
  String get glowStyleDot;

  /// No description provided for @glowStyleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get glowStyleOff;

  /// No description provided for @showWordOnTile.
  ///
  /// In en, this message translates to:
  /// **'Show the word on each tile'**
  String get showWordOnTile;

  /// No description provided for @showWordOnTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off to show pictures only'**
  String get showWordOnTileSubtitle;

  /// No description provided for @showPictogramOnTile.
  ///
  /// In en, this message translates to:
  /// **'Show the picture on each tile'**
  String get showPictogramOnTile;

  /// No description provided for @showPictogramOnTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off to show words only'**
  String get showPictogramOnTileSubtitle;

  /// No description provided for @otaLastCheckedNever.
  ///
  /// In en, this message translates to:
  /// **'Last checked: never on this device.'**
  String get otaLastCheckedNever;

  /// No description provided for @otaCheckedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Checked just now'**
  String get otaCheckedJustNow;

  /// No description provided for @feedbackThanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your message is on its way.'**
  String get feedbackThanksTitle;

  /// No description provided for @feedbackThanksBody.
  ///
  /// In en, this message translates to:
  /// **'A real person at Kinder Horizon reads every note. If you left an email, we will reply when we can. Lighthouse is built by a small nonprofit team, and your words genuinely shape what we fix next.'**
  String get feedbackThanksBody;

  /// No description provided for @feedbackSendAnother.
  ///
  /// In en, this message translates to:
  /// **'Send another'**
  String get feedbackSendAnother;

  /// No description provided for @feedbackBackToBoard.
  ///
  /// In en, this message translates to:
  /// **'Back to the board'**
  String get feedbackBackToBoard;

  /// No description provided for @aboutLicence.
  ///
  /// In en, this message translates to:
  /// **'Open source · MIT licence'**
  String get aboutLicence;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Picture symbols'**
  String get aboutCredits;

  /// No description provided for @aboutLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicences;

  /// No description provided for @aboutLicencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Licences for the code and fonts Lighthouse uses'**
  String get aboutLicencesSubtitle;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get tourSkip;

  /// No description provided for @tourFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get tourFinish;

  /// Guided tour step progress, e.g. 3 of 11
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String tourProgress(int current, int total);

  /// No description provided for @tourTakeQuick.
  ///
  /// In en, this message translates to:
  /// **'Take the quick tour'**
  String get tourTakeQuick;

  /// No description provided for @tourSkipToBoard.
  ///
  /// In en, this message translates to:
  /// **'Skip, go to the board'**
  String get tourSkipToBoard;

  /// No description provided for @tourSettingsRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Take the tour'**
  String get tourSettingsRowTitle;

  /// No description provided for @tourSettingsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick guided walkthrough of the app'**
  String get tourSettingsRowSubtitle;

  /// No description provided for @tipEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Editing your board'**
  String get tipEditorTitle;

  /// No description provided for @tipEditorBody.
  ///
  /// In en, this message translates to:
  /// **'Press and drag a tile to move it, or tap Select to favourite or hide several at once.'**
  String get tipEditorBody;

  /// No description provided for @tipGateTitle.
  ///
  /// In en, this message translates to:
  /// **'A quick check for grown-ups'**
  String get tipGateTitle;

  /// No description provided for @tipGateBody.
  ///
  /// In en, this message translates to:
  /// **'Answer a simple sum to get in. It is a speed bump to keep little hands out, not a password.'**
  String get tipGateBody;

  /// No description provided for @tipButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your own buttons'**
  String get tipButtonsTitle;

  /// No description provided for @tipButtonsBody.
  ///
  /// In en, this message translates to:
  /// **'Make tiles for the people, foods, and places your child needs, each with a photo and a word.'**
  String get tipButtonsBody;

  /// No description provided for @tipFavouritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Home favourites'**
  String get tipFavouritesTitle;

  /// No description provided for @tipFavouritesBody.
  ///
  /// In en, this message translates to:
  /// **'Pinned words sit in a row at the top of the home board, so the words used most are the easiest to find.'**
  String get tipFavouritesBody;

  /// No description provided for @tipAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get tipAdvancedTitle;

  /// No description provided for @tipAdvancedBody.
  ///
  /// In en, this message translates to:
  /// **'These options change how the board looks and behaves. Your child\'s words and layout are never touched here.'**
  String get tipAdvancedBody;

  /// No description provided for @tipGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tipGotIt;

  /// No description provided for @tourBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'This is your child\'s board'**
  String get tourBoardTitle;

  /// No description provided for @tourBoardBody.
  ///
  /// In en, this message translates to:
  /// **'Your child taps these tiles to talk. The tiles never move, so the layout becomes muscle memory over time.'**
  String get tourBoardBody;

  /// No description provided for @tourSentenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Words build a sentence here'**
  String get tourSentenceTitle;

  /// No description provided for @tourSentenceBody.
  ///
  /// In en, this message translates to:
  /// **'Each tap adds a word to this bar. Tap the speaker to say the whole sentence out loud; use backspace or clear to fix it.'**
  String get tourSentenceBody;

  /// No description provided for @tourGlowTitle.
  ///
  /// In en, this message translates to:
  /// **'The gentle next-word glow'**
  String get tourGlowTitle;

  /// No description provided for @tourGlowBody.
  ///
  /// In en, this message translates to:
  /// **'A soft amber glow points to the words your child is most likely to want next. It only changes the glow, never the tiles, so they stay put.'**
  String get tourGlowBody;

  /// No description provided for @tourFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Folders open sub-boards'**
  String get tourFoldersTitle;

  /// No description provided for @tourFoldersBody.
  ///
  /// In en, this message translates to:
  /// **'Coloured folders like Food or People open a deeper board with the same calm layout, then bring you back.'**
  String get tourFoldersBody;

  /// No description provided for @tourSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything for grown-ups'**
  String get tourSettingsTitle;

  /// No description provided for @tourSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'The gear opens Settings: the voice, languages, favourites, and how the app behaves. Each board-changing action asks a quick grown-up question first.'**
  String get tourSettingsBody;

  /// No description provided for @homeFavouritesPinnedNow.
  ///
  /// In en, this message translates to:
  /// **'Pinned now'**
  String get homeFavouritesPinnedNow;

  /// No description provided for @homeFavouritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No words pinned yet. Add some from a group below.'**
  String get homeFavouritesEmpty;

  /// No description provided for @customButtonsEmptyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Make a button for your child'**
  String get customButtonsEmptyHeadline;

  /// No description provided for @customButtonsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a photo and a word for the people, foods, and places your child needs most. New buttons join the board in the right colour group.'**
  String get customButtonsEmptyBody;

  /// No description provided for @customButtonsAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first button'**
  String get customButtonsAddFirst;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start using Lighthouse'**
  String get onboardingStart;

  /// No description provided for @placeHomeSub.
  ///
  /// In en, this message translates to:
  /// **'Where most days happen'**
  String get placeHomeSub;

  /// No description provided for @placeSchoolSub.
  ///
  /// In en, this message translates to:
  /// **'A classroom or therapy room'**
  String get placeSchoolSub;

  /// No description provided for @placeBothSub.
  ///
  /// In en, this message translates to:
  /// **'It moves with your child'**
  String get placeBothSub;

  /// No description provided for @placeOtherSub.
  ///
  /// In en, this message translates to:
  /// **'Tell us later if you like'**
  String get placeOtherSub;

  /// No description provided for @onboardingPrivacyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this device'**
  String get onboardingPrivacyHeadline;

  /// No description provided for @onboardingPrivacyPoint1.
  ///
  /// In en, this message translates to:
  /// **'No account, no ads, no tracking'**
  String get onboardingPrivacyPoint1;

  /// No description provided for @onboardingPrivacyPoint2.
  ///
  /// In en, this message translates to:
  /// **'Works fully offline'**
  String get onboardingPrivacyPoint2;

  /// No description provided for @onboardingPrivacyPoint3.
  ///
  /// In en, this message translates to:
  /// **'Open source, so anyone can check'**
  String get onboardingPrivacyPoint3;

  /// No description provided for @crashLogsSentCleared.
  ///
  /// In en, this message translates to:
  /// **'Crash logs sent. They have been removed from this device.'**
  String get crashLogsSentCleared;

  /// No description provided for @exportBoardPack.
  ///
  /// In en, this message translates to:
  /// **'Export this board'**
  String get exportBoardPack;

  /// No description provided for @exportBoardPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your board as a file another device can import'**
  String get exportBoardPackSubtitle;

  /// No description provided for @tourColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'The colours group words'**
  String get tourColorsTitle;

  /// No description provided for @tourColorsBody.
  ///
  /// In en, this message translates to:
  /// **'Each colour is a kind of word: yellow for people and pronouns, green for action words, orange for things, food, and places, blue for feelings and yes or no, pink for social words and urgent needs, purple for questions and time.'**
  String get tourColorsBody;

  /// No description provided for @tourArrangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrange the board'**
  String get tourArrangeTitle;

  /// No description provided for @tourArrangeBody.
  ///
  /// In en, this message translates to:
  /// **'The board button lets you move, hide, add, or rename tiles, and record your own voice for any tile. It asks a quick grown-up question first, so your child cannot change their own board.'**
  String get tourArrangeBody;

  /// No description provided for @recordVoiceOptional.
  ///
  /// In en, this message translates to:
  /// **'Record your own voice (optional)'**
  String get recordVoiceOptional;

  /// No description provided for @recordVoiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recordVoiceStop;

  /// No description provided for @recordVoiceRecorded.
  ///
  /// In en, this message translates to:
  /// **'Voice recorded'**
  String get recordVoiceRecorded;

  /// No description provided for @recordVoiceClear.
  ///
  /// In en, this message translates to:
  /// **'Remove recording'**
  String get recordVoiceClear;
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
      <String>['ar', 'en', 'es'].contains(locale.languageCode);

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
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
