// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get back => 'Atrás';

  @override
  String get skip => 'Omitir';

  @override
  String get next => 'Siguiente';

  @override
  String get done => 'Listo';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get settingsTooltip => 'Ajustes';

  @override
  String packNotLoaded(String folder) {
    return 'Paquete no cargado: $folder';
  }

  @override
  String get couldNotLoadBoard =>
      'No se pudo cargar el tablero predeterminado.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get followSystem => 'Seguir el sistema';

  @override
  String get sectionCrashLogs => 'Registros de errores';

  @override
  String get viewCrashLogs => 'Ver registros de errores';

  @override
  String get viewCrashLogsSubtitle =>
      'Mira exactamente qué se enviaría antes de enviarlo';

  @override
  String get shareCrashLogs => 'Enviar registros de errores';

  @override
  String get shareCrashLogsSubtitle =>
      'Abre tu app de correo para enviar los registros a KHF; tú tocas enviar';

  @override
  String get sectionBoards => 'Tableros';

  @override
  String get importBoardPack => 'Importar un tablero';

  @override
  String get importBoardPackSubtitle =>
      'Agrega un archivo de tablero JSON desde este dispositivo';

  @override
  String get sectionOnboarding => 'Introducción';

  @override
  String get rerunOnboarding => 'Repetir la bienvenida';

  @override
  String get rerunOnboardingSubtitle =>
      'Muestra de nuevo el flujo de primer inicio';

  @override
  String get sectionAdvanced => 'Avanzado';

  @override
  String get advancedSettings => 'Ajustes avanzados';

  @override
  String get advancedSettingsSubtitle =>
      'Voz, brillo, tamaño táctil, aprendizaje';

  @override
  String get sectionUpdates => 'Actualizaciones';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String get aboutLighthouse => 'Acerca de Lighthouse';

  @override
  String get aboutLighthouseSubtitle =>
      'Un proyecto gratuito de la Kinder Horizon Foundation';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get privacyPolicySubtitle =>
      'Cómo Lighthouse trata tus datos (se abre en el navegador)';

  @override
  String get couldNotOpenLink => 'No se pudo abrir el enlace.';

  @override
  String get noCrashLogsToShare => 'No hay registros de errores para enviar.';

  @override
  String get shareSubject => 'Registros de errores de Lighthouse AAC';

  @override
  String get crashEmailBody =>
      'Los registros de errores adjuntos son de Lighthouse AAC. Gracias por ayudarnos a solucionar el problema.';

  @override
  String get shareBody =>
      'Los registros de errores de Lighthouse AAC están adjuntos. Envíalos a bugs@kinderhorizon.org.';

  @override
  String get rerunOnboardingConfirmTitle => '¿Repetir la introducción?';

  @override
  String get rerunOnboardingConfirmBody =>
      'Verás de nuevo el flujo de primer inicio. El tablero y los patrones que ha aprendido tu hijo o hija no se ven afectados.';

  @override
  String get rerun => 'Repetir';

  @override
  String get couldNotReadFile => 'No se pudo leer el archivo seleccionado.';

  @override
  String importedBoard(String board) {
    return 'Se importó \"$board\".';
  }

  @override
  String couldNotImport(String error) {
    return 'No se pudo importar: $error';
  }

  @override
  String get advancedTitle => 'Avanzado';

  @override
  String get sectionVoice => 'Voz';

  @override
  String get sectionVisual => 'Cómo se ve el tablero';

  @override
  String get sectionLearning => 'Aprendizaje';

  @override
  String get resetLearnedState => 'Restablecer lo que Lighthouse ha aprendido';

  @override
  String get resetLearnedStateSubtitle =>
      'Borra los patrones de palabras de tu hijo. El tablero en sí no cambia.';

  @override
  String get resetLearnedStateConfirmTitle =>
      '¿Restablecer el estado aprendido?';

  @override
  String get resetLearnedStateConfirmBody =>
      'Esto borra de forma permanente las predicciones de brillo que tu hijo o hija ha acumulado. No se puede deshacer. El tablero, el idioma y los demás ajustes no se ven afectados.\n\nUsa esto al entregar el dispositivo a otro niño o niña, o si los brillos ya no coinciden con la forma en que tu hijo o hija se comunica.';

  @override
  String get erase => 'Borrar';

  @override
  String get learnedStateCleared => 'Estado aprendido restablecido.';

  @override
  String get couldNotClearLearnedState =>
      'No se pudo restablecer el estado aprendido. Inténtalo de nuevo.';

  @override
  String get voiceOutput => 'Salida de voz';

  @override
  String get ttsModeOn => 'Activada (hablar en cada toque)';

  @override
  String get ttsModeOnRequest => 'A petición (mantener pulsado para hablar)';

  @override
  String get ttsModeOff => 'Desactivada (sin voz sintetizada)';

  @override
  String get ttsModeAls => 'Mostrar la palabra grande, sin voz (ALS)';

  @override
  String get glowStyle => 'Estilo de brillo';

  @override
  String get glowStyleHalo => 'Halo suave';

  @override
  String get hitboxExpansion => 'Tamaño táctil';

  @override
  String get hitboxNone => 'Estándar';

  @override
  String get hitboxSubtle => 'Cómodo';

  @override
  String get hitboxMaximum => 'Grande';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutTagline =>
      'Un proyecto gratuito de la Kinder Horizon Foundation.';

  @override
  String get aboutBody =>
      'Lighthouse ayuda a comunicarse a los niños y niñas que no hablan. Es gratis, no tiene anuncios y mantiene en este dispositivo todo lo que hace tu hijo o hija.';

  @override
  String get visitWebsite => 'Visitar kinderhorizon.org';

  @override
  String get visitWebsiteSubtitle => 'Abre nuestro sitio web en tu navegador';

  @override
  String get couldNotOpenBrowser => 'No se pudo abrir el navegador.';

  @override
  String get version => 'Versión';

  @override
  String versionLabel(String version, String build) {
    return 'Versión $version ($build)';
  }

  @override
  String get mathGateError => 'No es correcto. Inténtalo de nuevo.';

  @override
  String get mathGateTitle => 'Comprobación rápida';

  @override
  String get mathGateBody =>
      'Estos ajustes pueden alterar el funcionamiento de la app para tu hijo o hija. Responde abajo para continuar.';

  @override
  String mathGateEquation(String a, String b) {
    return '$a + $b = ?';
  }

  @override
  String get mathGateAnswerLabel => 'Respuesta';

  @override
  String get crashLogsTitle => 'Registros de errores';

  @override
  String get noCrashLogsOnDevice =>
      'No hay registros de errores en este dispositivo. No hay nada que compartir.';

  @override
  String get onboardingGridTitle =>
      'Este es el tablero que verá tu hijo o hija.';

  @override
  String get onboardingGridBody =>
      'Toca cualquier casilla para oír cómo suena. Las casillas nunca se mueven; la distribución que tu hijo o hija aprende hoy será siempre la misma.';

  @override
  String get onboardingPlaceTitle => '¿Dónde usará tu hijo Lighthouse?';

  @override
  String get onboardingPlaceBody =>
      'Usamos esto para etiquetar el lugar que Lighthouse aprende primero. No cambia el comportamiento de la app; puedes omitirlo.';

  @override
  String get onboardingWifiTitle => 'Aprende palabras para cada lugar';

  @override
  String get onboardingWifiBody =>
      'Lighthouse puede usar el nombre de tu red Wi-Fi, cifrado en este dispositivo, para aprender qué palabras necesita tu hijo o hija en distintos lugares, como casa y la escuela. El nombre nunca sale de la tableta, y esto es opcional.';

  @override
  String get onboardingWifiAllow => 'Permitir';

  @override
  String get onboardingWifiGranted =>
      'Activado. Lighthouse aprenderá palabras para cada lugar.';

  @override
  String get onboardingWifiDenied =>
      'Ahora no. Puedes activarlo más tarde en Ajustes.';

  @override
  String get placeHome => 'Casa';

  @override
  String get placeSchool => 'Escuela';

  @override
  String get placeBoth => 'Casa y escuela';

  @override
  String get placeOther => 'En otro lugar';

  @override
  String get privacyTitle => 'Privacidad';

  @override
  String get privacyTooltip => 'Cómo sabemos que esto es cierto';

  @override
  String get privacyBody =>
      'Lo que acabas de contarnos, y todo lo que tu hijo toque después, se queda aquí. Lighthouse no tiene cuenta y nunca envía las palabras de tu hijo a ningún sitio.';

  @override
  String get howWeKnowTitle => 'Cómo lo sabemos';

  @override
  String get howWeKnowBody1 =>
      'Lighthouse no se conecta a ninguna nube. No hay ningún SDK de analítica en la app. No hay informes de errores automáticos. Los datos solo salen del dispositivo cuando tú decides enviarlos: si tocas \"Enviar registros de errores\", que abre tu propia app de correo ya dirigida a nosotros para que revises y toques enviar, o si compartes un tablero de vocabulario con otra familia, donde tú eliges el destino. Tú mantienes el control en ambos casos; nada se envía automáticamente.';

  @override
  String get howWeKnowBody2 =>
      'Puedes verificarlo en la pantalla de Ajustes, que te permite ver el contenido exacto del registro de errores antes de enviarlo. Un registro de errores incluye el modelo del dispositivo, la versión del sistema y un informe técnico del error (el tipo de error, su mensaje y la traza de código). La app está diseñada para no registrar las palabras que toca tu hijo o hija ni el contenido de tus tableros, y como tú revisas cada registro y decides si enviarlo, mantienes el control de lo que sale del dispositivo.';

  @override
  String get howWeKnowUpdates =>
      'Si tocas «Buscar actualizaciones», la app envía solo su número de versión para preguntar si hay correcciones de palabras, imágenes o sonidos disponibles. No envía nada sobre tu hijo o hija ni sobre cómo se usa la app.';

  @override
  String get howWeKnowFeedback =>
      'Si tocas «Enviar comentarios», la app envía solo el mensaje que escribes, además de la versión de la app y del sistema. El mensaje no se almacena y no incluye nada sobre tu hijo o hija ni sobre tus tableros.';

  @override
  String get sectionNavigation => 'Desplazarse';

  @override
  String get autoReturnToHome => 'Volver al inicio tras una palabra';

  @override
  String get autoReturnToHomeSubtitle =>
      'Tras una palabra dentro de una carpeta, vuelve al tablero de inicio';

  @override
  String get hideTileText => 'Ocultar el texto de las casillas';

  @override
  String get hideTileTextSubtitle =>
      'Mostrar solo los pictogramas, sin la palabra debajo de cada casilla';

  @override
  String get sentenceBarLabel => 'Frase';

  @override
  String get sentenceBarHint => 'Toca palabras para formar una frase';

  @override
  String get boardScrollHint => 'más palabras';

  @override
  String get sentenceSpeak => 'Decir la frase';

  @override
  String get sentenceBackspace => 'Borrar la última palabra';

  @override
  String get sentenceClear => 'Borrar la frase';

  @override
  String get customButtonsTitle => 'Tus propios botones';

  @override
  String get customButtonsSubtitle =>
      'Añade imágenes y palabras que tu hijo necesita';

  @override
  String get imageRejected =>
      'Esa imagen es demasiado grande o no es de un tipo compatible. Elige una foto más pequeña.';

  @override
  String get customButtonsAdd => 'Añadir un botón';

  @override
  String get customButtonsBoardLabel => 'Tablero';

  @override
  String get customButtonsWordLabel => 'Palabra';

  @override
  String get customButtonsChoosePhoto => 'Elegir foto';

  @override
  String get customButtonsNoFreeSlots =>
      'Este tablero está lleno. Elige otro tablero.';

  @override
  String get customButtonsDelete => 'Eliminar botón';

  @override
  String get customButtonsSave => 'Guardar';

  @override
  String get homeFavouritesTitle => 'Favoritos del inicio';

  @override
  String get homeFavouritesSubtitle =>
      'Fija en la página de inicio las palabras que tu hijo usa más';

  @override
  String get homeFavouritesIntro =>
      'Las palabras fijadas aparecen en una fila en la página de inicio, siempre en el mismo lugar.';

  @override
  String get homeFavouritesSuggested => 'Usadas a menudo';

  @override
  String get homeFavouritesAllWords => 'Añadir desde un grupo';

  @override
  String get homeFavouritesPin => 'Fijar en inicio';

  @override
  String get homeFavouritesUnpin => 'Quitar de inicio';

  @override
  String homeFavouritesFull(int count) {
    return 'El inicio está lleno ($count favoritos). Quita uno para añadir otro.';
  }

  @override
  String get editBoardTooltip => 'Organizar el tablero';

  @override
  String get editBoardTitle => 'Organizar el tablero';

  @override
  String get editBoardHint =>
      'Toca un botón para moverlo, fijarlo o reemplazarlo. Arrastra para reordenar. Tu hijo verá el nuevo diseño cuando salgas.';

  @override
  String get editActionMove => 'Mover';

  @override
  String get editMoveHint => 'Toca dónde colocarlo';

  @override
  String get editActionPin => 'Fijar en favoritos';

  @override
  String get editActionUnpin => 'Quitar de favoritos';

  @override
  String get editActionAddHere => 'Añadir un botón aquí';

  @override
  String get editResetBoard => 'Restablecer este tablero';

  @override
  String get editResetAll => 'Restablecer todo';

  @override
  String get editResetBoardConfirm =>
      '¿Dejar este tablero como estaba al principio? Se deshará cada cambio que hiciste en él (casillas que moviste, ocultaste, cambiaste de imagen, regrabaste o añadiste). Los demás tableros no se ven afectados.';

  @override
  String get editResetAllConfirm =>
      '¿Dejar todos los tableros como estaban al principio? Se desharán todos tus cambios en todos los tableros (casillas movidas, ocultadas, con otra imagen, regrabadas y añadidas).';

  @override
  String get editResetConfirmButton => 'Restablecer';

  @override
  String get editDone => 'Hecho';

  @override
  String get editArrangeHint =>
      'Arrastra una casilla para moverla. Toca una casilla para más opciones, o toca Seleccionar para cambiar varias a la vez.';

  @override
  String get editSelectHint =>
      'Toca las casillas para elegirlas y luego elige una acción abajo. Los cambios se aplican a todas las casillas elegidas a la vez.';

  @override
  String get editSelect => 'Seleccionar';

  @override
  String get editSelectTiles => 'Seleccionar casillas';

  @override
  String editSelectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String get editSelectAll => 'Todas';

  @override
  String get editSelectNone => 'Ninguna';

  @override
  String get editTileSheetSubtitle => 'Elige qué cambiar';

  @override
  String get editActionRecordVoice => 'Grabar voz';

  @override
  String get editActionRerecordVoice => 'Volver a grabar';

  @override
  String get editActionRecordVoiceSub => 'Usa tu propia voz';

  @override
  String get editActionVoiceSetSub => 'Tu voz está configurada';

  @override
  String get editActionReplacePicture => 'Cambiar imagen';

  @override
  String get editActionReplacePictureSub => 'Elige una foto';

  @override
  String get editActionPinSub => 'Mostrar en favoritos de inicio';

  @override
  String get editActionHide => 'Ocultar del tablero';

  @override
  String get editActionHideSub => 'Tu hijo no la verá';

  @override
  String get editActionShow => 'Mostrar en el tablero';

  @override
  String get editActionShowSub => 'Tu hijo podrá verla de nuevo';

  @override
  String get editBatchHide => 'Ocultar';

  @override
  String get editBatchShow => 'Mostrar';

  @override
  String editToastPinned(int count) {
    return '$count fijadas en favoritos';
  }

  @override
  String editToastUnpinned(int count) {
    return '$count quitadas de favoritos';
  }

  @override
  String editToastHidden(int count) {
    return '$count ocultas del tablero';
  }

  @override
  String editToastShown(int count) {
    return '$count mostradas en el tablero';
  }

  @override
  String get editToastPinnedOne => 'Fijada en favoritos';

  @override
  String get editToastUnpinnedOne => 'Quitada de favoritos';

  @override
  String get editToastHiddenOne => 'Oculta del tablero';

  @override
  String get editToastShownOne => 'Mostrada en el tablero';

  @override
  String get editToastPictureReplaced => 'Imagen cambiada';

  @override
  String get editToastVoiceSaved => 'Voz guardada';

  @override
  String get editToastVoiceDeleted =>
      'Grabación eliminada, usando la voz integrada';

  @override
  String editVoiceTitle(String word) {
    return 'Voz para \"$word\"';
  }

  @override
  String get editVoiceOverrideSub => 'Tu grabación reemplaza la predeterminada';

  @override
  String editVoicePrompt(String word) {
    return 'Toca el micrófono y di \"$word\". Tu grabación se reproducirá en lugar de la voz integrada para esta casilla.';
  }

  @override
  String get editVoiceTapToRecord => 'Toca para grabar';

  @override
  String editVoiceListening(String word) {
    return 'Escuchando, di \"$word\"';
  }

  @override
  String get editVoiceTapToStop => 'Toca para detener';

  @override
  String editVoiceReview(String word) {
    return 'Aquí está tu grabación para \"$word\".';
  }

  @override
  String get editVoicePlay => 'Reproducir';

  @override
  String get editVoiceRerecord => 'Volver a grabar';

  @override
  String get editVoiceUseRecording => 'Usar esta grabación';

  @override
  String editVoiceSavedMsg(String word) {
    return 'Tu voz está configurada para \"$word\". Puedes reproducirla, volver a grabarla o eliminarla en cualquier momento. Al eliminarla, vuelve la voz integrada.';
  }

  @override
  String get editVoiceDelete => 'Eliminar';

  @override
  String get editVoiceDone => 'Listo';

  @override
  String get editVoiceMicDenied =>
      'El acceso al micrófono está desactivado. Actívalo en Ajustes para grabar una voz.';

  @override
  String editFavouritesFull(int count) {
    return 'Favoritos está lleno (máx. $count)';
  }

  @override
  String get editShareBoard => 'Compartir este tablero';

  @override
  String get shareVocabTitle => '¿Compartir este vocabulario?';

  @override
  String get shareVocabBody =>
      'Compartirás las palabras que creaste en este tablero. En la otra tableta llega como un tablero nuevo e independiente que empieza a aprender desde cero; no se combina con el tablero de la otra persona. Nada se comparte automáticamente.';

  @override
  String shareVocabPhotos(int count) {
    return '$count botones usan fotos de esta tableta. Se compartirán solo como palabras; las fotos se quedan en tu dispositivo.';
  }

  @override
  String get shareVocabConfirm => 'Compartir';

  @override
  String get shareVocabFailed =>
      'No se pudo preparar este tablero para compartir.';

  @override
  String get otaTitle => 'Buscar actualizaciones';

  @override
  String get otaSettingsSubtitle =>
      'Obtén las últimas correcciones de palabras, imágenes y sonidos';

  @override
  String get otaBody =>
      'Lighthouse puede consultar a Kinder Horizon si hay correcciones de palabras, traducciones, imágenes y sonidos. Solo consulta cuando tocas el botón de abajo, y no envía nada sobre ti ni sobre tu hijo o hija.';

  @override
  String get otaCheckNow => 'Buscar ahora';

  @override
  String get otaChecking => 'Buscando...';

  @override
  String get otaUpToDate => 'Ya está todo actualizado.';

  @override
  String get otaAvailable => 'Hay correcciones disponibles.';

  @override
  String get otaApply => 'Aplicar';

  @override
  String get otaApplying => 'Aplicando...';

  @override
  String get otaApplied => 'Aplicado.';

  @override
  String get otaShowNow => 'Mostrar la actualización ahora';

  @override
  String get otaApplyFallback =>
      'O estará lista la próxima vez que abras Lighthouse.';

  @override
  String get otaIncompatible =>
      'Estas correcciones necesitan una versión más reciente de Lighthouse. Actualiza la app.';

  @override
  String get otaError =>
      'No se pudo buscar ahora mismo. Inténtalo de nuevo más tarde.';

  @override
  String get sectionFeedback => 'Comentarios';

  @override
  String get feedbackTitle => 'Enviar comentarios';

  @override
  String get feedbackSettingsSubtitle =>
      'Informa de un error o sugiere una mejora';

  @override
  String get feedbackBody =>
      'Cuéntanos qué no funciona o qué ayudaría. Leemos todos los mensajes.';

  @override
  String get feedbackCategoryLabel => '¿De qué se trata?';

  @override
  String get feedbackCategoryBug => 'Un error';

  @override
  String get feedbackCategorySuggestion => 'Una sugerencia';

  @override
  String get feedbackCategoryOther => 'Otra cosa';

  @override
  String get feedbackMessageLabel => 'Tu mensaje';

  @override
  String get feedbackMessageHint => '¿Qué pasó o qué ayudaría?';

  @override
  String get feedbackEmailLabel => 'Tu correo (opcional)';

  @override
  String get feedbackEmailHint => 'Solo si quieres una respuesta';

  @override
  String get feedbackPrivacyNote =>
      'Enviamos solo tu mensaje y la versión de la app. Nada sobre tu hijo, tus tableros ni cómo se usa la app.';

  @override
  String get feedbackSend => 'Enviar';

  @override
  String get feedbackSending => 'Enviando...';

  @override
  String get feedbackErrorEmpty => 'Escribe un mensaje primero.';

  @override
  String get feedbackErrorEmail => 'Ese correo no parece correcto.';

  @override
  String get feedbackErrorNetwork =>
      'No se pudo enviar ahora mismo. Inténtalo de nuevo más tarde.';

  @override
  String get feedbackErrorTooLong =>
      'Ese mensaje es demasiado largo. Acórtalo, por favor.';

  @override
  String get sectionYourChildsBoard => 'El tablero de tu hijo';

  @override
  String get sectionHowAppBehaves => 'Cómo se comporta la app';

  @override
  String get sectionUpdatesSupport => 'Novedades y ayuda';

  @override
  String get crashLogsRowSubtitle =>
      'Mira qué se podría enviar y luego envíalo';

  @override
  String get crashEmptyHeadline => 'No ha ocurrido ningún error';

  @override
  String get crashEmptyBody =>
      'No hay registros de errores en este dispositivo, así que no hay nada que enviar. Si la app se cierra de forma inesperada, aquí aparecerá un registro para que lo revises antes de enviarlo.';

  @override
  String get glowStyleRing => 'Anillo interior';

  @override
  String get glowStyleLift => 'Elevación y subrayado';

  @override
  String get glowStyleDot => 'Punto discreto en la esquina';

  @override
  String get glowStyleOff => 'Desactivado';

  @override
  String get showWordOnTile => 'Mostrar la palabra en cada casilla';

  @override
  String get showWordOnTileSubtitle => 'Desactívalo para mostrar solo imágenes';

  @override
  String get showPictogramOnTile => 'Mostrar la imagen en cada casilla';

  @override
  String get showPictogramOnTileSubtitle =>
      'Desactívalo para mostrar solo palabras';

  @override
  String get otaLastCheckedNever =>
      'Última comprobación: nunca en este dispositivo.';

  @override
  String get otaCheckedJustNow => 'Comprobado ahora mismo';

  @override
  String get feedbackThanksTitle => 'Gracias. Tu mensaje va en camino.';

  @override
  String get feedbackThanksBody =>
      'Una persona real de Kinder Horizon lee cada mensaje. Si dejaste un correo, te responderemos cuando podamos. Lighthouse lo crea un pequeño equipo sin fines de lucro, y tus palabras dan forma a lo que mejoramos.';

  @override
  String get feedbackSendAnother => 'Enviar otro';

  @override
  String get feedbackBackToBoard => 'Volver al tablero';

  @override
  String get aboutLicence => 'Código abierto · licencia MIT';

  @override
  String get aboutCredits => 'Símbolos pictográficos';

  @override
  String get aboutLicences => 'Licencias de código abierto';

  @override
  String get aboutLicencesSubtitle =>
      'Licencias del código y las fuentes que usa Lighthouse';

  @override
  String get tourSkip => 'Saltar el recorrido';

  @override
  String get tourFinish => 'Finalizar';

  @override
  String tourProgress(int current, int total) {
    return '$current de $total';
  }

  @override
  String get tourTakeQuick => 'Hacer el recorrido rápido';

  @override
  String get tourSkipToBoard => 'Omitir, ir al tablero';

  @override
  String get tourSettingsRowTitle => 'Hacer el recorrido';

  @override
  String get tourSettingsRowSubtitle => 'Un recorrido guiado rápido por la app';

  @override
  String get tipEditorTitle => 'Editar tu tablero';

  @override
  String get tipEditorBody =>
      'Mantén pulsada y arrastra una casilla para moverla, o toca Seleccionar para fijar como favorita u ocultar varias a la vez.';

  @override
  String get tipGateTitle => 'Una comprobación rápida para adultos';

  @override
  String get tipGateBody =>
      'Responde una suma sencilla para entrar. Es un freno para mantener alejadas las manos pequeñas, no una contraseña.';

  @override
  String get tipButtonsTitle => 'Añade tus propios botones';

  @override
  String get tipButtonsBody =>
      'Crea casillas para las personas, comidas y lugares que tu hijo necesita, cada una con una foto y una palabra.';

  @override
  String get tipFavouritesTitle => 'Favoritos de inicio';

  @override
  String get tipFavouritesBody =>
      'Las palabras fijadas se sitúan en una fila en la parte superior del tablero de inicio, así las más usadas son las más fáciles de encontrar.';

  @override
  String get tipAdvancedTitle => 'Ajustes avanzados';

  @override
  String get tipAdvancedBody =>
      'Estas opciones cambian cómo se ve y se comporta el tablero. Las palabras y la disposición de tu hijo nunca se tocan aquí.';

  @override
  String get tipGotIt => 'Entendido';

  @override
  String get tourBoardTitle => 'Este es el tablero de tu hijo';

  @override
  String get tourBoardBody =>
      'Tu hijo toca estas casillas para hablar. Las casillas nunca se mueven, así que la disposición se vuelve memoria muscular con el tiempo.';

  @override
  String get tourSentenceTitle => 'Aquí se forman las frases';

  @override
  String get tourSentenceBody =>
      'Cada toque añade una palabra a esta barra. Toca el altavoz para decir la frase completa en voz alta; usa retroceso o borrar para corregirla.';

  @override
  String get tourGlowTitle => 'El suave brillo de la siguiente palabra';

  @override
  String get tourGlowBody =>
      'Un suave brillo ámbar señala las palabras que tu hijo probablemente querrá a continuación. Solo cambia el brillo, nunca las casillas, así que permanecen en su sitio.';

  @override
  String get tourFoldersTitle => 'Las carpetas abren subtableros';

  @override
  String get tourFoldersBody =>
      'Las carpetas de colores como Comida o Personas abren un tablero más profundo con la misma disposición tranquila, y luego te traen de vuelta.';

  @override
  String get tourSettingsTitle => 'Todo para los adultos';

  @override
  String get tourSettingsBody =>
      'El engranaje abre los Ajustes: la voz, los idiomas, los favoritos y el comportamiento de la app. Cada acción que cambia el tablero hace primero una pregunta rápida para adultos.';

  @override
  String get homeFavouritesPinnedNow => 'Fijadas ahora';

  @override
  String get homeFavouritesEmpty =>
      'Aún no hay palabras fijadas. Añade algunas desde un grupo de abajo.';

  @override
  String get customButtonsEmptyHeadline => 'Crea un botón para tu hijo';

  @override
  String get customButtonsEmptyBody =>
      'Añade una foto y una palabra para las personas, comidas y lugares que tu hijo más necesita. Los botones nuevos se unen al tablero en el grupo de color correcto.';

  @override
  String get customButtonsAddFirst => 'Añade tu primer botón';

  @override
  String get onboardingStart => 'Empezar a usar Lighthouse';

  @override
  String get placeHomeSub => 'Donde transcurre la mayoría de los días';

  @override
  String get placeSchoolSub => 'Un aula o sala de terapia';

  @override
  String get placeBothSub => 'Se mueve con tu hijo';

  @override
  String get placeOtherSub => 'Cuéntanoslo más tarde si quieres';

  @override
  String get onboardingPrivacyHeadline => 'Todo se queda en este dispositivo';

  @override
  String get onboardingPrivacyPoint1 => 'Sin cuenta, sin anuncios, sin rastreo';

  @override
  String get onboardingPrivacyPoint2 => 'Funciona totalmente sin conexión';

  @override
  String get onboardingPrivacyPoint3 =>
      'Código abierto, para que cualquiera pueda comprobarlo';

  @override
  String get crashLogsSentCleared =>
      'Registros de errores enviados. Se han eliminado de este dispositivo.';

  @override
  String get exportBoardPack => 'Exportar este tablero';

  @override
  String get exportBoardPackSubtitle =>
      'Comparte tu tablero como un archivo que otro dispositivo puede importar';

  @override
  String get tourColorsTitle => 'Los colores agrupan las palabras';

  @override
  String get tourColorsBody =>
      'Cada color es un tipo de palabra: amarillo para personas y pronombres, verde para palabras de acción, naranja para cosas, comida y lugares, azul para sentimientos y sí o no, rosa para palabras sociales y necesidades urgentes, morado para preguntas y tiempo.';

  @override
  String get tourArrangeTitle => 'Organiza el tablero';

  @override
  String get tourArrangeBody =>
      'El botón del tablero te permite mover, ocultar, añadir o renombrar casillas, y grabar tu propia voz para cualquier casilla. Primero hace una pregunta rápida para adultos, para que tu hijo no pueda cambiar su propio tablero.';

  @override
  String get recordVoiceOptional => 'Graba tu propia voz (opcional)';

  @override
  String get recordVoiceStop => 'Detener';

  @override
  String get recordVoiceRecorded => 'Voz grabada';

  @override
  String get recordVoiceClear => 'Quitar grabación';
}
