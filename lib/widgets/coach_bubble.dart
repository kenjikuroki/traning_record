import 'dart:async';
import 'package:flutter/material.dart';

/// しっぽの向き
enum _Tail { top, bottom }

/// 青系ピル型のコーチバルーン（依存パッケージなし・Overlayのみ）
class CoachBubbleController {
  CoachBubbleController._();

  /// anchors と messages は同じ長さ。バルーン or 画面どこでもタップで次へ進みます。
  static Future<void> showSequence({
    required BuildContext context,
    required List<GlobalKey> anchors,
    required List<String> messages,
    String semanticsPrefix = 'Hint',
    Color bubbleColor = const Color(0xFF2F6AA6), // 落ち着いた青系
    Duration appear = const Duration(milliseconds: 280),
    Duration disappear = const Duration(milliseconds: 200),
  }) async {
    assert(anchors.length == messages.length);

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // 半透明の暗転（ポインタはこのエントリでは受けない）
    final barrier = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Container(color: Colors.black.withOpacity(0.25)),
      ),
    );
    overlay.insert(barrier);

    try {
      for (var i = 0; i < anchors.length; i++) {
        final visible = ValueNotifier<bool>(false);
        final completer = Completer<void>();
        bool stepDone = false; // 二重完了防止

        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (ctx) {
            final box =
            anchors[i].currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return const SizedBox.shrink();

            final anchorSize = box.size;
            final anchorPos = box.localToGlobal(Offset.zero);
            final screenSize = MediaQuery.of(ctx).size;

            const gap = 8.0;
            const maxW = 320.0;
            final belowSpace =
                screenSize.height - (anchorPos.dy + anchorSize.height);
            final placeBelow = belowSpace > 96.0; // 2行想定の目安
            final tail = placeBelow ? _Tail.top : _Tail.bottom;

            final centerX = anchorPos.dx + anchorSize.width / 2;
            final left =
            (centerX - maxW / 2).clamp(12.0, screenSize.width - 12.0 - maxW);
            final top = tail == _Tail.top
                ? anchorPos.dy + anchorSize.height + gap
                : anchorPos.dy - gap;

            Future<void> next() async {
              if (stepDone) return;
              stepDone = true;
              visible.value = false;              // フワッと消える
              await Future<void>.delayed(disappear);
              if (!completer.isCompleted) completer.complete();
            }

            // visible の変化で再ビルド → Animated* が発火
            return ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (ctx, vis, _) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque, // 画面どこでもタップ可
                  onTap: next,                      // ★ 背景タップで次へ
                  child: AnimatedScale(
                    duration: appear,
                    curve: Curves.easeOutCubic,
                    scale: vis ? 1.0 : 0.92, // 出現時にフワッ
                    child: AnimatedOpacity(
                      duration: appear,
                      curve: Curves.easeOutCubic,
                      opacity: vis ? 1.0 : 0.0,
                      child: Stack(
                        children: [
                          // バルーン本体（こちらのタップでも next）
                          Positioned(
                            left: left,
                            top: tail == _Tail.top ? top : null,
                            bottom: tail == _Tail.bottom
                                ? (screenSize.height - top)
                                : null,
                            child: ConstrainedBox(
                              constraints:
                              const BoxConstraints(maxWidth: maxW),
                              child: Semantics(
                                label: '$semanticsPrefix: ${messages[i]}',
                                button: true,
                                child: _Bubble(
                                  text: messages[i],
                                  color: bubbleColor,
                                  tail: tail,
                                  bubbleLeft: left,
                                  targetX: centerX,
                                  onTap: next, // ★ バルーン自体をタップしても次へ
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

        // 1フレーム後に可視化して“ふわっ”と出す
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

/// ピル型＋三角しっぽのバルーン
class _Bubble extends StatelessWidget {
  final String text;
  final Color color;
  final _Tail tail;
  final VoidCallback onTap;

  /// バルーンの左端（画面座標）
  final double bubbleLeft;

  /// アンカーの中心X座標
  final double targetX;

  const _Bubble({
    super.key,
    required this.text,
    required this.color,
    required this.tail,
    required this.onTap,
    required this.bubbleLeft,
    required this.targetX,
  });

  @override
  Widget build(BuildContext context) {
    final tailWidget = CustomPaint(
      painter: _TailPainter(color: color, tail: tail),
      size: const Size(18, 10),
    );

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

    // 実際の幅に合わせてしっぽの位置を計算
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final frac = ((targetX - bubbleLeft) / w).clamp(0.08, 0.92);
        final alignX = frac * 2 - 1;

        final tailAligned = Align(
          alignment: Alignment(alignX, 0),
          child: CustomPaint(
            painter: _TailPainter(color: color, tail: tail),
            size: const Size(18, 10),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tail == _Tail.top) tailAligned,   // 上側に三角
            bubble,
            if (tail == _Tail.bottom) tailAligned, // 下側に三角
          ],
        );
      },
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  final _Tail tail;

  _TailPainter({required this.color, required this.tail});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (tail == _Tail.top) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tail != tail;
}
