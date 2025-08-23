import 'package:flutter/material.dart';

class SlideUpRoute<T> extends PageRouteBuilder<T> {
  SlideUpRoute({required Widget page})
      : super(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween<Offset>(
        begin: const Offset(0, 1),  // 下から
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
