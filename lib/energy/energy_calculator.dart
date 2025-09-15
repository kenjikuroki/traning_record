// lib/energy/energy_calculator.dart
//
// 有酸素の消費カロリー算出ロジック（筋トレ拡張も想定して分離）
// 使い方：
//   final out = EnergyCalculator.estimateAerobicKcal(
//     distanceKm: 5.0,
//     duration: Duration(minutes: 30),
//     weightKg: 65.0,
//     activity: AerobicActivity.running, // 未指定なら速度で歩/走/自転車を概ね推定
//   );
//   if (out != null) {
//     print(out.kcal);           // 生値（UI側で丸め）
//     print(out.breakdown.met);  // 使用MET
//   }
//
// メモ：UI側の「❔ヘルプ」は breakdown の数値（速度, MET, 時間, 体重, 活動種別）を
// l10n 文言に埋め込んで表示してください。

enum AerobicActivity {
  running,        // ランニング / ジョギング
  walking,        // ウォーキング
  cycling,        // 自転車（屋外）
  exerciseBike,   // エアロバイク（室内）
  elliptical,     // エリプティカル
  rowing,         // ローイング
  unknown,        // 不明（記述のみ等）
}

class PersonalProfile {
  /// "male" | "female" | "unspecified"
  final String gender;
  final DateTime? birthDate;
  final double? heightCm;

  const PersonalProfile({
    this.gender = 'unspecified',
    this.birthDate,
    this.heightCm,
  });

  int? get ageYears {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - birthDate!.year;
    final hadBirthday =
        (now.month > birthDate!.month) ||
            (now.month == birthDate!.month && now.day >= birthDate!.day);
    if (!hadBirthday) age -= 1;
    return age;
  }
}

class EnergyBreakdown {
  final double speedKph;            // 実測速度 [km/h]
  final double met;                 // 使用した MET
  final double durationHours;       // 運動時間 [h]
  final double weightKg;            // 体重 [kg]
  final AerobicActivity activity;   // 算出に用いた活動種別

  const EnergyBreakdown({
    required this.speedKph,
    required this.met,
    required this.durationHours,
    required this.weightKg,
    required this.activity,
  });
}

class EnergyCalcOutput {
  final double kcal;                // 消費カロリー（kcal）※丸めはUI側で
  final EnergyBreakdown breakdown;  // 内訳（ヘルプ表示用）

  const EnergyCalcOutput({
    required this.kcal,
    required this.breakdown,
  });
}

class EnergyCalculator {
  /// 有酸素の消費カロリーを推定します。
  /// - 必須：距離[km]と時間、体重[kg]
  /// - activity 未指定時は速度しきい値で「歩く/走る/自転車」を概ね推定します
  ///   （UI側でプリセット選択がある場合は activity を明示指定してください）
  static EnergyCalcOutput? estimateAerobicKcal({
    required double distanceKm,
    required Duration duration,
    required double weightKg,
    AerobicActivity activity = AerobicActivity.unknown,
    PersonalProfile? profile, // 将来拡張用（年齢/身長などが必要になったら利用）
  }) {
    if (distanceKm <= 0 || duration.inSeconds <= 0 || weightKg <= 0) {
      return null;
    }

    final hours = duration.inSeconds / 3600.0;
    final kph = distanceKm / hours;

    final resolved = _resolveActivity(activity, kph);
    final met = _metFor(resolved, kph);

    // 基本式：kcal = MET × 体重(kg) × 時間(h)
    final kcal = met * weightKg * hours;

    return EnergyCalcOutput(
      kcal: kcal,
      breakdown: EnergyBreakdown(
        speedKph: kph,
        met: met,
        durationHours: hours,
        weightKg: weightKg,
        activity: resolved,
      ),
    );
  }

  // 未指定時のフォールバック推定（控えめ）
  static AerobicActivity _resolveActivity(AerobicActivity given, double kph) {
    if (given != AerobicActivity.unknown) return given;
    if (kph < 7.0) return AerobicActivity.walking;      // <7km/h は歩行想定
    if (kph >= 18.0) return AerobicActivity.cycling;    // ≥18km/h は自転車想定
    return AerobicActivity.running;                      // 中間は走行想定
  }

  static double _metFor(AerobicActivity kind, double kph) {
    switch (kind) {
      case AerobicActivity.walking:
        return _metWalking(kph);
      case AerobicActivity.running:
        return _metRunning(kph);
      case AerobicActivity.cycling:
        return _metCycling(kph);
      case AerobicActivity.exerciseBike:
        return _metStationaryBike(kph);
      case AerobicActivity.elliptical:
        return _metElliptical(kph);
      case AerobicActivity.rowing:
        return _metRowing(kph);
      case AerobicActivity.unknown:
      default:
        return _metRunning(kph);
    }
  }

  // ───── MET 推定関数群 ─────
  // ACSM の平地方程式から速度依存で概算（v[m/min] → MET）
  // Walking: VO2 = 0.1*v + 3.5 -> MET = (0.1*v+3.5)/3.5
  // Running: VO2 = 0.2*v + 3.5 -> MET = (0.2*v+3.5)/3.5
  // v[m/min] = kph * 1000 / 60

  static double _metWalking(double kph) {
    final met = 1.0 + 0.476190476 * kph; // ≒ 1 + 0.476*kph
    final clamped = met.clamp(2.0, 8.0); // 妥当域に制限
    return (clamped as num).toDouble();
  }

  static double _metRunning(double kph) {
    final met = 1.0 + 0.952380952 * kph; // ≒ 1 + 0.952*kph
    final clamped = met.clamp(4.0, 18.0);
    return (clamped as num).toDouble();
  }

  // 屋外サイクリング：速度帯で段階化（一般的な目安）
  static double _metCycling(double kph) {
    if (kph < 16) return 6.0;     // ~ゆっくり
    if (kph < 19) return 8.0;     // ふつう
    if (kph < 22) return 10.0;    // 速い
    if (kph < 25) return 12.0;    // かなり速い
    if (kph < 30) return 14.0;    // 強度高め
    return 16.0;                  // とても高強度
  }

  // エアロバイク：目安（速度があれば準用）
  static double _metStationaryBike(double kph) {
    if (kph < 16) return 6.0;
    if (kph < 22) return 7.0;
    if (kph < 28) return 10.0;
    return 12.0;
  }

  // エリプティカル
  static double _metElliptical(double kph) {
    if (kph < 5) return 5.0;
    if (kph < 8) return 6.5;
    if (kph < 11) return 7.5;
    return 9.0;
  }

  // ローイング
  static double _metRowing(double kph) {
    if (kph < 6) return 6.0;
    if (kph < 8) return 7.0;
    if (kph < 10) return 8.5;
    if (kph < 12) return 10.0;
    return 12.0;
  }
}
