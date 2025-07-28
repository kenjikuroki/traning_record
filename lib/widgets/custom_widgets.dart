import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter を使用するためにインポート

// StylishButton ウィジェット
class StylishButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Color? buttonColor;
  final Color? textColor;

  const StylishButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.fontSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.buttonColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor ?? colorScheme.primary,
        foregroundColor: textColor ?? colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        padding: padding,
        elevation: 5, // シャドウを追加
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// StylishInput ウィジェット
class StylishInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Color normalTextColor;
  final Color suggestionTextColor;
  final Color fillColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isSuggestionDisplay;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const StylishInput({
    Key? key,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    required this.normalTextColor,
    required this.suggestionTextColor,
    required this.fillColor,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    this.isSuggestionDisplay = false,
    this.textAlign = TextAlign.left,
    this.onChanged,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? [],
      style: TextStyle(
        color: isSuggestionDisplay ? suggestionTextColor : normalTextColor,
        fontSize: 14.0,
        fontWeight: isSuggestionDisplay ? FontWeight.normal : FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: suggestionTextColor, fontSize: 14.0),
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
      textAlign: textAlign,
      onChanged: onChanged,
      onTap: onTap,
    );
  }
}

// GlassCard ウィジェット
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 12.0,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

// CircularAddButtonWithText ウィジェット
class CircularAddButtonWithText extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? buttonColor;
  final Color? textColor;
  final double iconSize;
  final double circleSize;
  final double fontSize;

  const CircularAddButtonWithText({
    Key? key,
    required this.label,
    required this.onPressed,
    this.buttonColor,
    this.textColor,
    this.iconSize = 20.0, // アイコンサイズを小さくしました
    this.circleSize = 40.0, // 丸のサイズをさらに小さくしました
    this.fontSize = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox( // Fixed: Added SizedBox to control the size of the FloatingActionButton
          width: circleSize,
          height: circleSize,
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: buttonColor ?? colorScheme.primary,
            foregroundColor: Colors.white, // 「+」記号を白文字にする
            shape: const CircleBorder(),
            elevation: 0, // 影をなくす
            child: Icon(Icons.add, size: iconSize),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor ?? colorScheme.onSurface,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
