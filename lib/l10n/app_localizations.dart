import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_id.dart';
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
    Locale('es'),
    Locale('id'),
    Locale('ja')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'T-Training Record'**
  String get appTitle;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'calendar'**
  String get calendar;

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

  /// No description provided for @graphScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get graphScreenTitle;

  /// No description provided for @albumTitle.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get albumTitle;

  /// Filter chip label to show every photo in the album.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get albumFilterAll;

  /// Filter chip label to show only award images.
  ///
  /// In en, this message translates to:
  /// **'Awards'**
  String get albumFilterAwards;

  /// Small ribbon label shown on award images in the album.
  ///
  /// In en, this message translates to:
  /// **'AWARD'**
  String get albumAwardRibbon;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

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

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enable camera permission'**
  String get cameraPermissionRequired;

  /// No description provided for @stopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatch;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @timerTime.
  ///
  /// In en, this message translates to:
  /// **'Timer duration'**
  String get timerTime;

  /// No description provided for @tapNumberToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap numbers to edit'**
  String get tapNumberToEdit;

  /// No description provided for @targetFmt.
  ///
  /// In en, this message translates to:
  /// **'Target {time} ({hint})'**
  String targetFmt(Object hint, Object time);

  /// No description provided for @statusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get statusRunning;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String hours(Object hours);

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// No description provided for @lbs.
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get lbs;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'unit'**
  String get unit;

  /// No description provided for @unitTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitTitle;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightUnit;

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

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

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

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'sets'**
  String get sets;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setLabel;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

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

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @perDayUnit.
  ///
  /// In en, this message translates to:
  /// **'photos/day'**
  String get perDayUnit;

  /// No description provided for @trainingParts.
  ///
  /// In en, this message translates to:
  /// **'Training Parts'**
  String get trainingParts;

  /// No description provided for @selectTrainingPart.
  ///
  /// In en, this message translates to:
  /// **'Select Training Part'**
  String get selectTrainingPart;

  /// No description provided for @selectPartPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select part'**
  String get selectPartPlaceholder;

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

  /// No description provided for @abs.
  ///
  /// In en, this message translates to:
  /// **'Abs'**
  String get abs;

  /// No description provided for @bodyWeightTraining.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyWeightTraining;

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

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @selectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select Exercise'**
  String get selectExercise;

  /// No description provided for @menuName.
  ///
  /// In en, this message translates to:
  /// **'Menu Name'**
  String get menuName;

  /// No description provided for @menuNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter menu name'**
  String get menuNameHint;

  /// No description provided for @addExercisePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select exercise'**
  String get addExercisePlaceholder;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'+ Exercise'**
  String get addExercise;

  /// No description provided for @addNewExercise.
  ///
  /// In en, this message translates to:
  /// **'+ New'**
  String get addNewExercise;

  /// No description provided for @customExerciseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Exercise'**
  String get customExerciseDialogTitle;

  /// No description provided for @customExerciseNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter exercise name'**
  String get customExerciseNameHint;

  /// No description provided for @customExerciseNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an exercise name'**
  String get customExerciseNameRequired;

  /// No description provided for @customExerciseDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This exercise is already registered'**
  String get customExerciseDuplicate;

  /// No description provided for @customExercisePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved exercises yet. Tap + to add one.'**
  String get customExercisePickerEmpty;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @removeCustomExercises.
  ///
  /// In en, this message translates to:
  /// **'Remove Custom Exercises'**
  String get removeCustomExercises;

  /// No description provided for @customExerciseRemovalHint.
  ///
  /// In en, this message translates to:
  /// **'Delete previously added custom exercises.'**
  String get customExerciseRemovalHint;

  /// No description provided for @noCustomExercises.
  ///
  /// In en, this message translates to:
  /// **'No custom exercises have been added.'**
  String get noCustomExercises;

  /// No description provided for @selectExerciseToDelete.
  ///
  /// In en, this message translates to:
  /// **'Select exercise to delete'**
  String get selectExerciseToDelete;

  /// No description provided for @customExerciseRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {exerciseName}.'**
  String customExerciseRemoved(Object exerciseName);

  /// No description provided for @addMenu.
  ///
  /// In en, this message translates to:
  /// **'Add Menu'**
  String get addMenu;

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

  /// No description provided for @partAlreadySelected.
  ///
  /// In en, this message translates to:
  /// **'This part is already selected.'**
  String get partAlreadySelected;

  /// No description provided for @setCount.
  ///
  /// In en, this message translates to:
  /// **'Set Count'**
  String get setCount;

  /// No description provided for @defaultSets.
  ///
  /// In en, this message translates to:
  /// **'Default Sets'**
  String get defaultSets;

  /// No description provided for @bodyWeight.
  ///
  /// In en, this message translates to:
  /// **'BW'**
  String get bodyWeight;

  /// No description provided for @weightCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightCardTitle;

  /// No description provided for @weightCardExtraFieldsHint.
  ///
  /// In en, this message translates to:
  /// **'You can add fields like body fat or waist from Settings. Weight units (kg/lbs) can also be changed from Settings.'**
  String get weightCardExtraFieldsHint;

  /// No description provided for @bodyWeightTracking.
  ///
  /// In en, this message translates to:
  /// **'Body Weight Tracking'**
  String get bodyWeightTracking;

  /// No description provided for @durationHint.
  ///
  /// In en, this message translates to:
  /// **'min:sec'**
  String get durationHint;

  /// No description provided for @distanceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter distance'**
  String get distanceHint;

  /// No description provided for @noRecordMessage.
  ///
  /// In en, this message translates to:
  /// **'No records found for the selected date.'**
  String get noRecordMessage;

  /// No description provided for @coachBubbleSemantic.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get coachBubbleSemantic;

  /// No description provided for @hintRecordSelectPart.
  ///
  /// In en, this message translates to:
  /// **'Please select the body part you will train.'**
  String get hintRecordSelectPart;

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

  /// No description provided for @hintRecordOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'You can change default sets in Settings.'**
  String get hintRecordOpenSettings;

  /// No description provided for @hintRecordFab.
  ///
  /// In en, this message translates to:
  /// **'Add a part, exercise, photo, or memo from here.'**
  String get hintRecordFab;

  /// No description provided for @hintCalendarTapDate.
  ///
  /// In en, this message translates to:
  /// **'Select a date to record.'**
  String get hintCalendarTapDate;

  /// No description provided for @hintGraphFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add frequently viewed data to Favorites.'**
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

  /// No description provided for @discardLongPressLabel.
  ///
  /// In en, this message translates to:
  /// **'Discard (long press)'**
  String get discardLongPressLabel;

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

  /// No description provided for @noGraphData.
  ///
  /// In en, this message translates to:
  /// **'Select a body part/exercise or weight to display the graph.'**
  String get noGraphData;

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

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'+ Photo'**
  String get addPhoto;

  /// No description provided for @dialogAddPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get dialogAddPhotoTitle;

  /// No description provided for @actionTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get actionTakePhoto;

  /// No description provided for @progressSnaps.
  ///
  /// In en, this message translates to:
  /// **'Progress snaps'**
  String get progressSnaps;

  /// No description provided for @mediaReachedDailyCap.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s save limit.'**
  String get mediaReachedDailyCap;

  /// No description provided for @mediaGoToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get mediaGoToAlbum;

  /// No description provided for @mediaGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get mediaGoToSettings;

  /// No description provided for @mediaDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mediaDelete;

  /// No description provided for @mediaCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mediaCancel;

  /// No description provided for @mediaUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mediaUndo;

  /// No description provided for @photoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the image'**
  String get photoLoadFailed;

  /// No description provided for @discardPhotoConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this photo?'**
  String get discardPhotoConfirmTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

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

  /// No description provided for @useDarkMode.
  ///
  /// In en, this message translates to:
  /// **'dark mode'**
  String get useDarkMode;

  /// No description provided for @selectBodyParts.
  ///
  /// In en, this message translates to:
  /// **'Select body parts to display'**
  String get selectBodyParts;

  /// No description provided for @changeSetCount.
  ///
  /// In en, this message translates to:
  /// **'Change Set Count'**
  String get changeSetCount;

  /// No description provided for @settingsStopwatchTimerVisibility.
  ///
  /// In en, this message translates to:
  /// **'Show Stopwatch/Timer'**
  String get settingsStopwatchTimerVisibility;

  /// No description provided for @intervalTimer.
  ///
  /// In en, this message translates to:
  /// **'Interval timer'**
  String get intervalTimer;

  /// No description provided for @settingsDailyMediaCap.
  ///
  /// In en, this message translates to:
  /// **'Daily photo limit'**
  String get settingsDailyMediaCap;

  /// No description provided for @settingsDailyMediaCapDesc.
  ///
  /// In en, this message translates to:
  /// **'Max photos you can save per day'**
  String get settingsDailyMediaCapDesc;

  /// No description provided for @settingsDailyMediaCapShort.
  ///
  /// In en, this message translates to:
  /// **'Photo limit'**
  String get settingsDailyMediaCapShort;

  /// No description provided for @recordDisplayOptions.
  ///
  /// In en, this message translates to:
  /// **'Display options'**
  String get recordDisplayOptions;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @limitOff.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get limitOff;

  /// No description provided for @autoPausedIdle5h.
  ///
  /// In en, this message translates to:
  /// **'Paused after 5 hours of inactivity'**
  String get autoPausedIdle5h;

  /// No description provided for @autoPausedOver5h.
  ///
  /// In en, this message translates to:
  /// **'Paused after running over 5 hours'**
  String get autoPausedOver5h;

  /// No description provided for @autoPausedBackground30m.
  ///
  /// In en, this message translates to:
  /// **'Paused after 30+ minutes in background'**
  String get autoPausedBackground30m;

  /// No description provided for @partLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 10 parts.'**
  String get partLimitReached;

  /// No description provided for @removePersonalCardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide personal card'**
  String get removePersonalCardTooltip;

  /// No description provided for @removePartCardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove part card'**
  String get removePartCardTooltip;

  /// No description provided for @deletePersonalConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide personal metrics card?'**
  String get deletePersonalConfirmationTitle;

  /// No description provided for @deletePartConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this part card?'**
  String get deletePartConfirmationTitle;

  /// No description provided for @exerciseLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 15 exercises.'**
  String get exerciseLimitReached;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hour;

  /// No description provided for @enterGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get enterGoal;

  /// No description provided for @deleteMenuConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise?'**
  String get deleteMenuConfirmationTitle;

  /// No description provided for @addPart.
  ///
  /// In en, this message translates to:
  /// **'+ Part'**
  String get addPart;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(Object count);

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Records for {date}'**
  String results(Object date);

  /// No description provided for @resultsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get resultsCopy;

  /// No description provided for @resultsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied results to clipboard'**
  String get resultsCopied;

  /// No description provided for @deleteSelectedConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} item(s)?'**
  String deleteSelectedConfirmTitle(Object count);

  /// No description provided for @albumEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Save your selfies in the album to track your training progress.'**
  String get albumEmptyMessage;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @addMemo.
  ///
  /// In en, this message translates to:
  /// **'+ Memo'**
  String get addMemo;

  /// No description provided for @memo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get memo;

  /// No description provided for @memoTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get memoTitle;

  /// No description provided for @memoBody.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get memoBody;

  /// No description provided for @memoTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter title'**
  String get memoTitlePlaceholder;

  /// No description provided for @memoBodyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter memo'**
  String get memoBodyPlaceholder;

  /// No description provided for @satisfaction.
  ///
  /// In en, this message translates to:
  /// **'Satisfaction'**
  String get satisfaction;

  /// No description provided for @satisfactionBad.
  ///
  /// In en, this message translates to:
  /// **'Bad'**
  String get satisfactionBad;

  /// No description provided for @satisfactionOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get satisfactionOkay;

  /// No description provided for @satisfactionGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get satisfactionGood;

  /// No description provided for @totalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total Volume'**
  String get totalVolume;

  /// No description provided for @totalVolumeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get totalVolumeCurrent;

  /// No description provided for @totalVolumePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get totalVolumePrevious;

  /// No description provided for @totalVolumeDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get totalVolumeDifference;

  /// No description provided for @valueNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'--'**
  String get valueNotAvailable;

  /// No description provided for @expandCard.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expandCard;

  /// No description provided for @collapseCard.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapseCard;

  /// No description provided for @hintRecordFirst.
  ///
  /// In en, this message translates to:
  /// **'Let’s start by recording a workout. Tap \"Select Training Part\" to begin.'**
  String get hintRecordFirst;

  /// No description provided for @unitChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Units can be changed from Settings.'**
  String get unitChangeHint;

  /// No description provided for @hintGraphSetGoal.
  ///
  /// In en, this message translates to:
  /// **'Set your goal.'**
  String get hintGraphSetGoal;

  /// No description provided for @personalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personalSettingsTitle;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get genderUnspecified;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDate;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @waist.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get waist;

  /// No description provided for @bodyFatTracking.
  ///
  /// In en, this message translates to:
  /// **'Body fat tracking'**
  String get bodyFatTracking;

  /// No description provided for @waistTracking.
  ///
  /// In en, this message translates to:
  /// **'Waist tracking'**
  String get waistTracking;

  /// No description provided for @bmiTracking.
  ///
  /// In en, this message translates to:
  /// **'BMI tracking'**
  String get bmiTracking;

  /// No description provided for @unitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @unitFtIn.
  ///
  /// In en, this message translates to:
  /// **'ft/in'**
  String get unitFtIn;

  /// No description provided for @unitFt.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get unitFt;

  /// No description provided for @unitIn.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get unitIn;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body fat'**
  String get bodyFat;

  /// No description provided for @bmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmi;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @bodyFatPercentage.
  ///
  /// In en, this message translates to:
  /// **'Body Fat %'**
  String get bodyFatPercentage;

  /// No description provided for @percentSymbol.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get percentSymbol;

  /// No description provided for @cm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get cm;

  /// No description provided for @standards.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get standards;

  /// No description provided for @bmiStdRange.
  ///
  /// In en, this message translates to:
  /// **'BMI {min}–{max}'**
  String bmiStdRange(Object max, Object min);

  /// No description provided for @bodyFatStdRange.
  ///
  /// In en, this message translates to:
  /// **'Body fat {min}–{max}{percent}'**
  String bodyFatStdRange(Object max, Object min, Object percent);

  /// No description provided for @waistStdSingle.
  ///
  /// In en, this message translates to:
  /// **'Waist {value}{cm}'**
  String waistStdSingle(Object cm, Object value);

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @maleShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get maleShort;

  /// No description provided for @femaleShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get femaleShort;

  /// No description provided for @mile.
  ///
  /// In en, this message translates to:
  /// **'mile'**
  String get mile;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @lengthNote.
  ///
  /// In en, this message translates to:
  /// **'Height and waist follow the Length unit (cm or ft·in).'**
  String get lengthNote;

  /// No description provided for @graphTitle.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get graphTitle;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @aerobicCalorieToggle.
  ///
  /// In en, this message translates to:
  /// **'Estimate aerobic calories'**
  String get aerobicCalorieToggle;

  /// No description provided for @calorie.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calorie;

  /// No description provided for @kcalUnit.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcalUnit;

  /// No description provided for @meal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get meal;

  /// No description provided for @mealAdd.
  ///
  /// In en, this message translates to:
  /// **'+ Meal'**
  String get mealAdd;

  /// No description provided for @mealCategory.
  ///
  /// In en, this message translates to:
  /// **'Meal category'**
  String get mealCategory;

  /// No description provided for @mealMorning.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealMorning;

  /// No description provided for @mealNoon.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealNoon;

  /// No description provided for @mealEvening.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealEvening;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @mealItem.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get mealItem;

  /// No description provided for @mealSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get mealSubtotal;

  /// No description provided for @mealTotalToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meal total'**
  String get mealTotalToday;

  /// No description provided for @mealDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all meals?'**
  String get mealDeleteConfirmTitle;

  /// No description provided for @addMealItem.
  ///
  /// In en, this message translates to:
  /// **'+ Menu'**
  String get addMealItem;

  /// No description provided for @bmrTitle.
  ///
  /// In en, this message translates to:
  /// **'BMR:'**
  String get bmrTitle;

  /// No description provided for @bmrTitleShort.
  ///
  /// In en, this message translates to:
  /// **'BMR'**
  String get bmrTitleShort;

  /// No description provided for @bmrDiffShort.
  ///
  /// In en, this message translates to:
  /// **'Intake - BMR'**
  String get bmrDiffShort;

  /// No description provided for @dailyBalanceSummary.
  ///
  /// In en, this message translates to:
  /// **'Intake − (BMR + Aerobic)'**
  String get dailyBalanceSummary;

  /// No description provided for @bmrDeficit.
  ///
  /// In en, this message translates to:
  /// **'Difference (Intake − BMR)'**
  String get bmrDeficit;

  /// No description provided for @bmrNeedPersonalNotice.
  ///
  /// In en, this message translates to:
  /// **'Weight, height, birth date, and gender are required. Set them in Settings → Personal.'**
  String get bmrNeedPersonalNotice;

  /// No description provided for @mealInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter menu name and kcal'**
  String get mealInputHint;

  /// No description provided for @mealEmptyNotice.
  ///
  /// In en, this message translates to:
  /// **'No entries'**
  String get mealEmptyNotice;

  /// No description provided for @mealRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore meal data'**
  String get mealRestoreFailed;

  /// No description provided for @calorieOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'You can edit this value'**
  String get calorieOverrideHint;

  /// No description provided for @calorieHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'About the calorie estimation'**
  String get calorieHelpTitle;

  /// No description provided for @calorieHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Formula: calories = MET × weight(kg) × time(hours).\n\nThe MET value is estimated from the exercise name. Because this is only an approximation, feel free to overwrite it with the reading from your smartwatch or other tracker.'**
  String get calorieHelpBody;

  /// No description provided for @dailyCalorieTotal.
  ///
  /// In en, this message translates to:
  /// **'Total calories'**
  String get dailyCalorieTotal;

  /// No description provided for @chooseFromPresets.
  ///
  /// In en, this message translates to:
  /// **'Choose from presets'**
  String get chooseFromPresets;

  /// No description provided for @presetRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get presetRunning;

  /// No description provided for @presetWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get presetWalking;

  /// No description provided for @presetCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get presetCycling;

  /// No description provided for @presetExerciseBike.
  ///
  /// In en, this message translates to:
  /// **'Exercise bike'**
  String get presetExerciseBike;

  /// No description provided for @presetElliptical.
  ///
  /// In en, this message translates to:
  /// **'Elliptical'**
  String get presetElliptical;

  /// No description provided for @presetRowing.
  ///
  /// In en, this message translates to:
  /// **'Rowing'**
  String get presetRowing;

  /// No description provided for @aerobicPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose or type exercise'**
  String get aerobicPickerTitle;

  /// No description provided for @aerobicCalorieUnknownHint.
  ///
  /// In en, this message translates to:
  /// **'Could not estimate calories for this exercise name. Please enter the value obtained from another device if available.'**
  String get aerobicCalorieUnknownHint;

  /// No description provided for @aerobicCalorieInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'About Calorie Estimation'**
  String get aerobicCalorieInfoTitle;

  /// No description provided for @aerobicCalorieInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Calories are estimated as MET × weight (kg) × time (hours). MET is inferred from the exercise name, distance, and duration.\n\nBecause this is only an approximation, please overwrite it with the value obtained from your smartwatch or other tracker if available. Distance or time must be provided for the estimate.\n\nEnvironmental conditions and your physical condition affect calorie expenditure. Remember to take breaks and stay hydrated.'**
  String get aerobicCalorieInfoBody;

  /// No description provided for @aerobicCalorieWeightRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your body weight in Personal settings to enable calorie estimation.'**
  String get aerobicCalorieWeightRequired;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @noRecords.
  ///
  /// In en, this message translates to:
  /// **'No records'**
  String get noRecords;

  /// No description provided for @editThisDay.
  ///
  /// In en, this message translates to:
  /// **'Edit this day'**
  String get editThisDay;

  /// No description provided for @addOnThisDay.
  ///
  /// In en, this message translates to:
  /// **'Add on this day'**
  String get addOnThisDay;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change theme?'**
  String get settingsThemeConfirmTitle;

  /// No description provided for @settingsThemeConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will update the app\'s colors. Continue?'**
  String get settingsThemeConfirmMessage;

  /// No description provided for @themeMonotone.
  ///
  /// In en, this message translates to:
  /// **'Monotone'**
  String get themeMonotone;

  /// No description provided for @themeRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get themeRed;

  /// No description provided for @themeBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get themeBlue;

  /// No description provided for @themeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get themeGreen;

  /// No description provided for @themeYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get themeYellow;

  /// No description provided for @themeColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get themeColorTitle;

  /// No description provided for @totalVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total volume'**
  String get totalVolumeLabel;

  /// No description provided for @previousLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousLabel;

  /// No description provided for @currentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentLabel;

  /// No description provided for @hintCalendarGotoRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to open the record screen'**
  String get hintCalendarGotoRecord;

  /// No description provided for @hintRecordTapExerciseCard.
  ///
  /// In en, this message translates to:
  /// **'Tap the exercise card'**
  String get hintRecordTapExerciseCard;

  /// No description provided for @hintRecordPickExercise.
  ///
  /// In en, this message translates to:
  /// **'Please select an exercise.'**
  String get hintRecordPickExercise;

  /// No description provided for @hintRecordCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Check after entering weight and reps.'**
  String get hintRecordCheckbox;

  /// No description provided for @hintRecordSave.
  ///
  /// In en, this message translates to:
  /// **'Tap Save when finished.'**
  String get hintRecordSave;

  /// No description provided for @exerciseAerobic01.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get exerciseAerobic01;

  /// No description provided for @exerciseAerobic02.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get exerciseAerobic02;

  /// No description provided for @exerciseAerobic03.
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get exerciseAerobic03;

  /// No description provided for @exerciseAerobic04.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get exerciseAerobic04;

  /// No description provided for @exerciseAerobic05.
  ///
  /// In en, this message translates to:
  /// **'Stationary Bike'**
  String get exerciseAerobic05;

  /// No description provided for @exerciseAerobic06.
  ///
  /// In en, this message translates to:
  /// **'Elliptical'**
  String get exerciseAerobic06;

  /// No description provided for @exerciseAerobic07.
  ///
  /// In en, this message translates to:
  /// **'Rowing Machine'**
  String get exerciseAerobic07;

  /// No description provided for @exerciseAerobic08.
  ///
  /// In en, this message translates to:
  /// **'Stair Climber'**
  String get exerciseAerobic08;

  /// No description provided for @exerciseAerobic09.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get exerciseAerobic09;

  /// No description provided for @exerciseAerobic10.
  ///
  /// In en, this message translates to:
  /// **'Jump Rope'**
  String get exerciseAerobic10;

  /// No description provided for @exerciseAerobic11.
  ///
  /// In en, this message translates to:
  /// **'Aerobics'**
  String get exerciseAerobic11;

  /// No description provided for @exerciseArm01.
  ///
  /// In en, this message translates to:
  /// **'Barbell Curl'**
  String get exerciseArm01;

  /// No description provided for @exerciseArm02.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Curl'**
  String get exerciseArm02;

  /// No description provided for @exerciseArm03.
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Curl'**
  String get exerciseArm03;

  /// No description provided for @exerciseArm04.
  ///
  /// In en, this message translates to:
  /// **'Cable Curl'**
  String get exerciseArm04;

  /// No description provided for @exerciseArm05.
  ///
  /// In en, this message translates to:
  /// **'Preacher Curl'**
  String get exerciseArm05;

  /// No description provided for @exerciseArm06.
  ///
  /// In en, this message translates to:
  /// **'Hammer Curl'**
  String get exerciseArm06;

  /// No description provided for @exerciseArm07.
  ///
  /// In en, this message translates to:
  /// **'Concentration Curl'**
  String get exerciseArm07;

  /// No description provided for @exerciseArm08.
  ///
  /// In en, this message translates to:
  /// **'Reverse Curl'**
  String get exerciseArm08;

  /// No description provided for @exerciseArm09.
  ///
  /// In en, this message translates to:
  /// **'Cable Triceps Pushdown'**
  String get exerciseArm09;

  /// No description provided for @exerciseArm10.
  ///
  /// In en, this message translates to:
  /// **'Skull Crusher'**
  String get exerciseArm10;

  /// No description provided for @exerciseArm11.
  ///
  /// In en, this message translates to:
  /// **'Overhead Triceps Extension'**
  String get exerciseArm11;

  /// No description provided for @exerciseArm12.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Triceps Kickback'**
  String get exerciseArm12;

  /// No description provided for @exerciseArm13.
  ///
  /// In en, this message translates to:
  /// **'Cable Overhead Triceps Extension'**
  String get exerciseArm13;

  /// No description provided for @exerciseArm14.
  ///
  /// In en, this message translates to:
  /// **'Close-grip Bench Press'**
  String get exerciseArm14;

  /// No description provided for @exerciseArm15.
  ///
  /// In en, this message translates to:
  /// **'Wrist Curl'**
  String get exerciseArm15;

  /// No description provided for @exerciseChest01.
  ///
  /// In en, this message translates to:
  /// **'Barbell Bench Press'**
  String get exerciseChest01;

  /// No description provided for @exerciseChest02.
  ///
  /// In en, this message translates to:
  /// **'Incline Bench Press'**
  String get exerciseChest02;

  /// No description provided for @exerciseChest03.
  ///
  /// In en, this message translates to:
  /// **'Decline Bench Press'**
  String get exerciseChest03;

  /// No description provided for @exerciseChest04.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Bench Press'**
  String get exerciseChest04;

  /// No description provided for @exerciseChest05.
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Press'**
  String get exerciseChest05;

  /// No description provided for @exerciseChest06.
  ///
  /// In en, this message translates to:
  /// **'Decline Dumbbell Press'**
  String get exerciseChest06;

  /// No description provided for @exerciseChest07.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Flye'**
  String get exerciseChest07;

  /// No description provided for @exerciseChest08.
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Flye'**
  String get exerciseChest08;

  /// No description provided for @exerciseChest09.
  ///
  /// In en, this message translates to:
  /// **'Cable Crossover'**
  String get exerciseChest09;

  /// No description provided for @exerciseChest10.
  ///
  /// In en, this message translates to:
  /// **'Pec Deck Flye'**
  String get exerciseChest10;

  /// No description provided for @exerciseChest11.
  ///
  /// In en, this message translates to:
  /// **'Chest Press'**
  String get exerciseChest11;

  /// No description provided for @exerciseChest12.
  ///
  /// In en, this message translates to:
  /// **'Smith Machine Bench Press'**
  String get exerciseChest12;

  /// No description provided for @exerciseChest13.
  ///
  /// In en, this message translates to:
  /// **'Smith Machine Incline Press'**
  String get exerciseChest13;

  /// No description provided for @exerciseChest14.
  ///
  /// In en, this message translates to:
  /// **'Dips'**
  String get exerciseChest14;

  /// No description provided for @exerciseChest15.
  ///
  /// In en, this message translates to:
  /// **'Weighted / Machine Push-up'**
  String get exerciseChest15;

  /// No description provided for @exerciseBack01.
  ///
  /// In en, this message translates to:
  /// **'Deadlift'**
  String get exerciseBack01;

  /// No description provided for @exerciseBack02.
  ///
  /// In en, this message translates to:
  /// **'Lat Pulldown'**
  String get exerciseBack02;

  /// No description provided for @exerciseBack03.
  ///
  /// In en, this message translates to:
  /// **'Reverse-grip Lat Pulldown'**
  String get exerciseBack03;

  /// No description provided for @exerciseBack04.
  ///
  /// In en, this message translates to:
  /// **'Barbell Bent-over Row'**
  String get exerciseBack04;

  /// No description provided for @exerciseBack05.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell One-arm Row'**
  String get exerciseBack05;

  /// No description provided for @exerciseBack06.
  ///
  /// In en, this message translates to:
  /// **'Seated Row'**
  String get exerciseBack06;

  /// No description provided for @exerciseBack07.
  ///
  /// In en, this message translates to:
  /// **'T-bar Row'**
  String get exerciseBack07;

  /// No description provided for @exerciseBack08.
  ///
  /// In en, this message translates to:
  /// **'Weighted Pull-up'**
  String get exerciseBack08;

  /// No description provided for @exerciseBack09.
  ///
  /// In en, this message translates to:
  /// **'Assisted Pull-up'**
  String get exerciseBack09;

  /// No description provided for @exerciseBack10.
  ///
  /// In en, this message translates to:
  /// **'Face Pull'**
  String get exerciseBack10;

  /// No description provided for @exerciseBack11.
  ///
  /// In en, this message translates to:
  /// **'Shrug'**
  String get exerciseBack11;

  /// No description provided for @exerciseBack12.
  ///
  /// In en, this message translates to:
  /// **'Cable Straight-arm Pulldown'**
  String get exerciseBack12;

  /// No description provided for @exerciseBack13.
  ///
  /// In en, this message translates to:
  /// **'Sumo Deadlift'**
  String get exerciseBack13;

  /// No description provided for @exerciseBack14.
  ///
  /// In en, this message translates to:
  /// **'Romanian Deadlift'**
  String get exerciseBack14;

  /// No description provided for @exerciseBack15.
  ///
  /// In en, this message translates to:
  /// **'Conventional Deadlift'**
  String get exerciseBack15;

  /// No description provided for @exerciseShoulder01.
  ///
  /// In en, this message translates to:
  /// **'Barbell Shoulder Press'**
  String get exerciseShoulder01;

  /// No description provided for @exerciseShoulder02.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Shoulder Press'**
  String get exerciseShoulder02;

  /// No description provided for @exerciseShoulder03.
  ///
  /// In en, this message translates to:
  /// **'Smith Machine Shoulder Press'**
  String get exerciseShoulder03;

  /// No description provided for @exerciseShoulder04.
  ///
  /// In en, this message translates to:
  /// **'Arnold Press'**
  String get exerciseShoulder04;

  /// No description provided for @exerciseShoulder05.
  ///
  /// In en, this message translates to:
  /// **'Side Raise'**
  String get exerciseShoulder05;

  /// No description provided for @exerciseShoulder06.
  ///
  /// In en, this message translates to:
  /// **'Rear Raise'**
  String get exerciseShoulder06;

  /// No description provided for @exerciseShoulder07.
  ///
  /// In en, this message translates to:
  /// **'Front Raise'**
  String get exerciseShoulder07;

  /// No description provided for @exerciseShoulder08.
  ///
  /// In en, this message translates to:
  /// **'Cable Rear Raise'**
  String get exerciseShoulder08;

  /// No description provided for @exerciseShoulder09.
  ///
  /// In en, this message translates to:
  /// **'Upright Row'**
  String get exerciseShoulder09;

  /// No description provided for @exerciseShoulder10.
  ///
  /// In en, this message translates to:
  /// **'Shoulder Press Machine'**
  String get exerciseShoulder10;

  /// No description provided for @exerciseShoulder11.
  ///
  /// In en, this message translates to:
  /// **'Cable Front Raise'**
  String get exerciseShoulder11;

  /// No description provided for @exerciseShoulder12.
  ///
  /// In en, this message translates to:
  /// **'Incline Side Raise'**
  String get exerciseShoulder12;

  /// No description provided for @exerciseShoulder13.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Shrug'**
  String get exerciseShoulder13;

  /// No description provided for @exerciseShoulder14.
  ///
  /// In en, this message translates to:
  /// **'Cable Side Raise'**
  String get exerciseShoulder14;

  /// No description provided for @exerciseShoulder15.
  ///
  /// In en, this message translates to:
  /// **'Face Pull'**
  String get exerciseShoulder15;

  /// No description provided for @exerciseLeg01.
  ///
  /// In en, this message translates to:
  /// **'Barbell Squat'**
  String get exerciseLeg01;

  /// No description provided for @exerciseLeg02.
  ///
  /// In en, this message translates to:
  /// **'Front Squat'**
  String get exerciseLeg02;

  /// No description provided for @exerciseLeg03.
  ///
  /// In en, this message translates to:
  /// **'Leg Press'**
  String get exerciseLeg03;

  /// No description provided for @exerciseLeg04.
  ///
  /// In en, this message translates to:
  /// **'Leg Extension'**
  String get exerciseLeg04;

  /// No description provided for @exerciseLeg05.
  ///
  /// In en, this message translates to:
  /// **'Leg Curl'**
  String get exerciseLeg05;

  /// No description provided for @exerciseLeg06.
  ///
  /// In en, this message translates to:
  /// **'Seated Leg Curl'**
  String get exerciseLeg06;

  /// No description provided for @exerciseLeg07.
  ///
  /// In en, this message translates to:
  /// **'Romanian Deadlift'**
  String get exerciseLeg07;

  /// No description provided for @exerciseLeg08.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get exerciseLeg08;

  /// No description provided for @exerciseLeg09.
  ///
  /// In en, this message translates to:
  /// **'Calf Raise'**
  String get exerciseLeg09;

  /// No description provided for @exerciseLeg10.
  ///
  /// In en, this message translates to:
  /// **'Seated Calf Raise'**
  String get exerciseLeg10;

  /// No description provided for @exerciseLeg11.
  ///
  /// In en, this message translates to:
  /// **'Hack Squat'**
  String get exerciseLeg11;

  /// No description provided for @exerciseLeg12.
  ///
  /// In en, this message translates to:
  /// **'Smith Machine Squat'**
  String get exerciseLeg12;

  /// No description provided for @exerciseLeg13.
  ///
  /// In en, this message translates to:
  /// **'Cable Kickback'**
  String get exerciseLeg13;

  /// No description provided for @exerciseLeg14.
  ///
  /// In en, this message translates to:
  /// **'Hip Thrust'**
  String get exerciseLeg14;

  /// No description provided for @exerciseLeg15.
  ///
  /// In en, this message translates to:
  /// **'Stiff-legged Deadlift'**
  String get exerciseLeg15;

  /// No description provided for @exerciseAbs01.
  ///
  /// In en, this message translates to:
  /// **'Crunch'**
  String get exerciseAbs01;

  /// No description provided for @exerciseAbs02.
  ///
  /// In en, this message translates to:
  /// **'Sit-up'**
  String get exerciseAbs02;

  /// No description provided for @exerciseAbs03.
  ///
  /// In en, this message translates to:
  /// **'Leg Raise'**
  String get exerciseAbs03;

  /// No description provided for @exerciseAbs04.
  ///
  /// In en, this message translates to:
  /// **'Hanging Leg Raise'**
  String get exerciseAbs04;

  /// No description provided for @exerciseAbs05.
  ///
  /// In en, this message translates to:
  /// **'Ab Roller'**
  String get exerciseAbs05;

  /// No description provided for @exerciseAbs06.
  ///
  /// In en, this message translates to:
  /// **'Cable Crunch'**
  String get exerciseAbs06;

  /// No description provided for @exerciseAbs07.
  ///
  /// In en, this message translates to:
  /// **'Machine Crunch'**
  String get exerciseAbs07;

  /// No description provided for @exerciseAbs08.
  ///
  /// In en, this message translates to:
  /// **'Side Bend'**
  String get exerciseAbs08;

  /// No description provided for @exerciseAbs09.
  ///
  /// In en, this message translates to:
  /// **'Russian Twist'**
  String get exerciseAbs09;

  /// No description provided for @exerciseAbs10.
  ///
  /// In en, this message translates to:
  /// **'Bicycle Crunch'**
  String get exerciseAbs10;

  /// No description provided for @exerciseAbs11.
  ///
  /// In en, this message translates to:
  /// **'V Sit-up'**
  String get exerciseAbs11;

  /// No description provided for @exerciseAbs12.
  ///
  /// In en, this message translates to:
  /// **'Weighted Plank'**
  String get exerciseAbs12;

  /// No description provided for @exerciseAbs13.
  ///
  /// In en, this message translates to:
  /// **'Weighted Side Plank'**
  String get exerciseAbs13;

  /// No description provided for @exerciseAbs14.
  ///
  /// In en, this message translates to:
  /// **'Jackknife Sit-up'**
  String get exerciseAbs14;

  /// No description provided for @exerciseAbs15.
  ///
  /// In en, this message translates to:
  /// **'Dragon Flag'**
  String get exerciseAbs15;

  /// No description provided for @exerciseFullBody01.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Swing'**
  String get exerciseFullBody01;

  /// No description provided for @exerciseFullBody02.
  ///
  /// In en, this message translates to:
  /// **'Burpee Jump'**
  String get exerciseFullBody02;

  /// No description provided for @exerciseFullBody03.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get exerciseFullBody03;

  /// No description provided for @exerciseFullBody04.
  ///
  /// In en, this message translates to:
  /// **'Clean and Press'**
  String get exerciseFullBody04;

  /// No description provided for @exerciseFullBody05.
  ///
  /// In en, this message translates to:
  /// **'Cable Woodchopper'**
  String get exerciseFullBody05;

  /// No description provided for @exerciseFullBody06.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Goblet Squat'**
  String get exerciseFullBody06;

  /// No description provided for @exerciseFullBody07.
  ///
  /// In en, this message translates to:
  /// **'Medicine Ball Slam'**
  String get exerciseFullBody07;

  /// No description provided for @exerciseFullBody08.
  ///
  /// In en, this message translates to:
  /// **'Sandbag Shoulder Squat'**
  String get exerciseFullBody08;

  /// No description provided for @exerciseFullBody09.
  ///
  /// In en, this message translates to:
  /// **'Sled Push'**
  String get exerciseFullBody09;

  /// No description provided for @exerciseFullBody10.
  ///
  /// In en, this message translates to:
  /// **'Step-up'**
  String get exerciseFullBody10;

  /// No description provided for @exerciseFullBody11.
  ///
  /// In en, this message translates to:
  /// **'Farmer\'s Walk'**
  String get exerciseFullBody11;

  /// No description provided for @exerciseFullBody12.
  ///
  /// In en, this message translates to:
  /// **'Medicine Ball Squat Press'**
  String get exerciseFullBody12;

  /// No description provided for @exerciseFullBody13.
  ///
  /// In en, this message translates to:
  /// **'Circuit Training'**
  String get exerciseFullBody13;

  /// No description provided for @exerciseFullBody14.
  ///
  /// In en, this message translates to:
  /// **'Burpee Circuit'**
  String get exerciseFullBody14;

  /// No description provided for @exerciseFullBody15.
  ///
  /// In en, this message translates to:
  /// **'Row and Push Circuit'**
  String get exerciseFullBody15;

  /// No description provided for @exerciseBodyweight01.
  ///
  /// In en, this message translates to:
  /// **'Push-up'**
  String get exerciseBodyweight01;

  /// No description provided for @exerciseBodyweight02.
  ///
  /// In en, this message translates to:
  /// **'Narrow Push-up'**
  String get exerciseBodyweight02;

  /// No description provided for @exerciseBodyweight03.
  ///
  /// In en, this message translates to:
  /// **'Wide Push-up'**
  String get exerciseBodyweight03;

  /// No description provided for @exerciseBodyweight04.
  ///
  /// In en, this message translates to:
  /// **'Diamond Push-up'**
  String get exerciseBodyweight04;

  /// No description provided for @exerciseBodyweight05.
  ///
  /// In en, this message translates to:
  /// **'Dips'**
  String get exerciseBodyweight05;

  /// No description provided for @exerciseBodyweight06.
  ///
  /// In en, this message translates to:
  /// **'Squat'**
  String get exerciseBodyweight06;

  /// No description provided for @exerciseBodyweight07.
  ///
  /// In en, this message translates to:
  /// **'Jump Squat'**
  String get exerciseBodyweight07;

  /// No description provided for @exerciseBodyweight08.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian Squat'**
  String get exerciseBodyweight08;

  /// No description provided for @exerciseBodyweight09.
  ///
  /// In en, this message translates to:
  /// **'Lunge'**
  String get exerciseBodyweight09;

  /// No description provided for @exerciseBodyweight10.
  ///
  /// In en, this message translates to:
  /// **'Calf Raise'**
  String get exerciseBodyweight10;

  /// No description provided for @exerciseBodyweight11.
  ///
  /// In en, this message translates to:
  /// **'Crunch'**
  String get exerciseBodyweight11;

  /// No description provided for @exerciseBodyweight12.
  ///
  /// In en, this message translates to:
  /// **'Leg Raise'**
  String get exerciseBodyweight12;

  /// No description provided for @exerciseBodyweight13.
  ///
  /// In en, this message translates to:
  /// **'Plank'**
  String get exerciseBodyweight13;

  /// No description provided for @exerciseBodyweight14.
  ///
  /// In en, this message translates to:
  /// **'Side Plank'**
  String get exerciseBodyweight14;

  /// No description provided for @exerciseBodyweight15.
  ///
  /// In en, this message translates to:
  /// **'Burpee'**
  String get exerciseBodyweight15;

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyweight;

  /// No description provided for @welcomeThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thanks for downloading. Have a great training life!'**
  String get welcomeThankYou;

  /// No description provided for @hintTapPlus.
  ///
  /// In en, this message translates to:
  /// **'Tap the “+” to start logging.'**
  String get hintTapPlus;

  /// No description provided for @notiDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Let’s keep it up today!'**
  String get notiDailyTitle;

  /// No description provided for @notiDailyBodyA.
  ///
  /// In en, this message translates to:
  /// **'It\'s time to train!'**
  String get notiDailyBodyA;

  /// No description provided for @notiDailyBodyB.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start training! Ready?'**
  String get notiDailyBodyB;

  /// No description provided for @notiInactive3Title.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get back to training!'**
  String get notiInactive3Title;

  /// No description provided for @notiInactive3Body.
  ///
  /// In en, this message translates to:
  /// **'Even just one set is fine—give it a try.'**
  String get notiInactive3Body;

  /// No description provided for @notiInactive7Title.
  ///
  /// In en, this message translates to:
  /// **'Restart today'**
  String get notiInactive7Title;

  /// No description provided for @notiInactive7Body.
  ///
  /// In en, this message translates to:
  /// **'A week off. Do 10 push-ups or 10 squats—either is fine.'**
  String get notiInactive7Body;

  /// No description provided for @notiSoftAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Would you like to set up notifications to keep training consistently?'**
  String get notiSoftAskTitle;

  /// No description provided for @notiSoftAskBody.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime.'**
  String get notiSoftAskBody;

  /// No description provided for @notiSoftAskLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get notiSoftAskLater;

  /// No description provided for @notiSoftAskEnable.
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get notiSoftAskEnable;

  /// No description provided for @notiSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notiSettingsTitle;

  /// No description provided for @notiSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get notiSettingsSubtitle;

  /// No description provided for @notiSettingsChangeTime.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get notiSettingsChangeTime;

  /// No description provided for @notiSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get notiSendTest;

  /// No description provided for @notiStopAll.
  ///
  /// In en, this message translates to:
  /// **'Stop all notifications'**
  String get notiStopAll;

  /// No description provided for @notiSettingsAllSame.
  ///
  /// In en, this message translates to:
  /// **'Apply to all'**
  String get notiSettingsAllSame;

  /// No description provided for @notiSettingsCopyWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Copy to weekdays'**
  String get notiSettingsCopyWeekdays;

  /// No description provided for @notiSettingsCopyWeekend.
  ///
  /// In en, this message translates to:
  /// **'Copy to weekend'**
  String get notiSettingsCopyWeekend;

  /// No description provided for @notiSettingsWeeklyLabel.
  ///
  /// In en, this message translates to:
  /// **'Every {weekday}'**
  String notiSettingsWeeklyLabel(Object weekday);

  /// No description provided for @mealHeaderNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get mealHeaderNo;

  /// No description provided for @mealHeaderMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get mealHeaderMenu;

  /// No description provided for @mealHeaderKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get mealHeaderKcal;

  /// No description provided for @notiCopyAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy to all days'**
  String get notiCopyAllTitle;

  /// No description provided for @notiCopyAllMessage.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite the time for all days. Continue?'**
  String get notiCopyAllMessage;

  /// No description provided for @notiCopyWeekdaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy to weekdays'**
  String get notiCopyWeekdaysTitle;

  /// No description provided for @notiCopyWeekdaysMessage.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite the time for Mon–Fri. Continue?'**
  String get notiCopyWeekdaysMessage;

  /// No description provided for @notiCopyWeekendTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy to weekend'**
  String get notiCopyWeekendTitle;

  /// No description provided for @notiCopyWeekendMessage.
  ///
  /// In en, this message translates to:
  /// **'This will set the same time for Sat & Sun. Continue?'**
  String get notiCopyWeekendMessage;

  /// No description provided for @notiConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get notiConfirmYes;

  /// No description provided for @notiConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get notiConfirmNo;

  /// No description provided for @awardTitleFirst.
  ///
  /// In en, this message translates to:
  /// **'First training achieved!'**
  String get awardTitleFirst;

  /// No description provided for @awardTitleDays.
  ///
  /// In en, this message translates to:
  /// **'Streak of {dayCount} days completed!'**
  String awardTitleDays(Object dayCount);

  /// No description provided for @awardTitleMax.
  ///
  /// In en, this message translates to:
  /// **'New record reached!'**
  String get awardTitleMax;

  /// No description provided for @awardLabelDate.
  ///
  /// In en, this message translates to:
  /// **'Date:'**
  String get awardLabelDate;

  /// No description provided for @awardLabelExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise:'**
  String get awardLabelExercise;

  /// No description provided for @awardLabelPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous record:'**
  String get awardLabelPrevious;

  /// No description provided for @awardFooterMessage.
  ///
  /// In en, this message translates to:
  /// **'Great job!'**
  String get awardFooterMessage;

  /// No description provided for @awardBadgeDay.
  ///
  /// In en, this message translates to:
  /// **'Day {dayCount}'**
  String awardBadgeDay(Object dayCount);

  /// No description provided for @awardSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your album'**
  String get awardSaved;

  /// No description provided for @awardShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get awardShare;

  /// No description provided for @awardClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get awardClose;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'id', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'id': return AppLocalizationsId();
    case 'ja': return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
