import 'package:ttraining_record/l10n/app_localizations.dart';
import '../settings_manager.dart';

String formatStrengthSetDisplay({
  required AppLocalizations l10n,
  required String weight,
  required String unit,
  required String reps,
}) {
  final weightTrimmed = weight.trim();
  final repsTrimmed = reps.trim();
  final hasWeight = weightTrimmed.isNotEmpty;
  final hasReps = repsTrimmed.isNotEmpty;

  if (hasWeight && hasReps) {
    return '$weightTrimmed $unit / $repsTrimmed ${l10n.reps}';
  }
  if (hasWeight) {
    return '$weightTrimmed $unit';
  }
  if (hasReps) {
    return '$repsTrimmed ${l10n.reps}';
  }
  return '-';
}

String formatTotalVolumeValue(
  AppLocalizations l10n,
  double? volume, {
  bool withSign = false,
}) {
  if (volume == null) {
    return l10n.valueNotAvailable;
  }
  final String unit =
      SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
  final bool isInteger =
      (volume - volume.truncateToDouble()).abs() < 0.0001;
  String number = isInteger
      ? volume.toStringAsFixed(0)
      : volume
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
  if (withSign && volume > 0) {
    number = '+$number';
  } else if (withSign && volume == 0) {
    number = '0';
  }
  return '$number $unit';
}
