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

  const StylishButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.fontSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
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

// スタイリッシュなテキスト入力ウィジェット (変更あり)
class StylishInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool isSuggestionDisplay; // 新しいプロパティ: 提案データとして表示するかどうか
  final TextAlign textAlign;
  final VoidCallback? onTap; // 追加: タップイベントを通知するコールバック
  final ValueChanged<String>? onChanged; // 追加: onChangedイベントを通知するコールバック

  const StylishInput({
    Key? key,
    required this.controller,
    this.hint = '',
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textStyle,
    this.fillColor,
    this.contentPadding,
    this.isSuggestionDisplay = false, // デフォルトはfalse
    this.textAlign = TextAlign.center,
    this.onTap, // 追加
    this.onChanged, // 追加
  }) : super(key: key);

  @override
  _StylishInputState createState() => _StylishInputState();
}

class _StylishInputState extends State<StylishInput> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // フォーカスが変更されたときにウィジェットを再ビルドして色を更新
    _focusNode.addListener(() {
      setState(() {});
      // フォーカスが当たったときにonTapコールバックをトリガー
      if (_focusNode.hasFocus && widget.onTap != null) {
        widget.onTap!();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = widget.textStyle ?? Theme.of(context).textTheme.bodyLarge;
    final effectiveFillColor = widget.fillColor ?? Theme.of(context).colorScheme.surfaceVariant;
    final colorScheme = Theme.of(context).colorScheme;

    Color textColor;
    // フォーカスがある場合、または提案表示ではない場合（ユーザーが入力済みの場合など）は濃い色
    if (_focusNode.hasFocus || !widget.isSuggestionDisplay) {
      textColor = effectiveTextStyle?.color ?? colorScheme.onSurface;
    } else {
      // フォーカスがなく、提案表示の場合は薄い色
      textColor = (effectiveTextStyle?.color ?? colorScheme.onSurface).withOpacity(0.5);
    }

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode, // FocusNodeをTextFieldに適用
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      style: effectiveTextStyle?.copyWith(color: textColor), // 色を動的に適用
      textAlign: widget.textAlign,
      decoration: InputDecoration(
        // コントローラーのテキストが空で、かつフォーカスがなく、提案表示の場合のみヒントテキストを表示
        hintText: widget.controller.text.isEmpty && !_focusNode.hasFocus && widget.isSuggestionDisplay ? widget.hint : null,
        hintStyle: effectiveTextStyle?.copyWith(color: effectiveTextStyle.color?.withOpacity(0.5) ?? Colors.grey),
        filled: true,
        fillColor: effectiveFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: widget.contentPadding,
      ),
      onChanged: (value) {
        // 外部から渡されたonChangedコールバックを呼び出す
        if (widget.onChanged != null) {
          widget.onChanged!(value);
        }
      },
      onTap: () {
        // TextFieldがタップされたときにonTapコールバックをトリガー
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
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