import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// SetInputDataクラスを定義
// このファイルでは使用しませんが、他のファイルとの整合性のため残します。
// ignore_for_file: unused_import
import '../models/menu_data.dart';

// アニメーションの方向を定義するenum
enum AnimationDirection {
  topToBottom,
  bottomToTop,
}

// アニメーション付きリストアイテムウィジェット
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AnimationDirection direction;

  const AnimatedListItem({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    this.direction = AnimationDirection.bottomToTop,
  }) : super(key: key);

  @override
  _AnimatedListItemState createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    Offset beginOffset;
    if (widget.direction == AnimationDirection.topToBottom) {
      beginOffset = const Offset(0.0, -0.5);
    } else {
      beginOffset = const Offset(0.0, 0.5);
    }

    _offsetAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }
}


// ★カスタム入力フィールド
class StylishInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool isPlaceholder;

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
    this.isPlaceholder = false,
  });

  @override
  State<StylishInput> createState() => _StylishInputState();
}

class _StylishInputState extends State<StylishInput> {
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

// ★カスタムボタン
class StylishButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final double? fontSize; // ★追加：フォントサイズ
  final EdgeInsetsGeometry? padding; // ★追加：パディング

  const StylishButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
    this.fontSize, // ★コンストラクタに追加
    this.padding, // ★コンストラクタに追加
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
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // ★パディングを適用
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
              fontSize: fontSize ?? 18.0, // ★フォントサイズを適用
              fontWeight: FontWeight.bold,
              color: textColor ?? colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ★ガラスカード
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
