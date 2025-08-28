// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../widgets/ad_square.dart';
import '../widgets/ad_banner.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
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
  // 見た目の統一
  static const double _kGap = 0.0;                 // カード間
  static const double _kGapAd = 12.0;              // 広告前後
  static const EdgeInsets _kCardMargin = EdgeInsets.symmetric(vertical: 2.0);
  static const double _kTileHeight = 56.0;         // 見出し行の高さ
  static const double _kIconGap = 12.0;            // アイコンと文字の距離
  static const EdgeInsets _kOuterPad = EdgeInsets.symmetric(horizontal: 16, vertical: 12);// 初期セット数カード基準の外側Padding

  // 状態
  late bool _showStopwatch;
  late bool _showWeightInput;

  final List<String> _bodyPartsOriginal = const [
    '有酸素運動','腕','胸','背中','肩','足','全身','その他１','その他２','その他３',
  ];
  late Map<String, bool> _selectedBodyParts;
  bool _isBodyPartsExpanded = false;

  late int _setCount;
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _showWeightInput = SettingsManager.showWeightInput;
    _showStopwatch   = SettingsManager.showStopwatch;

    final Map stored = (widget.settingsBox.get('selectedBodyParts') as Map?) ?? {};
    _selectedBodyParts = { for (final p in _bodyPartsOriginal) p: (stored[p] as bool?) ?? true };

    _setCount   = widget.setCountBox.get('setCount') ?? 3;
    _themeMode  = SettingsManager.currentThemeMode;
    _selectedUnit = SettingsManager.currentUnit;
  }

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

  String _translatePart(BuildContext context, String part) => part;

  bool _darkSwitchValue(BuildContext context) {
    final mode = SettingsManager.currentThemeMode;
    if (mode == ThemeMode.system) {
      return Theme.of(context).brightness == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  // ---- ヘッダー行をきっちり中央に揃える共通ウィジェット（ListTileは使わない）----
  Widget _headerRow({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return SizedBox(
      height: _kTileHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // ←縦センター
        children: [
          Icon(icon),
          const SizedBox(width: _kIconGap),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: colorScheme.surface,
        elevation: 0.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          l10n.settings,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 19.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // ====== 最上部バナー ======
          const AdBanner(screenName: 'settings_top'),
          const SizedBox(height: 6),

          // ====== ストップウォッチ/タイマー表示 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: _kOuterPad, // 初期セット数と同じ外側Padding
              child: _headerRow(
                icon: Icons.timer_outlined,
                title: l10n.settingsStopwatchTimerVisibility,
                trailing: Switch(
                  value: _showStopwatch,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ←縦サイズの過剰さを抑える
                  onChanged: (v) {
                    setState(() => _showStopwatch = v);
                    SettingsManager.setShowStopwatch(v);
                  },
                  activeColor: colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 体重管理 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            margin: _kCardMargin,
            child: Padding(
              padding: _kOuterPad,
              child: _headerRow(
                icon: Icons.monitor_weight_outlined,
                title: l10n.bodyWeightTracking,
                trailing: Switch(
                  value: _showWeightInput,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() => _showWeightInput = v);
                    SettingsManager.setShowWeightInput(v);
                  },
                  activeColor: colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 表示する部位を選択 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            margin: _kCardMargin,
            child: Padding(
              padding: _kOuterPad,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  // ヘッダーはRowではなくExpansionTile標準だが、横だけにして高さ感は外側Paddingで合わせる
                  leading: const Icon(Icons.sports_gymnastics_outlined),
                  initiallyExpanded: _isBodyPartsExpanded,
                  onExpansionChanged: (v) => setState(() => _isBodyPartsExpanded = v),
                  expandedAlignment: Alignment.centerLeft,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 0), // 横0（外側で左右16）
                  childrenPadding: EdgeInsets.zero,
                  title: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.selectBodyParts,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                    ),
                  ),
                  children: _bodyPartsOriginal.map((p) {
                    final translated = _translatePart(context, p);
                    final current    = _selectedBodyParts[p] ?? true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          translated,
                          style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                        ),
                        value: current,
                        onChanged: (bool value) async {
                          setState(() => _selectedBodyParts[p] = value);
                          await widget.settingsBox.put('selectedBodyParts', _selectedBodyParts);
                        },
                        activeThumbColor: colorScheme.primary,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== セット数の変更（基準カード） ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: _kOuterPad, // ←基準
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerRow(
                    icon: Icons.format_list_numbered_outlined,
                    title: l10n.defaultSets,
                    trailing: Text(
                      '$_setCount${l10n.sets}',
                      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _setCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _setCount.toString(),
                      onChanged: (double newValue) => setState(() => _setCount = newValue.round()),
                      onChangeEnd: (v) => widget.setCountBox.put('setCount', v.round()),
                      activeColor: colorScheme.primary,
                      inactiveColor: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 広告 ======
          const SizedBox(height: _kGapAd),
          SizedBox(
            height: 100,
            child: Center(
              child: AdSquare(
                adSize: AdBoxSize.largeBanner,
                showPlaceholder: false,
                screenName: 'settings',
              ),
            ),
          ),
          const SizedBox(height: _kGapAd),

          // ====== ダークモード ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: _kOuterPad,
              child: _headerRow(
                icon: Icons.dark_mode_outlined,
                title: l10n.useDarkMode,
                trailing: Switch(
                  value: _darkSwitchValue(context),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool value) {
                    final mode = value ? ThemeMode.dark : ThemeMode.light;
                    _onThemeChanged(mode);
                  },
                  activeColor: colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: _kGap),

          // ====== 単位 ======
          Card(
            color: colorScheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            margin: _kCardMargin,
            child: Padding(
              padding: _kOuterPad,
              child: _headerRow(
                icon: Icons.fitness_center_outlined,
                title: l10n.unitTitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min, // 右端寄せ
                  children: [
                    Radio<String>(
                      value: 'kg',
                      groupValue: _selectedUnit,
                      onChanged: _onUnitChanged,
                      activeColor: colorScheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    const Text('kg', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 24),
                    Radio<String>(
                      value: 'lbs',
                      groupValue: _selectedUnit,
                      onChanged: _onUnitChanged,
                      activeColor: colorScheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    const Text('lbs', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
