import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ガラスのようなカードウィジェット
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 8.0,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      color: backgroundColor,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

// スタイリッシュなボタンウィジェット
class StylishButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Color buttonColor;
  final Color textColor;

  const StylishButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.fontSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.buttonColor = Colors.blue,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// スタイリッシュな入力フィールドウィジェット
class StylishInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Color normalTextColor; // 新しいプロパティ
  final Color suggestionTextColor; // 新しいプロパティ
  final Color fillColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isSuggestionDisplay;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;

  const StylishInput({
    Key? key,
    required this.controller,
    this.hint = '',
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    required this.normalTextColor, // 必須
    required this.suggestionTextColor, // 必須
    required this.fillColor,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    this.isSuggestionDisplay = false,
    this.textAlign = TextAlign.left,
    this.onChanged,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayColor = isSuggestionDisplay ? suggestionTextColor : normalTextColor;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      style: TextStyle( // ここでTextStyleを簡素化
        color: displayColor,
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle( // ヒントは常に薄い色
          color: suggestionTextColor,
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: fillColor,
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
          borderSide: BorderSide.none,
        ),
        contentPadding: contentPadding,
      ),
      onChanged: onChanged,
      onTap: onTap,
    );
  }
}
