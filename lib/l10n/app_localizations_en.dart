// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'T-Training Record';

  @override
  String get calendar => 'calendar';

  @override
  String get graph => 'graph';

  @override
  String get favorites => 'favorites';

  @override
  String get favoritesNew => 'Favorites (New)';

  @override
  String get recordScreenTitle => 'Record';

  @override
  String get calendarScreenTitle => 'Calendar';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get graphScreenTitle => 'Graph';

  @override
  String get albumTitle => 'Album';

  @override
  String get albumFilterAll => 'All';

  @override
  String get albumFilterAwards => 'Awards';

  @override
  String get albumAwardRibbon => 'AWARD';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get reset => 'Reset';

  @override
  String get saved => 'Saved';

  @override
  String get save => 'Save';

  @override
  String get discard => 'Discard';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get resume => 'Resume';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get cameraPermissionRequired => 'Please enable camera permission';

  @override
  String get stopwatch => 'Stopwatch';

  @override
  String get timer => 'Timer';

  @override
  String get timerTime => 'Timer duration';

  @override
  String get tapNumberToEdit => 'Tap numbers to edit';

  @override
  String targetFmt(Object hint, Object time) {
    return 'Target $time ($hint)';
  }

  @override
  String get statusRunning => 'Running';

  @override
  String get statusIdle => 'Idle';

  @override
  String hours(Object hours) {
    return '${hours}h';
  }

  @override
  String get kg => 'kg';

  @override
  String get lbs => 'lbs';

  @override
  String get unit => 'unit';

  @override
  String get unitTitle => 'Unit';

  @override
  String get weightUnit => 'Weight';

  @override
  String get min => 'min';

  @override
  String get sec => 'sec';

  @override
  String get minutes => 'min';

  @override
  String get minutesHint => 'Min';

  @override
  String get secondsHint => 'Sec';

  @override
  String get sets => 'sets';

  @override
  String get setLabel => 'Set';

  @override
  String get reps => 'Reps';

  @override
  String get distance => 'distance';

  @override
  String get km => 'km';

  @override
  String get m => 'm';

  @override
  String get pace => 'Pace';

  @override
  String get perDayUnit => 'photos/day';

  @override
  String get trainingParts => 'Training Parts';

  @override
  String get selectTrainingPart => 'Select Training Part';

  @override
  String get selectPartPlaceholder => 'Select part';

  @override
  String get aerobicExercise => 'Aerobic Exercise';

  @override
  String get arm => 'Arm';

  @override
  String get chest => 'Chest';

  @override
  String get back => 'Back';

  @override
  String get shoulder => 'Shoulder';

  @override
  String get leg => 'Leg';

  @override
  String get abs => 'Abs';

  @override
  String get bodyWeightTraining => 'Bodyweight';

  @override
  String get fullBody => 'Full Body';

  @override
  String get other1 => 'Other 1';

  @override
  String get other2 => 'Other 2';

  @override
  String get other3 => 'Other 3';

  @override
  String get exercise => 'Exercise';

  @override
  String get selectExercise => 'Select Exercise';

  @override
  String get menuName => 'Menu Name';

  @override
  String get menuNameHint => 'Enter menu name';

  @override
  String get addExercisePlaceholder => 'Select exercise';

  @override
  String get addExercise => '+ Exercise';

  @override
  String get addNewExercise => '+ New';

  @override
  String get customExerciseDialogTitle => 'Add New Exercise';

  @override
  String get customExerciseNameHint => 'Enter exercise name';

  @override
  String get customExerciseNameRequired => 'Enter an exercise name';

  @override
  String get customExerciseDuplicate => 'This exercise is already registered';

  @override
  String get customExercisePickerEmpty => 'No saved exercises yet. Tap + to add one.';

  @override
  String get open => 'Open';

  @override
  String get removeCustomExercises => 'Remove Custom Exercises';

  @override
  String get customExerciseRemovalHint => 'Delete previously added custom exercises.';

  @override
  String get keepScreenOn => 'Keep screen on';

  @override
  String get keepScreenOnHint => 'If enabled, the screen will stay on while the app is open.';

  @override
  String get noCustomExercises => 'No custom exercises have been added.';

  @override
  String get selectExerciseToDelete => 'Select exercise to delete';

  @override
  String customExerciseRemoved(Object exerciseName) {
    return 'Removed $exerciseName.';
  }

  @override
  String get addMenu => 'Add Menu';

  @override
  String get addSet => '+ Set';

  @override
  String get openAddMenu => 'Open add menu';

  @override
  String get partAlreadySelected => 'This part is already selected.';

  @override
  String get setCount => 'Set Count';

  @override
  String get defaultSets => 'Default Sets';

  @override
  String get bodyWeight => 'BW';

  @override
  String get weightCardTitle => 'Weight';

  @override
  String get weightCardExtraFieldsHint => 'You can add fields like body fat or waist from Settings. Weight units (kg/lbs) can also be changed from Settings.';

  @override
  String get bodyWeightTracking => 'Body Weight Tracking';

  @override
  String get durationHint => 'min:sec';

  @override
  String get distanceHint => 'Enter distance';

  @override
  String get noRecordMessage => 'No records found for the selected date.';

  @override
  String get coachBubbleSemantic => 'Hint';

  @override
  String get hintRecordSelectPart => 'Please select the body part you will train.';

  @override
  String get hintRecordExerciseField => 'Enter exercise name here.';

  @override
  String get hintRecordAddExercise => 'Tap here to add the exercise.';

  @override
  String get hintRecordChangePart => 'You can add another body part here.';

  @override
  String get hintRecordOpenSettings => 'You can change default sets in Settings.';

  @override
  String get hintRecordFab => 'Add a part, exercise, photo, or memo from here.';

  @override
  String get hintCalendarTapDate => 'Select a date to record.';

  @override
  String get hintGraphFavorite => 'Add frequently viewed data to Favorites.';

  @override
  String get hintGraphChartArea => 'The chart of your recorded data will appear here.';

  @override
  String get hintGraphSelectPart => 'Select body part and exercise.';

  @override
  String get discardLongPressLabel => 'Discard (long press)';

  @override
  String get dayDisplay => 'Day';

  @override
  String get weekDisplay => 'Week';

  @override
  String get monthDisplay => 'Mth';

  @override
  String get noGraphData => 'Select a body part/exercise or weight to display the graph.';

  @override
  String favorited(Object menuName) {
    return '$menuName added to favorites';
  }

  @override
  String unfavorited(Object menuName) {
    return '$menuName removed from favorites';
  }

  @override
  String get addPhoto => '+ Photo';

  @override
  String get dialogAddPhotoTitle => 'Add photo';

  @override
  String get actionTakePhoto => 'Take photo';

  @override
  String get progressSnaps => 'Progress snaps';

  @override
  String get mediaReachedDailyCap => 'You\'ve reached today\'s save limit.';

  @override
  String get mediaGoToAlbum => 'Go to Album';

  @override
  String get mediaGoToSettings => 'Go to Settings';

  @override
  String get mediaDelete => 'Delete';

  @override
  String get mediaCancel => 'Cancel';

  @override
  String get mediaUndo => 'Undo';

  @override
  String get photoLoadFailed => 'Couldn\'t load the image';

  @override
  String get discardPhotoConfirmTitle => 'Discard this photo?';

  @override
  String get settings => 'Settings';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeTitle => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get systemDefault => 'System Default';

  @override
  String get useDarkMode => 'dark mode';

  @override
  String get selectBodyParts => 'Select body parts to display';

  @override
  String get changeSetCount => 'Change Set Count';

  @override
  String get settingsStopwatchTimerVisibility => 'Show Stopwatch/Timer';

  @override
  String get intervalTimer => 'Interval timer';

  @override
  String get settingsDailyMediaCap => 'Daily photo limit';

  @override
  String get settingsDailyMediaCapDesc => 'Max photos you can save per day';

  @override
  String get settingsDailyMediaCapShort => 'Photo limit';

  @override
  String get recordDisplayOptions => 'Display options';

  @override
  String get background => 'Background';

  @override
  String get none => 'None';

  @override
  String get limitOff => 'No limit';

  @override
  String get autoPausedIdle5h => 'Paused after 5 hours of inactivity';

  @override
  String get autoPausedOver5h => 'Paused after running over 5 hours';

  @override
  String get autoPausedBackground30m => 'Paused after 30+ minutes in background';

  @override
  String get partLimitReached => 'You can add up to 10 parts.';

  @override
  String get removePersonalCardTooltip => 'Hide personal card';

  @override
  String get removePartCardTooltip => 'Remove part card';

  @override
  String get deletePersonalConfirmationTitle => 'Hide personal metrics card?';

  @override
  String get deletePartConfirmationTitle => 'Remove this part card?';

  @override
  String get exerciseLimitReached => 'You can add up to 15 exercises.';

  @override
  String get time => 'Time';

  @override
  String get hour => 'hour';

  @override
  String get enterGoal => 'Goal';

  @override
  String get deleteMenuConfirmationTitle => 'Delete Exercise?';

  @override
  String get addPart => '+ Part';

  @override
  String get ok => 'OK';

  @override
  String get share => 'Share';

  @override
  String get clear => 'Clear';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String results(Object date) {
    return 'Records for $date';
  }

  @override
  String get resultsCopy => 'Copy';

  @override
  String get resultsCopied => 'Copied results to clipboard';

  @override
  String deleteSelectedConfirmTitle(Object count) {
    return 'Delete $count item(s)?';
  }

  @override
  String get albumEmptyMessage => 'Save your selfies in the album to track your training progress.';

  @override
  String get close => 'Close';

  @override
  String get addMemo => '+ Memo';

  @override
  String get memo => 'Memo';

  @override
  String get memoTitle => 'Title';

  @override
  String get memoBody => 'Memo';

  @override
  String get memoTitlePlaceholder => 'Enter title';

  @override
  String get memoBodyPlaceholder => 'Enter memo';

  @override
  String get satisfaction => 'Satisfaction';

  @override
  String get satisfactionBad => 'Bad';

  @override
  String get satisfactionOkay => 'Okay';

  @override
  String get satisfactionGood => 'Good';

  @override
  String get totalVolume => 'Total Volume';

  @override
  String get totalVolumeCurrent => 'Current';

  @override
  String get totalVolumePrevious => 'Previous';

  @override
  String get totalVolumeDifference => 'Difference';

  @override
  String get valueNotAvailable => '--';

  @override
  String get expandCard => 'Expand';

  @override
  String get collapseCard => 'Collapse';

  @override
  String get hintRecordFirst => 'Let’s start by recording a workout. Tap \"Select Training Part\" to begin.';

  @override
  String get unitChangeHint => 'Units can be changed from Settings.';

  @override
  String get hintGraphSetGoal => 'Set your goal.';

  @override
  String get personalSettingsTitle => 'Personal';

  @override
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderUnspecified => 'Not specified';

  @override
  String get birthDate => 'Birth date';

  @override
  String get notSet => 'Not set';

  @override
  String get height => 'Height';

  @override
  String get waist => 'Waist';

  @override
  String get bodyFatTracking => 'Body fat tracking';

  @override
  String get waistTracking => 'Waist tracking';

  @override
  String get bmiTracking => 'BMI tracking';

  @override
  String get unitCm => 'cm';

  @override
  String get unitFtIn => 'ft/in';

  @override
  String get unitFt => 'ft';

  @override
  String get unitIn => 'in';

  @override
  String get bodyFat => 'Body fat';

  @override
  String get bmi => 'BMI';

  @override
  String get personal => 'Personal';

  @override
  String get bodyFatPercentage => 'Body Fat %';

  @override
  String get percentSymbol => '%';

  @override
  String get cm => 'cm';

  @override
  String get standards => 'Reference';

  @override
  String bmiStdRange(Object max, Object min) {
    return 'BMI $min–$max';
  }

  @override
  String bodyFatStdRange(Object max, Object min, Object percent) {
    return 'Body fat $min–$max$percent';
  }

  @override
  String waistStdSingle(Object cm, Object value) {
    return 'Waist $value$cm';
  }

  @override
  String get photos => 'Photos';

  @override
  String get maleShort => 'M';

  @override
  String get femaleShort => 'F';

  @override
  String get mile => 'mile';

  @override
  String get length => 'Length';

  @override
  String get lengthNote => 'Height and waist follow the Length unit (cm or ft·in).';

  @override
  String get graphTitle => 'Graph';

  @override
  String get backTooltip => 'Back';

  @override
  String get noneLabel => 'None';

  @override
  String get aerobicCalorieToggle => 'Estimate aerobic calories';

  @override
  String get calorie => 'Calories';

  @override
  String get kcalUnit => 'kcal';

  @override
  String get meal => 'Meal';

  @override
  String get mealAdd => '+ Meal';

  @override
  String get mealCategory => 'Meal category';

  @override
  String get mealMorning => 'Breakfast';

  @override
  String get mealNoon => 'Lunch';

  @override
  String get mealEvening => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get mealItem => 'Menu';

  @override
  String get mealSubtotal => 'Subtotal';

  @override
  String get mealTotalToday => 'Today\'s meal total';

  @override
  String get mealDeleteConfirmTitle => 'Remove all meals?';

  @override
  String get addMealItem => '+ Menu';

  @override
  String get bmrTitle => 'BMR:';

  @override
  String get bmrTitleShort => 'BMR';

  @override
  String get bmrDiffShort => 'Intake - BMR';

  @override
  String get dailyBalanceSummary => 'Intake − (BMR + Aerobic)';

  @override
  String get bmrDeficit => 'Difference (Intake − BMR)';

  @override
  String get bmrNeedPersonalNotice => 'Weight, height, birth date, and gender are required. Set them in Settings → Personal.';

  @override
  String get mealInputHint => 'Enter menu name and kcal';

  @override
  String get mealEmptyNotice => 'No entries';

  @override
  String get mealRestoreFailed => 'Could not restore meal data';

  @override
  String get calorieOverrideHint => 'You can edit this value';

  @override
  String get calorieHelpTitle => 'About the calorie estimation';

  @override
  String get calorieHelpBody => 'Formula: calories = MET × weight(kg) × time(hours).\n\nThe MET value is estimated from the exercise name. Because this is only an approximation, feel free to overwrite it with the reading from your smartwatch or other tracker.';

  @override
  String get dailyCalorieTotal => 'Total calories';

  @override
  String get chooseFromPresets => 'Choose from presets';

  @override
  String get presetRunning => 'Running';

  @override
  String get presetWalking => 'Walking';

  @override
  String get presetCycling => 'Cycling';

  @override
  String get presetExerciseBike => 'Exercise bike';

  @override
  String get presetElliptical => 'Elliptical';

  @override
  String get presetRowing => 'Rowing';

  @override
  String get aerobicPickerTitle => 'Choose or type exercise';

  @override
  String get aerobicCalorieUnknownHint => 'Could not estimate calories for this exercise name. Please enter the value obtained from another device if available.';

  @override
  String get aerobicCalorieInfoTitle => 'About Calorie Estimation';

  @override
  String get aerobicCalorieInfoBody => 'Calories are estimated as MET × weight (kg) × time (hours). MET is inferred from the exercise name, distance, and duration.\n\nBecause this is only an approximation, please overwrite it with the value obtained from your smartwatch or other tracker if available. Distance or time must be provided for the estimate.\n\nEnvironmental conditions and your physical condition affect calorie expenditure. Remember to take breaks and stay hydrated.';

  @override
  String get aerobicCalorieWeightRequired => 'Enter your body weight in Personal settings to enable calorie estimation.';

  @override
  String get add => 'Add';

  @override
  String get noRecords => 'No records';

  @override
  String get editThisDay => 'Edit this day';

  @override
  String get addOnThisDay => 'Add on this day';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeConfirmTitle => 'Change theme?';

  @override
  String get settingsThemeConfirmMessage => 'This will update the app\'s colors. Continue?';

  @override
  String get themeMonotone => 'Monotone';

  @override
  String get themeRed => 'Red';

  @override
  String get themeBlue => 'Blue';

  @override
  String get themeGreen => 'Green';

  @override
  String get themeYellow => 'Yellow';

  @override
  String get themeColorTitle => 'Theme color';

  @override
  String get totalVolumeLabel => 'Total volume';

  @override
  String get previousLabel => 'Previous';

  @override
  String get currentLabel => 'Current';

  @override
  String get hintCalendarGotoRecord => 'Tap to open the record screen';

  @override
  String get hintRecordTapExerciseCard => 'Tap the exercise card';

  @override
  String get hintRecordPickExercise => 'Please select an exercise.';

  @override
  String get hintRecordCheckbox => 'Check after entering weight and reps.';

  @override
  String get hintRecordSave => 'Tap Save when finished.';

  @override
  String get exerciseAerobic01 => 'Running';

  @override
  String get exerciseAerobic02 => 'Walking';

  @override
  String get exerciseAerobic03 => 'Treadmill';

  @override
  String get exerciseAerobic04 => 'Cycling';

  @override
  String get exerciseAerobic05 => 'Stationary Bike';

  @override
  String get exerciseAerobic06 => 'Elliptical';

  @override
  String get exerciseAerobic07 => 'Rowing Machine';

  @override
  String get exerciseAerobic08 => 'Stair Climber';

  @override
  String get exerciseAerobic09 => 'Swimming';

  @override
  String get exerciseAerobic10 => 'Jump Rope';

  @override
  String get exerciseAerobic11 => 'Aerobics';

  @override
  String get exerciseArm01 => 'Barbell Curl';

  @override
  String get exerciseArm02 => 'Dumbbell Curl';

  @override
  String get exerciseArm03 => 'Incline Dumbbell Curl';

  @override
  String get exerciseArm04 => 'Cable Curl';

  @override
  String get exerciseArm05 => 'Preacher Curl';

  @override
  String get exerciseArm06 => 'Hammer Curl';

  @override
  String get exerciseArm07 => 'Concentration Curl';

  @override
  String get exerciseArm08 => 'Reverse Curl';

  @override
  String get exerciseArm09 => 'Cable Triceps Pushdown';

  @override
  String get exerciseArm10 => 'Skull Crusher';

  @override
  String get exerciseArm11 => 'Overhead Triceps Extension';

  @override
  String get exerciseArm12 => 'Dumbbell Triceps Kickback';

  @override
  String get exerciseArm13 => 'Cable Overhead Triceps Extension';

  @override
  String get exerciseArm14 => 'Close-grip Bench Press';

  @override
  String get exerciseArm15 => 'Wrist Curl';

  @override
  String get exerciseChest01 => 'Barbell Bench Press';

  @override
  String get exerciseChest02 => 'Incline Bench Press';

  @override
  String get exerciseChest03 => 'Decline Bench Press';

  @override
  String get exerciseChest04 => 'Dumbbell Bench Press';

  @override
  String get exerciseChest05 => 'Incline Dumbbell Press';

  @override
  String get exerciseChest06 => 'Decline Dumbbell Press';

  @override
  String get exerciseChest07 => 'Dumbbell Flye';

  @override
  String get exerciseChest08 => 'Incline Dumbbell Flye';

  @override
  String get exerciseChest09 => 'Cable Crossover';

  @override
  String get exerciseChest10 => 'Pec Deck Flye';

  @override
  String get exerciseChest11 => 'Chest Press';

  @override
  String get exerciseChest12 => 'Smith Machine Bench Press';

  @override
  String get exerciseChest13 => 'Smith Machine Incline Press';

  @override
  String get exerciseChest14 => 'Dips';

  @override
  String get exerciseChest15 => 'Weighted / Machine Push-up';

  @override
  String get exerciseBack01 => 'Deadlift';

  @override
  String get exerciseBack02 => 'Lat Pulldown';

  @override
  String get exerciseBack03 => 'Reverse-grip Lat Pulldown';

  @override
  String get exerciseBack04 => 'Barbell Bent-over Row';

  @override
  String get exerciseBack05 => 'Dumbbell One-arm Row';

  @override
  String get exerciseBack06 => 'Seated Row';

  @override
  String get exerciseBack07 => 'T-bar Row';

  @override
  String get exerciseBack08 => 'Weighted Pull-up';

  @override
  String get exerciseBack09 => 'Assisted Pull-up';

  @override
  String get exerciseBack10 => 'Face Pull';

  @override
  String get exerciseBack11 => 'Shrug';

  @override
  String get exerciseBack12 => 'Cable Straight-arm Pulldown';

  @override
  String get exerciseBack13 => 'Sumo Deadlift';

  @override
  String get exerciseBack14 => 'Romanian Deadlift';

  @override
  String get exerciseBack15 => 'Conventional Deadlift';

  @override
  String get exerciseShoulder01 => 'Barbell Shoulder Press';

  @override
  String get exerciseShoulder02 => 'Dumbbell Shoulder Press';

  @override
  String get exerciseShoulder03 => 'Smith Machine Shoulder Press';

  @override
  String get exerciseShoulder04 => 'Arnold Press';

  @override
  String get exerciseShoulder05 => 'Side Raise';

  @override
  String get exerciseShoulder06 => 'Rear Raise';

  @override
  String get exerciseShoulder07 => 'Front Raise';

  @override
  String get exerciseShoulder08 => 'Cable Rear Raise';

  @override
  String get exerciseShoulder09 => 'Upright Row';

  @override
  String get exerciseShoulder10 => 'Shoulder Press Machine';

  @override
  String get exerciseShoulder11 => 'Cable Front Raise';

  @override
  String get exerciseShoulder12 => 'Incline Side Raise';

  @override
  String get exerciseShoulder13 => 'Dumbbell Shrug';

  @override
  String get exerciseShoulder14 => 'Cable Side Raise';

  @override
  String get exerciseShoulder15 => 'Face Pull';

  @override
  String get exerciseLeg01 => 'Barbell Squat';

  @override
  String get exerciseLeg02 => 'Front Squat';

  @override
  String get exerciseLeg03 => 'Leg Press';

  @override
  String get exerciseLeg04 => 'Leg Extension';

  @override
  String get exerciseLeg05 => 'Leg Curl';

  @override
  String get exerciseLeg06 => 'Seated Leg Curl';

  @override
  String get exerciseLeg07 => 'Romanian Deadlift';

  @override
  String get exerciseLeg08 => 'Good Morning';

  @override
  String get exerciseLeg09 => 'Calf Raise';

  @override
  String get exerciseLeg10 => 'Seated Calf Raise';

  @override
  String get exerciseLeg11 => 'Hack Squat';

  @override
  String get exerciseLeg12 => 'Smith Machine Squat';

  @override
  String get exerciseLeg13 => 'Cable Kickback';

  @override
  String get exerciseLeg14 => 'Hip Thrust';

  @override
  String get exerciseLeg15 => 'Stiff-legged Deadlift';

  @override
  String get exerciseAbs01 => 'Crunch';

  @override
  String get exerciseAbs02 => 'Sit-up';

  @override
  String get exerciseAbs03 => 'Leg Raise';

  @override
  String get exerciseAbs04 => 'Hanging Leg Raise';

  @override
  String get exerciseAbs05 => 'Ab Roller';

  @override
  String get exerciseAbs06 => 'Cable Crunch';

  @override
  String get exerciseAbs07 => 'Machine Crunch';

  @override
  String get exerciseAbs08 => 'Side Bend';

  @override
  String get exerciseAbs09 => 'Russian Twist';

  @override
  String get exerciseAbs10 => 'Bicycle Crunch';

  @override
  String get exerciseAbs11 => 'V Sit-up';

  @override
  String get exerciseAbs12 => 'Weighted Plank';

  @override
  String get exerciseAbs13 => 'Weighted Side Plank';

  @override
  String get exerciseAbs14 => 'Jackknife Sit-up';

  @override
  String get exerciseAbs15 => 'Dragon Flag';

  @override
  String get exerciseFullBody01 => 'Kettlebell Swing';

  @override
  String get exerciseFullBody02 => 'Burpee Jump';

  @override
  String get exerciseFullBody03 => 'Clean';

  @override
  String get exerciseFullBody04 => 'Clean and Press';

  @override
  String get exerciseFullBody05 => 'Cable Woodchopper';

  @override
  String get exerciseFullBody06 => 'Kettlebell Goblet Squat';

  @override
  String get exerciseFullBody07 => 'Medicine Ball Slam';

  @override
  String get exerciseFullBody08 => 'Sandbag Shoulder Squat';

  @override
  String get exerciseFullBody09 => 'Sled Push';

  @override
  String get exerciseFullBody10 => 'Step-up';

  @override
  String get exerciseFullBody11 => 'Farmer\'s Walk';

  @override
  String get exerciseFullBody12 => 'Medicine Ball Squat Press';

  @override
  String get exerciseFullBody13 => 'Circuit Training';

  @override
  String get exerciseFullBody14 => 'Burpee Circuit';

  @override
  String get exerciseFullBody15 => 'Row and Push Circuit';

  @override
  String get exerciseBodyweight01 => 'Push-up';

  @override
  String get exerciseBodyweight02 => 'Narrow Push-up';

  @override
  String get exerciseBodyweight03 => 'Wide Push-up';

  @override
  String get exerciseBodyweight04 => 'Diamond Push-up';

  @override
  String get exerciseBodyweight05 => 'Dips';

  @override
  String get exerciseBodyweight06 => 'Squat';

  @override
  String get exerciseBodyweight07 => 'Jump Squat';

  @override
  String get exerciseBodyweight08 => 'Bulgarian Squat';

  @override
  String get exerciseBodyweight09 => 'Lunge';

  @override
  String get exerciseBodyweight10 => 'Calf Raise';

  @override
  String get exerciseBodyweight11 => 'Crunch';

  @override
  String get exerciseBodyweight12 => 'Leg Raise';

  @override
  String get exerciseBodyweight13 => 'Plank';

  @override
  String get exerciseBodyweight14 => 'Side Plank';

  @override
  String get exerciseBodyweight15 => 'Burpee';

  @override
  String get bodyweight => 'Bodyweight';

  @override
  String get welcomeThankYou => 'Thanks for downloading. Have a great training life!';

  @override
  String get hintTapPlus => 'Tap the “+” to start logging.';

  @override
  String get notiDailyTitle => 'Let’s keep it up today!';

  @override
  String get notiDailyBodyA => 'It\'s time to train!';

  @override
  String get notiDailyBodyB => 'Let\'s start training! Ready?';

  @override
  String get notiInactive3Title => 'Let\'s get back to training!';

  @override
  String get notiInactive3Body => 'Even just one set is fine—give it a try.';

  @override
  String get notiInactive7Title => 'Restart today';

  @override
  String get notiInactive7Body => 'A week off. Do 10 push-ups or 10 squats—either is fine.';

  @override
  String get notiSoftAskTitle => 'Would you like to set up notifications to keep training consistently?';

  @override
  String get notiSoftAskBody => 'You can change this anytime.';

  @override
  String get notiSoftAskLater => 'Later';

  @override
  String get notiSoftAskEnable => 'Notify me';

  @override
  String get notiSettingsTitle => 'Notification settings';

  @override
  String get notiSettingsSubtitle => 'Daily reminder';

  @override
  String get notiSettingsChangeTime => 'Change time';

  @override
  String get notiSendTest => 'Send test notification';

  @override
  String get notiStopAll => 'Stop all notifications';

  @override
  String get notiSettingsAllSame => 'Apply to all';

  @override
  String get notiSettingsCopyWeekdays => 'Copy to weekdays';

  @override
  String get notiSettingsCopyWeekend => 'Copy to weekend';

  @override
  String notiSettingsWeeklyLabel(Object weekday) {
    return 'Every $weekday';
  }

  @override
  String get mealHeaderNo => 'No';

  @override
  String get mealHeaderMenu => 'Menu';

  @override
  String get mealHeaderKcal => 'kcal';

  @override
  String get notiCopyAllTitle => 'Copy to all days';

  @override
  String get notiCopyAllMessage => 'This will overwrite the time for all days. Continue?';

  @override
  String get notiCopyWeekdaysTitle => 'Copy to weekdays';

  @override
  String get notiCopyWeekdaysMessage => 'This will overwrite the time for Mon–Fri. Continue?';

  @override
  String get notiCopyWeekendTitle => 'Copy to weekend';

  @override
  String get notiCopyWeekendMessage => 'This will set the same time for Sat & Sun. Continue?';

  @override
  String get notiConfirmYes => 'Yes';

  @override
  String get notiConfirmNo => 'No';

  @override
  String get awardTitleFirst => 'First training achieved!';

  @override
  String awardTitleDays(Object dayCount) {
    return 'Streak of $dayCount days completed!';
  }

  @override
  String get awardTitleMax => 'New record reached!';

  @override
  String get awardLabelDate => 'Date:';

  @override
  String get awardLabelExercise => 'Exercise:';

  @override
  String get awardLabelPrevious => 'Previous record:';

  @override
  String get awardFooterMessage => 'Great job!';

  @override
  String awardBadgeDay(Object dayCount) {
    return 'Day $dayCount';
  }

  @override
  String get awardSaved => 'Saved to your album';

  @override
  String get awardShare => 'Share';

  @override
  String get awardClose => 'Close';
}
