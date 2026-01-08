import 'dart:collection';
import 'package:ttraining_record/l10n/app_localizations.dart';

class ExerciseCatalog {
  ExerciseCatalog._();

  static const Map<String, List<String>> _defaultExercises = {
    '有酸素運動': [
      'ランニング',
      'ウォーキング',
      'トレッドミル',
      'サイクリング',
      'エアロバイク',
      'クロストレーナー',
      'ローイングマシン',
      'ステアクライマー',
      'スイミング',
      'ジャンプロープ',
      'エアロビクス',
    ],
    '腕': [
      'バーベルカール',
      'ダンベルカール',
      'インクラインダンベルカール',
      'ケーブルカール',
      'プリーチャーカール',
      'ハンマーカール',
      'コンセントレーションカール',
      'リバースカール',
      'ケーブルトライセプスプレスダウン',
      'スカルクラッシャー',
      'オーバーヘッドトライセプスエクステンション',
      'ダンベルトライセプスキックバック',
      'ケーブルオーバーヘッドトライセプスエクステンション',
      'クローズグリップベンチプレス',
      'リストカール',
    ],
    '胸': [
      'バーベルベンチプレス',
      'インクラインベンチプレス',
      'デクラインベンチプレス',
      'ダンベルベンチプレス',
      'インクラインダンベルプレス',
      'デクラインダンベルプレス',
      'ダンベルフライ',
      'インクラインダンベルフライ',
      'ケーブルクロスオーバー',
      'ペックデックフライ',
      'チェストプレス',
      'スミスマシンベンチプレス',
      'スミスマシンインクラインプレス',
      'ディップス',
      'プッシュアップ（加重・マシン）',
    ],
    '背中': [
      'デッドリフト',
      'ラットプルダウン',
      'リバースグリップラットプルダウン',
      'バーベルベントオーバーロウ',
      'ダンベルワンハンドロウ',
      'シーテッドロウ',
      'Tバーロウ',
      'チンニング（加重）',
      'チンニング（アシスト）',
      'フェイスプル',
      'シュラッグ',
      'ケーブルストレートアームプルダウン',
      'スモウデッドリフト',
      'ルーマニアンデッドリフト',
      'デッドリフト（ベーシック）',
    ],
    '足': [
      'バーベルスクワット',
      'フロントスクワット',
      'レッグプレス',
      'レッグエクステンション',
      'レッグカール',
      'シーテッドレッグカール',
      'ルーマニアンデッドリフト',
      'グッドモーニング',
      'カーフレイズ',
      'シーテッドカーフレイズ',
      'ハックスクワット',
      'スミスマシンスクワット',
      'ケーブルキックバック',
      'ヒップスラスト',
      'デッドリフト（スティッフレッグ）',
    ],
    '肩': [
      'バーベルショルダープレス',
      'ダンベルショルダープレス',
      'スミスマシンショルダープレス',
      'アーノルドプレス',
      'サイドレイズ',
      'リアレイズ',
      'フロントレイズ',
      'ケーブルリアレイズ',
      'アップライトロウ',
      'ショルダープレスマシン',
      'ケーブルフロントレイズ',
      'インクラインサイドレイズ',
      'ダンベルシュラッグ',
      'ケーブルサイドレイズ',
      'フェイスプル',
    ],
    '腹筋': [
      'クランチ',
      'シットアップ',
      'レッグレイズ',
      'ハンギングレッグレイズ',
      'アブローラー',
      'ケーブルクランチ',
      'マシンクランチ',
      'サイドベント',
      'ロシアンツイスト',
      'バイシクルクランチ',
      'Vシットアップ',
      'プランク（加重）',
      'サイドプランク（加重）',
      'ジャックナイフシットアップ',
      'ドラゴンフラッグ',
    ],
    '全身': [
      'ケトルベルスイング',
      'バーピージャンプ',
      'クリーン',
      'クリーン＆プレス',
      'ケーブルウッドチョッパー',
      'ケトルベルゴブレットスクワット',
      'メディシンボールスラム',
      'サンドバッグショルダースクワット',
      'スレッドプッシュ',
      'ステップアップ',
      'ファーマーズウォーク',
      'メディシンボールスクワットプレス',
      'サーキットトレーニング',
      'バーピーサーキット',
      'ロー＆プッシュサーキット',
    ],
    '自重': [
      '腕立て伏せ',
      'ナロー腕立て伏せ',
      'ワイド腕立て伏せ',
      'ダイヤモンド腕立て伏せ',
      'ディップス',
      'スクワット',
      'ジャンプスクワット',
      'ブルガリアンスクワット',
      'ランジ',
      'カーフレイズ',
      '腹筋（クランチ）',
      'レッグレイズ',
      'プランク',
      'サイドプランク',
      'バーピー',
    ],
  };

  // ▼ 追加：l10nからローカライズ済みの配列を返す（camelCaseキーでARB登録済み前提）
  // 部位名（part）は UI表示用のローカライズ文字列（l10n.arm 等）を想定
  static List<String> localizedDefaultsFor(AppLocalizations l10n, String part) {
    if (part == l10n.aerobicExercise) return _aerobicList(l10n);
    if (part == l10n.arm)            return _armList(l10n);
    if (part == l10n.chest)          return _chestList(l10n);
    if (part == l10n.back)           return _backList(l10n);
    if (part == l10n.shoulder)       return _shoulderList(l10n);
    if (part == l10n.leg)            return _legList(l10n);
    if (part == l10n.abs)            return _absList(l10n);
    if (part == l10n.fullBody)       return _fullBodyList(l10n);
    if (part == l10n.bodyweight)     return _bodyweightList(l10n);
    // 不明時は空配列
    return const <String>[];
  }

  // 以下、ARBで用意した camelCase キーを配列化（各15件／有酸素は11件）
  static List<String> _aerobicList(AppLocalizations l10n) => [
    l10n.exerciseAerobic01, l10n.exerciseAerobic02, l10n.exerciseAerobic03,
    l10n.exerciseAerobic04, l10n.exerciseAerobic05, l10n.exerciseAerobic06,
    l10n.exerciseAerobic07, l10n.exerciseAerobic08, l10n.exerciseAerobic09,
    l10n.exerciseAerobic10, l10n.exerciseAerobic11,
  ];

  /// 後方互換：l10nが渡されたらローカライズ配列、無ければ旧デフォルト表（日本語ハードコード）
  /// 既存コードが defaultsFor(part) を呼んでもビルドが通るようにしておく
  static List<String> defaultsFor(String part, {AppLocalizations? l10n}) {
    if (l10n != null) {
      return localizedDefaultsFor(l10n, part);
    }
    final list = _defaultExercises[part];
    return list == null ? const <String>[] : List<String>.unmodifiable(list);
  }


  static List<String> _armList(AppLocalizations l10n) => [
    l10n.exerciseArm01, l10n.exerciseArm02, l10n.exerciseArm03,
    l10n.exerciseArm04, l10n.exerciseArm05, l10n.exerciseArm06,
    l10n.exerciseArm07, l10n.exerciseArm08, l10n.exerciseArm09,
    l10n.exerciseArm10, l10n.exerciseArm11, l10n.exerciseArm12,
    l10n.exerciseArm13, l10n.exerciseArm14, l10n.exerciseArm15,
  ];

  static List<String> _chestList(AppLocalizations l10n) => [
    l10n.exerciseChest01, l10n.exerciseChest02, l10n.exerciseChest03,
    l10n.exerciseChest04, l10n.exerciseChest05, l10n.exerciseChest06,
    l10n.exerciseChest07, l10n.exerciseChest08, l10n.exerciseChest09,
    l10n.exerciseChest10, l10n.exerciseChest11, l10n.exerciseChest12,
    l10n.exerciseChest13, l10n.exerciseChest14, l10n.exerciseChest15,
  ];

  static List<String> _backList(AppLocalizations l10n) => [
    l10n.exerciseBack01, l10n.exerciseBack02, l10n.exerciseBack03,
    l10n.exerciseBack04, l10n.exerciseBack05, l10n.exerciseBack06,
    l10n.exerciseBack07, l10n.exerciseBack08, l10n.exerciseBack09,
    l10n.exerciseBack10, l10n.exerciseBack11, l10n.exerciseBack12,
    l10n.exerciseBack13, l10n.exerciseBack14, l10n.exerciseBack15,
  ];

  static List<String> _shoulderList(AppLocalizations l10n) => [
    l10n.exerciseShoulder01, l10n.exerciseShoulder02, l10n.exerciseShoulder03,
    l10n.exerciseShoulder04, l10n.exerciseShoulder05, l10n.exerciseShoulder06,
    l10n.exerciseShoulder07, l10n.exerciseShoulder08, l10n.exerciseShoulder09,
    l10n.exerciseShoulder10, l10n.exerciseShoulder11, l10n.exerciseShoulder12,
    l10n.exerciseShoulder13, l10n.exerciseShoulder14, l10n.exerciseShoulder15,
  ];

  static List<String> _legList(AppLocalizations l10n) => [
    l10n.exerciseLeg01, l10n.exerciseLeg02, l10n.exerciseLeg03,
    l10n.exerciseLeg04, l10n.exerciseLeg05, l10n.exerciseLeg06,
    l10n.exerciseLeg07, l10n.exerciseLeg08, l10n.exerciseLeg09,
    l10n.exerciseLeg10, l10n.exerciseLeg11, l10n.exerciseLeg12,
    l10n.exerciseLeg13, l10n.exerciseLeg14, l10n.exerciseLeg15,
  ];

  static List<String> _absList(AppLocalizations l10n) => [
    l10n.exerciseAbs01, l10n.exerciseAbs02, l10n.exerciseAbs03,
    l10n.exerciseAbs04, l10n.exerciseAbs05, l10n.exerciseAbs06,
    l10n.exerciseAbs07, l10n.exerciseAbs08, l10n.exerciseAbs09,
    l10n.exerciseAbs10, l10n.exerciseAbs11, l10n.exerciseAbs12,
    l10n.exerciseAbs13, l10n.exerciseAbs14, l10n.exerciseAbs15,
  ];

  static List<String> _fullBodyList(AppLocalizations l10n) => [
    l10n.exerciseFullBody01, l10n.exerciseFullBody02, l10n.exerciseFullBody03,
    l10n.exerciseFullBody04, l10n.exerciseFullBody05, l10n.exerciseFullBody06,
    l10n.exerciseFullBody07, l10n.exerciseFullBody08, l10n.exerciseFullBody09,
    l10n.exerciseFullBody10, l10n.exerciseFullBody11, l10n.exerciseFullBody12,
    l10n.exerciseFullBody13, l10n.exerciseFullBody14, l10n.exerciseFullBody15,
  ];

  static List<String> _bodyweightList(AppLocalizations l10n) => [
    l10n.exerciseBodyweight01, l10n.exerciseBodyweight02, l10n.exerciseBodyweight03,
    l10n.exerciseBodyweight04, l10n.exerciseBodyweight05, l10n.exerciseBodyweight06,
    l10n.exerciseBodyweight07, l10n.exerciseBodyweight08, l10n.exerciseBodyweight09,
    l10n.exerciseBodyweight10, l10n.exerciseBodyweight11, l10n.exerciseBodyweight12,
    l10n.exerciseBodyweight13, l10n.exerciseBodyweight14, l10n.exerciseBodyweight15,
  ];


  static bool supportsPart(String part) => _defaultExercises.containsKey(part);

  static Map<String, List<String>> get allDefaults =>
      UnmodifiableMapView(_defaultExercises);
}
