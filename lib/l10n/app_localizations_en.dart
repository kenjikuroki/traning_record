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
  String get weightUnit => 'Weight Unit';

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
  String get reps => 'reps';

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
  String get addExercisePlaceholder => 'Add exercise';

  @override
  String get addExercise => '+ Exercise';

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
  String get bodyWeight => 'Body weight';

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
  String get settingsDailyMediaCap => 'Daily photo limit';

  @override
  String get settingsDailyMediaCapDesc => 'Max photos you can save per day';

  @override
  String get settingsDailyMediaCapShort => 'Photo limit';

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
  String get results => 'Results';

  @override
  String deleteSelectedConfirmTitle(Object count) {
    return 'Delete $count item(s)?';
  }

  @override
  String get albumEmptyMessage => 'Take photos from the Record screen and they will appear here. Keep your training progress in the album.';

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
  String get hintRecordFirst => 'Start by recording a workout or your body weight.';

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
}
