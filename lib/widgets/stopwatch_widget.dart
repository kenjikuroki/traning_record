// lib/widgets/stopwatch_widget.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

/// モード
enum ClockMode { stopwatch, timer }

/// 外部から制御するためのコントローラ
class StopwatchController extends ChangeNotifier {
  StopwatchController({ClockMode initialMode = ClockMode.stopwatch})
      : _mode = initialMode;

  static const _tick = Duration(seconds: 1); // 秒刻み
  static const _hardCap = Duration(hours: 5); // 5時間上限

  Timer? _ticker;
  Duration _elapsed = Duration.zero; // ストップウォッチの経過、またはタイマーの経過
  Duration _timerTarget = const Duration(minutes: 30); // タイマーの設定値
  bool _isRunning = false;
  ClockMode _mode;

  /// API（RecordScreen が使っているもの）
  bool get isRunning => _isRunning;
  void start() => _start(); // 互換
  void pause() => _pause();
  void reset() => _reset();

  /// 追加API
  Duration get elapsed => _elapsed;
  ClockMode get mode => _mode;
  set mode(ClockMode m) {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
  }

  Duration get timerTarget => _timerTarget;
  set timerTarget(Duration d) {
    _timerTarget = d;
    if (_mode == ClockMode.timer && _elapsed > _timerTarget) {
      _elapsed = _timerTarget;
    }
    notifyListeners();
  }

  bool get isFinishedTimer =>
      _mode == ClockMode.timer && _elapsed >= _timerTarget;

  void toggle() {
    if (_mode == ClockMode.timer && isFinishedTimer) {
      // タイマー完了状態で開始要求 → リセットして再スタート
      _reset();
    }
    _isRunning ? _pause() : _start();
  }

  void _tickOnce() {
    if (!_isRunning) return;

    // 5時間で自動一時停止
    if (_elapsed >= _hardCap) {
      _pause();
      return;
    }

    if (_mode == ClockMode.stopwatch) {
      _elapsed += _tick;
      notifyListeners();
    } else {
      // timer = 経過を積み上げて、target に達したら停止
      final next = _elapsed + _tick;
      if (next >= _timerTarget) {
        _elapsed = _timerTarget;
        _pause(); // 停止
      } else {
        _elapsed = next;
        notifyListeners();
      }
    }
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(_tick, (_) => _tickOnce());
  }

  void _start() {
    if (_isRunning) return;
    _isRunning = true;
    _ensureTicker();
    notifyListeners();
    HapticFeedback.lightImpact();
  }

  void _pause() {
    if (!_isRunning) return;
    _isRunning = false;
    notifyListeners();
    HapticFeedback.selectionClick();
  }

  void _reset() {
    _elapsed = Duration.zero;
    _isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

/// 見た目のバリエーション
class StopwatchWidget extends StatefulWidget {
  const StopwatchWidget({
    super.key,
    required this.controller,
    this.compact = false,
    this.triangleOnlyStart = false, // 追加：開始ボタンを三角アイコンのみで表示
  });

  final StopwatchController controller;
  final bool compact;
  final bool triangleOnlyStart;

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();
}

class _StopwatchWidgetState extends State<StopwatchWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant StopwatchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // ミリ秒なし（h:mm:ss / mm:ss）
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Future<void> _pickTimer(BuildContext context) async {
    final initial = widget.controller.timerTarget;
    Duration? picked = initial;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Text(l10n.timerTime, style: Theme.of(ctx).textTheme.titleMedium),
                SizedBox(
                  height: 200,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm, // 時・分（秒は非表示）
                    initialTimerDuration: initial,
                    onTimerDurationChanged: (d) => picked = d,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        widget.controller.timerTarget = picked!;
        widget.controller.reset();
      });
    }
  }

  // Duration を  min..max に丸めるユーティリティ
  Duration _clampDuration(Duration d, Duration min, Duration max) {
    if (d < min) return min;
    if (d > max) return max;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact(context) : _buildFull(context);
  }

  // ===== COMPACT =====
  Widget _buildCompact(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ctl = widget.controller;
    final isRunning = ctl.isRunning;
    final isTimer = ctl.mode == ClockMode.timer;

    final time = isTimer ? (ctl.timerTarget - ctl.elapsed) : ctl.elapsed;
    final display = time.isNegative ? Duration.zero : time;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;

        // 段階的にコンパクト化
        final ultraTight = w < 310; // リセットを隠す
        final veryTight = w < 340;
        final tight = w < 380;

        // === モード切替ピルを中くらいサイズに調整 ===
        final pillW =
        ultraTight ? 100.0 : (veryTight ? 110.0 : (tight ? 120.0 : 130.0));
        final pillH =
        ultraTight ? 34.0  : (veryTight ? 36.0  : (tight ? 38.0  : 42.0));
        final knobW =
        ultraTight ? 36.0  : (veryTight ? 40.0  : (tight ? 46.0  : 54.0));
        final knobH =
        ultraTight ? 28.0  : (veryTight ? 30.0  : (tight ? 32.0  : 36.0));
        final pillIc =
        ultraTight ? 18.0  : (veryTight ? 19.0  : (tight ? 20.0  : 22.0));

        final playDia =
        ultraTight ? 30.0 : (veryTight ? 32.0 : (tight ? 36.0 : 38.0));
        final playIc =
        ultraTight ? 16.0 : (veryTight ? 16.0 : (tight ? 18.0 : 20.0));

        final resetDia =
        ultraTight ? 0.0 : (veryTight ? 30.0 : (tight ? 34.0 : 36.0));
        final resetIc =
        ultraTight ? 0.0 : (veryTight ? 16.0 : (tight ? 17.0 : 18.0));
        final showReset = !ultraTight;

        final gapXS = ultraTight ? 4.0 : 6.0;
        final gapS = ultraTight ? 6.0 : 8.0;
        final gapM = ultraTight ? 8.0 : 10.0;

        final hPad = ultraTight ? 6.0 : (veryTight ? 8.0 : 12.0);
        final vPad = ultraTight ? 4.0 : 6.0;

        // モード切替ピル
        final modePill = _ModePill(
          isTimer: isTimer,
          onTapStopwatch: () {
            HapticFeedback.selectionClick();
            ctl.mode = ClockMode.stopwatch;
            ctl.pause();
          },
          onTapTimer: () {
            HapticFeedback.selectionClick();
            ctl.mode = ClockMode.timer;
            ctl.pause();
          },
          width: pillW,
          height: pillH,
          knobWidth: knobW,
          knobHeight: knobH,
          iconSize: pillIc,
        );

        // 三角だけ少し大きく
        final double triIconSize = playIc + 4; // 例: 16→20, 18→22
        final double triDiameter = playDia + 6; // 例: 36→42

        // Start/Pause ボタン（※宣言は1回だけ）
        final Widget startPauseBtn = isRunning
        // 一時停止は従来通り 丸ボタン
            ? _RoundIconButton(
          icon: Icons.pause_rounded,
          bg: c.tertiary,
          fg: c.onPrimary,
          semantic: AppLocalizations.of(context)!.pause,
          onTap: () => ctl.toggle(),
          diameter: playDia,
          iconSize: playIc,
        )
        // 開始時だけオプションで三角アイコン単体
            : (widget.triangleOnlyStart
            ? _PlainIconButton(
          icon: Icons.play_arrow_rounded,
          fg: c.primary,
          semantic: AppLocalizations.of(context)!.start,
          onTap: () => ctl.toggle(),
          diameter: triDiameter,
          iconSize: triIconSize,
        )
            : _RoundIconButton(
          icon: Icons.play_arrow_rounded,
          bg: c.primary,
          fg: c.onPrimary,
          semantic: AppLocalizations.of(context)!.start,
          onTap: () => ctl.toggle(),
          diameter: playDia,
          iconSize: playIc,
        ));

// ---- 幅計算（右はみ出し防止） ----
        final double reservePx = 2.0; // 安全マージン（丸め誤差吸収）
        bool showResetLocal = showReset;

// 左固定幅（ピル＋隙間＋再生ボタン＋隙間）
        final double fixedLeft = pillW + gapXS + playDia + gapM;
// 右ブロック（隙間＋リセット）※表示時のみ
        double fixedRight = showResetLocal ? (gapS + resetDia) : 0.0;

// 残り幅（初期）
        double remain = w - fixedLeft - fixedRight - reservePx;

// 残りが不足ならリセットを隠して再計算
        if (remain < 100.0 && showResetLocal) {
          showResetLocal = false;
          fixedRight = 0.0;
          remain = w - fixedLeft - reservePx;
        }

// 時間ボックスの最大幅（小さめに抑える）
        final double timeMax = math.max(140.0, w * 0.45);
// ★ 残り幅“以内”に必ず収める（下限は 0）
        final double timeW = remain.clamp(0.0, timeMax);

// ---- レイアウト ----
        return SizedBox(
          width: w,
          child: Row(
            children: [
              // 左：ピル
              modePill,
              SizedBox(width: gapXS),

              // 再生/一時
              SizedBox(
                width: playDia,
                height: playDia,
                child: Center(child: startPauseBtn),
              ),
              SizedBox(width: gapM),

              // 時間ボックス（残り幅以内の厳密幅）
              SizedBox(
                width: timeW,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isTimer ? () => _pickTimer(context) : null,
                  onLongPress: (!showResetLocal && ctl.elapsed > Duration.zero)
                      ? () { HapticFeedback.mediumImpact(); ctl.reset(); }
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
                    decoration: BoxDecoration(
                      color: c.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _fmt(display),
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w700,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 右：隙間＋リセット（表示できるときだけ）
              if (showResetLocal) ...[
                SizedBox(width: gapS),
                SizedBox(
                  width: resetDia,
                  height: resetDia,
                  child: _RoundIconButton(
                    icon: Icons.restart_alt_rounded,
                    bg: c.surfaceContainerHighest,
                    fg: c.onSurfaceVariant,
                    semantic: AppLocalizations.of(context)!.reset,
                    onTap: ctl.elapsed > Duration.zero ? () => ctl.reset() : null,
                    diameter: resetDia,
                    iconSize: resetIc,
                  ),
                ),
              ],
            ],
          ),
        );


      },
    );
  }

  // ===== FULL =====
  Widget _buildFull(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ctl = widget.controller;
    final isRunning = ctl.isRunning;
    final isTimer = ctl.mode == ClockMode.timer;

    final elapsed = ctl.elapsed;
    final target = ctl.timerTarget;

    final rawRemain = isTimer ? (target - elapsed) : elapsed;
    final remain =
    isTimer ? _clampDuration(rawRemain, Duration.zero, target) : rawRemain;

    final progress = isTimer && target.inMilliseconds > 0
        ? (elapsed.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final timeStr = isTimer ? _fmt(remain) : _fmt(elapsed);

    final modePill = _ModePill(
      isTimer: isTimer,
      onTapStopwatch: () {
        HapticFeedback.selectionClick();
        ctl.mode = ClockMode.stopwatch;
        ctl.pause();
      },
      onTapTimer: () {
        HapticFeedback.selectionClick();
        ctl.mode = ClockMode.timer;
        ctl.pause();
      },
    );

    final l10n = AppLocalizations.of(context)!;

    // 操作ボタン（フル）
    final Widget startPause = isRunning
        ? ElevatedButton.icon(
      onPressed: () => ctl.toggle(),
      icon: const Icon(Icons.pause_rounded),
      label: Text(l10n.pause),
      style: ElevatedButton.styleFrom(
        backgroundColor: c.tertiary,
        foregroundColor: c.onPrimary,
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    )
        : (widget.triangleOnlyStart
        ? IconButton(
      onPressed: () => ctl.toggle(),
      icon: const Icon(Icons.play_arrow_rounded),
      tooltip: l10n.start,
      iconSize: 32, // ← 少し大きめ
    )
        : ElevatedButton.icon(
      onPressed: () => ctl.toggle(),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(l10n.start),
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        padding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ring + Big time
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring (timer時のみ)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) {
                  final pulse =
                      (math.sin(_pulseCtrl.value * 2 * math.pi) + 1) / 2;
                  return CustomPaint(
                    size: const Size.square(160),
                    painter: _RingPainter(
                      progress: isTimer ? progress : null,
                      baseColor: c.surfaceContainerHighest,
                      stroke: 10,
                      glowStrength: isRunning ? (0.4 + pulse * 0.4) : 0.0,
                      glowColor: c.primary,
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: isTimer ? () => _pickTimer(context) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      child: Text(
                        timeStr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                          color: c.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTimer
                    // targetFmt は位置引数2つを要求する生成になっているため、positionalで呼ぶ
                        ? l10n.targetFmt(
                      _humanize(context, target),
                      l10n.tapNumberToEdit,
                    )
                        : (isRunning ? l10n.statusRunning : l10n.statusIdle),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Buttons row（左：モード、右：操作）
        Row(
          children: [
            modePill,
            const Spacer(),
            startPause,
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: ctl.elapsed > Duration.zero ? () => ctl.reset() : null,
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: l10n.reset,
            ),
            // （時間編集ボタンは廃止。数字タップで編集）
          ],
        ),
      ],
    );
  }

  String _humanize(BuildContext context, Duration d) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isJa = locale.languageCode.toLowerCase() == 'ja';

    final h = d.inHours;
    final m = d.inMinutes % 60;

    final hourUnit = isJa ? '時間' : 'h';
    final minuteUnit = l10n.minutes; // 既存の minutes を単位として使用

    if (h > 0) {
      return m > 0 ? '$h$hourUnit $m$minuteUnit' : '$h$hourUnit';
    }
    return '$m$minuteUnit';
  }
}

/// タイマー/ストップウォッチ切替の“おしゃれピルスイッチ”
/// 左：ストップウォッチ（av_timer） 右：タイマー（hourglass）
class _ModePill extends StatelessWidget {
  final bool isTimer;
  final VoidCallback onTapStopwatch;
  final VoidCallback onTapTimer;

  // レスポンシブに調整できるよう外からサイズ指定可能
  final double width;
  final double height;
  final double knobWidth;
  final double knobHeight;
  final double iconSize;

  const _ModePill({
    super.key,
    required this.isTimer,
    required this.onTapStopwatch,
    required this.onTapTimer,
    this.width = 120,      // ← 幅を広げる（96→120）
    this.height = 48,      // ← 高さを少しUP（40→48）
    this.knobWidth = 70,   // ← ノブ幅を拡大（44→56）
    this.knobHeight = 40,  // ← ノブ高さを拡大（32→40）
    this.iconSize = 24,    // ← アイコンも少し大きく（20→24）
  });


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Stack(
        children: [
          // 選択インジケータ
          AnimatedAlign(
            alignment: isTimer ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Container(
              width: knobWidth,
              height: knobHeight,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // アイコン2つ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ModeIcon(
                icon: Icons.av_timer,
                tooltip: l10n.stopwatch,
                boxWidth: knobWidth,
                boxHeight: knobHeight,
                iconSize: iconSize,
              ),
              _ModeIcon(
                icon: Icons.hourglass_bottom_rounded,
                tooltip: l10n.timer,
                boxWidth: knobWidth,
                boxHeight: knobHeight,
                iconSize: iconSize,
              ),
            ],
          ),
          // タップ領域（左右）
          Row(
            children: [
              Expanded(child: GestureDetector(onTap: onTapStopwatch)),
              Expanded(child: GestureDetector(onTap: onTapTimer)),
            ],
          ),
        ],
      ),
    );


  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.icon,
    required this.tooltip,
    required this.boxWidth,
    required this.boxHeight,
    required this.iconSize,
  });

  final IconData icon;
  final String tooltip;
  final double boxWidth;
  final double boxHeight;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: Center( // ← 中央配置で端のピクセル衝突を回避
          child: Icon(icon, size: iconSize),
        ),
      ),
    );

  }
}

/// 丸い小ボタン（コンパクト用）
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.semantic,
    this.onTap,
    this.diameter = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final String semantic;
  final VoidCallback? onTap;
  final double diameter;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: enabled ? bg : Theme.of(context).colorScheme.surfaceContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Center(
              child:
              Icon(icon, color: enabled ? fg : Colors.grey, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// 三角アイコンのみ（丸背景なし・タップ領域は確保）
class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.icon,
    required this.fg,
    required this.semantic,
    required this.onTap,
    this.diameter = 38,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color fg;
  final String semantic;
  final VoidCallback onTap;
  final double diameter;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Center(
            child: Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

/// タイマーの円形プログレス
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.baseColor,
    required this.stroke,
    this.progress, // null のときは淡色ベースのみ
    this.glowStrength = 0.0,
    this.glowColor,
  });

  final double stroke;
  final Color baseColor;
  final double? progress; // 0..1
  final double glowStrength;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    // ベース
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, basePaint);

    // プログレス
    if (progress != null) {
      final start = -math.pi / 2;
      final sweep = (progress!).clamp(0.0, 1.0) * 2 * math.pi;

      final gradient = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          (glowColor ?? Colors.blue).withOpacity(0.9),
          (glowColor ?? Colors.blue).withOpacity(0.6),
          (glowColor ?? Colors.blue).withOpacity(0.9),
        ],
      );
      final progPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke;

      // ぼかし光彩（鼓動）
      if (glowStrength > 0) {
        final glowPaint = Paint()
          ..color = (glowColor ?? Colors.blue)
              .withOpacity(0.35 * glowStrength)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * glowStrength)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        progPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.baseColor != baseColor ||
        old.stroke != stroke ||
        old.glowStrength != glowStrength ||
        old.glowColor != glowColor;
  }
}
