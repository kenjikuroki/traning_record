// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'T-Training Record';

  @override
  String get calendar => 'calendario';

  @override
  String get graph => 'gráfico';

  @override
  String get favorites => 'favoritos';

  @override
  String get favoritesNew => 'Favoritos (Nuevo)';

  @override
  String get recordScreenTitle => 'Registro';

  @override
  String get calendarScreenTitle => 'Calendario';

  @override
  String get settingsScreenTitle => 'Ajustes';

  @override
  String get graphScreenTitle => 'Gráfico';

  @override
  String get albumTitle => 'Álbum';

  @override
  String get albumFilterAll => 'Todos';

  @override
  String get albumFilterAwards => 'Premios';

  @override
  String get albumAwardRibbon => 'AWARD';

  @override
  String get start => 'Iniciar';

  @override
  String get pause => 'Pausar';

  @override
  String get reset => 'Reiniciar';

  @override
  String get saved => 'Guardado';

  @override
  String get save => 'Guardar';

  @override
  String get discard => 'Descartar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get resume => 'Reanudar';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get cameraPermissionRequired => 'Habilita el permiso de la cámara';

  @override
  String get stopwatch => 'Cronómetro';

  @override
  String get timer => 'Temporizador';

  @override
  String get timerTime => 'Duración del temporizador';

  @override
  String get tapNumberToEdit => 'Toca los números para editar';

  @override
  String targetFmt(Object hint, Object time) {
    return 'Objetivo $time ($hint)';
  }

  @override
  String get statusRunning => 'En curso';

  @override
  String get statusIdle => 'En espera';

  @override
  String hours(Object hours) {
    return '${hours}h';
  }

  @override
  String get kg => 'kg';

  @override
  String get lbs => 'lb';

  @override
  String get unit => 'unidad';

  @override
  String get unitTitle => 'Unidad';

  @override
  String get weightUnit => 'Peso';

  @override
  String get min => 'min';

  @override
  String get sec => 'seg';

  @override
  String get minutes => 'min';

  @override
  String get minutesHint => 'Min';

  @override
  String get secondsHint => 'Seg';

  @override
  String get sets => 'series';

  @override
  String get setLabel => 'Set';

  @override
  String get reps => 'Rep.';

  @override
  String get distance => 'distancia';

  @override
  String get km => 'km';

  @override
  String get m => 'm';

  @override
  String get pace => 'Ritmo';

  @override
  String get perDayUnit => 'fotos/día';

  @override
  String get trainingParts => 'Partes del entrenamiento';

  @override
  String get selectTrainingPart => 'Selecciona la parte del cuerpo';

  @override
  String get selectPartPlaceholder => 'Selecciona la parte';

  @override
  String get aerobicExercise => 'Ejercicio aeróbico';

  @override
  String get arm => 'Brazo';

  @override
  String get chest => 'Pecho';

  @override
  String get back => 'Espalda';

  @override
  String get shoulder => 'Hombro';

  @override
  String get leg => 'Pierna';

  @override
  String get abs => 'Abdominales';

  @override
  String get bodyWeightTraining => 'Peso corporal';

  @override
  String get fullBody => 'Cuerpo completo';

  @override
  String get other1 => 'Otro 1';

  @override
  String get other2 => 'Otro 2';

  @override
  String get other3 => 'Otro 3';

  @override
  String get exercise => 'Ejercicio';

  @override
  String get selectExercise => 'Selecciona el ejercicio';

  @override
  String get menuName => 'Nombre del ejercicio';

  @override
  String get menuNameHint => 'Introduce el nombre del ejercicio';

  @override
  String get addExercisePlaceholder => 'Selecciona el ejercicio';

  @override
  String get addExercise => '+ Ejercicio';

  @override
  String get addNewExercise => '+ Nuevo';

  @override
  String get customExerciseDialogTitle => 'Añadir ejercicio nuevo';

  @override
  String get customExerciseNameHint => 'Introduce el nombre del ejercicio';

  @override
  String get customExerciseNameRequired => 'Introduce un nombre de ejercicio';

  @override
  String get customExerciseDuplicate => 'Este ejercicio ya está registrado';

  @override
  String get customExercisePickerEmpty => 'No hay ejercicios guardados. Pulsa + para añadir uno.';

  @override
  String get open => 'Abrir';

  @override
  String get removeCustomExercises => 'Eliminar ejercicios añadidos';

  @override
  String get customExerciseRemovalHint => 'Elimina los ejercicios personalizados que añadiste.';

  @override
  String get keepScreenOn => 'Mantener la pantalla encendida';

  @override
  String get keepScreenOnHint => 'Si está activado, la pantalla no se apagará mientras la app esté abierta.';

  @override
  String get calendarSettingTitle => 'Integración con calendario';

  @override
  String get calendarSettingCurrentLabel => 'Calendario a usar';

  @override
  String get calendarSettingNotSelected => 'Sin seleccionar';

  @override
  String get calendarSettingHint => 'Los registros de entrenamiento se añadirán al calendario seleccionado aquí.';

  @override
  String calendarEventTitle(Object part) {
    return '$part';
  }

  @override
  String get noCustomExercises => 'No hay ejercicios personalizados añadidos.';

  @override
  String get selectExerciseToDelete => 'Selecciona el ejercicio a eliminar';

  @override
  String customExerciseRemoved(Object exerciseName) {
    return 'Se eliminó $exerciseName.';
  }

  @override
  String get addMenu => 'Añadir ejercicio';

  @override
  String get addSet => '+ Serie';

  @override
  String get openAddMenu => 'Abrir menú de añadido';

  @override
  String get partAlreadySelected => 'Esta parte ya está seleccionada.';

  @override
  String get setCount => 'Número de series';

  @override
  String get defaultSets => 'Series predeterminadas';

  @override
  String get bodyWeight => 'Peso corporal';

  @override
  String get trainingLocation => 'Lugar de entrenamiento';

  @override
  String get trainingTime => 'Tiempo de entrenamiento';

  @override
  String get startTime => 'Hora de inicio';

  @override
  String get endTime => 'Hora de finalización';

  @override
  String get calendarShareTooltip => 'Compartir al calendario';

  @override
  String get calendarExportSuccess => 'Se ha añadido al calendario.';

  @override
  String get calendarExportError => 'No se pudo añadir al calendario.';

  @override
  String get calendarExportPermissionRequired => 'Permite el acceso al calendario.';

  @override
  String get calendarExportNeedTime => 'Configura la hora de entrenamiento.';

  @override
  String get calendarExportNoWritableCalendar => 'No se encontró ningún calendario editable.';

  @override
  String get calendarSelectTitle => 'Seleccionar calendario';

  @override
  String get calendarPrimaryLabel => 'Calendario principal';

  @override
  String get weightCardTitle => 'Peso';

  @override
  String get weightCardExtraFieldsHint => 'Puedes añadir campos como grasa corporal o cintura desde Configuración. También puedes cambiar las unidades de peso (kg/lbs) desde Configuración.';

  @override
  String get bodyWeightTracking => 'Seguimiento de peso corporal';

  @override
  String get durationHint => 'min:seg';

  @override
  String get distanceHint => 'Introduce la distancia';

  @override
  String get noRecordMessage => 'No se encontraron registros para la fecha seleccionada.';

  @override
  String get coachBubbleSemantic => 'Sugerencia';

  @override
  String get hintRecordSelectPart => 'Selecciona la parte del cuerpo que entrenarás.';

  @override
  String get hintRecordExerciseField => 'Introduce aquí el nombre del ejercicio.';

  @override
  String get hintRecordAddExercise => 'Toca aquí para añadir el ejercicio.';

  @override
  String get hintRecordChangePart => 'Aquí puedes añadir otra parte del cuerpo.';

  @override
  String get hintRecordOpenSettings => 'Puedes cambiar las series predeterminadas en Ajustes.';

  @override
  String get hintRecordFab => 'Desde aquí añade parte, ejercicio, foto o nota.';

  @override
  String get hintCalendarTapDate => 'Selecciona una fecha para registrar.';

  @override
  String get hintGraphFavorite => 'Añade datos frecuentes a Favoritos.';

  @override
  String get hintGraphChartArea => 'El gráfico de tus registros aparecerá aquí.';

  @override
  String get hintGraphSelectPart => 'Selecciona parte del cuerpo y ejercicio.';

  @override
  String get discardLongPressLabel => 'Descartar (mantén pulsado)';

  @override
  String get dayDisplay => 'D';

  @override
  String get weekDisplay => 'Sem';

  @override
  String get monthDisplay => 'Mes';

  @override
  String get noGraphData => 'Selecciona parte/exercicio o peso para mostrar el gráfico.';

  @override
  String favorited(Object menuName) {
    return '$menuName añadido a favoritos';
  }

  @override
  String unfavorited(Object menuName) {
    return '$menuName eliminado de favoritos';
  }

  @override
  String get addPhoto => '+ Foto';

  @override
  String get dialogAddPhotoTitle => 'Añadir foto';

  @override
  String get actionTakePhoto => 'Tomar foto';

  @override
  String get progressSnaps => 'Fotos de progreso';

  @override
  String get mediaReachedDailyCap => 'Has alcanzado el límite diario de guardado.';

  @override
  String get mediaGoToAlbum => 'Ir al álbum';

  @override
  String get mediaGoToSettings => 'Ir a Ajustes';

  @override
  String get mediaDelete => 'Eliminar';

  @override
  String get mediaCancel => 'Cancelar';

  @override
  String get mediaUndo => 'Deshacer';

  @override
  String get photoLoadFailed => 'No se pudo cargar la imagen';

  @override
  String get discardPhotoConfirmTitle => '¿Descartar esta foto?';

  @override
  String get settings => 'Ajustes';

  @override
  String get themeMode => 'Modo de tema';

  @override
  String get themeTitle => 'Tema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get useDarkMode => 'modo oscuro';

  @override
  String get selectBodyParts => 'Selecciona las partes a mostrar';

  @override
  String get changeSetCount => 'Cambiar número de series';

  @override
  String get settingsStopwatchTimerVisibility => 'Mostrar cronómetro/temporizador';

  @override
  String get intervalTimer => 'Temporizador de intervalos';

  @override
  String get settingsDailyMediaCap => 'Límite diario de fotos';

  @override
  String get settingsDailyMediaCapDesc => 'Máximo de fotos que puedes guardar por día';

  @override
  String get settingsDailyMediaCapShort => 'Límite de fotos';

  @override
  String get recordDisplayOptions => 'Opciones de visualización';

  @override
  String get background => 'Fondo';

  @override
  String get none => 'Ninguno';

  @override
  String get limitOff => 'Sin límite';

  @override
  String get autoPausedIdle5h => 'Pausado tras 5 horas inactivo';

  @override
  String get autoPausedOver5h => 'Pausado tras más de 5 horas en marcha';

  @override
  String get autoPausedBackground30m => 'Pausado tras más de 30 minutos en segundo plano';

  @override
  String get partLimitReached => 'Puedes añadir hasta 10 partes.';

  @override
  String get removePersonalCardTooltip => 'Ocultar tarjeta personal';

  @override
  String get removePartCardTooltip => 'Eliminar tarjeta de parte';

  @override
  String get deletePersonalConfirmationTitle => '¿Ocultar la tarjeta de datos personales?';

  @override
  String get deletePartConfirmationTitle => '¿Eliminar esta tarjeta de parte?';

  @override
  String get exerciseLimitReached => 'Puedes añadir hasta 15 ejercicios.';

  @override
  String get time => 'Tiempo';

  @override
  String get hour => 'hora';

  @override
  String get enterGoal => 'Objetivo';

  @override
  String get deleteMenuConfirmationTitle => '¿Eliminar ejercicio?';

  @override
  String get addPart => '+ Parte';

  @override
  String get ok => 'OK';

  @override
  String get share => 'Compartir';

  @override
  String get clear => 'Limpiar';

  @override
  String selectedCount(Object count) {
    return '$count seleccionado(s)';
  }

  @override
  String results(Object date) {
    return 'Registros del $date';
  }

  @override
  String get resultsCopy => 'Copiar';

  @override
  String get resultsCopied => 'Resultados copiados';

  @override
  String get calendarLockedResultsMessage =>
      'Los registros de hace más de 10 días aparecerán después de ver un anuncio.';

  @override
  String get calendarLockedResultsButton => 'Ver registros';

  @override
  String deleteSelectedConfirmTitle(Object count) {
    return '¿Eliminar $count elemento(s)?';
  }

  @override
  String get albumEmptyMessage => 'Guarda tus selfies en el álbum para seguir el progreso de tu entrenamiento.';

  @override
  String get close => 'Cerrar';

  @override
  String get addMemo => '+ Nota';

  @override
  String get memo => 'Nota';

  @override
  String get memoTitle => 'Título';

  @override
  String get memoBody => 'Nota';

  @override
  String get memoTitlePlaceholder => 'Introduce el título';

  @override
  String get memoBodyPlaceholder => 'Introduce la nota';

  @override
  String get satisfaction => 'Satisfacción';

  @override
  String get satisfactionBad => 'Mala';

  @override
  String get satisfactionOkay => 'Normal';

  @override
  String get satisfactionGood => 'Buena';

  @override
  String get totalVolume => 'Volumen total';

  @override
  String get totalVolumeCurrent => 'Actual';

  @override
  String get totalVolumePrevious => 'Anterior';

  @override
  String get totalVolumeDifference => 'Diferencia';

  @override
  String get valueNotAvailable => '--';

  @override
  String get expandCard => 'Expandir';

  @override
  String get collapseCard => 'Contraer';

  @override
  String get hintRecordFirst => 'Empieza registrando un entrenamiento. Toca \"Selecciona parte del entrenamiento\" para comenzar.';

  @override
  String get unitChangeHint => 'Puedes cambiar las unidades desde Configuración.';

  @override
  String get hintGraphSetGoal => 'Define tu objetivo.';

  @override
  String get personalSettingsTitle => 'Personal';

  @override
  String get gender => 'Género';

  @override
  String get genderMale => 'Hombre';

  @override
  String get genderFemale => 'Mujer';

  @override
  String get genderUnspecified => 'Sin especificar';

  @override
  String get birthDate => 'Fecha de nacimiento';

  @override
  String get notSet => 'Sin definir';

  @override
  String get height => 'Altura';

  @override
  String get waist => 'Cintura';

  @override
  String get bodyFatTracking => 'Seguimiento de grasa corporal';

  @override
  String get waistTracking => 'Seguimiento de cintura';

  @override
  String get bmiTracking => 'Seguimiento de IMC';

  @override
  String get unitCm => 'cm';

  @override
  String get unitFtIn => 'ft/in';

  @override
  String get unitFt => 'ft';

  @override
  String get unitIn => 'in';

  @override
  String get bodyFat => 'Grasa corporal';

  @override
  String get bmi => 'IMC';

  @override
  String get personal => 'Personal';

  @override
  String get bodyFatPercentage => 'Grasa corporal %';

  @override
  String get percentSymbol => '%';

  @override
  String get cm => 'cm';

  @override
  String get standards => 'Referencia';

  @override
  String bmiStdRange(Object max, Object min) {
    return 'IMC $min–$max';
  }

  @override
  String bodyFatStdRange(Object max, Object min, Object percent) {
    return 'Grasa corporal $min–$max$percent';
  }

  @override
  String waistStdSingle(Object cm, Object value) {
    return 'Cintura $value$cm';
  }

  @override
  String get photos => 'Fotos';

  @override
  String get maleShort => 'H';

  @override
  String get femaleShort => 'M';

  @override
  String get mile => 'milla';

  @override
  String get length => 'Longitud';

  @override
  String get lengthNote => 'La altura y la cintura siguen la unidad de longitud (cm o ft·in).';

  @override
  String get graphTitle => 'Gráfico';

  @override
  String get backTooltip => 'Atrás';

  @override
  String get noneLabel => 'Ninguno';

  @override
  String get aerobicCalorieToggle => 'Estimar calorías aeróbicas';

  @override
  String get calorie => 'Calorías';

  @override
  String get kcalUnit => 'kcal';

  @override
  String get meal => 'Comida';

  @override
  String get mealAdd => '+ Comida';

  @override
  String get mealCategory => 'Categoría de comida';

  @override
  String get mealMorning => 'Desayuno';

  @override
  String get mealNoon => 'Almuerzo';

  @override
  String get mealEvening => 'Cena';

  @override
  String get mealSnack => 'Merienda';

  @override
  String get mealItem => 'Plato';

  @override
  String get mealSubtotal => 'Subtotal';

  @override
  String get mealTotalToday => 'Total de comidas de hoy';

  @override
  String get mealDeleteConfirmTitle => '¿Eliminar todas las comidas?';

  @override
  String get addMealItem => '+ Plato';

  @override
  String get bmrTitle => 'Metabolismo basal:';

  @override
  String get bmrTitleShort => 'Metabolismo basal';

  @override
  String get bmrDiffShort => 'Ingesta - Metabolismo basal';

  @override
  String get dailyBalanceSummary => 'Ingesta − (Metabolismo basal + Aeróbico)';

  @override
  String get bmrDeficit => 'Diferencia (Ingesta − BMR)';

  @override
  String get bmrNeedPersonalNotice => 'Se requieren peso, estatura, fecha de nacimiento y género. Configúralos en Ajustes → Personal.';

  @override
  String get mealInputHint => 'Ingresa el nombre del plato y las kcal';

  @override
  String get mealEmptyNotice => 'Sin registros';

  @override
  String get mealRestoreFailed => 'No se pudieron recuperar los datos de comida';

  @override
  String get calorieOverrideHint => 'Puedes editar este valor';

  @override
  String get calorieHelpTitle => 'Acerca de la estimación de calorías';

  @override
  String get calorieHelpBody => 'Fórmula: calorías = MET × peso(kg) × tiempo(horas).\n\nEl valor MET se estima a partir del nombre del ejercicio. Como solo es una aproximación, si tienes un dato de tu reloj u otro dispositivo, sobrescríbelo.';

  @override
  String get dailyCalorieTotal => 'Calorías totales';

  @override
  String get chooseFromPresets => 'Elegir de los preajustes';

  @override
  String get presetRunning => 'Correr';

  @override
  String get presetWalking => 'Caminar';

  @override
  String get presetCycling => 'Ciclismo';

  @override
  String get presetExerciseBike => 'Bicicleta estática';

  @override
  String get presetElliptical => 'Elíptica';

  @override
  String get presetRowing => 'Remo';

  @override
  String get aerobicPickerTitle => 'Escribe o elige un ejercicio';

  @override
  String get aerobicCalorieUnknownHint => 'No se pudieron estimar las calorías para este ejercicio. Introduce el valor de otro dispositivo si lo tienes.';

  @override
  String get aerobicCalorieInfoTitle => 'Acerca de la estimación de calorías';

  @override
  String get aerobicCalorieInfoBody => 'Las calorías se estiman como MET × peso (kg) × tiempo (horas). El MET se infiere del nombre del ejercicio, la distancia y la duración.\n\nDado que es un valor estimado, sobrescríbelo con el dato de tu reloj inteligente u otro dispositivo si lo tienes. Si la distancia o el tiempo están vacíos no se hará la estimación.\n\nEl entorno caluroso y tu estado físico pueden afectar al consumo. Procura descansar y mantenerte hidratado.';

  @override
  String get aerobicCalorieWeightRequired => 'Introduce tu peso en la configuración personal para activar el cálculo de calorías.';

  @override
  String get add => 'Añadir';

  @override
  String get noRecords => 'Sin registros';

  @override
  String get editThisDay => 'Editar este día';

  @override
  String get addOnThisDay => 'Agregar en este día';

  @override
  String get settingsThemeTitle => 'Tema';

  @override
  String get settingsThemeConfirmTitle => '¿Cambiar el tema?';

  @override
  String get settingsThemeConfirmMessage => 'Se actualizarán los colores de la app. ¿Continuar?';

  @override
  String get themeMonotone => 'Monocromo';

  @override
  String get themeRed => 'Rojo';

  @override
  String get themeBlue => 'Azul';

  @override
  String get themeGreen => 'Verde';

  @override
  String get themeYellow => 'Amarillo';

  @override
  String get themeColorTitle => 'Color del tema';

  @override
  String get totalVolumeLabel => 'Volumen total';

  @override
  String get previousLabel => 'Anterior';

  @override
  String get currentLabel => 'Actual';

  @override
  String get hintCalendarGotoRecord => 'Toca para ir a la pantalla de registro';

  @override
  String get hintRecordTapExerciseCard => 'Toca la tarjeta de ejercicio';

  @override
  String get hintRecordPickExercise => 'Selecciona un ejercicio.';

  @override
  String get hintRecordCheckbox => 'Marca después de ingresar peso y repeticiones.';

  @override
  String get hintRecordSave => 'Toca Guardar al finalizar.';

  @override
  String get exerciseAerobic01 => 'Correr';

  @override
  String get exerciseAerobic02 => 'Caminar';

  @override
  String get exerciseAerobic03 => 'Cinta de correr';

  @override
  String get exerciseAerobic04 => 'Ciclismo';

  @override
  String get exerciseAerobic05 => 'Bicicleta estática';

  @override
  String get exerciseAerobic06 => 'Elíptica';

  @override
  String get exerciseAerobic07 => 'Máquina de remo';

  @override
  String get exerciseAerobic08 => 'Escaladora';

  @override
  String get exerciseAerobic09 => 'Natación';

  @override
  String get exerciseAerobic10 => 'Comba';

  @override
  String get exerciseAerobic11 => 'Aeróbic';

  @override
  String get exerciseArm01 => 'Curl con barra';

  @override
  String get exerciseArm02 => 'Curl con mancuernas';

  @override
  String get exerciseArm03 => 'Curl inclinado con mancuernas';

  @override
  String get exerciseArm04 => 'Curl en polea';

  @override
  String get exerciseArm05 => 'Curl predicador';

  @override
  String get exerciseArm06 => 'Curl martillo';

  @override
  String get exerciseArm07 => 'Curl de concentración';

  @override
  String get exerciseArm08 => 'Curl inverso';

  @override
  String get exerciseArm09 => 'Jalón de tríceps en polea';

  @override
  String get exerciseArm10 => 'Press francés (Skull Crusher)';

  @override
  String get exerciseArm11 => 'Extensión de tríceps por encima de la cabeza';

  @override
  String get exerciseArm12 => 'Patada de tríceps con mancuernas';

  @override
  String get exerciseArm13 => 'Extensión de tríceps en polea por encima de la cabeza';

  @override
  String get exerciseArm14 => 'Press de banca agarre cerrado';

  @override
  String get exerciseArm15 => 'Curl de muñeca';

  @override
  String get exerciseChest01 => 'Press de banca con barra';

  @override
  String get exerciseChest02 => 'Press inclinado con barra';

  @override
  String get exerciseChest03 => 'Press declinado con barra';

  @override
  String get exerciseChest04 => 'Press de banca con mancuernas';

  @override
  String get exerciseChest05 => 'Press inclinado con mancuernas';

  @override
  String get exerciseChest06 => 'Press declinado con mancuernas';

  @override
  String get exerciseChest07 => 'Aperturas con mancuernas';

  @override
  String get exerciseChest08 => 'Aperturas inclinadas con mancuernas';

  @override
  String get exerciseChest09 => 'Cruce en polea';

  @override
  String get exerciseChest10 => 'Aperturas en pec deck';

  @override
  String get exerciseChest11 => 'Press de pecho en máquina';

  @override
  String get exerciseChest12 => 'Press de banca en multipower';

  @override
  String get exerciseChest13 => 'Press inclinado en multipower';

  @override
  String get exerciseChest14 => 'Fondos';

  @override
  String get exerciseChest15 => 'Flexiones con peso / en máquina';

  @override
  String get exerciseBack01 => 'Peso muerto';

  @override
  String get exerciseBack02 => 'Jalón al pecho';

  @override
  String get exerciseBack03 => 'Jalón al pecho agarre inverso';

  @override
  String get exerciseBack04 => 'Remo con barra';

  @override
  String get exerciseBack05 => 'Remo a una mano con mancuerna';

  @override
  String get exerciseBack06 => 'Remo sentado';

  @override
  String get exerciseBack07 => 'Remo en T';

  @override
  String get exerciseBack08 => 'Dominadas lastradas';

  @override
  String get exerciseBack09 => 'Dominadas asistidas';

  @override
  String get exerciseBack10 => 'Face Pull';

  @override
  String get exerciseBack11 => 'Encogimientos de hombros';

  @override
  String get exerciseBack12 => 'Jalón con brazos rectos en polea';

  @override
  String get exerciseBack13 => 'Peso muerto sumo';

  @override
  String get exerciseBack14 => 'Peso muerto rumano';

  @override
  String get exerciseBack15 => 'Peso muerto convencional';

  @override
  String get exerciseShoulder01 => 'Press militar con barra';

  @override
  String get exerciseShoulder02 => 'Press militar con mancuernas';

  @override
  String get exerciseShoulder03 => 'Press militar en multipower';

  @override
  String get exerciseShoulder04 => 'Press Arnold';

  @override
  String get exerciseShoulder05 => 'Elevaciones laterales';

  @override
  String get exerciseShoulder06 => 'Elevaciones posteriores';

  @override
  String get exerciseShoulder07 => 'Elevaciones frontales';

  @override
  String get exerciseShoulder08 => 'Elevaciones posteriores en polea';

  @override
  String get exerciseShoulder09 => 'Remo al mentón';

  @override
  String get exerciseShoulder10 => 'Press de hombros en máquina';

  @override
  String get exerciseShoulder11 => 'Elevaciones frontales en polea';

  @override
  String get exerciseShoulder12 => 'Elevaciones laterales inclinadas';

  @override
  String get exerciseShoulder13 => 'Encogimientos con mancuernas';

  @override
  String get exerciseShoulder14 => 'Elevaciones laterales en polea';

  @override
  String get exerciseShoulder15 => 'Face Pull';

  @override
  String get exerciseLeg01 => 'Sentadilla con barra';

  @override
  String get exerciseLeg02 => 'Sentadilla frontal';

  @override
  String get exerciseLeg03 => 'Prensa de piernas';

  @override
  String get exerciseLeg04 => 'Extensión de piernas';

  @override
  String get exerciseLeg05 => 'Curl de piernas';

  @override
  String get exerciseLeg06 => 'Curl de piernas sentado';

  @override
  String get exerciseLeg07 => 'Peso muerto rumano';

  @override
  String get exerciseLeg08 => 'Buenos días';

  @override
  String get exerciseLeg09 => 'Elevación de gemelos';

  @override
  String get exerciseLeg10 => 'Elevación de gemelos sentado';

  @override
  String get exerciseLeg11 => 'Sentadilla Hack';

  @override
  String get exerciseLeg12 => 'Sentadilla en multipower';

  @override
  String get exerciseLeg13 => 'Patada de glúteo en polea';

  @override
  String get exerciseLeg14 => 'Elevación de cadera (Hip Thrust)';

  @override
  String get exerciseLeg15 => 'Peso muerto piernas rígidas';

  @override
  String get exerciseAbs01 => 'Crunch';

  @override
  String get exerciseAbs02 => 'Abdominales';

  @override
  String get exerciseAbs03 => 'Elevación de piernas';

  @override
  String get exerciseAbs04 => 'Elevación de piernas colgado';

  @override
  String get exerciseAbs05 => 'Rueda abdominal';

  @override
  String get exerciseAbs06 => 'Crunch en polea';

  @override
  String get exerciseAbs07 => 'Crunch en máquina';

  @override
  String get exerciseAbs08 => 'Inclinaciones laterales';

  @override
  String get exerciseAbs09 => 'Giro ruso';

  @override
  String get exerciseAbs10 => 'Crunch bicicleta';

  @override
  String get exerciseAbs11 => 'Abdominal en V';

  @override
  String get exerciseAbs12 => 'Plancha con peso';

  @override
  String get exerciseAbs13 => 'Plancha lateral con peso';

  @override
  String get exerciseAbs14 => 'Abdominales jackknife';

  @override
  String get exerciseAbs15 => 'Bandera del dragón';

  @override
  String get exerciseFullBody01 => 'Balanceo con kettlebell';

  @override
  String get exerciseFullBody02 => 'Burpee con salto';

  @override
  String get exerciseFullBody03 => 'Clean';

  @override
  String get exerciseFullBody04 => 'Clean and Press';

  @override
  String get exerciseFullBody05 => 'Woodchopper en polea';

  @override
  String get exerciseFullBody06 => 'Sentadilla goblet con kettlebell';

  @override
  String get exerciseFullBody07 => 'Slam con balón medicinal';

  @override
  String get exerciseFullBody08 => 'Sentadilla con saco de arena al hombro';

  @override
  String get exerciseFullBody09 => 'Empuje de trineo';

  @override
  String get exerciseFullBody10 => 'Step-up';

  @override
  String get exerciseFullBody11 => 'Paseo del granjero';

  @override
  String get exerciseFullBody12 => 'Sentadilla y press con balón medicinal';

  @override
  String get exerciseFullBody13 => 'Entrenamiento en circuito';

  @override
  String get exerciseFullBody14 => 'Circuito de burpees';

  @override
  String get exerciseFullBody15 => 'Circuito de remo y empuje';

  @override
  String get exerciseBodyweight01 => 'Flexión de brazos';

  @override
  String get exerciseBodyweight02 => 'Flexión cerrada';

  @override
  String get exerciseBodyweight03 => 'Flexión abierta';

  @override
  String get exerciseBodyweight04 => 'Flexión diamante';

  @override
  String get exerciseBodyweight05 => 'Fondos';

  @override
  String get exerciseBodyweight06 => 'Sentadilla';

  @override
  String get exerciseBodyweight07 => 'Sentadilla con salto';

  @override
  String get exerciseBodyweight08 => 'Sentadilla búlgara';

  @override
  String get exerciseBodyweight09 => 'Zancada';

  @override
  String get exerciseBodyweight10 => 'Elevación de gemelos';

  @override
  String get exerciseBodyweight11 => 'Abdominales (Crunch)';

  @override
  String get exerciseBodyweight12 => 'Elevación de piernas';

  @override
  String get exerciseBodyweight13 => 'Plancha';

  @override
  String get exerciseBodyweight14 => 'Plancha lateral';

  @override
  String get exerciseBodyweight15 => 'Burpee';

  @override
  String get bodyweight => 'Peso corporal';

  @override
  String get welcomeThankYou => 'Gracias por descargar. ¡Que tengas un gran entrenamiento!';

  @override
  String get hintTapPlus => 'Toca el “+” para empezar a registrar.';

  @override
  String get notiDailyTitle => '¡Vamos con todo hoy!';

  @override
  String get notiDailyBodyA => '¡Es hora de entrenar!';

  @override
  String get notiDailyBodyB => '¡Empecemos a entrenar! ¿Preparado/a?';

  @override
  String get notiInactive3Title => '¡Volvamos a entrenar!';

  @override
  String get notiInactive3Body => 'Con una sola serie también está bien. Pruébalo.';

  @override
  String get notiInactive7Title => 'Reinicia hoy';

  @override
  String get notiInactive7Body => 'Una semana de pausa. Haz 10 flexiones o 10 sentadillas; una opción basta.';

  @override
  String get notiSoftAskTitle => '¿Quieres activar las notificaciones para continuar entrenando de forma constante?';

  @override
  String get notiSoftAskBody => 'Puedes cambiar esto en cualquier momento.';

  @override
  String get notiSoftAskLater => 'Más tarde';

  @override
  String get notiSoftAskEnable => 'Activar avisos';

  @override
  String get notiSettingsTitle => 'Ajustes de notificaciones';

  @override
  String get notiSettingsSubtitle => 'Recordatorio diario';

  @override
  String get notiSettingsChangeTime => 'Cambiar hora';

  @override
  String get notiSendTest => 'Enviar notificación de prueba';

  @override
  String get notiStopAll => 'Detener todas las notificaciones';

  @override
  String get notiSettingsAllSame => 'Aplicar a todos los días';

  @override
  String get notiSettingsCopyWeekdays => 'Copiar a días laborables';

  @override
  String get notiSettingsCopyWeekend => 'Copiar a fin de semana';

  @override
  String notiSettingsWeeklyLabel(Object weekday) {
    return 'Cada $weekday';
  }

  @override
  String get mealHeaderNo => 'N.º';

  @override
  String get mealHeaderMenu => 'Menú';

  @override
  String get mealHeaderKcal => 'kcal';

  @override
  String get notiCopyAllTitle => 'Copiar a todos los días';

  @override
  String get notiCopyAllMessage => 'Esto sobrescribirá la hora de todos los días. ¿Continuar?';

  @override
  String get notiCopyWeekdaysTitle => 'Copiar a los días laborables';

  @override
  String get notiCopyWeekdaysMessage => 'Esto sobrescribirá la hora de lunes a viernes. ¿Continuar?';

  @override
  String get notiCopyWeekendTitle => 'Copiar al fin de semana';

  @override
  String get notiCopyWeekendMessage => 'Esto establecerá la misma hora para sábado y domingo. ¿Continuar?';

  @override
  String get notiConfirmYes => 'Sí';

  @override
  String get notiConfirmNo => 'No';

  @override
  String get awardTitleFirst => '¡Primer entrenamiento logrado!';

  @override
  String awardTitleDays(Object dayCount) {
    return '¡Racha de $dayCount días completada!';
  }

  @override
  String get awardTitleMax => '¡Nuevo récord alcanzado!';

  @override
  String get timelineStrengthFallback => 'Entrenamiento';

  @override
  String get awardLabelDate => 'Fecha:';

  @override
  String get awardLabelExercise => 'Ejercicio:';

  @override
  String get awardLabelPrevious => 'Registro anterior:';

  @override
  String get awardFooterMessage => '¡Buen trabajo!';

  @override
  String awardBadgeDay(Object dayCount) {
    return 'Día $dayCount';
  }

  @override
  String get awardSaved => 'Guardado en tu álbum';

  @override
  String get awardShare => 'Compartir';

  @override
  String get awardClose => 'Cerrar';
}
