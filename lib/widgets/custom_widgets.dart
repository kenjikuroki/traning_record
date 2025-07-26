import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter を使用するためにインポート

// StylishButton ウィジェットの定義
class StylishButton extends StatelessWidget {
  final String text; // ボタンに表示するテキスト
  final VoidCallback onPressed; // ボタンが押されたときに実行されるコールバック
  final double fontSize; // テキストのフォントサイズ
  final EdgeInsetsGeometry padding; // ボタンのパディング
  final Color? buttonColor; // 追加: ボタンの背景色（オプション）

  const StylishButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.fontSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.buttonColor, // コンストラクタにbuttonColorを追加
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // buttonColorが指定されていればそれを使用し、なければテーマのprimary色を使用
        backgroundColor: buttonColor ?? Theme.of(context).colorScheme.primary,
        // ボタンのテキスト色を白に設定（青系のボタンに合うように）
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0), // 角丸を設定
        ),
        padding: padding, // パディングを設定
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize), // フォントサイズを設定
      ),
    );
  }
}

// GlassCard ウィジェットの定義（既存のコードから変更なし）
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 8.0,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
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

// StylishInput ウィジェットの定義
class StylishInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters; // 型定義を修正
  final TextStyle? textStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isSuggestionDisplay;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;

  const StylishInput({
    Key? key,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textStyle,
    this.fillColor,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    this.isSuggestionDisplay = false,
    this.textAlign = TextAlign.left,
    this.onChanged,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultTextStyle = TextStyle(color: colorScheme.onSurface, fontSize: 16.0);
    final suggestionTextStyle = defaultTextStyle.copyWith(
      color: colorScheme.onSurface.withOpacity(0.5), // 薄い色で表示
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: isSuggestionDisplay ? suggestionTextStyle : (textStyle ?? defaultTextStyle),
      textAlign: textAlign,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 14.0),
        filled: true,
        fillColor: fillColor ?? colorScheme.surfaceContainer,
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
