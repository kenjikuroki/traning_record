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
  String get weightUnit => '重量単位';

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
  String get addExercisePlaceholder => '種目を追加';

  @override
  String get addExercise => '＋種目';

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
  String get enterYourWeight => '体重を入力';

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
  String get exerciseLimitReached => '種目は15個までしか追加できません。';

  @override
  String get time => '時間';

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
  String get results => '実績';

  @override
  String deleteSelectedConfirmTitle(Object count) {
    return '選択した$count件を削除しますか？';
  }

  @override
  String get albumEmptyMessage => '記録画面で写真を撮影するとアルバムに表示されます。トレーニングの進捗をアルバムに残そう。';

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
  String get satisfactionLabel => '満足度';

  @override
  String get satisfactionGood => '良い';

  @override
  String get satisfactionNeutral => '普通';

  @override
  String get satisfactionBad => '悪い';

  @override
  String get hintRecordFirst => 'まずはトレーニングや体重を記録しよう';

  @override
  String get hintGraphSetGoal => '目標を設定しよう';
}
