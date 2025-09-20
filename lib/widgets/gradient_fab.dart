// lib/widgets/gradient_fab.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 落ち着いたピンク〜パープル系の角丸“＋”ボタン。
/// - 位置は既存の `floatingActionButtonLocation` をそのまま使用してください。
/// - `heroTag` を渡せば従来の FAB と同じように Hero 遷移も維持できます。
class GradientFAB extends StatelessWidget {
  /// タップ時の処理
  final VoidCallback onPressed;

  /// アイコン（既定は +）
  final IconData icon;

  /// 長押し時のツールチップ
  final String? tooltip;

  /// Hero タグ（画面ごとにユニーク推奨。不要なら null）
  final String? heroTag;

  /// 幅（角丸ボタンなので width/height を個別指定）
  final double width;

  /// 高さ
  final double height;

  /// 角丸半径
  final double borderRadius;

  /// 色を上書きしたい場合は指定（未指定なら AppTokens.gradientMuted）
  final List<Color>? colors;

  /// 影を出すかどうか
  final bool showShadow;

  const GradientFAB({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
    this.heroTag,
    this.width = 60,
    this.height = 56,
    this.borderRadius = 16,
    this.colors,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final core = SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: colors ?? AppTokens.gradientMuted,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: showShadow
                ? const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 6),
                color: Color(0x26000000), // 15%くらいの柔らかい影
              ),
            ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onPressed,
            child: Center(
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );

    final withTooltip =
    (tooltip != null && tooltip!.isNotEmpty) ? Tooltip(message: tooltip!, child: core) : core;

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: withTooltip);
    }
    return withTooltip;
  }
}
