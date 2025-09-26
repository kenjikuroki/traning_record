// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'T-トレーニング記録';

  @override
  String get calendar => 'カレンダー';

  @override
  String get graph => 'グラフ';

  @override
  String get favorites => 'お気に入り';

  @override
  String get recordScreenTitle => '記録';

  @override
  String get calendarScreenTitle => 'カレンダー';

  @override
  String get settingsScreenTitle => '設定';

  @override
  String get graphScreenTitle => 'グラフ';

  @override
  String get albumTitle => 'アルバム';

  @override
  String get start => '開始';

  @override
  String get pause => '一時停止';

  @override
  String get reset => 'リセット';

  @override
  String get saved => '保存しました';

  @override
  String get save => '保存';

  @override
  String get discard => '破棄';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get yes => 'はい';

  @override
  String get no => 'いいえ';

  @override
  String get resume => '再開';

  @override
  String get openSettings => '設定を開く';

  @override
  String get open => '開く';

  @override
  String get cameraPermissionRequired => 'カメラ権限を有効にしてください';

  @override
  String get stopwatch => 'ストップウォッチ';

  @override
  String get timer => 'タイマー';

  @override
  String get timerTime => 'タイマー時間';

  @override
  String get tapNumberToEdit => '数字タップで編集';

  @override
  String targetFmt(Object hint, Object time) {
    return '目標 $time（$hint）';
  }

  @override
  String get statusRunning => '計測中';

  @override
  String get statusIdle => '待機中';

  @override
  String hours(Object hours) {
    return '$hours時間';
  }

  @override
  String get kg => 'kg';

  @override
  String get lbs => 'lbs';

  @override
  String get unit => '単位';

  @override
  String get unitTitle => '単位';

  @override
  String get weightUnit => '重量';

  @override
  String get min => '分';

  @override
  String get sec => '秒';

  @override
  String get minutes => '分';

  @override
  String get minutesHint => '分';

  @override
  String get secondsHint => '秒';

  @override
  String get sets => 'セット';

  @override
  String get reps => '回';

  @override
  String get distance => '距離';

  @override
  String get km => 'km';

  @override
  String get m => 'm';

  @override
  String get pace => 'ペース';

  @override
  String get perDayUnit => '枚/日';

  @override
  String get trainingParts => 'トレーニング部位';

  @override
  String get selectTrainingPart => 'トレーニング部位を選択';

  @override
  String get selectPartPlaceholder => '部位を選択';

  @override
  String get aerobicExercise => '有酸素運動';

  @override
  String get arm => '腕';

  @override
  String get chest => '胸';

  @override
  String get back => '背中';

  @override
  String get shoulder => '肩';

  @override
  String get leg => '足';

  @override
  String get abs => '腹筋';

  @override
  String get bodyWeightTraining => '自重';

  @override
  String get fullBody => '全身';

  @override
  String get other1 => 'その他１';

  @override
  String get other2 => 'その他２';

  @override
  String get other3 => 'その他３';

  @override
  String get exercise => '種目';

  @override
  String get selectExercise => '種目を選択';

  @override
  String get menuName => '種目名を記入';

  @override
  String get menuNameHint => '種目名を入力';

  @override
  String get addExercisePlaceholder => '種目を選択';

  @override
  String get addExercise => '＋種目';

  @override
  String get addNewExercise => '＋新規';

  @override
  String get customExerciseDialogTitle => '新規種目を追加';

  @override
  String get customExerciseNameHint => '種目名を入力';

  @override
  String get customExerciseNameRequired => '種目名を入力してください';

  @override
  String get customExerciseDuplicate => 'この種目は既に登録されています';

  @override
  String get customExercisePickerEmpty =>
      '登録済みの候補がありません。＋から追加してください。';

  @override
  String get removeCustomExercises => '追加した種目の削除';

  @override
  String get customExerciseRemovalHint => '追加済みのカスタム種目を削除します。';

  @override
  String get noCustomExercises => '追加された種目はありません。';

  @override
  String get selectExerciseToDelete => '削除する種目を選択';

  @override
  String customExerciseRemoved(String exerciseName) =>
      '$exerciseNameを削除しました。';

  @override
  String get addMenu => '種目を追加';

  @override
  String get addSet => '＋セット';

  @override
  String get openAddMenu => '追加メニューを開く';

  @override
  String get partAlreadySelected => 'この部位はすでに選択されています。';

  @override
  String get setCount => 'セット数';

  @override
  String get defaultSets => '初期セット数';

  @override
  String get bodyWeight => '体重';

  @override
  String get bodyWeightTracking => '体重管理';

  @override
  String get durationHint => '時間:分';

  @override
  String get distanceHint => '距離を入力';

  @override
  String get noRecordMessage => '選択された日付には記録がありません。';

  @override
  String get coachBubbleSemantic => 'ヒント';

  @override
  String get hintRecordSelectPart => 'トレーニングする部位を選択してください。';

  @override
  String get hintRecordExerciseField => 'ここに種目名を入力します。';

  @override
  String get hintRecordAddExercise => 'ここをタップして種目を追加します。';

  @override
  String get hintRecordChangePart => 'ここから部位を追加できます。';

  @override
  String get hintRecordOpenSettings => 'セット数の初期値は設定から変更できます。';

  @override
  String get hintRecordFab => 'ここから部位・種目・写真・メモを追加できます';

  @override
  String get hintCalendarTapDate => '記録する日付を選択';

  @override
  String get hintGraphFavorite => 'よく見るデータはお気に入りに登録しよう。';

  @override
  String get hintGraphChartArea => '記録したデータのグラフが出力されます。';

  @override
  String get hintGraphSelectPart => '部位・種目を選択';

  @override
  String get discardLongPressLabel => '破棄（長押し）';

  @override
  String get dayDisplay => '日';

  @override
  String get weekDisplay => '週';

  @override
  String get noGraphData => '部位・種目や体重を選択するとグラフが表示されます。';

  @override
  String favorited(Object menuName) {
    return '$menuNameをお気に入りに登録しました';
  }

  @override
  String unfavorited(Object menuName) {
    return '$menuNameのお気に入りを解除しました';
  }

  @override
  String get addPhoto => '＋写真';

  @override
  String get dialogAddPhotoTitle => '写真を追加';

  @override
  String get actionTakePhoto => '写真を撮影';

  @override
  String get progressSnaps => '進捗スナップ';

  @override
  String get mediaReachedDailyCap => '今日の保存上限に達しました';

  @override
  String get mediaGoToAlbum => 'アルバムへ';

  @override
  String get mediaGoToSettings => '設定へ';

  @override
  String get mediaDelete => '削除';

  @override
  String get mediaCancel => 'キャンセル';

  @override
  String get mediaUndo => '元に戻す';

  @override
  String get photoLoadFailed => '画像を読み込めませんでした';

  @override
  String get discardPhotoConfirmTitle => 'この写真を破棄しますか？';

  @override
  String get settings => '設定';

  @override
  String get themeMode => 'テーマ';

  @override
  String get themeTitle => 'テーマ';

  @override
  String get light => 'ライト';

  @override
  String get dark => 'ダーク';

  @override
  String get systemDefault => 'システムデフォルト';

  @override
  String get useDarkMode => 'ダークモード';

  @override
  String get selectBodyParts => '表示する部位を選択';

  @override
  String get changeSetCount => 'セット数の変更';

  @override
  String get settingsStopwatchTimerVisibility => 'ストップウォッチ/タイマー表示';

  @override
  String get recordDisplayOptions => '表示項目';

  @override
  String get intervalTimer => 'インターバルタイマー';

  @override
  String get settingsDailyMediaCap => '1日の写真上限';

  @override
  String get settingsDailyMediaCapDesc => '1日に保存できる写真の上限枚数';

  @override
  String get settingsDailyMediaCapShort => '写真上限';

  @override
  String get background => '背景';

  @override
  String get none => 'なし';

  @override
  String get limitOff => '上限なし';

  @override
  String get autoPausedIdle5h => '無操作が5時間続いたため一時停止しました';

  @override
  String get autoPausedOver5h => '5時間を超えたため一時停止しました';

  @override
  String get autoPausedBackground30m => 'アプリが30分以上バックグラウンドのため一時停止しました';

  @override
  String get partLimitReached => '部位は10個までしか追加できません。';

  @override
  String get removePersonalCardTooltip => 'パーソナルカードを閉じる';

  @override
  String get removePartCardTooltip => '部位カードを削除';

  @override
  String get deletePersonalConfirmationTitle =>
      'パーソナルカードを閉じますか？';

  @override
  String get deletePartConfirmationTitle => 'この部位カードを削除しますか？';

  @override
  String get exerciseLimitReached => '種目は15個までしか追加できません。';

  @override
  String get time => '時間';

  @override
  String get hour => '時間';

  @override
  String get enterGoal => '目標値';

  @override
  String get deleteMenuConfirmationTitle => '種目を削除しますか？';

  @override
  String get addPart => '＋部位';

  @override
  String get ok => 'OK';

  @override
  String get share => '共有';

  @override
  String get clear => '解除';

  @override
  String selectedCount(Object count) {
    return '$count件選択中';
  }

  @override
  String results(Object date) {
    return '$dateの記録';
  }

  @override
  String deleteSelectedConfirmTitle(Object count) {
    return '選択した$count件を削除しますか？';
  }

  @override
  String get albumEmptyMessage => '自撮り写真をアルバムに残してトレーニングの進捗を確認しよう。';

  @override
  String get close => '閉じる';

  @override
  String get addMemo => '＋メモ';

  @override
  String get memo => 'メモ';

  @override
  String get memoTitle => '題名';

  @override
  String get memoBody => 'メモ';

  @override
  String get memoTitlePlaceholder => '題名を入力';

  @override
  String get memoBodyPlaceholder => 'メモを入力';

  @override
  String get satisfaction => '満足度';

  @override
  String get satisfactionBad => '悪い';

  @override
  String get satisfactionOkay => '普通';

  @override
  String get satisfactionGood => '良い';

  @override
  String get totalVolume => '総ボリューム';

  @override
  String get totalVolumeCurrent => '今回';

  @override
  String get totalVolumePrevious => '前回';

  @override
  String get totalVolumeDifference => '前回比';

  @override
  String get valueNotAvailable => '--';

  @override
  String get expandCard => '展開';

  @override
  String get collapseCard => '折りたたむ';

  @override
  String get hintRecordFirst => 'まずはトレーニングや体重を記録しよう';

  @override
  String get hintGraphSetGoal => '目標を設定しよう';

  @override
  String get personalSettingsTitle => 'パーソナル設定';

  @override
  String get gender => '性別';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get genderUnspecified => '未選択';

  @override
  String get birthDate => '生年月日';

  @override
  String get notSet => '未設定';

  @override
  String get height => '身長';

  @override
  String get waist => 'ウエスト';

  @override
  String get bodyFatTracking => '体脂肪管理';

  @override
  String get waistTracking => 'ウエスト管理';

  @override
  String get bmiTracking => 'BMI管理';

  @override
  String get unitCm => 'cm';

  @override
  String get unitFtIn => 'ft/in';

  @override
  String get unitFt => 'ft';

  @override
  String get unitIn => 'in';

  @override
  String get bodyFat => '体脂肪';

  @override
  String get bmi => 'BMI';

  @override
  String get personal => 'パーソナル';

  @override
  String get bodyFatPercentage => '体脂肪率';

  @override
  String get percentSymbol => '%';

  @override
  String get cm => 'cm';

  @override
  String get standards => '基準';

  @override
  String bmiStdRange(Object max, Object min) {
    return 'BMI $min–$max';
  }

  @override
  String bodyFatStdRange(Object max, Object min, Object percent) {
    return '体脂肪率 $min–$max$percent';
  }

  @override
  String waistStdSingle(Object cm, Object value) {
    return 'ウエスト $value$cm';
  }

  @override
  String get photos => '写真';

  @override
  String get maleShort => '男';

  @override
  String get femaleShort => '女';

  @override
  String get mile => 'mile';

  @override
  String get length => '長さ';

  @override
  String get lengthNote => '長さの単位に合わせて、身長・ウエスト（cm / ft·in）も自動で切り替わります。';

  @override
  String get graphTitle => 'グラフ';

  @override
  String get backTooltip => '戻る';

  @override
  String get noneLabel => 'なし';

  @override
  String get aerobicCalorieToggle => '有酸素運動のカロリー算出';

  @override
  String get calorie => 'カロリー';

  @override
  String get kcalUnit => 'kcal';

  @override
  String get calorieOverrideHint => '必要に応じて編集できます';

  @override
  String get calorieHelpTitle => 'カロリー計算について';

  @override
  String get calorieHelpBody => '計算式: 消費エネルギー = MET × 体重(kg) × 時間(h)。\n\n種目名から推測したMET値で概算しています。スマートウォッチなどで正確な値が分かる場合は、この項目を手入力で上書きしてください。';

  @override
  String get dailyCalorieTotal => '総消費カロリー';

  @override
  String get chooseFromPresets => 'プリセットを選ぶ';

  @override
  String get presetRunning => 'ランニング';

  @override
  String get presetWalking => 'ウォーキング';

  @override
  String get presetCycling => 'サイクリング';

  @override
  String get presetExerciseBike => 'エアロバイク';

  @override
  String get presetElliptical => 'エリプティカル';

  @override
  String get presetRowing => 'ローイング';

  @override
  String get aerobicPickerTitle => '種目を入力・選択';

  @override
  String get aerobicCalorieUnknownHint => '不明な種目名のためカロリーを算出できませんでした。スマートウォッチなどで取得した値があれば入力してください。';

  @override
  String get aerobicCalorieInfoTitle => 'カロリー計算について';

  @override
  String get aerobicCalorieInfoBody => '消費カロリー = MET × 体重(kg) × 運動時間(時間) で概算しています。種目名・距離・時間から運動強度(MET)を推定します。\n\n推定値のため、スマートウォッチ等で取得した値があれば上書きしてください。距離や時間が空欄の場合は推定されません。\n\n暑熱環境や体調によって消費量は変動します。休憩と水分補給も心掛けてください。';

  @override
  String get aerobicCalorieWeightRequired => 'カロリー算出を有効にするにはパーソナル設定で体重を入力してください。';

  @override
  String get add => '追加';

  @override
  String get noRecords => '記録はありません';

  @override
  String get editThisDay => 'この日を編集';

  @override
  String get addOnThisDay => 'この日に追加';

  @override
  String get settingsThemeTitle => 'テーマ選択';

  @override
  String get settingsThemeConfirmTitle => 'テーマを変更しますか？';

  @override
  String get settingsThemeConfirmMessage => 'アプリの配色を変更します。よろしいですか？';

  @override
  String get themeMonotone => 'モノトーン';

  @override
  String get themeRed => '赤';

  @override
  String get themeBlue => '青';

  @override
  String get themeGreen => '緑';

  @override
  String get themeYellow => '黄色';

  @override
  String get themeColorTitle => 'テーマカラー';

  @override
  String get totalVolumeLabel => '総ボリューム';

  @override
  String get previousLabel => '前回';

  @override
  String get currentLabel => '今回';
}
