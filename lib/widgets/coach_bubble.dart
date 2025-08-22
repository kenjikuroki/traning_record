// lib/widgets/coach_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// しっぽの取り付け位置（バルーンに対して）
enum _Tail { top, bottom }

/// 青系ピル型のコーチバルーン（Overlayのみで実装）
class CoachBubbleController {
  CoachBubbleController._();

  /// anchors と messages は同数。バルーン or 背景どこでもタップで次へ。
  static Future<void> showSequence({
    required BuildContext context,
    required List<GlobalKey> anchors,
    required List<String> messages,
    String semanticsPrefix = 'Hint',
    Color bubbleColor = const Color(0xFF2F6AA6), // 落ち着いた青
    Duration appear = const Duration(milliseconds: 280),
    Duration disappear = const Duration(milliseconds: 200),
    EdgeInsets screenPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    double maxBubbleWidth = 320,
  }) async {
    assert(anchors.length == messages.length);

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // 半透明バリア（入力は受けない）
    final barrier = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Container(color: Colors.black.withValues(alpha: 0.25)),
      ),
    );
    overlay.insert(barrier);

    try {
      for (var i = 0; i < anchors.length; i++) {
        final visible = ValueNotifier<bool>(false);
        final completer = Completer<void>();
        bool stepDone = false;

        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (ctx) {
            final box = anchors[i].currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return const SizedBox.shrink();

            final anchorSize = box.size;
            final anchorPos = box.localToGlobal(Offset.zero);
            final screenSize = MediaQuery.of(ctx).size;

            // しっぽ方向の決定
            const gap = 8.0;
            final belowSpace = screenSize.height - (anchorPos.dy + anchorSize.height);
            final placeBelow = belowSpace > 96.0; // 下側に十分スペースがある
            final tail = placeBelow ? _Tail.top : _Tail.bottom;

            // バルーンの左端。中心をアンカーに合わせつつ画面端でクランプ
            final centerX = anchorPos.dx + anchorSize.width / 2;
            final left = (centerX - maxBubbleWidth / 2)
                .clamp(screenPadding.left, screenSize.width - screenPadding.right - maxBubbleWidth);

            // バルーンの Y 位置
            final top = tail == _Tail.top
                ? anchorPos.dy + anchorSize.height + gap
                : anchorPos.dy - gap;

            Future<void> next() async {
              if (stepDone) return;
              stepDone = true;
              visible.value = false;               // ふわっと消える
              await Future<void>.delayed(disappear);
              if (!completer.isCompleted) completer.complete();
            }

            // visible の切替だけで出入りアニメーション
            return ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (ctx, vis, _) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque, // 背景どこでもOK
                  onTap: next,
                  child: AnimatedScale(
                    duration: appear,
                    curve: Curves.easeOutCubic,
                    scale: vis ? 1.0 : 0.92,
                    child: AnimatedOpacity(
                      duration: appear,
                      curve: Curves.easeOutCubic,
                      opacity: vis ? 1.0 : 0.0,
                      child: Stack(
                        children: [
                          Positioned(
                            left: left,
                            top: tail == _Tail.top ? top : null,
                            bottom: tail == _Tail.bottom
                                ? (MediaQuery.of(ctx).size.height - top)
                                : null,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                              child: Semantics(
                                label: '$semanticsPrefix: ${messages[i]}',
                                button: true,
                                child: _Bubble(
                                  text: messages[i],
                                  color: bubbleColor,
                                  tail: tail,
                                  bubbleLeft: left,
                                  targetX: centerX,
                                  onTap: next, // バルーン自体のタップ
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );

        overlay.insert(entry);

        // 1フレーム後に可視化 → ふわっと出す
        await Future<void>.delayed(const Duration(milliseconds: 16));
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        entry.markNeedsBuild();
        visible.value = true;

        await completer.future;
        entry.remove();
      }
    } finally {
      barrier.remove();
    }
  }
}

/// ピル型＋三角しっぽのバルーン本体
class _Bubble extends StatelessWidget {
  final String text;
  final Color color;
  final _Tail tail;
  final VoidCallback onTap;

  /// バルーン左端（画面座標）
  final double bubbleLeft;

  /// アンカー中心 X（画面座標）
  final double targetX;

  const _Bubble({
    required this.text,
    required this.color,
    required this.tail,
    required this.onTap,
    required this.bubbleLeft,
    required this.targetX,
  });

  @override
  Widget build(BuildContext context) {
    // 実際の幅を取って、しっぽの水平位置を算出
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth; // 実表示幅
        // バルーン左端から見たアンカー位置（0.0〜1.0）
        final frac = ((targetX - bubbleLeft) / w).clamp(0.10, 0.90);
        // Alignment の -1.0〜+1.0 に変換
        final alignX = frac * 2 - 1;

        // しっぽ
        Widget tailWidget() => SizedBox(
          width: w,
          height: 10,
          child: Align(
            alignment: Alignment(alignX, 0),
            child: CustomPaint(
              size: const Size(18, 10),
              painter: _TailPainter(color: color, tail: tail),
            ),
          ),
        );

        // バルーン本体
        final bubble = Material(
          elevation: 8,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(blurRadius: 8, offset: Offset(0, 3), color: Color(0x33000000)),
                ],
              ),
              child: Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );

        // しっぽの取り付け方向に応じた並び
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tail == _Tail.top) tailWidget(), // 上にしっぽ → バルーンは下
            bubble,
            if (tail == _Tail.bottom) tailWidget(), // 下にしっぽ → バルーンは上
          ],
        );
      },
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  final _Tail tail;

  const _TailPainter({required this.color, required this.tail});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (tail == _Tail.top) {
      // ▲（上向き）…上辺中央が頂点
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      // ▼（下向き）…下辺中央が頂点
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) =>
      old.color != color || old.tail != tail;
}
