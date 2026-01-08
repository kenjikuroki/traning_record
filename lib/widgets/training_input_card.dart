import 'package:flutter/material.dart';

/// TrainingInputCard: _MenuDetailPage から抽出した筋トレ入力UI本体をまとめるカードWidget。
/// 現時点ではページ側から渡された各種Widget/コールバックをラップし、
/// 将来的に RecordScreen からも直接再利用できるよう準備する段階の実装です。
class TrainingInputCard extends StatelessWidget {
  const TrainingInputCard({
    super.key,
    required this.nameArea,
    required this.showIntervalTimer,
    this.intervalTimer,
    required this.onSave,
    required this.saveLabel,
    required this.saveButtonStyle,
    required this.headerBackground,
    required this.headerForeground,
    required this.bodyContent,
    this.bodyPadding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
  });

  final Widget nameArea;
  final bool showIntervalTimer;
  final Widget? intervalTimer;
  final VoidCallback onSave;
  final String saveLabel;
  final ButtonStyle saveButtonStyle;
  final Color headerBackground;
  final Color headerForeground;
  final Widget bodyContent;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: headerBackground,
              borderRadius: BorderRadius.circular(14.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: nameArea),
                if (showIntervalTimer && intervalTimer != null) ...[
                  const SizedBox(width: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: intervalTimer!,
                  ),
                  const SizedBox(width: 10),
                ],
                TextButton.icon(
                  onPressed: onSave,
                  style: saveButtonStyle,
                  icon: Icon(Icons.check_rounded, color: headerForeground),
                  label: Text(
                    saveLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: bodyPadding,
            child: bodyContent,
          ),
        ),
      ],
    );
  }
}
