import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatterのために必要

// StylishInput: テキスト入力フィールドのカスタムスタイル
class StylishInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;

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
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: textStyle ?? TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: hintStyle ?? TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
        filled: true,
        fillColor: fillColor ?? colorScheme.surface, // デフォルトはsurface
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: colorScheme.primary, width: 2), // フォーカス時の色
        ),
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }
}

// StylishButton: ElevatedButtonのカスタムスタイル
class StylishButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor; // オプションで背景色を指定できるようにする

  const StylishButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, color: colorScheme.onPrimary, size: 28.0) // アイコンの色はonPrimary
          : const SizedBox.shrink(), // アイコンがない場合は空のSizedBox
      label: Text(
        text,
        style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 18.0), // テキストの色はonPrimary
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? colorScheme.primary, // デフォルトはprimary
        padding: const EdgeInsets.symmetric(vertical: 18.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 4.0,
        shadowColor: colorScheme.shadow.withOpacity(0.3), // 影の色
      ),
    );
  }
}

// GlassCard: Cardのカスタムスタイル（Material Design 3のCardをベースに）
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor; // オプションで背景色を指定できるようにする
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0.0),
      elevation: 1.0, // 影は控えめに
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      color: backgroundColor ?? colorScheme.surfaceVariant, // デフォルトはsurfaceVariant
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }
}
