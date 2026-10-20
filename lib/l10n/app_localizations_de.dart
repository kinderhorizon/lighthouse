// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get back => 'Zurück';

  @override
  String get skip => 'Überspringen';

  @override
  String get next => 'Weiter';

  @override
  String get done => 'Fertig';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get continueLabel => 'Fortfahren';

  @override
  String get settingsTooltip => 'Einstellungen';

  @override
  String packNotLoaded(String folder) {
    return 'Paket nicht geladen: $folder';
  }

  @override
  String get couldNotLoadBoard => 'Standard-Tafel konnte nicht geladen werden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get followSystem => 'Systemstandard';

  @override
  String get sectionCrashLogs => 'Absturzberichte';

  @override
  String get viewCrashLogs => 'Absturzberichte anzeigen';

  @override
  String get viewCrashLogsSubtitle =>
      'See exactly what would be sent before you send it';

  @override
  String get shareCrashLogs => 'Send Absturz Berichte';

  @override
  String get shareCrashLogsSubtitle =>
      'Opens your mail app to send the Berichte to KHF; you Tippen send';

  @override
  String get sectionBoards => 'Boards';

  @override
  String get importBoardPack => 'Importieren a Tafel pack';

  @override
  String get importBoardPackSubtitle =>
      'Add a Tafel JSON file from this device';

  @override
  String get sectionOnboarding => 'Onboarding';

  @override
  String get rerunOnboarding => 'Re-run the Willkommen';

  @override
  String get rerunOnboardingSubtitle => 'Anzeigen the first-launch flow again';

  @override
  String get sectionAdvanced => 'Advanced';

  @override
  String get advancedSettings => 'Advanced Einstellungen';

  @override
  String get advancedSettingsSubtitle =>
      'Stimme, Hervorhebung, Tippen size, learning';

  @override
  String get sectionUpdates => 'Aktualisierungen';

  @override
  String get sectionAbout => 'Über';

  @override
  String get aboutLighthouse => 'Über Lighthouse';

  @override
  String get aboutLighthouseSubtitle =>
      'A free project of the Kinder Horizon Foundation';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get privacyPolicySubtitle =>
      'How Lighthouse handles your data (opens in your browser)';

  @override
  String get couldNotOpenLink => 'Konnte nicht open the link.';

  @override
  String get noCrashLogsToShare => 'No Absturz Berichte to send.';

  @override
  String get shareSubject => 'Lighthouse AAC Absturz Berichte';

  @override
  String get crashEmailBody =>
      'The attached Absturz Berichte are from Lighthouse AAC. Thank you for helping us fix the problem.';

  @override
  String get shareBody =>
      'Absturz Berichte from Lighthouse AAC are attached. Please send them to bugs@kinderhorizon.org.';

  @override
  String get rerunOnboardingConfirmTitle => 'Re-run onboarding?';

  @override
  String get rerunOnboardingConfirmBody =>
      'You will see the first-launch flow again. The Tafel and your child\'s learned patterns are not affected.';

  @override
  String get rerun => 'Re-run';

  @override
  String get couldNotReadFile => 'Konnte nicht read the picked file.';

  @override
  String importedBoard(String board) {
    return 'Imported \"$board\".';
  }

  @override
  String couldNotImport(String error) {
    return 'Konnte nicht import: $error';
  }

  @override
  String get advancedTitle => 'Advanced';

  @override
  String get sectionVoice => 'Stimme';

  @override
  String get sectionVisual => 'How the Tafel looks';

  @override
  String get sectionLearning => 'Learning';

  @override
  String get resetLearnedState => 'Gelernte Vorhersagen zurücksetzen';

  @override
  String get resetLearnedStateSubtitle =>
      'Löscht den lokalen Lernverlauf und stellt die Standardvorschläge wieder her';

  @override
  String get resetLearnedStateConfirmTitle => 'Zurücksetzen learned state?';

  @override
  String get resetLearnedStateConfirmBody =>
      'This permanently erases the Hervorhebung predictions your Kind has built up. It cannot be undone. The Tafel, language, and other Einstellungen are not affected.\n\nUse this when handing the device to a different Kind, or if the glows no longer match how your Kind communicates.';

  @override
  String get erase => 'Erase';

  @override
  String get learnedStateCleared => 'Learned state cleared.';

  @override
  String get couldNotClearLearnedState =>
      'Konnte nicht clear learned state. Try again.';

  @override
  String get voiceOutput => 'Stimme output';

  @override
  String get ttsModeOn => 'On (speak every tap)';

  @override
  String get ttsModeOnRequest => 'On-request (long-press to speak)';

  @override
  String get ttsModeOff => 'Off (no synthesized speech)';

  @override
  String get ttsModeAls => 'Anzeigen Wort large, no Sprache (ALS)';

  @override
  String get glowStyle => 'Hervorhebung style';

  @override
  String get glowStyleHalo => 'Soft halo';

  @override
  String get hitboxExpansion => 'Tippen size';

  @override
  String get hitboxNone => 'Standard';

  @override
  String get hitboxSubtle => 'Comfortable';

  @override
  String get hitboxMaximum => 'Large';

  @override
  String get aboutTitle => 'Über';

  @override
  String get aboutTagline => 'A free project of the Kinder Horizon Foundation.';

  @override
  String get aboutBody =>
      'Lighthouse helps non-speaking children communicate. It is free, has no ads, and keeps everything your Kind does on this device.';

  @override
  String get visitWebsite => 'Visit kinderhorizon.org';

  @override
  String get visitWebsiteSubtitle => 'Opens our website in your browser';

  @override
  String get couldNotOpenBrowser => 'Browser konnte nicht geöffnet werden.';

  @override
  String get version => 'Version';

  @override
  String versionLabel(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get mathGateError => 'Not quite. Try again.';

  @override
  String get mathGateTitle => 'Elternbereich';

  @override
  String get mathGateBody =>
      'These Einstellungen can disrupt how the app works for your Kind. Answer below to continue.';

  @override
  String mathGateEquation(String a, String b) {
    return '$a + $b = ?';
  }

  @override
  String get mathGateAnswerLabel => 'Answer';

  @override
  String get crashLogsTitle => 'Absturz Berichte';

  @override
  String get noCrashLogsOnDevice =>
      'Keine Absturzberichte auf dem Gerät vorhanden.';

  @override
  String get onboardingGridTitle => 'This is the Tafel your Kind will see.';

  @override
  String get onboardingGridBody =>
      'Tippen any Feld to hear how it sounds. Buttons never move; the layout your Kind learns today is the layout they will always have.';

  @override
  String get onboardingPlaceTitle => 'Where will your Kind use Lighthouse?';

  @override
  String get onboardingPlaceBody =>
      'We use this to Beschriftung the place Lighthouse learns first. It does not change how the app behaves; you can skip it.';

  @override
  String get onboardingWifiTitle => 'Learn Wörter for each place';

  @override
  String get onboardingWifiBody =>
      'Lighthouse can use your Wi-Fi Netzwerk name, scrambled on this device, to learn which Wörter your Kind needs in different places like home and school. The name never leaves the tablet, and this is optional.';

  @override
  String get onboardingWifiAllow => 'Allow';

  @override
  String get onboardingWifiGranted =>
      'On. Lighthouse will learn Wörter for each place.';

  @override
  String get onboardingWifiDenied =>
      'Not now. You can turn this on later in Einstellungen.';

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
      'What you just told us, and everything your Kind taps next, stays here. Lighthouse has no account and never sends your child\'s Wörter anywhere.';

  @override
  String get howWeKnowTitle => 'How we know';

  @override
  String get howWeKnowBody1 =>
      'Lighthouse does not connect to any cloud. There is no analytics SDK in the app. There is no automatic Absturz reporting. Data leaves the device only when you choose to send it: if you Tippen \"Send Absturz logs\", which opens your own mail app pre-addressed to us so you can review and Tippen send, or if you Teilen a vocabulary Tafel with another family, where you pick the destination. You stay in control either way; nothing is sent automatically.';

  @override
  String get howWeKnowBody2 =>
      'You can verify this on the Einstellungen screen, which lets you preview the exact Absturz log contents before you send. A Absturz log holds the device model, the OS Version, and a technical Fehler report (the Fehler type, its message, and the code trace). The app is built not to Aufnehmen the Wörter your Kind taps or your Tafel content, and because you preview each log and choose whether to send it, you stay in control of what leaves the device.';

  @override
  String get howWeKnowUpdates =>
      'If you Tippen \"Check for updates\", the app sends only its Version number to ask whether corrected Wörter, pictures, or sounds are available. It sends nothing Über your Kind or how the app is used.';

  @override
  String get howWeKnowFeedback =>
      'If you Tippen \"Send feedback\", the app sends only the message you write, plus the app and system Version. The message is not stored, and it carries nothing Über your Kind or your boards.';

  @override
  String get sectionNavigation => 'Moving around';

  @override
  String get autoReturnToHome => 'Go home after a Wort';

  @override
  String get autoReturnToHomeSubtitle =>
      'After a Wort inside a Ordner, return to the home Tafel';

  @override
  String get hideTileText => 'Ausblenden text on tiles';

  @override
  String get hideTileTextSubtitle =>
      'Anzeigen pictures only, without the Wort under each Feld';

  @override
  String get sentenceBarLabel => 'Satz';

  @override
  String get sentenceBarHint => 'Tippen Wörter to build a Satz';

  @override
  String get boardScrollHint => 'more Wörter';

  @override
  String get sentenceSpeak => 'Sprechen Satz';

  @override
  String get sentenceBackspace => 'Entfernen last Wort';

  @override
  String get sentenceClear => 'Leeren Satz';

  @override
  String get customButtonsTitle => 'Eigene Felder';

  @override
  String get customButtonsSubtitle =>
      'Eigene Wörter mit Fotos und Sprachaufnahmen hinzufügen';

  @override
  String get imageRejected =>
      'That Bild is too large or not a supported type. Please choose a smaller Foto.';

  @override
  String get customButtonsAdd => 'Add a Taste';

  @override
  String get customButtonsBoardLabel => 'Tafel';

  @override
  String get customButtonsWordLabel => 'Wort';

  @override
  String get customButtonsChoosePhoto => 'Choose Foto';

  @override
  String get customButtonsNoFreeSlots =>
      'This Tafel is full. Choose another Tafel.';

  @override
  String get customButtonsDelete => 'Löschen Taste';

  @override
  String get customButtonsSave => 'Speichern';

  @override
  String get homeFavouritesTitle => 'Favoriten-Leiste';

  @override
  String get homeFavouritesSubtitle =>
      'Wichtige Wörter auf der Haupttafel anheften';

  @override
  String get homeFavouritesIntro =>
      'Pinned Wörter appear in a row on the home page, always in the same place.';

  @override
  String get homeFavouritesSuggested => 'Used a lot';

  @override
  String get homeFavouritesAllWords => 'Add from a group';

  @override
  String get homeFavouritesPin => 'Anheften';

  @override
  String get homeFavouritesUnpin => 'Lösen';

  @override
  String homeFavouritesFull(int count) {
    return 'Home is full ($count favourites). Entfernen one to add another.';
  }

  @override
  String get editBoardTooltip => 'Arrange Tafel';

  @override
  String get editBoardTitle => 'Arrange Tafel';

  @override
  String get editBoardHint =>
      'Tippen a Taste to move it, Anheften it, or replace it. Drag to rearrange. Your Kind sees the new layout when you leave.';

  @override
  String get editActionMove => 'Move';

  @override
  String get editMoveHint => 'Tippen where to place it';

  @override
  String get editActionPin => 'Anheften to favourites';

  @override
  String get editActionUnpin => 'Entfernen from favourites';

  @override
  String get editActionAddHere => 'Add a Taste here';

  @override
  String get editResetBoard => 'Zurücksetzen this Tafel';

  @override
  String get editResetAll => 'Zurücksetzen everything';

  @override
  String get editResetBoardConfirm =>
      'Put this Tafel back the way it came? Every change you made to it (tiles you moved, hid, re-pictured, re-recorded, or added) will be undone. Other boards are not affected.';

  @override
  String get editResetAllConfirm =>
      'Put every Tafel back the way it came? All your changes on every Tafel (moved, hidden, re-pictured, re-recorded, and added tiles) will be undone.';

  @override
  String get editResetConfirmButton => 'Zurücksetzen';

  @override
  String get editDone => 'Done';

  @override
  String get editArrangeHint =>
      'Drag a Feld to move it. Tippen a Feld for more, or Tippen Auswählen to change several at once.';

  @override
  String get editSelectHint =>
      'Tippen tiles to choose them, then pick an action below. Changes apply to all chosen tiles at once.';

  @override
  String get editSelect => 'Auswählen';

  @override
  String get editSelectTiles => 'Auswählen tiles';

  @override
  String editSelectedCount(int count) {
    return '$count Ausgewählt';
  }

  @override
  String get editSelectAll => 'All';

  @override
  String get editSelectNone => 'Keine';

  @override
  String get editTileSheetSubtitle => 'Choose what to change';

  @override
  String get editActionRecordVoice => 'Aufnehmen Stimme';

  @override
  String get editActionRerecordVoice => 'Re-record Stimme';

  @override
  String get editActionRecordVoiceSub => 'Use your own Stimme';

  @override
  String get editActionVoiceSetSub => 'Your Stimme is set';

  @override
  String get editActionReplacePicture => 'Replace picture';

  @override
  String get editActionReplacePictureSub => 'Choose a Foto';

  @override
  String get editActionPinSub => 'Anzeigen it in home favourites';

  @override
  String get editActionHide => 'Ausblenden from the Tafel';

  @override
  String get editActionHideSub => 'Your Kind will not see it';

  @override
  String get editActionShow => 'Anzeigen on the Tafel';

  @override
  String get editActionShowSub => 'Your Kind can see it again';

  @override
  String get editBatchHide => 'Ausblenden';

  @override
  String get editBatchShow => 'Anzeigen';

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
    return '$count hidden from the Tafel';
  }

  @override
  String editToastShown(int count) {
    return '$count shown on the Tafel';
  }

  @override
  String get editToastPinnedOne => 'Pinned to favourites';

  @override
  String get editToastUnpinnedOne => 'Removed from favourites';

  @override
  String get editToastHiddenOne => 'Hidden from the Tafel';

  @override
  String get editToastShownOne => 'Shown on the Tafel';

  @override
  String get editToastPictureReplaced => 'Picture replaced';

  @override
  String get editToastVoiceSaved => 'Stimme saved';

  @override
  String get editToastVoiceDeleted =>
      'Recording deleted, using the built-in Stimme';

  @override
  String editVoiceTitle(String word) {
    return 'Stimme for \"$word\"';
  }

  @override
  String get editVoiceOverrideSub => 'Your recording overrides the default';

  @override
  String editVoicePrompt(String word) {
    return 'Tippen the Mikrofon and say \"$word\". Your recording will Abspielen instead of the built-in Stimme for this Feld.';
  }

  @override
  String get editVoiceTapToRecord => 'Tippen to Aufnehmen';

  @override
  String editVoiceListening(String word) {
    return 'Listening, say \"$word\"';
  }

  @override
  String get editVoiceTapToStop => 'Tippen to stop';

  @override
  String editVoiceReview(String word) {
    return 'Here is your recording for \"$word\".';
  }

  @override
  String get editVoicePlay => 'Abspielen';

  @override
  String get editVoiceRerecord => 'Re-record';

  @override
  String get editVoiceUseRecording => 'Use this recording';

  @override
  String editVoiceSavedMsg(String word) {
    return 'Your Stimme is set for \"$word\". You can Abspielen, re-record, or Löschen it at any time. Deleting it brings back the built-in Stimme.';
  }

  @override
  String get editVoiceDelete => 'Löschen';

  @override
  String get editVoiceDone => 'Done';

  @override
  String get editVoiceMicDenied =>
      'Mikrofon access is off. Turn it on in Einstellungen to Aufnehmen a Stimme.';

  @override
  String editFavouritesFull(int count) {
    return 'Favourites are full ($count max)';
  }

  @override
  String get editShareBoard => 'Teilen this Tafel';

  @override
  String get shareVocabTitle => 'Teilen this vocabulary?';

  @override
  String get shareVocabBody =>
      'You will Teilen the Wörter you built on this Tafel. On the other tablet it arrives as a new, separate Tafel that starts learning fresh; it is not merged into their Tafel. Nothing is shared automatically.';

  @override
  String shareVocabPhotos(int count) {
    return '$count buttons use photos from this tablet. They will be shared as Wörter only; the photos stay on your device.';
  }

  @override
  String get shareVocabConfirm => 'Teilen';

  @override
  String get shareVocabFailed => 'Konnte nicht prepare this board to share.';

  @override
  String get otaTitle => 'Inhalts-Aktualisierungen';

  @override
  String get otaSettingsSubtitle =>
      'Get the latest Wort, picture, and Ton corrections';

  @override
  String get otaBody =>
      'Lighthouse can Prüfen Kinder Horizon for corrections to Wörter, translations, pictures, and sounds. It only checks when you Tippen below, and sends nothing Über you or your Kind.';

  @override
  String get otaCheckNow => 'Jetzt prüfen';

  @override
  String get otaChecking => 'Suche nach Aktualisierungen…';

  @override
  String get otaUpToDate => 'Alle Inhalte sind auf dem neuesten Stand.';

  @override
  String get otaAvailable => 'Neue Inhalte verfügbar';

  @override
  String get otaApply => 'Jetzt aktualisieren';

  @override
  String get otaApplying => 'Applying...';

  @override
  String get otaApplied => 'Inhalte erfolgreich aktualisiert.';

  @override
  String get otaShowNow => 'Anzeigen the Aktualisieren now';

  @override
  String get otaApplyFallback =>
      'Or it will be ready the next time you open Lighthouse.';

  @override
  String get otaIncompatible =>
      'These corrections need a newer Version of Lighthouse. Please Aktualisieren the app.';

  @override
  String get otaError =>
      'Konnte nicht check right now. Please try again later.';

  @override
  String get sectionFeedback => 'Rückmeldung';

  @override
  String get feedbackTitle => 'Feedback senden';

  @override
  String get feedbackSettingsSubtitle =>
      'Report a bug or suggest an improvement';

  @override
  String get feedbackBody =>
      'Tell us what is not working or what would help. We read every message.';

  @override
  String get feedbackCategoryLabel => 'What is this Über?';

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
      'We send only your message and the app Version. Nothing Über your Kind, your boards, or how the app is used.';

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
      'Konnte nicht send right now. Please try again later.';

  @override
  String get feedbackErrorTooLong =>
      'That message is too long. Please shorten it.';

  @override
  String get sectionYourChildsBoard => 'Your child\'s Tafel';

  @override
  String get sectionHowAppBehaves => 'How the app behaves';

  @override
  String get sectionUpdatesSupport => 'Aktualisierungen & support';

  @override
  String get crashLogsRowSubtitle => 'View what could be shared, then send it';

  @override
  String get crashEmptyHeadline => 'Nothing has gone wrong';

  @override
  String get crashEmptyBody =>
      'There are no Absturz Berichte on this device, so there is nothing to send. If the app ever closes unexpectedly, a log will appear here for you to review before sending.';

  @override
  String get glowStyleRing => 'Inset ring';

  @override
  String get glowStyleLift => 'Lift and underline';

  @override
  String get glowStyleDot => 'Quiet corner dot';

  @override
  String get glowStyleOff => 'Off';

  @override
  String get showWordOnTile => 'Anzeigen the Wort on each Feld';

  @override
  String get showWordOnTileSubtitle => 'Turn off to Anzeigen pictures only';

  @override
  String get showPictogramOnTile => 'Anzeigen the picture on each Feld';

  @override
  String get showPictogramOnTileSubtitle => 'Turn off to Anzeigen Wörter only';

  @override
  String get otaLastCheckedNever => 'Noch nie geprüft';

  @override
  String get otaCheckedJustNow => 'Gerade eben geprüft';

  @override
  String otaLastChecked(String when) {
    return 'Last checked: $when';
  }

  @override
  String get otaWhenJustNow => 'just now';

  @override
  String get otaWhenToday => 'today';

  @override
  String get otaWhenYesterday => 'yesterday';

  @override
  String get feedbackThanksTitle => 'Thank you. Your message is on its way.';

  @override
  String get feedbackThanksBody =>
      'A real person at Kinder Horizon reads every note. If you left an email, we will reply when we can. Lighthouse is built by a small nonprofit team, and your Wörter genuinely shape what we fix next.';

  @override
  String get feedbackSendAnother => 'Send another';

  @override
  String get feedbackBackToBoard => 'Back to the Tafel';

  @override
  String get aboutLicence => 'Open source · MIT Lizenz';

  @override
  String get aboutCredits => 'Danksagungen & Lizenzen';

  @override
  String get aboutLicences => 'Open-source Lizenzen';

  @override
  String get aboutLicencesSubtitle =>
      'Lizenzen for the code and fonts Lighthouse uses';

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
  String get tourSkipToBoard => 'Skip, go to the Tafel';

  @override
  String get tourSettingsRowTitle => 'Take the tour';

  @override
  String get tourSettingsRowSubtitle => 'A quick guided walkthrough of the app';

  @override
  String get tipEditorTitle => 'Editing your Tafel';

  @override
  String get tipEditorBody =>
      'Press and drag a Feld to move it, or Tippen Auswählen to favourite or Ausblenden several at once.';

  @override
  String get tipGateTitle => 'A quick Prüfen for grown-ups';

  @override
  String get tipGateBody =>
      'Answer a simple sum to get in. It is a Geschwindigkeit bump to keep little hands out, not a password.';

  @override
  String get tipButtonsTitle => 'Add your own buttons';

  @override
  String get tipButtonsBody =>
      'Make tiles for the people, foods, and places your Kind needs, each with a Foto and a Wort.';

  @override
  String get tipFavouritesTitle => 'Home favourites';

  @override
  String get tipFavouritesBody =>
      'Pinned Wörter sit in a row at the top of the home Tafel, so the Wörter used most are the easiest to find.';

  @override
  String get tipAdvancedTitle => 'Advanced Einstellungen';

  @override
  String get tipAdvancedBody =>
      'These options change how the Tafel looks and behaves. Your child\'s Wörter and layout are never touched here.';

  @override
  String get tipGotIt => 'Got it';

  @override
  String get tourBoardTitle => 'This is your child\'s Tafel';

  @override
  String get tourBoardBody =>
      'Your Kind taps these tiles to talk. The tiles never move, so the layout becomes muscle memory over time.';

  @override
  String get tourSentenceTitle => 'Satzleiste';

  @override
  String get tourSentenceBody =>
      'Wörter reihen sich hier aneinander. Tippen Sie auf Vorlesen, um den ganzen Satz zu hören.';

  @override
  String get tourGlowTitle => 'Sanfte Leucht-Hinweise';

  @override
  String get tourGlowBody =>
      'Lighthouse hebt passende nächste Wörter sanft hervor, ohne die Tasten zu verschieben.';

  @override
  String get tourFoldersTitle => 'Themen-Ordner';

  @override
  String get tourFoldersBody =>
      'Ordner mit dem Eck-Symbol öffnen weitere spezifische Wörter.';

  @override
  String get tourSettingsTitle => 'Geschützte Einstellungen';

  @override
  String get tourSettingsBody =>
      'Eltern und Therapeuten gelangen über die Rechenaufgabe in die Einstellungen.';

  @override
  String get homeFavouritesPinnedNow => 'Aktuell angeheftet';

  @override
  String get homeFavouritesEmpty => 'Noch keine Wörter angeheftet.';

  @override
  String get customButtonsEmptyHeadline => 'Noch keine eigenen Felder erstellt';

  @override
  String get customButtonsEmptyBody =>
      'Add a Foto and a Wort for the people, foods, and places your Kind needs most. New buttons join the Tafel in the right colour group.';

  @override
  String get customButtonsAddFirst => 'Add your first Taste';

  @override
  String get onboardingStart => 'Start using Lighthouse';

  @override
  String get placeHomeSub => 'Where most days happen';

  @override
  String get placeSchoolSub => 'A classroom or therapy room';

  @override
  String get placeBothSub => 'It moves with your Kind';

  @override
  String get placeOtherSub => 'Tell us later if you like';

  @override
  String get onboardingPrivacyHeadline => 'Everything stays on this device';

  @override
  String get onboardingPrivacyPoint1 => 'No account, no ads, no tracking';

  @override
  String get onboardingPrivacyPoint2 => 'Works fully Offline';

  @override
  String get onboardingPrivacyPoint3 => 'Open source, so anyone can Prüfen';

  @override
  String get crashLogsSentCleared =>
      'Absturz Berichte sent. They have been removed from this device.';

  @override
  String get exportBoardPack => 'Exportieren this Tafel';

  @override
  String get exportBoardPackSubtitle =>
      'Teilen your Tafel as a file another device can Importieren';

  @override
  String get tourColorsTitle => 'The colours group Wörter';

  @override
  String get tourColorsBody =>
      'Each colour is a kind of word: yellow for people and pronouns, green for action Wörter, orange for things, food, and places, blue for feelings and yes or no, pink for social Wörter and urgent needs, purple for questions and time.';

  @override
  String get tourArrangeTitle => 'Arrange the Tafel';

  @override
  String get tourArrangeBody =>
      'The Tafel Taste lets you move, Ausblenden, add, or rename tiles, and Aufnehmen your own Stimme for any Feld. It asks a quick grown-up question first, so your Kind cannot change their own Tafel.';

  @override
  String get recordVoiceOptional => 'Aufnehmen your own Stimme (optional)';

  @override
  String get recordVoiceStop => 'Stop';

  @override
  String get recordVoiceRecorded => 'Stimme recorded';

  @override
  String get recordVoiceClear => 'Entfernen recording';

  @override
  String get userProfilesTitle => 'Benutzerprofile';

  @override
  String get userProfilesSubtitle =>
      'Kommunikationsprofile wechseln oder verwalten';

  @override
  String get userProfilesDescription =>
      'Verwalten Sie unabhängige Benutzerprofile für Kommunikatoren, Schüler oder Familienmitglieder. Jedes Profil behält getrennte Spracheinstellungen, Zugangsmethoden und Vokabular.';

  @override
  String get addNewProfile => 'Neues Profil hinzufügen';

  @override
  String get createProfileTitle => 'Profil erstellen';

  @override
  String get profileNameLabel => 'Profilname';

  @override
  String get profileNameHint => 'z. B. Maya, Karim, Leo';

  @override
  String editProfileTitle(String name) {
    return 'Profil bearbeiten: $name';
  }

  @override
  String deleteProfileTitle(String name) {
    return 'Profil \"$name\" löschen?';
  }

  @override
  String get deleteProfileConfirm =>
      'Dadurch wird dieses Profil und seine benutzerdefinierten Einstellungen dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String switchedToProfile(String name) {
    return 'Zu Profil gewechselt: $name';
  }

  @override
  String get activeBadge => 'AKTIV';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get deleteProfile => 'Profil löschen';

  @override
  String get activateProfile => 'Profil aktivieren';

  @override
  String get saveAction => 'Speichern';

  @override
  String get deleteAction => 'Löschen';

  @override
  String get createAction => 'Erstellen';

  @override
  String get speechOutputLanguage => 'Sprachausgabe-Sprache';

  @override
  String matchesInterfaceLanguage(String lang) {
    return 'Entspricht der Benutzeroberfläche ($lang)';
  }

  @override
  String get speechSpeed => 'Sprechgeschwindigkeit';

  @override
  String get speechPitch => 'Tonhöhe';

  @override
  String get speechVolume => 'Sprachlautstärke';

  @override
  String get highContrastBoard => 'Kontrastreiches Raster';

  @override
  String get highContrastBoardSubtitle =>
      'Verbesserte Ränder für klare visuelle Erkennung';

  @override
  String get sectionAiAssistance => 'KI-Unterstützung';

  @override
  String get aiPredictionBar => 'KI-Vorhersageleiste';

  @override
  String get aiPredictionBarSubtitle =>
      'Offline-Vorschläge für nächste Wörter und Satzbau anzeigen';

  @override
  String get sectionSwitchAccessibility => 'Taster-Bedienung (Switch Access)';

  @override
  String get accessMethod => 'Zugangsmethode';

  @override
  String get accessDirectTouch => 'Direkte Berührung';

  @override
  String get accessSwitchSingle => 'Einzeltaster (Automatisches Scannen)';

  @override
  String get accessSwitchDual => 'Zweitaster (Schritt & Auswahl)';

  @override
  String get autoScanDwellTime => 'Verweildauer für Auto-Scan';

  @override
  String get aiAssistantTitle => 'KI-Textassistent & Übersetzer';

  @override
  String get aiAssistantInputHint =>
      'Wörter, Stichworte oder unvollständige Sätze eingeben...';

  @override
  String get aiSuggestionsHeader =>
      'Satzvorschläge (Tippen zum Sprechen oder Kopieren):';

  @override
  String get translateTo => 'Übersetzen nach: ';

  @override
  String get speakSentence => 'Satz sprechen';

  @override
  String get aiCommunicationAssistantTooltip => 'KI-Kommunikationsassistent';

  @override
  String get switchStep => 'SCHRITT (Leertaste)';

  @override
  String get switchSelect => 'AUSWÄHLEN (Eingabe)';

  @override
  String get symbolLicenseNotice =>
      'Symbole: Open AAC Symbols & Material Symbols. Lizenz: Apache 2.0 (kommerziell nutzbar, permissives Open-Source).';
}
