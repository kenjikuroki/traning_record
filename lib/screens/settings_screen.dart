// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../widgets/ad_square.dart';
import '../widgets/ad_banner.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart'; // DailyRecord などのモデル
import '../settings_manager.dart';

class SettingsScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const SettingsScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 通常のカード間隔はゼロ
  static const double _kGap = 0.0;
  // 「セット数の変更」と広告の間／広告と「テーマ」の間だけ広め
  static const double _kGapAd = 12.0;
  // カード同士の“すこーしだけ”の間（見た目を詰めつつ完全ゼロは避ける）
  static const EdgeInsets _kCardMargin = EdgeInsets.symmetric(vertical: 2.0);
  // テーマ見出しとスイッチの間（横並びの余白）
  static const double _kThemeGap = 56.0;

  // 表示系
  late bool _showStopwatch;
  late bool _showWeightInput;

  // 部位
  final List<String> _bodyPartsOriginal = const [
    '有酸素運動',
    '腕',
    '胸',
    '背中',
    '肩',
    '足',
    '全身',
    'その他１',
    'その他２',
    'その他３',
  ];
  late Map<String, bool> _selectedBodyParts;
  bool _isBodyPartsExpanded = false;

  // セット数
  late int _setCount;

  // テーマ・単位
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedUnit = 'kg'; // 'kg' | 'lbs'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ====== 設定読み込み ======
  void _loadSettings() {
    // 表示系
    _showWeightInput = SettingsManager.showWeightInput;
    _showStopwatch = SettingsManager.showStopwatch;

    // 部位
    final Map stored =
        (widget.settingsBox.get('selectedBodyParts') as Map?) ?? {};
    _selectedBodyParts = {
      for (final p in _bodyPartsOriginal) p: (stored[p] as bool?) ?? true,
    };

    // セット数
    _setCount = widget.setCountBox.get('setCount') ?? 3;

    // テーマ / 単位（SettingsManager に統一）
    _themeMode = SettingsManager.currentThemeMode;
    _selectedUnit = SettingsManager.currentUnit;
  }

  // ====== ハンドラ ======
  void _onThemeChanged(ThemeMode? m) {
    if (m == null) return;
    setState(() => _themeMode = m);
    SettingsManager.setThemeMode(m);
  }

  void _onUnitChanged(String? u) {
    if (u == null) return;
    setState(() => _selectedUnit = u);
    SettingsManager.setUnit(u);
  }

  String _translatePart(BuildContext context, String part) {
    // 必要なら l10n と紐付け。今は原文返しで運用。
    return part;
  }

  /// 初期表示時のダークスイッチ値を決める:
  /// - ThemeMode.system のときは現在の端末テーマに追従
  /// - dark / light のときはその値を表示
  bool _darkSwitchValue(BuildContext context) {
    final mode = SettingsManager.currentThemeMode;
    if (mode == ThemeMode.system) {
      return Theme.of(context).brightness == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    const EdgeInsets cardPad = EdgeInsets.fromLTRB(16, 12, 16, 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // ====== 画面最上部のバナー広告（復活） ======
          const AdBanner(screenName: 'settings_top'),
          const SizedBox(height: 6),

          // ====== ストップウォッチ/タイマー表示 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            margin: _kCardMargin,
            child: SwitchListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              secondary: const Icon(Icons.timer_outlined),
              title: Text(
                l10n.settingsStopwatchTimerVisibility,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                ),
              ),
              value: _showStopwatch,
              onChanged: (bool value) {
                setState(() => _showStopwatch = value);
                SettingsManager.setShowStopwatch(value);
              },
              activeThumbColor: colorScheme.primary,
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 体重管理 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            margin: _kCardMargin,
            child: SwitchListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              secondary: const Icon(Icons.monitor_weight_outlined),
              title: Text(
                l10n.bodyWeightTracking,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                ),
              ),
              value: _showWeightInput,
              onChanged: (bool value) {
                setState(() => _showWeightInput = value);
                SettingsManager.setShowWeightInput(value);
              },
              activeThumbColor: colorScheme.primary,
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 表示する部位を選択 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  // ★ 要望：体操している人アイコンに変更
                  leading: const Icon(Icons.sports_gymnastics_outlined),
                  initiallyExpanded: _isBodyPartsExpanded,
                  onExpansionChanged: (v) =>
                      setState(() => _isBodyPartsExpanded = v),
                  expandedAlignment: Alignment.centerLeft,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12.0),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  title: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.selectBodyParts,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                      ),
                    ),
                  ),
                  children: _bodyPartsOriginal.map((p) {
                    final translated = _translatePart(context, p);
                    final current = _selectedBodyParts[p] ?? true;
                    return SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        translated,
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: current,
                      onChanged: (bool value) async {
                        setState(() => _selectedBodyParts[p] = value);
                        await widget.settingsBox.put(
                          'selectedBodyParts',
                          _selectedBodyParts,
                        );
                      },
                      activeThumbColor: colorScheme.primary,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== セット数の変更 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: cardPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_list_numbered_outlined),
                      const SizedBox(width: 8),
                      Text(
                        l10n.changeSetCount,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _setCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _setCount.toString(),
                      onChanged: (double newValue) {
                        setState(() => _setCount = newValue.round());
                      },
                      onChangeEnd: (v) {
                        widget.setCountBox.put('setCount', v.round());
                      },
                      activeColor: colorScheme.primary,
                      inactiveColor:
                      colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_setCount${l10n.sets}',
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 広告（高さ先取りでレイアウトジャンプ抑止） ======
          const SizedBox(height: _kGapAd), // セット数の変更 ↓ と広告の間を広め
          SizedBox(
            height: 100, // 320x100 ラージバナー想定
            child: Center(
              child: AdSquare(
                adSize: AdBoxSize.largeBanner,
                showPlaceholder: false,
                screenName: 'settings',
              ),
            ),
          ),

          const SizedBox(height: _kGapAd), // 広告と テーマ ↑ の間を広め

          // ====== テーマ（ダークモードを使用：スイッチ1個） ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: cardPad,
              child: Row(
                children: [
                  const Icon(Icons.dark_mode_outlined),
                  const SizedBox(width: 8),
                  Text(
                    l10n.themeTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                  const SizedBox(width: _kThemeGap),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.useDarkMode, // ← l10n 登録済みキー
                          style: const TextStyle(
                              fontSize: 16.0, fontWeight: FontWeight.w600),
                        ),
                        value: _darkSwitchValue(context),
                        onChanged: (bool value) {
                          // 触られたら system 追従をやめて固定保存（dark / light）
                          final mode =
                          value ? ThemeMode.dark : ThemeMode.light;
                          _onThemeChanged(mode);
                        },
                        activeColor: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 単位 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: cardPad,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左：見出し（1つだけ）
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fitness_center_outlined), // バーベル
                      const SizedBox(width: 8),
                      Text(
                        l10n.unitTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.0),
                      ),
                    ],
                  ),
                  const SizedBox(width: 56), // 見出しと選択群の間
                  // 右：横並びのラジオ
                  Expanded(
                    child: Row(
                      children: [
                        Radio<String>(
                          value: 'kg',
                          groupValue: _selectedUnit,
                          onChanged: _onUnitChanged,
                          activeColor: colorScheme.primary,
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        const Text('kg',
                            style: TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 32),
                        Radio<String>(
                          value: 'lbs',
                          groupValue: _selectedUnit,
                          onChanged: _onUnitChanged,
                          activeColor: colorScheme.primary,
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        const Text('lbs',
                            style: TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
