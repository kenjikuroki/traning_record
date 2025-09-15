// lib/energy_calc.dart
// 有酸素のカロリー算出ユーティリティ（将来：筋トレ拡張予定）
// 依存：純Dart（Flutter/UIやHiveに依存しない純ロジック）
//
// 使い方（例）:
//   final r = EnergyCalc.estimateAerobic(
//     distanceKm: 5.0,
//     durationMinutes: 30,
//     bodyMassKg: 65,
//     preset: AerobicPreset.none, // or walk/run/cycle（将来UIの選択に接続）
//   );
//   if (r != null) {
//     print('${r.kcal} kcal, MET=${r.met}, v=${r.speedKmh} km/h');
//   }
//
// 注意：UI側では「距離」「時間」が両方入力済みのときだけ呼び出す。
//       設定トグル（feature.aeroKcal）がOFFならUI表示しない。
//       上書き（手入力）を許す設計はUI側で実装する。

/// 有酸素プリセット（将来、記述＋選択の“選択側”用）
enum AerobicPreset {
  none,  // 未指定（速度から推定テーブルを選ぶ）
  walk,  // ウォーキング系（速度テーブル：歩行）
  run,   // ランニング系（速度テーブル：走行）
  cycle, // 自転車系（速度テーブル：サイクリング）
  // TODO: 筋トレ導入時に追加（row, swim, elliptical など拡張余地）
}

/// 算出結果（UI表示やログ保存で再利用できるメタ付き）
class AerobicCalcResult {
  final double kcal;       // 消費カロリー（kcal）
  final double met;        // 用いた MET
  final double speedKmh;   // 入力から算出した速度（km/h）
  final AerobicPreset usedPreset; // 実際に使われたプリセット

  const AerobicCalcResult({
    required this.kcal,
    required this.met,
    required this.speedKmh,
    required this.usedPreset,
  });
}

class EnergyCalc {
  EnergyCalc._(); // staticユーティリティ

  /// 有酸素のカロリー推定
  ///
  /// [distanceKm] 走行距離(km)
  /// [durationMinutes] 所要時間(分)
  /// [bodyMassKg] 体重(kg) — 設定の単位が lbs の場合はUI側で kg に換算して渡す
  /// [preset] ユーザーがプリセットを選んだ場合に指定（未選択なら none）
  ///
  /// 戻り値：十分な入力があれば [AerobicCalcResult]、なければ null
  static AerobicCalcResult? estimateAerobic({
    required double distanceKm,
    required double durationMinutes,
    required double bodyMassKg,
    AerobicPreset preset = AerobicPreset.none,
  }) {
    if (distanceKm <= 0 || durationMinutes <= 0 || bodyMassKg <= 0) {
      return null;
    }

    final speedKmh = _safeSpeedKmh(distanceKm, durationMinutes);
    final usedPreset = _decidePreset(preset, speedKmh);
    final met = _metFromSpeed(speedKmh, usedPreset);

    // kcal = MET × 体重(kg) × 時間(h)
    final hours = durationMinutes / 60.0;
    final kcal = met * bodyMassKg * hours;

    return AerobicCalcResult(
      kcal: _round1(kcal),
      met: met,
      speedKmh: _round2(speedKmh),
      usedPreset: usedPreset,
    );
  }

  /// 速度(km/h)の安全計算
  static double _safeSpeedKmh(double distanceKm, double durationMinutes) {
    final h = durationMinutes / 60.0;
    if (h <= 0) return 0;
    final v = distanceKm / h;
    // 非現実的な値の丸め（上限は任意。ここでは 0〜80km/h にクリップ）
    if (v.isNaN || !v.isFinite) return 0;
    return v.clamp(0.0, 80.0);
  }

  /// プリセット最終決定
  /// - ユーザー指定があればそれを優先
  /// - 指定なし(none)の場合は速度から簡易判定
  static AerobicPreset _decidePreset(AerobicPreset preset, double speedKmh) {
    if (preset != AerobicPreset.none) return preset;

    // 簡易ヒューリスティクス（UIにカテゴリを“表示”しない前提の内部振り分け）
    // - ~ 6.5 km/h までは歩行テーブル
    // - 6.5 ~ 15 km/h は走行テーブル
    // - 15 km/h 以上は自転車テーブル
    if (speedKmh < 6.5) return AerobicPreset.walk;
    if (speedKmh < 15.0) return AerobicPreset.run;
    return AerobicPreset.cycle;
  }

  /// 速度に応じた MET を返す
  /// 値は「歩行/走行/自転車」の代表的レンジを段階化（Compendium系の代表値を簡略化）
  static double _metFromSpeed(double vKmh, AerobicPreset preset) {
    switch (preset) {
      case AerobicPreset.walk:
      // 歩行（代表値）
        if (vKmh < 3.2) return 2.5;      // とてもゆっくり
        if (vKmh < 4.0) return 3.0;      // ゆっくり
        if (vKmh < 4.8) return 3.3;      // 普通
        if (vKmh < 5.6) return 3.8;      // 速歩
        if (vKmh < 6.4) return 4.3;      // とても速歩
        return 5.0;                      // 速歩の上限側
      case AerobicPreset.run:
      // 走行（代表値）
        if (vKmh < 8.0)  return 7.0;     // ジョグ手前
        if (vKmh < 9.7)  return 8.3;     // 5 mph 相当
        if (vKmh < 10.8) return 9.0;
        if (vKmh < 11.3) return 9.8;     // 6 mph 相当
        if (vKmh < 12.9) return 10.5;
        if (vKmh < 14.5) return 11.5;    // 7.5 mph 付近
        return 12.5;                     // それ以上
      case AerobicPreset.cycle:
      // 自転車（代表値：実走/エアロバイク目安）
        if (vKmh < 16.0) return 4.0;     // とても楽
        if (vKmh < 19.0) return 6.8;     // 楽〜中
        if (vKmh < 22.5) return 8.0;     // 中
        if (vKmh < 25.5) return 10.0;    // ややきつい
        if (vKmh < 30.5) return 12.0;    // きつい
        return 15.8;                     // とてもきつい
      case AerobicPreset.none:
      // ここには来ない想定（_decidePresetで決まる）
        return 6.0;
    }
  }

  static double _round1(double v) => (v * 10).round() / 10.0;
  static double _round2(double v) => (v * 100).round() / 100.0;

// ───────── 将来拡張（筋トレ）プレースホルダ ─────────
// MEMO: 筋トレ導入時に以下を追加
//  - estimateResistanceTraining({ sets/reps/重量/休息/推定1RM など })
//  - METまたは代謝モデル（EPOC等）の併用検討
//  - 種目別のベースMETは met_catalog.dart 等のテーブルから取得
}
