import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatter を使用するためにインポート

// CircularAddButtonWithText ウィジェット (ライトモード時の背景を暗めに + テキストサイズに合わせる)
class CircularAddButtonWithText extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? normalBgColorOverride;
  final Color? pressedBgColorOverride;
  final Color? textColorOverride;
  final Color? accentColorOverride;

  const CircularAddButtonWithText({
    Key? key,
    required this.label,
    required this.onPressed,
    this.normalBgColorOverride,
    this.pressedBgColorOverride,
    this.textColorOverride,
    this.accentColorOverride,
  }) : super(key: key);

  @override
  _CircularAddButtonWithTextState createState() => _CircularAddButtonWithTextState();
}

class _CircularAddButtonWithTextState extends State<CircularAddButtonWithText> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;

    final Color normalBgColor = widget.normalBgColorOverride ??
        (isLightMode ? const Color(0xFFCCCCCC) : const Color(0xFF2C2F33));
    final Color pressedBgColor = widget.pressedBgColorOverride ??
        (isLightMode ? const Color(0xFFE0E0E0) : const Color(0xFF383C40));
    final Color textColor = widget.textColorOverride ??
        (isLightMode ? const Color(0xFF555555) : const Color(0xFFCCCCCC));
    final Color accentColor = widget.accentColorOverride ??
        (isLightMode ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA));

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isPressed ? pressedBgColor : normalBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: _isPressed ? accentColor : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
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
    this.borderRadius = 8.0,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
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

// lib/widgets/custom_widgets.dart

class StylishInput extends StatefulWidget {
  final TextEditingController controller;
  final String? hint; // ここを String? に変更
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Color normalTextColor;
  final Color suggestionTextColor;
  final Color fillColor;
  final EdgeInsetsGeometry contentPadding;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const StylishInput({
    Key? key,
    required this.controller,
    this.hint, // ここも required を外し、null を許容するように
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    required this.normalTextColor,
    required this.suggestionTextColor,
    required this.fillColor,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    required this.textAlign,
    this.onChanged,
    this.onTap,
  }) : super(key: key);

  @override
  _StylishInputState createState() => _StylishInputState();
}

class _StylishInputState extends State<StylishInput> {
  late bool _isSuggestionDisplay;

  @override
  void initState() {
    super.initState();
    // hint が null でない場合にのみ _isSuggestionDisplay を初期化
    _isSuggestionDisplay = widget.controller.text.isEmpty && (widget.hint != null && widget.hint!.isNotEmpty);
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant StylishInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      // hint が null でない場合にのみ _isSuggestionDisplay を更新
      _isSuggestionDisplay = widget.controller.text.isEmpty && (widget.hint != null && widget.hint!.isNotEmpty);
    }
    if (oldWidget.hint != widget.hint) {
      // hint が null でない場合にのみ _isSuggestionDisplay を更新
      _isSuggestionDisplay = widget.controller.text.isEmpty && (widget.hint != null && widget.hint!.isNotEmpty);
    }
  }

  void _handleControllerChange() {
    // hint が null でない場合のみロジックを実行
    if (widget.hint != null && widget.hint!.isNotEmpty) {
      if (_isSuggestionDisplay && widget.controller.text.isNotEmpty) {
        setState(() {
          _isSuggestionDisplay = false;
        });
      } else if (!_isSuggestionDisplay && widget.controller.text.isEmpty) {
        setState(() {
          _isSuggestionDisplay = true;
        });
      }
    } else {
      // hint がない場合は常に通常の表示
      if (_isSuggestionDisplay) {
        setState(() {
          _isSuggestionDisplay = false;
        });
      }
    }
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign,
      style: TextStyle(
        color: _isSuggestionDisplay ? widget.suggestionTextColor : widget.normalTextColor,
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: _isSuggestionDisplay ? widget.hint : null, // hintText は String? を受け入れる
        hintStyle: TextStyle(
          color: widget.suggestionTextColor,
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: widget.fillColor,
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
        contentPadding: widget.contentPadding,
      ),
      onTap: () {
        // hint が null でない場合のみロジックを実行
        if (widget.hint != null && _isSuggestionDisplay) {
          setState(() {
            _isSuggestionDisplay = false;
          });
        }
        widget.onTap?.call();
      },
    );
  }
}