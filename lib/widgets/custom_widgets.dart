import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  _CircularAddButtonWithTextState createState() =>
      _CircularAddButtonWithTextState();
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
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
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

class StylishInput extends StatefulWidget {
  final String? suffixText;
  final TextStyle? suffixStyle;
  final TextEditingController controller;
  final String? hint;
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
    this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    required this.normalTextColor,
    required this.suggestionTextColor,
    required this.fillColor,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    required this.textAlign,
    this.onChanged,
    this.onTap,
    this.suffixText,
    this.suffixStyle,
  }) : super(key: key);

  @override
  _StylishInputState createState() => _StylishInputState();
}

class _StylishInputState extends State<StylishInput> {
  late bool _isSuggestionDisplay;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _isSuggestionDisplay = widget.controller.text.isEmpty &&
        (widget.hint != null && widget.hint!.isNotEmpty);
    _lastText = widget.controller.text;
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant StylishInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _isSuggestionDisplay = widget.controller.text.isEmpty &&
          (widget.hint != null && widget.hint!.isNotEmpty);
      _lastText = widget.controller.text;
    }
    if (oldWidget.hint != widget.hint) {
      _isSuggestionDisplay = widget.controller.text.isEmpty &&
          (widget.hint != null && widget.hint!.isNotEmpty);
    }
  }

  void _handleControllerChange() {
    final text = widget.controller.text;
    // ヒント表示トグルと onChanged の発火を分離。値が変わった時だけ onChanged を呼ぶ
    bool shouldNotify = text != _lastText;
    _lastText = text;

    if (widget.hint != null && widget.hint!.isNotEmpty) {
      final shouldShowHint = text.isEmpty;
      if (_isSuggestionDisplay != shouldShowHint) {
        setState(() {
          _isSuggestionDisplay = shouldShowHint;
        });
      }
    } else if (_isSuggestionDisplay) {
      setState(() {
        _isSuggestionDisplay = false;
      });
    }

    if (shouldNotify) {
      widget.onChanged?.call(text);
    }
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
        color: _isSuggestionDisplay
            ? widget.suggestionTextColor
            : widget.normalTextColor,
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        suffixText: widget.suffixText,          // 追加
        suffixStyle: widget.suffixStyle,        // 追加
        hintText: _isSuggestionDisplay ? widget.hint : null,
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
