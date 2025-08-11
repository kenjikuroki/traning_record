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
  String get selectTrainingPart => 'トレーニング部位を選択';

  @override
  String get addPart => '＋部位';

  @override
  String get addExercise => '＋種目';

  @override
  String get partLimitReached => '部位は10個までしか追加できません。';

  @override
  String get exerciseLimitReached => '種目は15個までしか追加できません。';

  @override
  String get settings => '設定';

  @override
  String get trainingParts => 'トレーニング部位';

  @override
  String get setCount => 'セット数';

  @override
  String get themeMode => 'テーマ';

  @override
  String get light => 'ライト';

  @override
  String get dark => 'ダーク';

  @override
  String get systemDefault => 'システムデフォルト';

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
  String get kg => 'kg';

  @override
  String get reps => '回';

  @override
  String get min => '分';

  @override
  String get sec => '秒';

  @override
  String get sets => 'セット';

  @override
  String get menuName => '種目名を記入';

  @override
  String get calendar => 'カレンダー';

  @override
  String get noRecordMessage => '選択された日付には記録がありません。';

  @override
  String get weightUnit => '重量単位';

  @override
  String get lbs => 'lbs';

  @override
  String get deleteMenuConfirmationTitle => '種目を削除しますか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get addExercisePlaceholder => '種目を追加';

  @override
  String get time => '時間';

  @override
  String get minutesHint => '分';

  @override
  String get secondsHint => '秒';

  @override
  String get graph => 'グラフ';

  @override
  String get favorites => 'お気に入り';

  @override
  String get selectExercise => '種目を選択';

  @override
  String get noGraphData => '記録がありません';

  @override
  String get graphScreenTitle => 'グラフ';

  @override
  String favorited(Object menuName) {
    return '$menuNameをお気に入りに登録しました';
  }

  @override
  String unfavorited(Object menuName) {
    return '$menuNameのお気に入りを解除しました';
  }

  @override
  String get dayDisplay => '日';

  @override
  String get weekDisplay => '週';

  @override
  String get distance => '距離';

  @override
  String get km => 'km';

  @override
  String get m => 'm';
}
