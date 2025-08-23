import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 画面全体を包み、「左右どちらのスワイプでもカレンダーへ」
/// - 画面端（左右のエッジ）から始まるジェスチャは無視して、OSの戻るに譲る
/// - ListView/Slider上でも確実に検出（Listener + VelocityTracker）
class SwipeToCalendar extends StatefulWidget {
  final Widget child;
  final WidgetBuilder calendarBuilder;
  final bool isOnCalendar;
  final double velocityThreshold;   // px/s：この速さ以上の左右フリックで発火
  final double distanceThreshold;   // px：この距離以上の左右移動で発火
  final double horizontalBias;      // 水平優位判定の係数（1.2など）
  final double edgeIgnoreInset;     // px：左右エッジの無効ゾーン（OSの戻るに譲る）

  const SwipeToCalendar({
    super.key,
    required this.child,
    required this.calendarBuilder,
    this.isOnCalendar = false,
    this.velocityThreshold = 300,
    this.distanceThreshold = 72,
    this.horizontalBias = 1.2,
    this.edgeIgnoreInset = 24, // 端24pxは無視（Androidの戻るジェスチャ対策）
  });

  @override
  State<SwipeToCalendar> createState() => _SwipeToCalendarState();
}

class _SwipeToCalendarState extends State<SwipeToCalendar> {
  late VelocityTracker _vt;
  Offset _sum = Offset.zero; // 累積移動量
  bool _navigated = false;
  bool _tracking = false;

  // 端からのスワイプを避けるために必要
  double _screenW = 0;
  double _startX = 0;
  bool _swipeAllowed = true;

  void _reset(PointerEvent e) {
    _vt = VelocityTracker.withKind(e.kind);
    _sum = Offset.zero;
    _navigated = false;
    _tracking = true;
  }

  void _goCalendar() {
    if (_navigated || widget.isOnCalendar) return;
    _navigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: widget.calendarBuilder),
          (route) => false,
    );
  }

  void _tryNavigate() {
    if (_navigated || widget.isOnCalendar || !_swipeAllowed) return;

    // 距離条件（左右どちらでもOK）＋水平優位
    final movedHorizEnough = _sum.dx.abs() >= widget.distanceThreshold;
    final horizontalDominant =
        _sum.dx.abs() * widget.horizontalBias > _sum.dy.abs();

    // 速度条件（左右どちらでもOK）
    final vdx = _vt.getVelocity().pixelsPerSecond.dx;

    if ((movedHorizEnough && horizontalDominant) ||
        vdx.abs() >= widget.velocityThreshold) {
      _goCalendar();
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenW = MediaQuery.of(context).size.width;

    return Listener(
      behavior: HitTestBehavior.translucent, // 空きスペースでも反応
      onPointerDown: (e) {
        _reset(e);
        _startX = e.position.dx;
        // 端の無効ゾーン内で始まったスワイプは無視（OSの戻るに譲る）
        _swipeAllowed = (_startX > widget.edgeIgnoreInset) &&
            (_startX < _screenW - widget.edgeIgnoreInset);
        _vt.addPosition(e.timeStamp, e.position);
      },
      onPointerMove: (e) {
        if (!_tracking) return;
        _vt.addPosition(e.timeStamp, e.position);
        if (_swipeAllowed) {
          _sum += e.delta; // 右=+, 左=-
          _tryNavigate();
        }
      },
      onPointerUp: (e) {
        if (!_tracking) return;
        _vt.addPosition(e.timeStamp, e.position);
        _tryNavigate();
        _tracking = false;
      },
      onPointerCancel: (_) => _tracking = false,
      child: widget.child,
    );
  }
}
