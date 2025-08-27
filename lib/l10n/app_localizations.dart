import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'T-Training Record'**
  String get appTitle;

  /// No description provided for @selectTrainingPart.
  ///
  /// In en, this message translates to:
  /// **'Select Training Part'**
  String get selectTrainingPart;

  /// No description provided for @addPart.
  ///
  /// In en, this message translates to:
  /// **'+ Part'**
  String get addPart;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'+ Exercise'**
  String get addExercise;

  /// No description provided for @partLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 10 parts.'**
  String get partLimitReached;

  /// No description provided for @exerciseLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 15 exercises.'**
  String get exerciseLimitReached;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @trainingParts.
  ///
  /// In en, this message translates to:
  /// **'Training Parts'**
  String get trainingParts;

  /// No description provided for @setCount.
  ///
  /// In en, this message translates to:
  /// **'Set Count'**
  String get setCount;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @aerobicExercise.
  ///
  /// In en, this message translates to:
  /// **'Aerobic Exercise'**
  String get aerobicExercise;

  /// No description provided for @arm.
  ///
  /// In en, this message translates to:
  /// **'Arm'**
  String get arm;

  /// No description provided for @chest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @shoulder.
  ///
  /// In en, this message translates to:
  /// **'Shoulder'**
  String get shoulder;

  /// No description provided for @leg.
  ///
  /// In en, this message translates to:
  /// **'Leg'**
  String get leg;

  /// No description provided for @fullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get fullBody;

  /// No description provided for @other1.
  ///
  /// In en, this message translates to:
  /// **'Other 1'**
  String get other1;

  /// No description provided for @other2.
  ///
  /// In en, this message translates to:
  /// **'Other 2'**
  String get other2;

  /// No description provided for @other3.
  ///
  /// In en, this message translates to:
  /// **'Other 3'**
  String get other3;

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'reps'**
  String get reps;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @sec.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get sec;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'sets'**
  String get sets;

  /// No description provided for @menuName.
  ///
  /// In en, this message translates to:
  /// **'Menu Name'**
  String get menuName;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'calendar'**
  String get calendar;

  /// No description provided for @noRecordMessage.
  ///
  /// In en, this message translates to:
  /// **'No records found for the selected date.'**
  String get noRecordMessage;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'Weight Unit'**
  String get weightUnit;

  /// No description provided for @lbs.
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get lbs;

  /// No description provided for @deleteMenuConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise?'**
  String get deleteMenuConfirmationTitle;

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

  /// No description provided for @addExercisePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercisePlaceholder;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @minutesHint.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minutesHint;

  /// No description provided for @secondsHint.
  ///
  /// In en, this message translates to:
  /// **'Sec'**
  String get secondsHint;

  /// No description provided for @graph.
  ///
  /// In en, this message translates to:
  /// **'graph'**
  String get graph;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'favorites'**
  String get favorites;

  /// No description provided for @selectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select Exercise'**
  String get selectExercise;

  /// No description provided for @noGraphData.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get noGraphData;

  /// No description provided for @graphScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get graphScreenTitle;

  /// No description provided for @favorited.
  ///
  /// In en, this message translates to:
  /// **'{menuName} added to favorites'**
  String favorited(Object menuName);

  /// No description provided for @unfavorited.
  ///
  /// In en, this message translates to:
  /// **'{menuName} removed from favorites'**
  String unfavorited(Object menuName);

  /// No description provided for @dayDisplay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayDisplay;

  /// No description provided for @weekDisplay.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekDisplay;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'distance'**
  String get distance;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get km;

  /// No description provided for @m.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get m;

  /// No description provided for @bodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Body weight'**
  String get bodyWeight;

  /// No description provided for @enterYourWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter your weight'**
  String get enterYourWeight;

  /// No description provided for @bodyWeightTracking.
  ///
  /// In en, this message translates to:
  /// **'Body Weight Tracking'**
  String get bodyWeightTracking;

  /// No description provided for @selectBodyParts.
  ///
  /// In en, this message translates to:
  /// **'Select body parts to display'**
  String get selectBodyParts;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'unit'**
  String get unit;

  /// No description provided for @defaultSets.
  ///
  /// In en, this message translates to:
  /// **'Default Sets'**
  String get defaultSets;

  /// No description provided for @menuNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter menu name'**
  String get menuNameHint;

  /// No description provided for @durationHint.
  ///
  /// In en, this message translates to:
  /// **'min:sec'**
  String get durationHint;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @recordScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordScreenTitle;

  /// No description provided for @calendarScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarScreenTitle;

  /// No description provided for @settingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreenTitle;

  /// No description provided for @addMenu.
  ///
  /// In en, this message translates to:
  /// **'Add Menu'**
  String get addMenu;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @partAlreadySelected.
  ///
  /// In en, this message translates to:
  /// **'This part is already selected.'**
  String get partAlreadySelected;

  /// No description provided for @distanceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter distance'**
  String get distanceHint;

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @selectPartPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select part'**
  String get selectPartPlaceholder;

  /// No description provided for @hintCalendarTapDate.
  ///
  /// In en, this message translates to:
  /// **'Select a date to record.'**
  String get hintCalendarTapDate;

  /// No description provided for @hintGraphFavorite.
  ///
  /// In en, this message translates to:
  /// **'Mark as favorite to quickly recall later.'**
  String get hintGraphFavorite;

  /// No description provided for @hintGraphChartArea.
  ///
  /// In en, this message translates to:
  /// **'The chart of your recorded data will appear here.'**
  String get hintGraphChartArea;

  /// No description provided for @hintGraphSelectPart.
  ///
  /// In en, this message translates to:
  /// **'Select body part and exercise.'**
  String get hintGraphSelectPart;

  /// No description provided for @hintRecordSelectPart.
  ///
  /// In en, this message translates to:
  /// **'Please select the body part you will train.'**
  String get hintRecordSelectPart;

  /// No description provided for @coachBubbleSemantic.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get coachBubbleSemantic;

  /// No description provided for @hintRecordOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'You can change default sets in Settings.'**
  String get hintRecordOpenSettings;

  /// No description provided for @hintRecordExerciseField.
  ///
  /// In en, this message translates to:
  /// **'Enter exercise name here.'**
  String get hintRecordExerciseField;

  /// No description provided for @hintRecordAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Tap here to add the exercise.'**
  String get hintRecordAddExercise;

  /// No description provided for @hintRecordChangePart.
  ///
  /// In en, this message translates to:
  /// **'You can add another body part here.'**
  String get hintRecordChangePart;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'+ Set'**
  String get addSet;

  /// No description provided for @openAddMenu.
  ///
  /// In en, this message translates to:
  /// **'Open add menu'**
  String get openAddMenu;

  /// No description provided for @hintRecordFab.
  ///
  /// In en, this message translates to:
  /// **'Add a set, exercise, or body part from here'**
  String get hintRecordFab;

  /// No description provided for @settingsStopwatchTimerVisibility.
  ///
  /// In en, this message translates to:
  /// **'Show Stopwatch/Timer'**
  String get settingsStopwatchTimerVisibility;

  /// No description provided for @changeSetCount.
  ///
  /// In en, this message translates to:
  /// **'Change Set Count'**
  String get changeSetCount;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @unitTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitTitle;

  /// No description provided for @useDarkMode.
  ///
  /// In en, this message translates to:
  /// **'dark mode'**
  String get useDarkMode;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
