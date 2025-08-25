// lib/widgets/stopwatch_widget.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

/// 親から制御するためのコントローラ
class StopwatchController {
  _StopwatchWidgetState? _state;
  void _attach(_StopwatchWidgetState s) => _state = s;
  void _detach(_StopwatchWidgetState s) {
    if (identical(_state, s)) _state = null;
  }

  bool get isRunning => _state?._running ?? false;
  void start() => _state?._start();
  void pause() => _state?._pause();
  void reset() => _state?._reset();
  void setTimer(Duration d) => _state?._setTimer(d);
}

class StopwatchWidget extends StatefulWidget {
  final ValueChanged<bool>? onRunningChanged;
  final StopwatchController? controller;

  /// true でコンパクト表示（1行・小さめフォント・余白少なめ）
  final bool compact;

  const StopwatchWidget({
    super.key,
    this.onRunningChanged,
    this.controller,
    this.compact = false,
  });

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();
}

enum _Mode { stopwatch, timer }

class _StopwatchWidgetState extends State<StopwatchWidget> {
  _Mode _mode = _Mode.stopwatch;
  bool _running = false;

  Duration _elapsed = Duration.zero; // stopwatch
  Duration _remaining = const Duration(minutes: 1); // timer
  final TextEditingController _timerTextCtrl =
  TextEditingController(text: '01:00');

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant StopwatchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _ticker?.cancel();
    _timerTextCtrl.dispose();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    setState(() {
      if (_mode == _Mode.stopwatch) {
        _elapsed += const Duration(milliseconds: 100);
      } else {
        _remaining -= const Duration(milliseconds: 100);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _stop(reachedZero: true);
          HapticFeedback.heavyImpact();
        }
      }
    });
  }

  void _start() {
    if (_running) return;
    if (_mode == _Mode.timer) {
      final parsed = _parseTimerText(_timerTextCtrl.text);
      if (parsed != null) _remaining = parsed;
      if (_remaining <= Duration.zero) return;
    }
    setState(() => _running = true);
    widget.onRunningChanged?.call(true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
    HapticFeedback.lightImpact();
  }

  void _pause() {
    if (!_running) return;
    _ticker?.cancel();
    setState(() => _running = false);
    widget.onRunningChanged?.call(false);
    HapticFeedback.selectionClick();
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
      _remaining =
          _parseTimerText(_timerTextCtrl.text) ?? const Duration(minutes: 1);
    });
    widget.onRunningChanged?.call(false);
    HapticFeedback.selectionClick();
  }

  void _setTimer(Duration d) {
    setState(() {
      _mode = _Mode.timer;
      _remaining = d;
      _timerTextCtrl.text = _format(d, withHundredth: false);
    });
  }

  void _toggle() => _running ? _pause() : _start();

  Duration? _parseTimerText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length != 2) return null;
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: m, seconds: s);
    } else {
      final s = int.tryParse(trimmed);
      if (s == null) return null;
      return Duration(seconds: s);
    }
  }

  String _format(Duration d, {bool withHundredth = true}) {
    final totalHundredths = (d.inMilliseconds / 10).floor();
    final hundredths = totalHundredths % 100;
    final seconds = d.inSeconds % 60;
    final minutes = d.inMinutes;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final hh = hundredths.toString().padLeft(2, '0');
    return withHundredth ? '$mm:$ss.$hh' : '$mm:$ss';
  }

  Future<void> _openTimerPicker() async {
    // iOS/Android問わず使える軽量ボトムシートに CupertinoTimerPicker を表示
    Duration tmp = _parseTimerText(_timerTextCtrl.text) ?? _remaining;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text('タイマー設定', style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cs.onSurface,
                    )),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _mode = _Mode.timer;
                          _setTimer(tmp);
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.ms,
                  initialTimerDuration: tmp,
                  onTimerDurationChanged: (d) => tmp = d,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _applyQuick(String key) {
    switch (key) {
      case '1m': _setTimer(const Duration(minutes: 1)); break;
      case '3m': _setTimer(const Duration(minutes: 3)); break;
      case '5m': _setTimer(const Duration(minutes: 5)); break;
      case '+10s': _setTimer(_remaining + const Duration(seconds: 10)); break;
      case '+30s': _setTimer(_remaining + const Duration(seconds: 30)); break;
      case '+1m': _setTimer(_remaining + const Duration(minutes: 1)); break;
      case 'clr': _setTimer(Duration.zero); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact(context) : _buildFull(context);
  }

  // ========= Compact UI（モード切替＋タップで時間Picker＋…メニュー）=========
  Widget _buildCompact(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStyle = TextStyle(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );

    final timeText =
    _mode == _Mode.stopwatch ? _format(_elapsed) : _format(_remaining);

    final timeWidget = InkWell(
      onTap: (_mode == _Mode.timer && !_running) ? _openTimerPicker : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          timeText,
          style: timeStyle.copyWith(
            decoration: (_mode == _Mode.timer && !_running)
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationStyle: TextDecorationStyle.dotted,
          ),
          maxLines: 1,
        ),
      ),
    );

    return Row(
      children: [
        _MiniModeToggle(
          mode: _mode,
          enabled: !_running,
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(width: 8),

        // 残り/経過時間（タイマーモード停止中はタップでPicker）
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: timeWidget,
          ),
        ),

        // 省スペースなクイックメニュー（…）
        if (_mode == _Mode.timer && !_running) ...[
          PopupMenuButton<String>(
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: '1m', child: Text('1:00 に設定')),
              const PopupMenuItem(value: '3m', child: Text('3:00 に設定')),
              const PopupMenuItem(value: '5m', child: Text('5:00 に設定')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: '+10s', child: Text('+10 秒')),
              const PopupMenuItem(value: '+30s', child: Text('+30 秒')),
              const PopupMenuItem(value: '+1m', child: Text('+1 分')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clr', child: Text('00:00 にリセット')),
            ],
            onSelected: _applyQuick,
            tooltip: 'クイック設定',
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.more_vert, size: 20),
            ),
          ),
        ],

        // 再生/一時停止 & リセット（小型化）
        const SizedBox(width: 4),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: _toggle,
            icon: Icon(_running ? Icons.pause : Icons.play_arrow, size: 20),
            tooltip: _running ? 'Pause' : 'Start',
          ),
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: _reset,
            icon: const Icon(Icons.replay, size: 18),
            tooltip: 'Reset',
          ),
        ),
      ],
    );
  }

  // ========= Full UI（従来の大きめ）=========
  Widget _buildFull(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bigStyle = TextStyle(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );
    final subStyle = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: 12,
    );

    final timeText =
    _mode == _Mode.stopwatch ? _format(_elapsed) : _format(_remaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(timeText, style: bigStyle),
              ),
            ),
            const SizedBox(width: 8),
            _PrimaryButton(running: _running, onPressed: _toggle),
            const SizedBox(width: 8),
            _SecondaryButton(icon: Icons.replay, label: 'Reset', onPressed: _reset),
          ],
        ),
        if (_mode == _Mode.timer && !_running) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickBtn('1:00', const Duration(minutes: 1)),
              _QuickBtn('3:00', const Duration(minutes: 3)),
              _QuickBtn('5:00', const Duration(minutes: 5)),
              _QuickBtn('+30s', const Duration(seconds: 30), add: true),
              _QuickBtn('+1m', const Duration(minutes: 1), add: true),
            ],
          )
        ],
        if (_mode == _Mode.timer && _running) ...[
          const SizedBox(height: 4),
          Text('Counting down', style: subStyle),
        ],
        if (_mode == _Mode.stopwatch && _running) ...[
          const SizedBox(height: 4),
          Text('Counting up', style: subStyle),
        ]
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeChip(
                label: 'STOPWATCH',
                selected: _mode == _Mode.stopwatch,
                onTap: _running ? null : () => setState(() => _mode = _Mode.stopwatch),
              ),
              const SizedBox(width: 4),
              _ModeChip(
                label: 'TIMER',
                selected: _mode == _Mode.timer,
                onTap: _running ? null : () => setState(() => _mode = _Mode.timer),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (_mode == _Mode.timer && !_running)
          SizedBox(
            width: 96,
            child: TextField(
              controller: _timerTextCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: 'MM:SS',
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) {
                final parsed = _parseTimerText(_timerTextCtrl.text);
                if (parsed != null) setState(() => _remaining = parsed);
              },
            ),
          ),
      ],
    );
  }

  Widget _QuickBtn(String label, Duration d, {bool add = false}) {
    return OutlinedButton(
      onPressed: () {
        final base = add ? _remaining : Duration.zero;
        final newD = add ? (base + d) : d;
        setState(() {
          _mode = _Mode.timer;
          _remaining = newD;
          _timerTextCtrl.text = _format(newD, withHundredth: false);
        });
      },
      child: Text(label),
    );
  }

  void _stop({bool reachedZero = false}) {
    _ticker?.cancel();
    setState(() => _running = false);
    widget.onRunningChanged?.call(false);
  }
}

/// ====== 極小トグル（⏱ / ⏲）======
/// ToggleButtons未使用。古いFlutterでも動くよう自前実装。
class _MiniModeToggle extends StatelessWidget {
  final _Mode mode;
  final bool enabled;
  final ValueChanged<_Mode> onChanged;

  const _MiniModeToggle({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildBtn(IconData icon, _Mode m, {BorderRadius? br}) {
      final selected = mode == m;
      return InkWell(
        onTap: enabled ? () => onChanged(m) : null,
        borderRadius: br ?? BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: br ?? BorderRadius.circular(8),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildBtn(Icons.av_timer, _Mode.stopwatch,
            br: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            )),
        const SizedBox(width: 4),
        buildBtn(Icons.timer, _Mode.timer,
            br: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            )),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final bool running;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.running, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(running ? Icons.pause : Icons.play_arrow),
      label: Text(running ? 'Pause' : 'Start'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: cs.onSurfaceVariant),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
