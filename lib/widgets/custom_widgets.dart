import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// グラスモーフィズム風のカードウィジェット
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final double elevation; // 影の深さを追加

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 16.0,
    this.backgroundColor = Colors.white54,
    this.padding = const EdgeInsets.all(16.0),
    this.elevation = 4.0, // デフォルトの影の深さ
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation, // 影の深さを適用
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
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
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Color? buttonColor; // ボタンの背景色を追加

  const StylishButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.fontSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.buttonColor, // コンストラクタに追加
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor ?? colorScheme.primary, // 指定があればそれを使用、なければプライマリカラー
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        padding: padding,
        elevation: 4.0,
        shadowColor: colorScheme.shadow.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize * 1.2),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// スタイリッシュなテキスト入力ウィジェット
class StylishInput extends StatefulWidget {
  final TextEditingController controller; // 外部から渡されるコントローラー
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
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
    this.textStyle,
    this.fillColor,
    this.contentPadding,
    this.isSuggestionDisplay = false,
    this.textAlign = TextAlign.center,
    this.onChanged,
    this.onTap,
  }) : super(key: key);

  @override
  _StylishInputState createState() => _StylishInputState();
}

class _StylishInputState extends State<StylishInput> {
  @override
  void initState() {
    super.initState();
    // コントローラーの変更をリッスンしてUIを更新
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // コントローラーのテキストが変更されたときにUIを更新する
  void _onControllerChanged() {
    // setStateを呼び出してウィジェットを再ビルドし、hintTextの表示を更新
    // ただし、ウィジェットがマウントされているか確認する
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = widget.textStyle ?? Theme.of(context).textTheme.bodyLarge;
    final effectiveFillColor = widget.fillColor ?? Theme.of(context).colorScheme.surfaceVariant;

    return TextField(
      controller: widget.controller, // 外部から渡されたコントローラーを直接使用
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      style: widget.isSuggestionDisplay && widget.controller.text.isEmpty
          ? effectiveTextStyle?.copyWith(color: effectiveTextStyle.color?.withOpacity(0.5) ?? Colors.grey) // 提案表示時は薄い色
          : effectiveTextStyle, // 通常時は元の色
      textAlign: widget.textAlign,
      decoration: InputDecoration(
        // コントローラーのテキストが空で、かつisSuggestionDisplayがtrueの場合のみヒントテキストを表示
        hintText: (widget.isSuggestionDisplay && widget.controller.text.isEmpty) ? widget.hint : null,
        hintStyle: effectiveTextStyle?.copyWith(color: effectiveTextStyle.color?.withOpacity(0.5) ?? Colors.grey),
        filled: true,
        fillColor: effectiveFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: widget.contentPadding,
      ),
      onChanged: widget.onChanged,
      onTap: widget.onTap,
    );
  }
}

// ドロップダウンメニューの項目ウィジェット
class DropMenuItem<T> extends DropdownMenuItem<T> {
  const DropMenuItem({
    Key? key,
    required T value,
    required Widget child,
  }) : super(key: key, value: value, child: child);
}
