// lib/widgets/swipe_down_to_pop.dart
import 'package:flutter/material.dart';

/// 画面全体の下スワイプで onPop を呼び出してから Navigator.pop() する薄いラッパー。
/// スクロール干渉を避けるために、上端からのスワイプ or かなり大きい下方向ドラッグのみ反応。
class SwipeDownToPop extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onPop;
  final double triggerDy; // どれだけ下に引いたら発火とみなすか

  const SwipeDownToPop({
    super.key,
    required this.child,
    this.onPop,
    this.triggerDy = 120.0,
  });

  @override
  State<SwipeDownToPop> createState() => _SwipeDownToPopState();
}

class _SwipeDownToPopState extends State<SwipeDownToPop> {
  double _accumulatedDy = 0.0;
  double _startDy = 0.0;
  bool _startedNearTop = false;

  void _reset() {
    _accumulatedDy = 0.0;
    _startDy = 0.0;
    _startedNearTop = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // iOS/Android 両方で動くように生のポインタイベントで開始位置を拾う
      onPointerDown: (e) {
        _startDy = e.position.dy;
        // ステータスバー/アプバー直下あたりからの開始のみ許可（干渉軽減）
        _startedNearTop = _startDy < 100.0;
        _accumulatedDy = 0.0;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (d) {
          if (!_startedNearTop) return;
          // 下方向のみ加算
          if (d.delta.dy > 0) _accumulatedDy += d.delta.dy;
        },
        onVerticalDragEnd: (_) async {
          if (_startedNearTop && _accumulatedDy >= widget.triggerDy) {
            if (widget.onPop != null) {
              await widget.onPop!();
            }
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
          _reset();
        },
        onVerticalDragCancel: _reset,
        child: widget.child,
      ),
    );
  }
}
