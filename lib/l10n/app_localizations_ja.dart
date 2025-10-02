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
  String get customExercisePickerEmpty => '登録済みの候補がありません。＋から追加してください。';

  @override
  String get open => '開く';

  @override
  String get removeCustomExercises => '追加した種目の削除';

  @override
  String get customExerciseRemovalHint => '追加済みのカスタム種目を削除します。';

  @override
  String get noCustomExercises => '追加された種目はありません。';

  @override
  String get selectExerciseToDelete => '削除する種目を選択';

  @override
  String customExerciseRemoved(Object exerciseName) {
    return '$exerciseNameを削除しました。';
  }

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
  String get hintRecordFab => 'Add a part, exercise, photo, or memo from here.';

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
  String get intervalTimer => 'インターバルタイマー';

  @override
  String get settingsDailyMediaCap => '1日の写真上限';

  @override
  String get settingsDailyMediaCapDesc => '1日に保存できる写真の上限枚数';

  @override
  String get settingsDailyMediaCapShort => '写真上限';

  @override
  String get recordDisplayOptions => '表示項目';

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
  String get deletePersonalConfirmationTitle => 'パーソナルカードを閉じますか？';

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
  String get meal => '食事';

  @override
  String get mealAdd => '＋食事';

  @override
  String get mealCategory => '食事区分';

  @override
  String get mealMorning => '朝';

  @override
  String get mealNoon => '昼';

  @override
  String get mealEvening => '夜';

  @override
  String get mealSnack => '間食';

  @override
  String get mealItem => 'メニュー';

  @override
  String get mealSubtotal => '小計';

  @override
  String get mealTotalToday => '本日の食事合計';

  @override
  String get mealDeleteConfirmTitle => '食事を削除しますか？';

  @override
  String get addMealItem => '＋メニュー';

  @override
  String get bmrTitle => '基礎代謝：';

  @override
  String get bmrTitleShort => '基礎代謝';

  @override
  String get bmrDiffShort => '基礎代謝 - 摂取';

  @override
  String get dailyBalanceSummary => '（基礎代謝＋有酸素）− 摂取';

  @override
  String get bmrDeficit => '差分（基礎代謝 − 摂取）';

  @override
  String get bmrNeedPersonalNotice => '体重・身長・生年月日・性別の入力が必要です（設定 → パーソナル）。';

  @override
  String get mealInputHint => 'メニュー名とkcalを入力してください';

  @override
  String get mealEmptyNotice => '入力がありません';

  @override
  String get mealRestoreFailed => '食事データを読み込めませんでした';

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

  @override
  String get hintCalendarGotoRecord => 'クリックして記録する画面へ';

  @override
  String get hintRecordTapExerciseCard => 'こちらをタップしてトレーニングする部位を選択してください。';

  @override
  String get hintRecordPickExercise => 'トレーニングする種目をタップするか、新しいカード種目カードを作成してください。';

  @override
  String get hintRecordCheckbox => '重量と回数を入力し、チェックボックスにチェックをいれてください';

  @override
  String get hintRecordSave => '完了したら保存をタップ。';

  @override
  String get exerciseAerobic01 => 'ランニング';

  @override
  String get exerciseAerobic02 => 'ウォーキング';

  @override
  String get exerciseAerobic03 => 'トレッドミル';

  @override
  String get exerciseAerobic04 => 'サイクリング';

  @override
  String get exerciseAerobic05 => 'エアロバイク';

  @override
  String get exerciseAerobic06 => 'クロストレーナー';

  @override
  String get exerciseAerobic07 => 'ローイングマシン';

  @override
  String get exerciseAerobic08 => 'ステアクライマー';

  @override
  String get exerciseAerobic09 => 'スイミング';

  @override
  String get exerciseAerobic10 => 'ジャンプロープ';

  @override
  String get exerciseAerobic11 => 'エアロビクス';

  @override
  String get exerciseArm01 => 'バーベルカール';

  @override
  String get exerciseArm02 => 'ダンベルカール';

  @override
  String get exerciseArm03 => 'インクラインダンベルカール';

  @override
  String get exerciseArm04 => 'ケーブルカール';

  @override
  String get exerciseArm05 => 'プリーチャーカール';

  @override
  String get exerciseArm06 => 'ハンマーカール';

  @override
  String get exerciseArm07 => 'コンセントレーションカール';

  @override
  String get exerciseArm08 => 'リバースカール';

  @override
  String get exerciseArm09 => 'ケーブルトライセプスプレスダウン';

  @override
  String get exerciseArm10 => 'スカルクラッシャー';

  @override
  String get exerciseArm11 => 'オーバーヘッドトライセプスエクステンション';

  @override
  String get exerciseArm12 => 'ダンベルトライセプスキックバック';

  @override
  String get exerciseArm13 => 'ケーブルオーバーヘッドトライセプスエクステンション';

  @override
  String get exerciseArm14 => 'クローズグリップベンチプレス';

  @override
  String get exerciseArm15 => 'リストカール';

  @override
  String get exerciseChest01 => 'バーベルベンチプレス';

  @override
  String get exerciseChest02 => 'インクラインベンチプレス';

  @override
  String get exerciseChest03 => 'デクラインベンチプレス';

  @override
  String get exerciseChest04 => 'ダンベルベンチプレス';

  @override
  String get exerciseChest05 => 'インクラインダンベルプレス';

  @override
  String get exerciseChest06 => 'デクラインダンベルプレス';

  @override
  String get exerciseChest07 => 'ダンベルフライ';

  @override
  String get exerciseChest08 => 'インクラインダンベルフライ';

  @override
  String get exerciseChest09 => 'ケーブルクロスオーバー';

  @override
  String get exerciseChest10 => 'ペックデックフライ';

  @override
  String get exerciseChest11 => 'チェストプレス';

  @override
  String get exerciseChest12 => 'スミスマシンベンチプレス';

  @override
  String get exerciseChest13 => 'スミスマシンインクラインプレス';

  @override
  String get exerciseChest14 => 'ディップス';

  @override
  String get exerciseChest15 => 'プッシュアップ（加重・マシン）';

  @override
  String get exerciseBack01 => 'デッドリフト';

  @override
  String get exerciseBack02 => 'ラットプルダウン';

  @override
  String get exerciseBack03 => 'リバースグリップラットプルダウン';

  @override
  String get exerciseBack04 => 'バーベルベントオーバーロウ';

  @override
  String get exerciseBack05 => 'ダンベルワンハンドロウ';

  @override
  String get exerciseBack06 => 'シーテッドロウ';

  @override
  String get exerciseBack07 => 'Tバーロウ';

  @override
  String get exerciseBack08 => 'チンニング（加重）';

  @override
  String get exerciseBack09 => 'チンニング（アシスト）';

  @override
  String get exerciseBack10 => 'フェイスプル';

  @override
  String get exerciseBack11 => 'シュラッグ';

  @override
  String get exerciseBack12 => 'ケーブルストレートアームプルダウン';

  @override
  String get exerciseBack13 => 'スモウデッドリフト';

  @override
  String get exerciseBack14 => 'ルーマニアンデッドリフト';

  @override
  String get exerciseBack15 => 'デッドリフト（ベーシック）';

  @override
  String get exerciseShoulder01 => 'バーベルショルダープレス';

  @override
  String get exerciseShoulder02 => 'ダンベルショルダープレス';

  @override
  String get exerciseShoulder03 => 'スミスマシンショルダープレス';

  @override
  String get exerciseShoulder04 => 'アーノルドプレス';

  @override
  String get exerciseShoulder05 => 'サイドレイズ';

  @override
  String get exerciseShoulder06 => 'リアレイズ';

  @override
  String get exerciseShoulder07 => 'フロントレイズ';

  @override
  String get exerciseShoulder08 => 'ケーブルリアレイズ';

  @override
  String get exerciseShoulder09 => 'アップライトロウ';

  @override
  String get exerciseShoulder10 => 'ショルダープレスマシン';

  @override
  String get exerciseShoulder11 => 'ケーブルフロントレイズ';

  @override
  String get exerciseShoulder12 => 'インクラインサイドレイズ';

  @override
  String get exerciseShoulder13 => 'ダンベルシュラッグ';

  @override
  String get exerciseShoulder14 => 'ケーブルサイドレイズ';

  @override
  String get exerciseShoulder15 => 'フェイスプル';

  @override
  String get exerciseLeg01 => 'バーベルスクワット';

  @override
  String get exerciseLeg02 => 'フロントスクワット';

  @override
  String get exerciseLeg03 => 'レッグプレス';

  @override
  String get exerciseLeg04 => 'レッグエクステンション';

  @override
  String get exerciseLeg05 => 'レッグカール';

  @override
  String get exerciseLeg06 => 'シーテッドレッグカール';

  @override
  String get exerciseLeg07 => 'ルーマニアンデッドリフト';

  @override
  String get exerciseLeg08 => 'グッドモーニング';

  @override
  String get exerciseLeg09 => 'カーフレイズ';

  @override
  String get exerciseLeg10 => 'シーテッドカーフレイズ';

  @override
  String get exerciseLeg11 => 'ハックスクワット';

  @override
  String get exerciseLeg12 => 'スミスマシンスクワット';

  @override
  String get exerciseLeg13 => 'ケーブルキックバック';

  @override
  String get exerciseLeg14 => 'ヒップスラスト';

  @override
  String get exerciseLeg15 => 'デッドリフト（スティッフレッグ）';

  @override
  String get exerciseAbs01 => 'クランチ';

  @override
  String get exerciseAbs02 => 'シットアップ';

  @override
  String get exerciseAbs03 => 'レッグレイズ';

  @override
  String get exerciseAbs04 => 'ハンギングレッグレイズ';

  @override
  String get exerciseAbs05 => 'アブローラー';

  @override
  String get exerciseAbs06 => 'ケーブルクランチ';

  @override
  String get exerciseAbs07 => 'マシンクランチ';

  @override
  String get exerciseAbs08 => 'サイドベント';

  @override
  String get exerciseAbs09 => 'ロシアンツイスト';

  @override
  String get exerciseAbs10 => 'バイシクルクランチ';

  @override
  String get exerciseAbs11 => 'Vシットアップ';

  @override
  String get exerciseAbs12 => 'プランク（加重）';

  @override
  String get exerciseAbs13 => 'サイドプランク（加重）';

  @override
  String get exerciseAbs14 => 'ジャックナイフシットアップ';

  @override
  String get exerciseAbs15 => 'ドラゴンフラッグ';

  @override
  String get exerciseFullBody01 => 'ケトルベルスイング';

  @override
  String get exerciseFullBody02 => 'バーピージャンプ';

  @override
  String get exerciseFullBody03 => 'クリーン';

  @override
  String get exerciseFullBody04 => 'クリーン＆プレス';

  @override
  String get exerciseFullBody05 => 'ケーブルウッドチョッパー';

  @override
  String get exerciseFullBody06 => 'ケトルベルゴブレットスクワット';

  @override
  String get exerciseFullBody07 => 'メディシンボールスラム';

  @override
  String get exerciseFullBody08 => 'サンドバッグショルダースクワット';

  @override
  String get exerciseFullBody09 => 'スレッドプッシュ';

  @override
  String get exerciseFullBody10 => 'ステップアップ';

  @override
  String get exerciseFullBody11 => 'ファーマーズウォーク';

  @override
  String get exerciseFullBody12 => 'メディシンボールスクワットプレス';

  @override
  String get exerciseFullBody13 => 'サーキットトレーニング';

  @override
  String get exerciseFullBody14 => 'バーピーサーキット';

  @override
  String get exerciseFullBody15 => 'ロー＆プッシュサーキット';

  @override
  String get exerciseBodyweight01 => '腕立て伏せ';

  @override
  String get exerciseBodyweight02 => 'ナロー腕立て伏せ';

  @override
  String get exerciseBodyweight03 => 'ワイド腕立て伏せ';

  @override
  String get exerciseBodyweight04 => 'ダイヤモンド腕立て伏せ';

  @override
  String get exerciseBodyweight05 => 'ディップス';

  @override
  String get exerciseBodyweight06 => 'スクワット';

  @override
  String get exerciseBodyweight07 => 'ジャンプスクワット';

  @override
  String get exerciseBodyweight08 => 'ブルガリアンスクワット';

  @override
  String get exerciseBodyweight09 => 'ランジ';

  @override
  String get exerciseBodyweight10 => 'カーフレイズ';

  @override
  String get exerciseBodyweight11 => '腹筋（クランチ）';

  @override
  String get exerciseBodyweight12 => 'レッグレイズ';

  @override
  String get exerciseBodyweight13 => 'プランク';

  @override
  String get exerciseBodyweight14 => 'サイドプランク';

  @override
  String get exerciseBodyweight15 => 'バーピー';

  @override
  String get bodyweight => '自重';

  @override
  String get welcomeThankYou => 'ダウンロードいただきありがとうございます。良いトレーニングライフをお過ごしください。';

  @override
  String get hintTapPlus => '記録を始めるには、右下の「＋」をタップしてください。';
}
