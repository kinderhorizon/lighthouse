// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get continueLabel => 'Continue';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String packNotLoaded(String folder) {
    return 'Pack not loaded: $folder';
  }

  @override
  String get couldNotLoadBoard => 'Could not load the default board.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get sectionCrashLogs => 'Crash logs';

  @override
  String get viewCrashLogs => 'View crash logs';

  @override
  String get viewCrashLogsSubtitle =>
      'See exactly what would be sent before you send it';

  @override
  String get shareCrashLogs => 'Send crash logs';

  @override
  String get shareCrashLogsSubtitle =>
      'Opens your mail app to send the logs to KHF; you tap send';

  @override
  String get sectionBoards => 'Boards';

  @override
  String get importBoardPack => 'Import a board pack';

  @override
  String get importBoardPackSubtitle =>
      'Add a board JSON file from this device';

  @override
  String get sectionOnboarding => 'Onboarding';

  @override
  String get rerunOnboarding => 'Re-run the welcome';

  @override
  String get rerunOnboardingSubtitle => 'Show the first-launch flow again';

  @override
  String get sectionAdvanced => 'Advanced';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get advancedSettingsSubtitle => 'Voice, glow, tap size, learning';

  @override
  String get sectionUpdates => 'Updates';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutLighthouse => 'About Lighthouse';

  @override
  String get aboutLighthouseSubtitle =>
      'A free project of the Kinder Horizon Foundation';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyPolicySubtitle =>
      'How Lighthouse handles your data (opens in your browser)';

  @override
  String get couldNotOpenLink => 'Could not open the link.';

  @override
  String get noCrashLogsToShare => 'No crash logs to send.';

  @override
  String get shareSubject => 'Lighthouse AAC crash logs';

  @override
  String get crashEmailBody =>
      'The attached crash logs are from Lighthouse AAC. Thank you for helping us fix the problem.';

  @override
  String get shareBody =>
      'Crash logs from Lighthouse AAC are attached. Please send them to bugs@kinderhorizon.org.';

  @override
  String get rerunOnboardingConfirmTitle => 'Re-run onboarding?';

  @override
  String get rerunOnboardingConfirmBody =>
      'You will see the first-launch flow again. The board and your child\'s learned patterns are not affected.';

  @override
  String get rerun => 'Re-run';

  @override
  String get couldNotReadFile => 'Could not read the picked file.';

  @override
  String importedBoard(String board) {
    return 'Imported \"$board\".';
  }

  @override
  String couldNotImport(String error) {
    return 'Could not import: $error';
  }

  @override
  String get advancedTitle => 'Advanced';

  @override
  String get sectionVoice => 'Voice';

  @override
  String get sectionVisual => 'How the board looks';

  @override
  String get sectionLearning => 'Learning';

  @override
  String get resetLearnedState => 'Reset what Lighthouse has learned';

  @override
  String get resetLearnedStateSubtitle =>
      'Clears your child\'s word patterns. The board itself is not changed.';

  @override
  String get resetLearnedStateConfirmTitle => 'Reset learned state?';

  @override
  String get resetLearnedStateConfirmBody =>
      'This permanently erases the glow predictions your child has built up. It cannot be undone. The board, language, and other settings are not affected.\n\nUse this when handing the device to a different child, or if the glows no longer match how your child communicates.';

  @override
  String get erase => 'Erase';

  @override
  String get learnedStateCleared => 'Learned state cleared.';

  @override
  String get couldNotClearLearnedState =>
      'Could not clear learned state. Try again.';

  @override
  String get voiceOutput => 'Voice output';

  @override
  String get ttsModeOn => 'On (speak every tap)';

  @override
  String get ttsModeOnRequest => 'On-request (long-press to speak)';

  @override
  String get ttsModeOff => 'Off (no synthesized speech)';

  @override
  String get ttsModeAls => 'Show word large, no speech (ALS)';

  @override
  String get glowStyle => 'Glow style';

  @override
  String get glowStyleHalo => 'Soft halo';

  @override
  String get hitboxExpansion => 'Tap size';

  @override
  String get hitboxNone => 'Standard';

  @override
  String get hitboxSubtle => 'Comfortable';

  @override
  String get hitboxMaximum => 'Large';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline => 'A free project of the Kinder Horizon Foundation.';

  @override
  String get aboutBody =>
      'Lighthouse helps non-speaking children communicate. It is free, has no ads, and keeps everything your child does on this device.';

  @override
  String get visitWebsite => 'Visit kinderhorizon.org';

  @override
  String get visitWebsiteSubtitle => 'Opens our website in your browser';

  @override
  String get couldNotOpenBrowser => 'Could not open the browser.';

  @override
  String get version => 'Version';

  @override
  String versionLabel(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get mathGateError => 'Not quite. Try again.';

  @override
  String get mathGateTitle => 'Quick check';

  @override
  String get mathGateBody =>
      'These settings can disrupt how the app works for your child. Answer below to continue.';

  @override
  String mathGateEquation(String a, String b) {
    return '$a + $b = ?';
  }

  @override
  String get mathGateAnswerLabel => 'Answer';

  @override
  String get crashLogsTitle => 'Crash logs';

  @override
  String get noCrashLogsOnDevice =>
      'No crash logs on this device. Nothing to share.';

  @override
  String get onboardingGridTitle => 'This is the board your child will see.';

  @override
  String get onboardingGridBody =>
      'Tap any tile to hear how it sounds. Buttons never move; the layout your child learns today is the layout they will always have.';

  @override
  String get onboardingPlaceTitle => 'Where will your child use Lighthouse?';

  @override
  String get onboardingPlaceBody =>
      'We use this to label the place Lighthouse learns first. It does not change how the app behaves; you can skip it.';

  @override
  String get onboardingWifiTitle => 'Learn words for each place';

  @override
  String get onboardingWifiBody =>
      'Lighthouse can use your Wi-Fi network name, scrambled on this device, to learn which words your child needs in different places like home and school. The name never leaves the tablet, and this is optional.';

  @override
  String get onboardingWifiAllow => 'Allow';

  @override
  String get onboardingWifiGranted =>
      'On. Lighthouse will learn words for each place.';

  @override
  String get onboardingWifiDenied =>
      'Not now. You can turn this on later in Settings.';

  @override
  String get placeHome => 'Home';

  @override
  String get placeSchool => 'School';

  @override
  String get placeBoth => 'Home and school';

  @override
  String get placeOther => 'Somewhere else';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyTooltip => 'How we know this is true';

  @override
  String get privacyBody =>
      'What you just told us, and everything your child taps next, stays here. Lighthouse has no account and never sends your child\'s words anywhere.';

  @override
  String get howWeKnowTitle => 'How we know';

  @override
  String get howWeKnowBody1 =>
      'Lighthouse does not connect to any cloud. There is no analytics SDK in the app. There is no automatic crash reporting. Data leaves the device only when you choose to send it: if you tap \"Send crash logs\", which opens your own mail app pre-addressed to us so you can review and tap send, or if you share a vocabulary board with another family, where you pick the destination. You stay in control either way; nothing is sent automatically.';

  @override
  String get howWeKnowBody2 =>
      'You can verify this on the Settings screen, which lets you preview the exact crash log contents before you send. A crash log holds the device model, the OS version, and a technical error report (the error type, its message, and the code trace). The app is built not to record the words your child taps or your board content, and because you preview each log and choose whether to send it, you stay in control of what leaves the device.';

  @override
  String get howWeKnowUpdates =>
      'If you tap \"Check for updates\", the app sends only its version number to ask whether corrected words, pictures, or sounds are available. It sends nothing about your child or how the app is used.';

  @override
  String get howWeKnowFeedback =>
      'If you tap \"Send feedback\", the app sends only the message you write, plus the app and system version. The message is not stored, and it carries nothing about your child or your boards.';

  @override
  String get sectionNavigation => 'Moving around';

  @override
  String get autoReturnToHome => 'Go home after a word';

  @override
  String get autoReturnToHomeSubtitle =>
      'After a word inside a folder, return to the home board';

  @override
  String get hideTileText => 'Hide text on tiles';

  @override
  String get hideTileTextSubtitle =>
      'Show pictures only, without the word under each tile';

  @override
  String get sentenceBarLabel => 'Sentence';

  @override
  String get sentenceBarHint => 'Tap words to build a sentence';

  @override
  String get boardScrollHint => 'more words';

  @override
  String get sentenceSpeak => 'Speak sentence';

  @override
  String get sentenceBackspace => 'Remove last word';

  @override
  String get sentenceClear => 'Clear sentence';

  @override
  String get customButtonsTitle => 'Your own buttons';

  @override
  String get customButtonsSubtitle => 'Add pictures and words your child needs';

  @override
  String get imageRejected =>
      'That image is too large or not a supported type. Please choose a smaller photo.';

  @override
  String get customButtonsAdd => 'Add a button';

  @override
  String get customButtonsBoardLabel => 'Board';

  @override
  String get customButtonsWordLabel => 'Word';

  @override
  String get customButtonsChoosePhoto => 'Choose photo';

  @override
  String get customButtonsNoFreeSlots =>
      'This board is full. Choose another board.';

  @override
  String get customButtonsDelete => 'Delete button';

  @override
  String get customButtonsSave => 'Save';

  @override
  String get homeFavouritesTitle => 'Home favourites';

  @override
  String get homeFavouritesSubtitle =>
      'Pin the words your child uses most to the home page';

  @override
  String get homeFavouritesIntro =>
      'Pinned words appear in a row on the home page, always in the same place.';

  @override
  String get homeFavouritesSuggested => 'Used a lot';

  @override
  String get homeFavouritesAllWords => 'Add from a group';

  @override
  String get homeFavouritesPin => 'Pin to home';

  @override
  String get homeFavouritesUnpin => 'Remove from home';

  @override
  String homeFavouritesFull(int count) {
    return 'Home is full ($count favourites). Remove one to add another.';
  }

  @override
  String get editBoardTooltip => 'Arrange board';

  @override
  String get editBoardTitle => 'Arrange board';

  @override
  String get editBoardHint =>
      'Tap a button to move it, pin it, or replace it. Drag to rearrange. Your child sees the new layout when you leave.';

  @override
  String get editActionMove => 'Move';

  @override
  String get editMoveHint => 'Tap where to place it';

  @override
  String get editActionPin => 'Pin to favourites';

  @override
  String get editActionUnpin => 'Remove from favourites';

  @override
  String get editActionAddHere => 'Add a button here';

  @override
  String get editResetBoard => 'Reset this board';

  @override
  String get editResetAll => 'Reset everything';

  @override
  String get editResetBoardConfirm =>
      'Put this board back the way it came? Every change you made to it (tiles you moved, hid, re-pictured, re-recorded, or added) will be undone. Other boards are not affected.';

  @override
  String get editResetAllConfirm =>
      'Put every board back the way it came? All your changes on every board (moved, hidden, re-pictured, re-recorded, and added tiles) will be undone.';

  @override
  String get editResetConfirmButton => 'Reset';

  @override
  String get editDone => 'Done';

  @override
  String get editArrangeHint =>
      'Drag a tile to move it. Tap a tile for more, or tap Select to change several at once.';

  @override
  String get editSelectHint =>
      'Tap tiles to choose them, then pick an action below. Changes apply to all chosen tiles at once.';

  @override
  String get editSelect => 'Select';

  @override
  String get editSelectTiles => 'Select tiles';

  @override
  String editSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get editSelectAll => 'All';

  @override
  String get editSelectNone => 'None';

  @override
  String get editTileSheetSubtitle => 'Choose what to change';

  @override
  String get editActionRecordVoice => 'Record voice';

  @override
  String get editActionRerecordVoice => 'Re-record voice';

  @override
  String get editActionRecordVoiceSub => 'Use your own voice';

  @override
  String get editActionVoiceSetSub => 'Your voice is set';

  @override
  String get editActionReplacePicture => 'Replace picture';

  @override
  String get editActionReplacePictureSub => 'Choose a photo';

  @override
  String get editActionPinSub => 'Show it in home favourites';

  @override
  String get editActionHide => 'Hide from the board';

  @override
  String get editActionHideSub => 'Your child will not see it';

  @override
  String get editActionShow => 'Show on the board';

  @override
  String get editActionShowSub => 'Your child can see it again';

  @override
  String get editBatchHide => 'Hide';

  @override
  String get editBatchShow => 'Show';

  @override
  String editToastPinned(int count) {
    return '$count pinned to favourites';
  }

  @override
  String editToastUnpinned(int count) {
    return '$count removed from favourites';
  }

  @override
  String editToastHidden(int count) {
    return '$count hidden from the board';
  }

  @override
  String editToastShown(int count) {
    return '$count shown on the board';
  }

  @override
  String get editToastPinnedOne => 'Pinned to favourites';

  @override
  String get editToastUnpinnedOne => 'Removed from favourites';

  @override
  String get editToastHiddenOne => 'Hidden from the board';

  @override
  String get editToastShownOne => 'Shown on the board';

  @override
  String get editToastPictureReplaced => 'Picture replaced';

  @override
  String get editToastVoiceSaved => 'Voice saved';

  @override
  String get editToastVoiceDeleted =>
      'Recording deleted, using the built-in voice';

  @override
  String editVoiceTitle(String word) {
    return 'Voice for \"$word\"';
  }

  @override
  String get editVoiceOverrideSub => 'Your recording overrides the default';

  @override
  String editVoicePrompt(String word) {
    return 'Tap the microphone and say \"$word\". Your recording will play instead of the built-in voice for this tile.';
  }

  @override
  String get editVoiceTapToRecord => 'Tap to record';

  @override
  String editVoiceListening(String word) {
    return 'Listening, say \"$word\"';
  }

  @override
  String get editVoiceTapToStop => 'Tap to stop';

  @override
  String editVoiceReview(String word) {
    return 'Here is your recording for \"$word\".';
  }

  @override
  String get editVoicePlay => 'Play';

  @override
  String get editVoiceRerecord => 'Re-record';

  @override
  String get editVoiceUseRecording => 'Use this recording';

  @override
  String editVoiceSavedMsg(String word) {
    return 'Your voice is set for \"$word\". You can play, re-record, or delete it at any time. Deleting it brings back the built-in voice.';
  }

  @override
  String get editVoiceDelete => 'Delete';

  @override
  String get editVoiceDone => 'Done';

  @override
  String get editVoiceMicDenied =>
      'Microphone access is off. Turn it on in Settings to record a voice.';

  @override
  String editFavouritesFull(int count) {
    return 'Favourites are full ($count max)';
  }

  @override
  String get editShareBoard => 'Share this board';

  @override
  String get shareVocabTitle => 'Share this vocabulary?';

  @override
  String get shareVocabBody =>
      'You will share the words you built on this board. On the other tablet it arrives as a new, separate board that starts learning fresh; it is not merged into their board. Nothing is shared automatically.';

  @override
  String shareVocabPhotos(int count) {
    return '$count buttons use photos from this tablet. They will be shared as words only; the photos stay on your device.';
  }

  @override
  String get shareVocabConfirm => 'Share';

  @override
  String get shareVocabFailed => 'Could not prepare this board to share.';

  @override
  String get otaTitle => 'Check for updates';

  @override
  String get otaSettingsSubtitle =>
      'Get the latest word, picture, and sound corrections';

  @override
  String get otaBody =>
      'Lighthouse can check Kinder Horizon for corrections to words, translations, pictures, and sounds. It only checks when you tap below, and sends nothing about you or your child.';

  @override
  String get otaCheckNow => 'Check now';

  @override
  String get otaChecking => 'Checking...';

  @override
  String get otaUpToDate => 'You are up to date.';

  @override
  String get otaAvailable => 'Corrections are available.';

  @override
  String get otaApply => 'Apply';

  @override
  String get otaApplying => 'Applying...';

  @override
  String get otaApplied => 'Applied.';

  @override
  String get otaShowNow => 'Show the update now';

  @override
  String get otaApplyFallback =>
      'Or it will be ready the next time you open Lighthouse.';

  @override
  String get otaIncompatible =>
      'These corrections need a newer version of Lighthouse. Please update the app.';

  @override
  String get otaError => 'Could not check right now. Please try again later.';

  @override
  String get sectionFeedback => 'Feedback';

  @override
  String get feedbackTitle => 'Send feedback';

  @override
  String get feedbackSettingsSubtitle =>
      'Report a bug or suggest an improvement';

  @override
  String get feedbackBody =>
      'Tell us what is not working or what would help. We read every message.';

  @override
  String get feedbackCategoryLabel => 'What is this about?';

  @override
  String get feedbackCategoryBug => 'A bug';

  @override
  String get feedbackCategorySuggestion => 'A suggestion';

  @override
  String get feedbackCategoryOther => 'Something else';

  @override
  String get feedbackMessageLabel => 'Your message';

  @override
  String get feedbackMessageHint => 'What happened, or what would help?';

  @override
  String get feedbackEmailLabel => 'Your email (optional)';

  @override
  String get feedbackEmailHint => 'Only if you would like a reply';

  @override
  String get feedbackPrivacyNote =>
      'We send only your message and the app version. Nothing about your child, your boards, or how the app is used.';

  @override
  String get feedbackSend => 'Send';

  @override
  String get feedbackSending => 'Sending...';

  @override
  String get feedbackErrorEmpty => 'Please write a message first.';

  @override
  String get feedbackErrorEmail => 'That email does not look right.';

  @override
  String get feedbackErrorNetwork =>
      'Could not send right now. Please try again later.';

  @override
  String get feedbackErrorTooLong =>
      'That message is too long. Please shorten it.';

  @override
  String get sectionYourChildsBoard => 'Your child\'s board';

  @override
  String get sectionHowAppBehaves => 'How the app behaves';

  @override
  String get sectionUpdatesSupport => 'Updates & support';

  @override
  String get crashLogsRowSubtitle => 'View what could be shared, then send it';

  @override
  String get crashEmptyHeadline => 'Nothing has gone wrong';

  @override
  String get crashEmptyBody =>
      'There are no crash logs on this device, so there is nothing to send. If the app ever closes unexpectedly, a log will appear here for you to review before sending.';

  @override
  String get glowStyleRing => 'Inset ring';

  @override
  String get glowStyleLift => 'Lift and underline';

  @override
  String get glowStyleDot => 'Quiet corner dot';

  @override
  String get glowStyleOff => 'Off';

  @override
  String get showWordOnTile => 'Show the word on each tile';

  @override
  String get showWordOnTileSubtitle => 'Turn off to show pictures only';

  @override
  String get showPictogramOnTile => 'Show the picture on each tile';

  @override
  String get showPictogramOnTileSubtitle => 'Turn off to show words only';

  @override
  String get otaLastCheckedNever => 'Last checked: never on this device.';

  @override
  String get otaCheckedJustNow => 'Checked just now';

  @override
  String get feedbackThanksTitle => 'Thank you. Your message is on its way.';

  @override
  String get feedbackThanksBody =>
      'A real person at Kinder Horizon reads every note. If you left an email, we will reply when we can. Lighthouse is built by a small nonprofit team, and your words genuinely shape what we fix next.';

  @override
  String get feedbackSendAnother => 'Send another';

  @override
  String get feedbackBackToBoard => 'Back to the board';

  @override
  String get aboutLicence => 'Open source · MIT licence';

  @override
  String get aboutCredits => 'Picture symbols';

  @override
  String get aboutLicences => 'Open-source licences';

  @override
  String get aboutLicencesSubtitle =>
      'Licences for the code and fonts Lighthouse uses';

  @override
  String get tourSkip => 'Skip tour';

  @override
  String get tourFinish => 'Finish';

  @override
  String tourProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get tourTakeQuick => 'Take the quick tour';

  @override
  String get tourSkipToBoard => 'Skip, go to the board';

  @override
  String get tourSettingsRowTitle => 'Take the tour';

  @override
  String get tourSettingsRowSubtitle => 'A quick guided walkthrough of the app';

  @override
  String get tipEditorTitle => 'Editing your board';

  @override
  String get tipEditorBody =>
      'Press and drag a tile to move it, or tap Select to favourite or hide several at once.';

  @override
  String get tipGateTitle => 'A quick check for grown-ups';

  @override
  String get tipGateBody =>
      'Answer a simple sum to get in. It is a speed bump to keep little hands out, not a password.';

  @override
  String get tipButtonsTitle => 'Add your own buttons';

  @override
  String get tipButtonsBody =>
      'Make tiles for the people, foods, and places your child needs, each with a photo and a word.';

  @override
  String get tipFavouritesTitle => 'Home favourites';

  @override
  String get tipFavouritesBody =>
      'Pinned words sit in a row at the top of the home board, so the words used most are the easiest to find.';

  @override
  String get tipAdvancedTitle => 'Advanced settings';

  @override
  String get tipAdvancedBody =>
      'These options change how the board looks and behaves. Your child\'s words and layout are never touched here.';

  @override
  String get tipGotIt => 'Got it';

  @override
  String get tourBoardTitle => 'This is your child\'s board';

  @override
  String get tourBoardBody =>
      'Your child taps these tiles to talk. The tiles never move, so the layout becomes muscle memory over time.';

  @override
  String get tourSentenceTitle => 'Words build a sentence here';

  @override
  String get tourSentenceBody =>
      'Each tap adds a word to this bar. Tap the speaker to say the whole sentence out loud; use backspace or clear to fix it.';

  @override
  String get tourGlowTitle => 'The gentle next-word glow';

  @override
  String get tourGlowBody =>
      'A soft amber glow points to the words your child is most likely to want next. It only changes the glow, never the tiles, so they stay put.';

  @override
  String get tourFoldersTitle => 'Folders open sub-boards';

  @override
  String get tourFoldersBody =>
      'Coloured folders like Food or People open a deeper board with the same calm layout, then bring you back.';

  @override
  String get tourSettingsTitle => 'Everything for grown-ups';

  @override
  String get tourSettingsBody =>
      'The gear opens Settings: the voice, languages, favourites, and how the app behaves. Each board-changing action asks a quick grown-up question first.';

  @override
  String get homeFavouritesPinnedNow => 'Pinned now';

  @override
  String get homeFavouritesEmpty =>
      'No words pinned yet. Add some from a group below.';

  @override
  String get customButtonsEmptyHeadline => 'Make a button for your child';

  @override
  String get customButtonsEmptyBody =>
      'Add a photo and a word for the people, foods, and places your child needs most. New buttons join the board in the right colour group.';

  @override
  String get customButtonsAddFirst => 'Add your first button';

  @override
  String get onboardingStart => 'Start using Lighthouse';

  @override
  String get placeHomeSub => 'Where most days happen';

  @override
  String get placeSchoolSub => 'A classroom or therapy room';

  @override
  String get placeBothSub => 'It moves with your child';

  @override
  String get placeOtherSub => 'Tell us later if you like';

  @override
  String get onboardingPrivacyHeadline => 'Everything stays on this device';

  @override
  String get onboardingPrivacyPoint1 => 'No account, no ads, no tracking';

  @override
  String get onboardingPrivacyPoint2 => 'Works fully offline';

  @override
  String get onboardingPrivacyPoint3 => 'Open source, so anyone can check';

  @override
  String get crashLogsSentCleared =>
      'Crash logs sent. They have been removed from this device.';

  @override
  String get exportBoardPack => 'Export this board';

  @override
  String get exportBoardPackSubtitle =>
      'Share your board as a file another device can import';

  @override
  String get tourColorsTitle => 'The colours group words';

  @override
  String get tourColorsBody =>
      'Each colour is a kind of word: yellow for people and pronouns, green for action words, orange for things, food, and places, blue for feelings and yes or no, pink for social words and urgent needs, purple for questions and time.';

  @override
  String get tourArrangeTitle => 'Arrange the board';

  @override
  String get tourArrangeBody =>
      'The board button lets you move, hide, add, or rename tiles, and record your own voice for any tile. It asks a quick grown-up question first, so your child cannot change their own board.';

  @override
  String get recordVoiceOptional => 'Record your own voice (optional)';

  @override
  String get recordVoiceStop => 'Stop';

  @override
  String get recordVoiceRecorded => 'Voice recorded';

  @override
  String get recordVoiceClear => 'Remove recording';
}
