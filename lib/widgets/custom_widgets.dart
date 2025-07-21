import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ★カスタムウィジェット
class StylishInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool isPlaceholder; // ★このプロパティは残す (初期表示用)

  const StylishInput({
    super.key,
    required this.controller,
    this.hint = '',
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textStyle,
    this.hintStyle,
    this.fillColor,
    this.contentPadding,
    this.isPlaceholder = false, // ★デフォルト値をfalseに
  });

  @override
  State<StylishInput> createState() => _StylishInputState();
}

class _StylishInputState extends State<StylishInput> {
  // ★_focusNodeと_currentIsPlaceholderは削除。直接widget.isPlaceholderを使用する。

  @override
  void initState() {
    super.initState();
    // ★コントローラーのリスナーはSetInputDataで管理するため、ここでは不要
    // ★フォーカスノードもここでは不要
  }

  @override
  void didUpdateWidget(covariant StylishInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ★コントローラーの変更検知もSetInputDataに任せる
  }

  @override
  void dispose() {
    // ★リスナーとフォーカスノードのdisposeは不要になった
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveTextStyle = widget.textStyle ?? TextStyle(color: colorScheme.onSurface);
    final effectiveHintStyle = widget.hintStyle ?? TextStyle(color: colorScheme.onSurfaceVariant);

    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      style: effectiveTextStyle.copyWith(
        // ★widget.isPlaceholderがtrueの場合に薄い色を適用
        color: widget.isPlaceholder ? effectiveHintStyle.color : effectiveTextStyle.color,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: effectiveHintStyle,
        filled: true,
        fillColor: widget.fillColor ?? colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }
}

// 他のカスタムウィジェットは変更なし
// StylishButton, GlassCard など
// ... (既存のコードをここに含める)
class StylishButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const StylishButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? colorScheme.primary,
        foregroundColor: textColor ?? colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: 4.0,
        shadowColor: colorScheme.shadow.withOpacity(0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? colorScheme.onPrimary),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: textColor ?? colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}
