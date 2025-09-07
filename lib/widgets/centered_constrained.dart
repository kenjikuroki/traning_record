import 'package:flutter/material.dart';

class CenteredConstrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const CenteredConstrained({
    super.key,
    required this.child,
    this.maxWidth = 760, // ← iPadの間延びを抑える上限幅
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = (padding != null) ? Padding(padding: padding!, child: child) : child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

