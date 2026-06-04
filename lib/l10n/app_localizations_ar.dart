// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get back => 'رجوع';

  @override
  String get skip => 'تخطّي';

  @override
  String get next => 'التالي';

  @override
  String get done => 'تم';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get settingsTooltip => 'الإعدادات';

  @override
  String packNotLoaded(String folder) {
    return 'لم يتم تحميل الحزمة: $folder';
  }

  @override
  String get couldNotLoadBoard => 'تعذّر تحميل اللوحة الافتراضية.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get followSystem => 'اتّباع النظام';

  @override
  String get sectionCrashLogs => 'سجلات الأعطال';

  @override
  String get viewCrashLogs => 'عرض سجلات الأعطال';

  @override
  String get viewCrashLogsSubtitle =>
      'اطّلع على ما سيتم إرساله بالضبط قبل الإرسال';

  @override
  String get shareCrashLogs => 'إرسال سجلات الأعطال';

  @override
  String get shareCrashLogsSubtitle =>
      'يفتح تطبيق البريد لديك لإرسال السجلات إلى KHF؛ أنت تضغط إرسال';

  @override
  String get sectionBoards => 'اللوحات';

  @override
  String get importBoardPack => 'استيراد لوحة';

  @override
  String get importBoardPackSubtitle => 'أضف ملف لوحة JSON من هذا الجهاز';

  @override
  String get sectionOnboarding => 'التمهيد';

  @override
  String get rerunOnboarding => 'إعادة عرض الترحيب';

  @override
  String get rerunOnboardingSubtitle => 'عرض شاشات التشغيل الأول مرة أخرى';

  @override
  String get sectionAdvanced => 'متقدّم';

  @override
  String get advancedSettings => 'الإعدادات المتقدّمة';

  @override
  String get advancedSettingsSubtitle => 'الصوت، التوهّج، حجم اللمس، التعلّم';

  @override
  String get sectionUpdates => 'التحديثات';

  @override
  String get sectionAbout => 'حول';

  @override
  String get aboutLighthouse => 'حول Lighthouse';

  @override
  String get aboutLighthouseSubtitle => 'مشروع مجاني من مؤسسة Kinder Horizon';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get privacyPolicySubtitle =>
      'كيف يتعامل Lighthouse مع بياناتك (يفتح في المتصفح)';

  @override
  String get couldNotOpenLink => 'تعذّر فتح الرابط.';

  @override
  String get noCrashLogsToShare => 'لا توجد سجلات أعطال لإرسالها.';

  @override
  String get shareSubject => 'سجلات أعطال Lighthouse AAC';

  @override
  String get crashEmailBody =>
      'السجلات المرفقة هي سجلات أعطال من Lighthouse AAC. شكرًا لمساعدتنا في إصلاح المشكلة.';

  @override
  String get shareBody =>
      'سجلات أعطال Lighthouse AAC مرفقة. أرسلها إلى bugs@kinderhorizon.org.';

  @override
  String get rerunOnboardingConfirmTitle => 'إعادة التمهيد؟';

  @override
  String get rerunOnboardingConfirmBody =>
      'سترى شاشات التشغيل الأول مرة أخرى. لن تتأثر اللوحة ولا الأنماط التي تعلّمها طفلك.';

  @override
  String get rerun => 'إعادة';

  @override
  String get couldNotReadFile => 'تعذّر قراءة الملف المحدّد.';

  @override
  String importedBoard(String board) {
    return 'تم استيراد \"$board\".';
  }

  @override
  String couldNotImport(String error) {
    return 'تعذّر الاستيراد: $error';
  }

  @override
  String get advancedTitle => 'متقدّم';

  @override
  String get sectionVoice => 'الصوت';

  @override
  String get sectionVisual => 'كيف تبدو اللوحة';

  @override
  String get sectionLearning => 'التعلّم';

  @override
  String get resetLearnedState => 'إعادة تعيين ما تعلّمه Lighthouse';

  @override
  String get resetLearnedStateSubtitle =>
      'يمسح أنماط كلمات طفلك. اللوحة نفسها لا تتغّير.';

  @override
  String get resetLearnedStateConfirmTitle => 'إعادة تعيين الحالة المكتسبة؟';

  @override
  String get resetLearnedStateConfirmBody =>
      'يؤدي هذا إلى مسح تنبؤات التوهّج التي اكتسبها طفلك بشكل دائم. لا يمكن التراجع عن ذلك. لا تتأثر اللوحة أو اللغة أو الإعدادات الأخرى.\n\nاستخدم هذا عند تسليم الجهاز إلى طفل آخر، أو إذا لم تعد التوهّجات تطابق طريقة تواصل طفلك.';

  @override
  String get erase => 'مسح';

  @override
  String get learnedStateCleared => 'تم مسح الحالة المكتسبة.';

  @override
  String get couldNotClearLearnedState =>
      'تعذّر مسح الحالة المكتسبة. حاول مرة أخرى.';

  @override
  String get voiceOutput => 'إخراج الصوت';

  @override
  String get ttsModeOn => 'مفعّل (النطق عند كل لمسة)';

  @override
  String get ttsModeOnRequest => 'عند الطلب (اضغط مطوّلاً للنطق)';

  @override
  String get ttsModeOff => 'متوقّف (بدون نطق مُركّب)';

  @override
  String get ttsModeAls => 'إظهار الكلمة كبيرة، بدون نطق (ALS)';

  @override
  String get glowStyle => 'نمط التوهّج';

  @override
  String get glowStyleHalo => 'هالة ناعمة';

  @override
  String get hitboxExpansion => 'حجم اللمس';

  @override
  String get hitboxNone => 'عادي';

  @override
  String get hitboxSubtle => 'مريح';

  @override
  String get hitboxMaximum => 'كبير';

  @override
  String get aboutTitle => 'حول';

  @override
  String get aboutTagline => 'مشروع مجاني من مؤسسة Kinder Horizon.';

  @override
  String get aboutBody =>
      'يساعد Lighthouse الأطفال غير الناطقين على التواصل. إنه مجاني، وبلا إعلانات، ويحتفظ بكل ما يفعله طفلك على هذا الجهاز.';

  @override
  String get visitWebsite => 'زيارة kinderhorizon.org';

  @override
  String get visitWebsiteSubtitle => 'يفتح موقعنا في متصفّحك';

  @override
  String get couldNotOpenBrowser => 'تعذّر فتح المتصفّح.';

  @override
  String get version => 'الإصدار';

  @override
  String versionLabel(String version, String build) {
    return 'الإصدار $version ($build)';
  }

  @override
  String get mathGateError => 'ليست صحيحة. حاول مرة أخرى.';

  @override
  String get mathGateTitle => 'تحقّق سريع';

  @override
  String get mathGateBody =>
      'قد تغيّر هذه الإعدادات طريقة عمل التطبيق لطفلك. أجب أدناه للمتابعة.';

  @override
  String mathGateEquation(String a, String b) {
    return '$a + $b = ؟';
  }

  @override
  String get mathGateAnswerLabel => 'الإجابة';

  @override
  String get crashLogsTitle => 'سجلات الأعطال';

  @override
  String get noCrashLogsOnDevice =>
      'لا توجد سجلات أعطال على هذا الجهاز. لا شيء لمشاركته.';

  @override
  String get onboardingGridTitle => 'هذه هي اللوحة التي سيراها طفلك.';

  @override
  String get onboardingGridBody =>
      'المس أي خانة لتسمع كيف تُنطق. الخانات لا تتحرك أبداً؛ التوزيع الذي يتعلّمه طفلك اليوم هو التوزيع الذي سيبقى دائماً.';

  @override
  String get onboardingPlaceTitle => 'أين سيستخدم طفلك Lighthouse؟';

  @override
  String get onboardingPlaceBody =>
      'نستخدم هذا لتسمية المكان الذي يتعلّمه Lighthouse أولاً. لا يغيّر سلوك التطبيق؛ يمكنك تخطّيه.';

  @override
  String get onboardingWifiTitle => 'تعلّم كلمات لكل مكان';

  @override
  String get onboardingWifiBody =>
      'يمكن لتطبيق Lighthouse استخدام اسم شبكة Wi-Fi الخاصة بك، مشفّرًا على هذا الجهاز، لمعرفة الكلمات التي يحتاجها طفلك في أماكن مختلفة مثل المنزل والمدرسة. لا يغادر الاسم الجهاز اللوحي أبدًا، وهذا أمر اختياري.';

  @override
  String get onboardingWifiAllow => 'السماح';

  @override
  String get onboardingWifiGranted =>
      'مُفعّل. سيتعلّم Lighthouse كلمات لكل مكان.';

  @override
  String get onboardingWifiDenied =>
      'ليس الآن. يمكنك تفعيل هذا لاحقًا من الإعدادات.';

  @override
  String get placeHome => 'المنزل';

  @override
  String get placeSchool => 'المدرسة';

  @override
  String get placeBoth => 'المنزل والمدرسة';

  @override
  String get placeOther => 'مكان آخر';

  @override
  String get privacyTitle => 'الخصوصية';

  @override
  String get privacyTooltip => 'كيف نعرف أن هذا صحيح';

  @override
  String get privacyBody =>
      'ما أخبرتنا به للتو، وكل ما يلمسه طفلك بعد ذلك، يبقى هنا. ليس لدى Lighthouse حساب ولا يرسل كلمات طفلك إلى أي مكان أبدًا.';

  @override
  String get howWeKnowTitle => 'كيف نعرف';

  @override
  String get howWeKnowBody1 =>
      'لا يتّصل Lighthouse بأي سحابة. لا يوجد SDK للتحليلات في التطبيق. لا يوجد إبلاغ تلقائي عن الأعطال. لا تخرج البيانات من الجهاز إلا عندما تختار إرسالها: إذا لمست «إرسال سجلات الأعطال»، التي تفتح تطبيق البريد لديك وقد وُجّه إلينا مسبقًا كي تراجع وتضغط إرسال، أو إذا شاركت لوحة مفردات مع عائلة أخرى حيث تختار الوجهة بنفسك. تبقى أنت المتحكّم في كلتا الحالتين؛ ولا يُرسَل شيء تلقائيًا.';

  @override
  String get howWeKnowBody2 =>
      'يمكنك التحقّق من ذلك في شاشة الإعدادات، التي تتيح لك معاينة محتوى سجل الأعطال بالضبط قبل إرساله. يتضمّن سجل الأعطال طراز الجهاز وإصدار النظام وتقريرًا تقنيًا عن الخطأ (نوع الخطأ ورسالته وتتبّع الشيفرة). صُمّم التطبيق كي لا يسجّل الكلمات التي يلمسها طفلك ولا محتوى لوحاتك، وبما أنك تعاين كل سجل وتقرّر إرساله، فأنت تتحكّم بما يخرج من الجهاز.';

  @override
  String get howWeKnowUpdates =>
      'إذا لمست «البحث عن تحديثات»، يرسل التطبيق رقم إصداره فقط ليسأل إن كانت هناك تصحيحات للكلمات أو الصور أو الأصوات. لا يرسل أي شيء عن طفلك أو عن كيفية استخدام التطبيق.';

  @override
  String get howWeKnowFeedback =>
      'إذا لمست «إرسال ملاحظات»، يرسل التطبيق الرسالة التي تكتبها فقط، إضافةً إلى إصدار التطبيق والنظام. لا تُخزَّن الرسالة ولا تتضمّن أي شيء عن طفلك أو عن لوحاتك.';

  @override
  String get sectionNavigation => 'التنقّل';

  @override
  String get autoReturnToHome => 'العودة إلى الصفحة الرئيسية بعد كلمة';

  @override
  String get autoReturnToHomeSubtitle =>
      'بعد كلمة داخل مجلد، يعود إلى اللوحة الرئيسية';

  @override
  String get hideTileText => 'إخفاء النص على الأزرار';

  @override
  String get hideTileTextSubtitle => 'إظهار الصور فقط دون الكلمة أسفل كل زر';

  @override
  String get sentenceBarLabel => 'جملة';

  @override
  String get sentenceBarHint => 'المس الكلمات لتكوين جملة';

  @override
  String get boardScrollHint => 'المزيد من الكلمات';

  @override
  String get sentenceSpeak => 'نطق الجملة';

  @override
  String get sentenceBackspace => 'حذف الكلمة الأخيرة';

  @override
  String get sentenceClear => 'مسح الجملة';

  @override
  String get customButtonsTitle => 'أزرارك الخاصة';

  @override
  String get customButtonsSubtitle => 'أضف صورًا وكلمات يحتاجها طفلك';

  @override
  String get imageRejected =>
      'هذه الصورة كبيرة جدًا أو من نوع غير مدعوم. يُرجى اختيار صورة أصغر.';

  @override
  String get customButtonsAdd => 'إضافة زر';

  @override
  String get customButtonsBoardLabel => 'اللوحة';

  @override
  String get customButtonsWordLabel => 'كلمة';

  @override
  String get customButtonsChoosePhoto => 'اختيار صورة';

  @override
  String get customButtonsNoFreeSlots => 'هذه اللوحة ممتلئة. اختر لوحة أخرى.';

  @override
  String get customButtonsDelete => 'حذف الزر';

  @override
  String get customButtonsSave => 'حفظ';

  @override
  String get homeFavouritesTitle => 'المفضلة في الرئيسية';

  @override
  String get homeFavouritesSubtitle =>
      'ثبّت الكلمات التي يستخدمها طفلك كثيرًا في الصفحة الرئيسية';

  @override
  String get homeFavouritesIntro =>
      'تظهر الكلمات المثبتة في صف على الصفحة الرئيسية، دائمًا في المكان نفسه.';

  @override
  String get homeFavouritesSuggested => 'كثيرة الاستخدام';

  @override
  String get homeFavouritesAllWords => 'الإضافة من مجموعة';

  @override
  String get homeFavouritesPin => 'تثبيت في الرئيسية';

  @override
  String get homeFavouritesUnpin => 'إزالة من الرئيسية';

  @override
  String homeFavouritesFull(int count) {
    return 'الرئيسية ممتلئة ($count مفضلة). أزل واحدة لإضافة أخرى.';
  }

  @override
  String get editBoardTooltip => 'ترتيب اللوحة';

  @override
  String get editBoardTitle => 'ترتيب اللوحة';

  @override
  String get editBoardHint =>
      'اضغط على زر لنقله أو تثبيته أو استبداله. اسحب لإعادة الترتيب. يرى طفلك التخطيط الجديد عند مغادرتك.';

  @override
  String get editActionMove => 'نقل';

  @override
  String get editMoveHint => 'اضغط على المكان الذي تريد وضعه فيه';

  @override
  String get editActionPin => 'تثبيت في المفضلة';

  @override
  String get editActionUnpin => 'إزالة من المفضلة';

  @override
  String get editActionAddHere => 'أضف زرًا هنا';

  @override
  String get editResetBoard => 'إعادة ضبط هذه اللوحة';

  @override
  String get editResetAll => 'إعادة ضبط كل شيء';

  @override
  String get editResetBoardConfirm =>
      'هل تريد إعادة هذه اللوحة كما كانت؟ سيُلغى كل تغيير أجريته عليها (المربعات التي حرّكتها أو أخفيتها أو غيّرت صورتها أو أعدت تسجيلها أو أضفتها). لن تتأثر اللوحات الأخرى.';

  @override
  String get editResetAllConfirm =>
      'هل تريد إعادة جميع اللوحات كما كانت؟ ستُلغى جميع تغييراتك على كل اللوحات (المربعات المُحرَّكة والمُخفاة والمُغيَّرة صورتها والمُعاد تسجيلها والمُضافة).';

  @override
  String get editResetConfirmButton => 'إعادة ضبط';

  @override
  String get editDone => 'تم';

  @override
  String get editArrangeHint =>
      'اسحب زرًا لتحريكه. اضغط على زر للمزيد، أو اضغط تحديد لتغيير عدة أزرار معًا.';

  @override
  String get editSelectHint =>
      'اضغط على الأزرار لاختيارها ثم اختر إجراءً بالأسفل. تُطبّق التغييرات على كل الأزرار المختارة معًا.';

  @override
  String get editSelect => 'تحديد';

  @override
  String get editSelectTiles => 'تحديد الأزرار';

  @override
  String editSelectedCount(int count) {
    return '$count محدد';
  }

  @override
  String get editSelectAll => 'الكل';

  @override
  String get editSelectNone => 'لا شيء';

  @override
  String get editTileSheetSubtitle => 'اختر ما تريد تغييره';

  @override
  String get editActionRecordVoice => 'تسجيل صوت';

  @override
  String get editActionRerecordVoice => 'إعادة التسجيل';

  @override
  String get editActionRecordVoiceSub => 'استخدم صوتك';

  @override
  String get editActionVoiceSetSub => 'صوتك مضبوط';

  @override
  String get editActionReplacePicture => 'تغيير الصورة';

  @override
  String get editActionReplacePictureSub => 'اختر صورة';

  @override
  String get editActionPinSub => 'عرضه في مفضلة الصفحة الرئيسية';

  @override
  String get editActionHide => 'إخفاء من اللوحة';

  @override
  String get editActionHideSub => 'لن يراه طفلك';

  @override
  String get editActionShow => 'إظهار على اللوحة';

  @override
  String get editActionShowSub => 'يمكن لطفلك رؤيته مرة أخرى';

  @override
  String get editBatchHide => 'إخفاء';

  @override
  String get editBatchShow => 'إظهار';

  @override
  String editToastPinned(int count) {
    return 'تم تثبيت $count في المفضلة';
  }

  @override
  String editToastUnpinned(int count) {
    return 'تمت إزالة $count من المفضلة';
  }

  @override
  String editToastHidden(int count) {
    return 'تم إخفاء $count من اللوحة';
  }

  @override
  String editToastShown(int count) {
    return 'تم إظهار $count على اللوحة';
  }

  @override
  String get editToastPinnedOne => 'تم التثبيت في المفضلة';

  @override
  String get editToastUnpinnedOne => 'تمت الإزالة من المفضلة';

  @override
  String get editToastHiddenOne => 'تم الإخفاء من اللوحة';

  @override
  String get editToastShownOne => 'تم الإظهار على اللوحة';

  @override
  String get editToastPictureReplaced => 'تم تغيير الصورة';

  @override
  String get editToastVoiceSaved => 'تم حفظ الصوت';

  @override
  String get editToastVoiceDeleted =>
      'تم حذف التسجيل، يتم استخدام الصوت المدمج';

  @override
  String editVoiceTitle(String word) {
    return 'صوت لـ \"$word\"';
  }

  @override
  String get editVoiceOverrideSub => 'تسجيلك يحل محل الصوت الافتراضي';

  @override
  String editVoicePrompt(String word) {
    return 'اضغط على الميكروفون وقل \"$word\". سيُشغَّل تسجيلك بدلًا من الصوت المدمج لهذا الزر.';
  }

  @override
  String get editVoiceTapToRecord => 'اضغط للتسجيل';

  @override
  String editVoiceListening(String word) {
    return 'جارٍ الاستماع، قل \"$word\"';
  }

  @override
  String get editVoiceTapToStop => 'اضغط للإيقاف';

  @override
  String editVoiceReview(String word) {
    return 'هذا تسجيلك لـ \"$word\".';
  }

  @override
  String get editVoicePlay => 'تشغيل';

  @override
  String get editVoiceRerecord => 'إعادة التسجيل';

  @override
  String get editVoiceUseRecording => 'استخدام هذا التسجيل';

  @override
  String editVoiceSavedMsg(String word) {
    return 'صوتك مضبوط لـ \"$word\". يمكنك تشغيله أو إعادة تسجيله أو حذفه في أي وقت. حذفه يعيد الصوت المدمج.';
  }

  @override
  String get editVoiceDelete => 'حذف';

  @override
  String get editVoiceDone => 'تم';

  @override
  String get editVoiceMicDenied =>
      'الوصول إلى الميكروفون مغلق. فعّله من الإعدادات لتسجيل صوت.';

  @override
  String editFavouritesFull(int count) {
    return 'المفضلة ممتلئة (الحد الأقصى $count)';
  }

  @override
  String get editShareBoard => 'مشاركة هذه اللوحة';

  @override
  String get shareVocabTitle => 'مشاركة هذه المفردات؟';

  @override
  String get shareVocabBody =>
      'ستشارك الكلمات التي أنشأتها على هذه اللوحة. على الجهاز اللوحي الآخر تصل كلوحة جديدة منفصلة تبدأ التعلّم من الصفر؛ ولا تُدمج مع لوحتهم. لا تتم مشاركة أي شيء تلقائيًا.';

  @override
  String shareVocabPhotos(int count) {
    return 'يستخدم $count من الأزرار صورًا من هذا الجهاز اللوحي. ستتم مشاركتها ككلمات فقط؛ وتبقى الصور على جهازك.';
  }

  @override
  String get shareVocabConfirm => 'مشاركة';

  @override
  String get shareVocabFailed => 'تعذّر تجهيز هذه اللوحة للمشاركة.';

  @override
  String get otaTitle => 'البحث عن تحديثات';

  @override
  String get otaSettingsSubtitle =>
      'احصل على أحدث تصحيحات الكلمات والصور والأصوات';

  @override
  String get otaBody =>
      'يمكن لتطبيق Lighthouse التحقق من Kinder Horizon بحثًا عن تصحيحات للكلمات والترجمات والصور والأصوات. يتحقق فقط عندما تضغط على الزر أدناه، ولا يرسل أي شيء عنك أو عن طفلك.';

  @override
  String get otaCheckNow => 'تحقّق الآن';

  @override
  String get otaChecking => 'جارٍ التحقق...';

  @override
  String get otaUpToDate => 'أنت على آخر تحديث.';

  @override
  String get otaAvailable => 'تتوفّر تصحيحات.';

  @override
  String get otaApply => 'تطبيق';

  @override
  String get otaApplying => 'جارٍ التطبيق...';

  @override
  String get otaApplied => 'تم التطبيق.';

  @override
  String get otaShowNow => 'اعرض التحديث الآن';

  @override
  String get otaApplyFallback =>
      'أو سيكون جاهزًا في المرة القادمة التي تفتح فيها Lighthouse.';

  @override
  String get otaIncompatible =>
      'تتطلّب هذه التصحيحات إصدارًا أحدث من Lighthouse. يُرجى تحديث التطبيق.';

  @override
  String get otaError => 'تعذّر التحقق الآن. يُرجى المحاولة لاحقًا.';

  @override
  String get sectionFeedback => 'ملاحظات';

  @override
  String get feedbackTitle => 'إرسال ملاحظات';

  @override
  String get feedbackSettingsSubtitle => 'أبلغ عن خطأ أو اقترح تحسينًا';

  @override
  String get feedbackBody =>
      'أخبرنا بما لا يعمل أو بما قد يساعد. نقرأ كل رسالة.';

  @override
  String get feedbackCategoryLabel => 'عمّ تدور هذه الملاحظة؟';

  @override
  String get feedbackCategoryBug => 'خطأ';

  @override
  String get feedbackCategorySuggestion => 'اقتراح';

  @override
  String get feedbackCategoryOther => 'شيء آخر';

  @override
  String get feedbackMessageLabel => 'رسالتك';

  @override
  String get feedbackMessageHint => 'ماذا حدث، أو ما الذي قد يساعد؟';

  @override
  String get feedbackEmailLabel => 'بريدك الإلكتروني (اختياري)';

  @override
  String get feedbackEmailHint => 'فقط إذا كنت تريد ردًّا';

  @override
  String get feedbackPrivacyNote =>
      'نرسل رسالتك وإصدار التطبيق فقط. لا شيء عن طفلك أو لوحاتك أو كيفية استخدام التطبيق.';

  @override
  String get feedbackSend => 'إرسال';

  @override
  String get feedbackSending => 'جارٍ الإرسال...';

  @override
  String get feedbackErrorEmpty => 'يُرجى كتابة رسالة أولًا.';

  @override
  String get feedbackErrorEmail => 'هذا البريد الإلكتروني لا يبدو صحيحًا.';

  @override
  String get feedbackErrorNetwork =>
      'تعذّر الإرسال الآن. يُرجى المحاولة لاحقًا.';

  @override
  String get feedbackErrorTooLong => 'هذه الرسالة طويلة جدًا. يُرجى اختصارها.';

  @override
  String get sectionYourChildsBoard => 'لوحة طفلك';

  @override
  String get sectionHowAppBehaves => 'كيف يعمل التطبيق';

  @override
  String get sectionUpdatesSupport => 'التحديثات والدعم';

  @override
  String get crashLogsRowSubtitle => 'اطّلع على ما يمكن إرساله ثم أرسله';

  @override
  String get crashEmptyHeadline => 'لم يحدث أي خطأ';

  @override
  String get crashEmptyBody =>
      'لا توجد سجلات أعطال على هذا الجهاز، لذا لا يوجد ما يُرسل. إذا أُغلق التطبيق فجأة في أي وقت، سيظهر سجل هنا لمراجعته قبل إرساله.';

  @override
  String get glowStyleRing => 'حلقة داخلية';

  @override
  String get glowStyleLift => 'ارتفاع وتسطير';

  @override
  String get glowStyleDot => 'نقطة هادئة في الزاوية';

  @override
  String get glowStyleOff => 'إيقاف';

  @override
  String get showWordOnTile => 'إظهار الكلمة على كل زر';

  @override
  String get showWordOnTileSubtitle => 'أوقفه لعرض الصور فقط';

  @override
  String get showPictogramOnTile => 'إظهار الصورة على كل زر';

  @override
  String get showPictogramOnTileSubtitle => 'أوقفه لعرض الكلمات فقط';

  @override
  String get otaLastCheckedNever => 'آخر فحص: لم يحدث على هذا الجهاز.';

  @override
  String get otaCheckedJustNow => 'تم الفحص للتو';

  @override
  String get feedbackThanksTitle => 'شكرًا لك. رسالتك في طريقها إلينا.';

  @override
  String get feedbackThanksBody =>
      'يقرأ شخص حقيقي في Kinder Horizon كل رسالة. إذا تركت بريدًا إلكترونيًا، فسنرد عليك عندما نستطيع. يبني Lighthouse فريق صغير غير ربحي، وكلماتك تشكّل ما نُصلحه لاحقًا.';

  @override
  String get feedbackSendAnother => 'إرسال رسالة أخرى';

  @override
  String get feedbackBackToBoard => 'العودة إلى اللوحة';

  @override
  String get aboutLicence => 'مفتوح المصدر · رخصة MIT';

  @override
  String get aboutCredits => 'الرموز التصويرية';

  @override
  String get aboutLicences => 'تراخيص المصادر المفتوحة';

  @override
  String get aboutLicencesSubtitle =>
      'تراخيص الشيفرة والخطوط التي يستخدمها Lighthouse';

  @override
  String get tourSkip => 'تخطّي الجولة';

  @override
  String get tourFinish => 'إنهاء';

  @override
  String tourProgress(int current, int total) {
    return '$current من $total';
  }

  @override
  String get tourTakeQuick => 'ابدأ الجولة السريعة';

  @override
  String get tourSkipToBoard => 'تخطّي والذهاب إلى اللوحة';

  @override
  String get tourSettingsRowTitle => 'ابدأ الجولة';

  @override
  String get tourSettingsRowSubtitle => 'جولة إرشادية سريعة في التطبيق';

  @override
  String get tipEditorTitle => 'تحرير لوحتك';

  @override
  String get tipEditorBody =>
      'اضغط مطوّلاً واسحب زرًا لتحريكه، أو اضغط تحديد لتثبيت عدة أزرار في المفضلة أو إخفائها معًا.';

  @override
  String get tipGateTitle => 'تحقّق سريع للكبار';

  @override
  String get tipGateBody =>
      'أجب عن جمع بسيط للدخول. هو مطبّ لإبعاد الأيدي الصغيرة، وليس كلمة مرور.';

  @override
  String get tipButtonsTitle => 'أضف أزرارك الخاصة';

  @override
  String get tipButtonsBody =>
      'أنشئ أزرارًا للأشخاص والأطعمة والأماكن التي يحتاجها طفلك، كل زر بصورة وكلمة.';

  @override
  String get tipFavouritesTitle => 'مفضلة الصفحة الرئيسية';

  @override
  String get tipFavouritesBody =>
      'تقع الكلمات المثبّتة في صف أعلى اللوحة الرئيسية، فتكون الأكثر استخدامًا أسهل في الوصول.';

  @override
  String get tipAdvancedTitle => 'الإعدادات المتقدمة';

  @override
  String get tipAdvancedBody =>
      'تغيّر هذه الخيارات شكل اللوحة وسلوكها. لا تُمسّ كلمات طفلك أو تخطيطه هنا أبدًا.';

  @override
  String get tipGotIt => 'فهمت';

  @override
  String get tourBoardTitle => 'هذه لوحة طفلك';

  @override
  String get tourBoardBody =>
      'يضغط طفلك على هذه الأزرار ليتكلم. الأزرار لا تتحرك أبدًا، لذا يصبح التخطيط ذاكرة عضلية مع الوقت.';

  @override
  String get tourSentenceTitle => 'هنا تُبنى الجملة';

  @override
  String get tourSentenceBody =>
      'كل ضغطة تضيف كلمة إلى هذا الشريط. اضغط على مكبّر الصوت لنطق الجملة كاملة؛ استخدم مفتاح المسح للخلف أو المسح لتصحيحها.';

  @override
  String get tourGlowTitle => 'توهّج الكلمة التالية اللطيف';

  @override
  String get tourGlowBody =>
      'يشير توهّج كهرماني خفيف إلى الكلمات التي يُرجَّح أن يريدها طفلك تاليًا. يتغيّر التوهّج فقط، لا الأزرار، فتبقى في مكانها.';

  @override
  String get tourFoldersTitle => 'المجلدات تفتح لوحات فرعية';

  @override
  String get tourFoldersBody =>
      'المجلدات الملوّنة مثل الطعام أو الأشخاص تفتح لوحة أعمق بنفس التخطيط الهادئ، ثم تعيدك.';

  @override
  String get tourSettingsTitle => 'كل شيء للكبار';

  @override
  String get tourSettingsBody =>
      'يفتح الترس الإعدادات: الصوت واللغات والمفضلة وكيفية عمل التطبيق. كل إجراء يغيّر اللوحة يطرح أولاً سؤالاً سريعاً للكبار.';

  @override
  String get homeFavouritesPinnedNow => 'المثبّتة الآن';

  @override
  String get homeFavouritesEmpty =>
      'لا توجد كلمات مثبّتة بعد. أضف بعضها من مجموعة بالأسفل.';

  @override
  String get customButtonsEmptyHeadline => 'أنشئ زرًا لطفلك';

  @override
  String get customButtonsEmptyBody =>
      'أضف صورة وكلمة للأشخاص والأطعمة والأماكن التي يحتاجها طفلك أكثر. تنضم الأزرار الجديدة إلى اللوحة في مجموعة اللون الصحيحة.';

  @override
  String get customButtonsAddFirst => 'أضف زرّك الأول';

  @override
  String get onboardingStart => 'ابدأ استخدام Lighthouse';

  @override
  String get placeHomeSub => 'حيث تمضي معظم الأيام';

  @override
  String get placeSchoolSub => 'فصل دراسي أو غرفة علاج';

  @override
  String get placeBothSub => 'ينتقل مع طفلك';

  @override
  String get placeOtherSub => 'أخبرنا لاحقًا إن أردت';

  @override
  String get onboardingPrivacyHeadline => 'كل شيء يبقى على هذا الجهاز';

  @override
  String get onboardingPrivacyPoint1 => 'بلا حساب، بلا إعلانات، بلا تتبّع';

  @override
  String get onboardingPrivacyPoint2 => 'يعمل دون اتصال تمامًا';

  @override
  String get onboardingPrivacyPoint3 =>
      'مفتوح المصدر، حتى يتمكّن أي شخص من التحقّق';

  @override
  String get crashLogsSentCleared =>
      'تم إرسال سجلات الأعطال. وقد أُزيلت من هذا الجهاز.';

  @override
  String get exportBoardPack => 'تصدير هذه اللوحة';

  @override
  String get exportBoardPackSubtitle =>
      'شارك لوحتك كملف يمكن لجهاز آخر استيراده';

  @override
  String get tourColorsTitle => 'الألوان تجمع الكلمات';

  @override
  String get tourColorsBody =>
      'كل لون نوع من الكلمات: الأصفر للأشخاص والضمائر، الأخضر لكلمات الأفعال، البرتقالي للأشياء والطعام والأماكن، الأزرق للمشاعر ونعم أو لا، الوردي للكلمات الاجتماعية والاحتياجات العاجلة، البنفسجي للأسئلة والوقت.';

  @override
  String get tourArrangeTitle => 'رتّب اللوحة';

  @override
  String get tourArrangeBody =>
      'يتيح لك زر اللوحة تحريك المربعات أو إخفاءها أو إضافتها أو إعادة تسميتها، وتسجيل صوتك الخاص لأي مربع. يطرح أولاً سؤالاً سريعاً للكبار، حتى لا يتمكن طفلك من تغيير لوحته بنفسه.';

  @override
  String get recordVoiceOptional => 'سجّل صوتك الخاص (اختياري)';

  @override
  String get recordVoiceStop => 'إيقاف';

  @override
  String get recordVoiceRecorded => 'تم تسجيل الصوت';

  @override
  String get recordVoiceClear => 'إزالة التسجيل';
}
