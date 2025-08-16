import 'package:flutter/material.dart';

/// アニメーション方向
enum AnimationDirection {
  /// アニメーションなし（そのまま描画）
  none,

  /// 上 → 下（上から出てくる）
  topToBottom,

  /// 下 → 上（下から出てくる）
  bottomToTop,

  /// 右 → 左（右から出てくる）
  rightToLeft,
}

/// 子ウィジェットをスライド＋フェードで表示する簡易アニメーションラッパー
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AnimationDirection direction;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    this.direction = AnimationDirection.bottomToTop,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _configureAnimations();

    if (widget.direction != AnimationDirection.none) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedListItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // duration 変更に追随
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    // 方向 or カーブが変わったら再設定
    if (oldWidget.direction != widget.direction ||
        oldWidget.curve != widget.curve) {
      _configureAnimations();
      if (widget.direction != AnimationDirection.none) {
        _controller
          ..reset()
          ..forward();
      }
    }
  }

  void _configureAnimations() {
    final beginOffset = switch (widget.direction) {
      AnimationDirection.topToBottom => const Offset(0.0, -0.5),
      AnimationDirection.bottomToTop => const Offset(0.0, 0.5),
      AnimationDirection.rightToLeft => const Offset(1.0, 0.0),
      AnimationDirection.none => Offset.zero,
    };

    _offsetAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _fadeAnimation = Tween<double>(
      begin: widget.direction == AnimationDirection.none ? 1.0 : 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.direction == AnimationDirection.none) {
      // アニメーション不要の場合はそのまま返す
      return widget.child;
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }
}
