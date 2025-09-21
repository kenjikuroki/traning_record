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

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'reps'**
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
  /// **'Add exercise'**
  String get addExercisePlaceholder;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'+ Exercise'**
  String get addExercise;

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

  /// No description provided for @deleteSelectedConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} item(s)?'**
  String deleteSelectedConfirmTitle(Object count);

  /// No description provided for @albumEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Take photos from the Record screen and they will appear here. Keep your training progress in the album.'**
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

  /// No description provided for @hintRecordFirst.
  ///
  /// In en, this message translates to:
  /// **'Start by recording a workout or your body weight.'**
  String get hintRecordFirst;

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

  /// No description provided for @themePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get themePurple;

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
