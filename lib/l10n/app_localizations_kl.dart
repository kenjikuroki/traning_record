// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kalaallisut Greenlandic (`kl`).
class AppLocalizationsKl extends AppLocalizations {
  AppLocalizationsKl([String locale = 'kl']) : super(locale);

  @override
  String get appTitle => 'T-Training Record';

  @override
  String get selectTrainingPart => 'Select Training Part';

  @override
  String get addPart => '+ Part';

  @override
  String get addExercise => '+ Exercise';

  @override
  String get partLimitReached => 'You can add up to 10 parts.';

  @override
  String get exerciseLimitReached => 'You can add up to 15 exercises.';

  @override
  String get settings => 'Settings';

  @override
  String get trainingParts => 'Training Parts';

  @override
  String get setCount => 'Set Count';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get systemDefault => 'System Default';

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
  String get kg => 'kg';

  @override
  String get reps => 'reps';

  @override
  String get min => 'min';

  @override
  String get sec => 'sec';

  @override
  String get sets => 'sets';

  @override
  String get menuName => 'Menu Name';

  @override
  String get calendar => 'calendar';

  @override
  String get noRecordMessage => 'No records found for the selected date.';

  @override
  String get weightUnit => 'Weight Unit';

  @override
  String get lbs => 'lbs';

  @override
  String get deleteMenuConfirmationTitle => 'Delete Exercise?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get addExercisePlaceholder => 'Add exercise';

  @override
  String get time => 'Time';

  @override
  String get minutesHint => 'Min';

  @override
  String get secondsHint => 'Sec';

  @override
  String get graph => 'graph';

  @override
  String get favorites => 'favorites';

  @override
  String get selectExercise => 'Select Exercise';

  @override
  String get noGraphData => 'No records found';

  @override
  String get graphScreenTitle => 'Graph';

  @override
  String favorited(Object menuName) {
    return '$menuName added to favorites';
  }

  @override
  String unfavorited(Object menuName) {
    return '$menuName removed from favorites';
  }

  @override
  String get dayDisplay => 'Day';

  @override
  String get weekDisplay => 'Week';

  @override
  String get distance => 'distance';

  @override
  String get km => 'km';

  @override
  String get m => 'm';
}
