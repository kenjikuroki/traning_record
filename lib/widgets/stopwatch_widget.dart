// lib/widgets/stopwatch_widget.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;

import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import '../l10n/app_localizations.dart';
import 'dart:io' show Platform;

/// モード
enum ClockMode { stopwatch, timer }

/// ビープの方針
/// mixed: 他アプリ音楽と“混在”（可能なら duck）
/// exclusive: 一時的に独占（他アプリは一時停止）
enum BeepPolicy { mixed, exclusive }

/// 外部から制御するためのコントローラ
class StopwatchController extends ChangeNotifier {
  StopwatchController({ClockMode initialMode = ClockMode.stopwatch})
      : _mode = initialMode;

  static const _tick = Duration(seconds: 1); // 秒刻み
  static const _hardCap = Duration(hours: 5); // 5時間上限

  Timer? _ticker;
  Duration _elapsed = Duration.zero; // ストップウォッチ/タイマーの経過
  Duration _timerTarget = const Duration(minutes: 5); // タイマー設定値(デフォ5分)
  bool _isRunning = false;
  ClockMode _mode;

  /// API（RecordScreen などが使っているもの）
  bool get isRunning => _isRunning;
  void start() => _start();
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
        _pause(); // いったん停止（リスナ通知：ここでビープが走る）
        // ★完了後は“表示”を元の設定時間に戻す（次の開始を待つ）
        // すぐ戻すとビープ検知に影響するので次フレームで実施
        scheduleMicrotask(() {
          _elapsed = Duration.zero;
          notifyListeners();
        });
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
    this.triangleOnlyStart = false,
    this.beepPolicy = BeepPolicy.mixed, // デフォは混在
  });

  final StopwatchController controller;
  final bool compact;
  final bool triangleOnlyStart;
  final BeepPolicy beepPolicy;

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();
}

class _StopwatchWidgetState extends State<StopwatchWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  // ===== ピピピ用オーディオ（just_audioのみ）=====
  final AudioPlayer _beepPlayer = AudioPlayer();
  bool _beepPrepared = false;
  bool _alarmPlaying = false;
  int _lastRemainSec = 999999;

  Timer? _rampTimer; // 自前フェード用

  // 再生リスト設定（1回だけ鳴らす + 余韻無音で外部音楽の復帰を少し遅らせる）
  static const _beepAsset = 'assets/sounds/pipi4_880_fast.m4a';
  static const _tailGap = Duration(milliseconds: 260); // ← 復帰遅延（被り防止）

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // セッション構成（現在の方針で）
    _configureSessionFor(widget.beepPolicy);

// ビープ準備（awaitしない）
    _prepareAudio();


    // アセット存在チェック（ログ用途）
    _debugCheckBeepAsset();

    _beepPlayer.playbackEventStream.listen((e) {
      debugPrint('[beep] state=${e.processingState} pos=${e.updatePosition} dur=${e.duration}');
    }, onError: (Object err, StackTrace st) {
      debugPrint('[beep] ERROR: $err\n$st');
    });
  }

  @override
  void didUpdateWidget(covariant StopwatchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (oldWidget.beepPolicy != widget.beepPolicy) {
      _configureSessionFor(widget.beepPolicy);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _stopAlarm(); // 念のため停止
    _beepPlayer.dispose();
    _rampTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ===== AudioSession 構成（iOSのサイレントでも鳴るよう playback を採用）=====
  Future<void> _configureSessionFor(BeepPolicy policy) async {
    final session = await AudioSession.instance;

    if (policy == BeepPolicy.mixed) {
      await session.configure(
        AudioSessionConfiguration(
          // iOS: 無音スイッチを無視して鳴らしつつ、他アプリは混在＋ダック
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers |
          AVAudioSessionCategoryOptions.duckOthers,

          // Android: 通知/サウンド用の属性でフォーカスは「MayDuck」
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.assistanceSonification,
          ),
          androidAudioFocusGainType:
          AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
    } else {
      // exclusive は本当に止めたい時専用（通常は使わない）
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.assistanceSonification,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: false,
        ),
      );
    }
  }

  Future<void> _ensureActiveIfMixed() async {
    final session = await AudioSession.instance;
    if (widget.beepPolicy == BeepPolicy.mixed) {
      try {
        await session.setActive(true); // 混在時は常時アクティブ化
      } catch (_) {}
    } else {
      try {
        await session.setActive(false); // 独占モードは必要時のみ有効化する
      } catch (_) {}
    }
  }

  // ===== アセット存在チェック（ログ用）=====
  Future<void> _debugCheckBeepAsset() async {
    try {
      final data = await rootBundle.load(_beepAsset);
      debugPrint('[beep] asset OK: $_beepAsset (${data.lengthInBytes} bytes)');
    } catch (e) {
      debugPrint('[beep] asset NOT FOUND: $_beepAsset  error=$e');
    }
  }

  // ==== Audio 準備 ====
  Future<void> _prepareAudio() async {
    if (_beepPrepared) return;

    try {
      // ビープ1回 + 余韻無音（音楽の復帰を遅らせて被りを防ぐ）
      final src = ConcatenatingAudioSource(children: [
        AudioSource.asset(_beepAsset),                // ← 1回だけ鳴らす
        SilenceAudioSource(duration: _tailGap),       // ← 無音
      ]);

      await _beepPlayer.setAudioSource(src, preload: true);
      await _beepPlayer.setLoopMode(LoopMode.off);
      await _beepPlayer.setShuffleModeEnabled(false);
      await _beepPlayer.setVolume(0.0);               // 初期は0

      final dur = await _beepPlayer.load();
      debugPrint('[beep] prepared (1x) duration=$dur');

      _beepPrepared = true;
    } catch (e, st) {
      debugPrint('beep setAudioSource error: $e\n$st');
    }
  }

  // ==== フェード（自前ラダー）====
  Future<void> _rampVolume(double from, double to, Duration dur) async {
    _rampTimer?.cancel();
    final steps = (dur.inMilliseconds / 16).clamp(1, 120).round();
    var tick = 0;
    _rampTimer = Timer.periodic(const Duration(milliseconds: 16), (t) async {
      tick++;
      final ratio = (tick / steps).clamp(0.0, 1.0);
      final v = from + (to - from) * ratio;
      try {
        await _beepPlayer.setVolume(v);
      } catch (_) {}
      if (ratio >= 1.0) t.cancel();
    });
  }

  // ==== 再生 ====
  Future<void> _playAlarm() async {
    await _prepareAudio();
    _alarmPlaying = true;
    final session = await AudioSession.instance;

    try {
      await _configureSessionFor(widget.beepPolicy);
      await session.setActive(true); // ← 再生直前だけアクティブ化

      await _beepPlayer.setLoopMode(LoopMode.off);
      await _beepPlayer.setShuffleModeEnabled(false);
      if (_beepPlayer.processingState == ProcessingState.idle) {
        await _beepPlayer.load();
      }

      await _beepPlayer.seek(Duration.zero, index: 0);
      await _beepPlayer.setVolume(1.0);
      await _beepPlayer.play();

      // 再生完了まで待機
      await _beepPlayer.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed);
    } catch (e, st) {
      debugPrint('playAlarm error: $e\n$st');
    } finally {
      _alarmPlaying = false;

      // ★ 被り防止：外部音楽が即復帰しないように、ほんの少し待つ
      await Future.delayed(const Duration(milliseconds: 350));

      // ★ iOS に「他アプリさん復帰どうぞ」の合図を出してからフォーカス解放
      try {
        await session.setActive(
          false,
          avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        );
      } catch (_) {}

      // 次回のために頭出し
      try { await _beepPlayer.seek(Duration.zero, index: 0); } catch (_) {}
    }
  }


  Future<void> _stopAlarm() async {
    _rampTimer?.cancel();
    _rampTimer = null;

    try {
      await _beepPlayer.stop();
      await _beepPlayer.seek(Duration.zero, index: 0);
      await _beepPlayer.setVolume(1.0);
    } catch (_) {}
    _alarmPlaying = false;
  }

  // ==== コントローラの変化を監視（完了時にビープ） ====
  void _onChanged() {
    if (!mounted) return;

    final ctl = widget.controller;
    final bool isTimer = ctl.mode == ClockMode.timer;
    final int remainSec =
    isTimer ? (ctl.timerTarget - ctl.elapsed).inSeconds : 0;

    // 0 到達瞬間で鳴らす（1回のみ）
    if (isTimer && !_alarmPlaying && _lastRemainSec > 0 && remainSec <= 0) {
      _playAlarm();
    }
    _lastRemainSec = remainSec;

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
                Text(l10n.timerTime,
                    style: Theme.of(ctx).textTheme.titleMedium),
                SizedBox(
                  height: 200,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms, // 秒まで設定可
                    initialTimerDuration: initial,
                    onTimerDurationChanged: (d) => picked = d,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                  Text(MaterialLocalizations.of(context).okButtonLabel),
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
        _stopAlarm();
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

    // 表示は：タイマー時＝残り、SW時＝経過
    final time = isTimer ? (ctl.timerTarget - ctl.elapsed) : ctl.elapsed;
    final display = time.isNegative ? Duration.zero : time;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;

        // 段階的にコンパクト化
        final ultraTight = w < 310; // リセットを隠す
        final veryTight = w < 340;
        final tight = w < 380;

        // === モード切替ピルのサイズ ===
        final pillW =
        ultraTight ? 100.0 : (veryTight ? 110.0 : (tight ? 120.0 : 130.0));
        final pillH =
        ultraTight ? 34.0 : (veryTight ? 36.0 : (tight ? 38.0 : 42.0));
        final knobW =
        ultraTight ? 36.0 : (veryTight ? 40.0 : (tight ? 46.0 : 54.0));
        final knobH =
        ultraTight ? 28.0 : (veryTight ? 30.0 : (tight ? 32.0 : 36.0));
        final pillIc =
        ultraTight ? 18.0 : (veryTight ? 19.0 : (tight ? 20.0 : 22.0));

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
            _stopAlarm();
            ctl.mode = ClockMode.stopwatch;
            ctl.pause();
          },
          onTapTimer: () {
            HapticFeedback.selectionClick();
            _stopAlarm();
            ctl.mode = ClockMode.timer;
            ctl.pause();
          },
          width: pillW,
          height: pillH,
          knobWidth: knobW,
          knobHeight: knobH,
          iconSize: pillIc,
        );

        final double triIconSize = playIc + 4;
        final double triDiameter = playDia + 6;

        final Widget startPauseBtn = isRunning
            ? _RoundIconButton(
          icon: Icons.pause_rounded,
          bg: c.tertiary,
          fg: c.onPrimary,
          semantic: AppLocalizations.of(context)!.pause,
          onTap: () {
            _stopAlarm();
            ctl.toggle();
          },
          diameter: playDia,
          iconSize: playIc,
        )
            : (widget.triangleOnlyStart
            ? _PlainIconButton(
          icon: Icons.play_arrow_rounded,
          fg: c.primary,
          semantic: AppLocalizations.of(context)!.start,
          onTap: () {
            _stopAlarm();
            ctl.toggle();
          },
          diameter: triDiameter,
          iconSize: triIconSize,
        )
            : _RoundIconButton(
          icon: Icons.play_arrow_rounded,
          bg: c.primary,
          fg: c.onPrimary,
          semantic: AppLocalizations.of(context)!.start,
          onTap: () {
            _stopAlarm();
            ctl.toggle();
          },
          diameter: playDia,
          iconSize: playIc,
        ));

        // ---- 幅計算（右はみ出し防止） ----
        const double reservePx = 2.0;
        bool showResetLocal = showReset;

        final double fixedLeft = pillW + gapXS + playDia + gapM;
        double fixedRight = showResetLocal ? (gapS + resetDia) : 0.0;

        double remain = w - fixedLeft - fixedRight - reservePx;

        if (remain < 100.0 && showResetLocal) {
          showResetLocal = false;
          fixedRight = 0.0;
          remain = w - fixedLeft - reservePx;
        }

        final double timeMax = math.max(140.0, w * 0.45);
        final double timeW = remain.clamp(0.0, timeMax);

        return SizedBox(
          width: w,
          child: Row(
            children: [
              modePill,
              SizedBox(width: gapXS),
              SizedBox(
                width: playDia,
                height: playDia,
                child: Center(child: startPauseBtn),
              ),
              SizedBox(width: gapM),
              SizedBox(
                width: timeW,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isTimer ? () => _pickTimer(context) : null,
                  onLongPress: (!showResetLocal && ctl.elapsed > Duration.zero)
                      ? () {
                    HapticFeedback.mediumImpact();
                    _stopAlarm();
                    ctl.reset();
                  }
                      : null,
                  child: Container(
                    padding:
                    EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontFeatures:
                          const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w700,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                    onTap: ctl.elapsed > Duration.zero
                        ? () {
                      _stopAlarm();
                      ctl.reset();
                    }
                        : null,
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
        ? (elapsed.inMilliseconds / target.inMilliseconds)
        .clamp(0.0, 1.0)
        : 0.0;

    final timeStr = isTimer ? _fmt(remain) : _fmt(elapsed);

    final modePill = _ModePill(
      isTimer: isTimer,
      onTapStopwatch: () {
        HapticFeedback.selectionClick();
        _stopAlarm();
        ctl.mode = ClockMode.stopwatch;
        ctl.pause();
      },
      onTapTimer: () {
        HapticFeedback.selectionClick();
        _stopAlarm();
        ctl.mode = ClockMode.timer;
        ctl.pause();
      },
    );

    final l10n = AppLocalizations.of(context)!;

    final Widget startPause = isRunning
        ? ElevatedButton.icon(
      onPressed: () {
        _stopAlarm();
        ctl.toggle();
      },
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
      onPressed: () {
        _stopAlarm();
        ctl.toggle();
      },
      icon: const Icon(Icons.play_arrow_rounded),
      tooltip: l10n.start,
      iconSize: 32,
    )
        : ElevatedButton.icon(
      onPressed: () {
        _stopAlarm();
        ctl.toggle();
      },
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
                        ? l10n.targetFmt(
                      _humanize(context, target),
                      l10n.tapNumberToEdit,
                    )
                        : (isRunning
                        ? l10n.statusRunning
                        : l10n.statusIdle),
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
              onPressed: ctl.elapsed > Duration.zero
                  ? () {
                _stopAlarm();
                ctl.reset();
              }
                  : null,
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: l10n.reset,
            ),
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
    this.width = 120,
    this.height = 48,
    this.knobWidth = 70,
    this.knobHeight = 40,
    this.iconSize = 24,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // ← 正しくはキャメルケース
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
        child: Center(
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
              child: Icon(icon,
                  color: enabled ? fg : Colors.grey, size: iconSize),
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
          ..color =
          (glowColor ?? Colors.blue).withOpacity(0.35 * glowStrength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
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
