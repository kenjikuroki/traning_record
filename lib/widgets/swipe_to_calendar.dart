// lib/widgets/swipe_to_calendar.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../models/daily_record.dart';
import '../models/menu_data.dart';

/// スワイプ動作の種類
enum SwipeBehavior {
  none,           // 何もしない
  toCalendar,     // 右→左でカレンダーへ（Calendar上では無効）
  verticalDismiss // 上→下で閉じる（記録画面用、左スワイプは何もしない）
}

/// 全画面で使えるスワイプラッパー（統合版）
class SwipeToCalendar extends StatefulWidget {
  final Widget child;

  // toCalendar の時に必要
  final Box<DailyRecord>? recordsBox;
  final Box<MenuData>? lastUsedMenusBox;
  final Box? settingsBox;
  final Box? setCountBox;
  final WidgetBuilder? calendarBuilder; // ★ 追加

  final SwipeBehavior behavior;
  final bool isOnCalendar;

  // 記録画面の下スワイプしきい値
  final double dismissDistance;
  final double dismissVelocity;

  // カレンダー遷移の横スワイプ速度しきい値（負方向で発火）
  final double horizontalVelocity;

  const SwipeToCalendar({
    Key? key,
    required this.child,
    this.recordsBox,
    this.lastUsedMenusBox,
    this.settingsBox,
    this.setCountBox,
    this.behavior = SwipeBehavior.none,
    this.isOnCalendar = false,
    this.dismissDistance = 160,
    this.dismissVelocity = 700,
    this.horizontalVelocity = 300,
    this.calendarBuilder,
  }) : super(key: key);

  @override
  State<SwipeToCalendar> createState() => _SwipeToCalendarState();
}

class _SwipeToCalendarState extends State<SwipeToCalendar> {
  double _dragDy = 0.0; // verticalDismiss 用

    void _goCalendar(BuildContext context) {
        // 必要 Box と builder の両方が揃っているときだけ遷移
        if (widget.calendarBuilder == null ||
            widget.recordsBox == null ||
            widget.lastUsedMenusBox == null ||
            widget.settingsBox == null ||
            widget.setCountBox == null) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          BottomUpRoute(builder: widget.calendarBuilder!), // ★ 統合済みのルートを使用
          (route) => false,
        );
      }

  // ---- 横スワイプ（toCalendar） ----
  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.behavior != SwipeBehavior.toCalendar) return;
    final v = details.primaryVelocity ?? 0;
    // 右→左で負方向
    if (v < -widget.horizontalVelocity) {
      if (widget.isOnCalendar) return; // カレンダー上は無効
      _goCalendar(context);
    }
  }

  // ---- 縦スワイプ（verticalDismiss） ----
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.behavior != SwipeBehavior.verticalDismiss) return;
    if (details.delta.dy > 0) {
      setState(() => _dragDy += details.delta.dy);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (widget.behavior != SwipeBehavior.verticalDismiss) return;
    final v = details.primaryVelocity ?? 0.0; // 下向きは +
    final shouldDismiss =
        _dragDy > widget.dismissDistance || v > widget.dismissVelocity;
    if (shouldDismiss) {
      HapticFeedback.selectionClick();
      Navigator.of(context).maybePop();
    } else {
      setState(() => _dragDy = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translateY = widget.behavior == SwipeBehavior.verticalDismiss
        ? math.max(0.0, _dragDy.clamp(0.0, 200.0))
        : 0.0;
    final opacity = widget.behavior == SwipeBehavior.verticalDismiss
        ? (1.0 - (translateY / 300.0)).clamp(0.85, 1.0)
        : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Opacity(opacity: opacity, child: widget.child),
      ),
    );
  }
}

class BottomUpRoute<T> extends PageRouteBuilder<T> {
  BottomUpRoute({
    required WidgetBuilder builder,
    Duration duration = const Duration(milliseconds: 260),
    RouteSettings? settings,
  }) : super(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    opaque: true,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}