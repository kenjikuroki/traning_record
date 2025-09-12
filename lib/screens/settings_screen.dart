// lib/screens/settings_screen.dart
import 'dart:ui'; // BackdropFilter 用
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../widgets/ad_square.dart';
import '../widgets/ad_banner.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import '../constants/backgrounds.dart';
import '../widgets/centered_constrained.dart';

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
  static const double _kGap = 0.0; // 連結カードの間隔（連結なので 0）
  static const double _kGapAd = 12.0; // 広告前後の余白
  static const EdgeInsets _kCardMargin = EdgeInsets.symmetric(vertical: 2.0);
  static const double _kTileHeight = 56.0; // 見出し行の高さ
  static const double _kIconGap = 12.0; // アイコンと文字の距離
  static const EdgeInsets _kOuterPad = EdgeInsets.symmetric(
      horizontal: 16, vertical: 12);

  // ===== 既存状態 =====
  late bool _showStopwatch; // ストップウォッチ表示
  late bool _showWeightInput; // 体重管理（※パーソナル設定内に移動）

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

  late int _setCount;
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedUnit = 'kg';
  String _selectedDistanceUnit = 'km';

  // 背景選択
  String _selectedBgAsset = '';
  bool _isBgExpanded = false;

  // ===== パーソナル設定（既定：閉） =====
  bool _isPersonalExpanded = false;

  // 性別: "male" | "female" | "unspecified"
  String _gender = 'unspecified';

  // 生年月日
  DateTime? _birthDate;

  // 身長（内部は cm で保存）/ 単位（表示用）: "cm" | "ftin"
  double? _heightCm; // 正規化保存値
  final TextEditingController _heightCmCtrl = TextEditingController();
  final TextEditingController _heightFtCtrl = TextEditingController();
  final TextEditingController _heightInCtrl = TextEditingController();
  final TextEditingController _birthDateCtrl = TextEditingController();

  // 管理トグル（既定OFF）
  bool _manageBodyFat = false;
  bool _manageWaist = false;
  bool _manageBmi = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // 既存
    _showWeightInput = SettingsManager.showWeightInput;
    _showStopwatch = SettingsManager.showStopwatch;

    final Map stored = (widget.settingsBox.get('selectedBodyParts') as Map?) ??
        {};
    _selectedBodyParts =
    { for (final p in _bodyPartsOriginal) p: (stored[p] as bool?) ?? true};

    _setCount = widget.setCountBox.get('setCount') ?? 3;
    _themeMode           = SettingsManager.currentThemeMode;
    _selectedUnit        = SettingsManager.currentUnit;
    _selectedDistanceUnit= SettingsManager.currentDistanceUnit;

    _selectedBgAsset = SettingsManager.currentBackgroundAsset;

    // パーソナル設定
    _gender =
        (widget.settingsBox.get('personal.gender') as String?) ?? 'unspecified';

    final bd = widget.settingsBox.get('personal.birthDate');
    if (bd is DateTime) {
      _birthDate = bd;
    } else if (bd is String) {
      _birthDate = DateTime.tryParse(bd);
    }
// 表示用テキストを同期
    final df = DateFormat('yyyy-MM-dd');
    _birthDateCtrl.text = _birthDate == null ? '' : df.format(_birthDate!);

    final hc = widget.settingsBox.get('personal.heightCm');
    if (hc is num) {
      _heightCm = hc.toDouble();
    } else if (hc is String) {
      _heightCm = double.tryParse(hc);
    }
    _syncHeightControllersFromCm();

    _manageBodyFat =
        (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    _manageWaist = (widget.settingsBox.get('manage.waist') as bool?) ?? false;
    _manageBmi = (widget.settingsBox.get('manage.bmi') as bool?) ?? false;
  }

  // ========== ヘルパ ==========
  bool _darkSwitchValue(BuildContext context) {
    final mode = SettingsManager.currentThemeMode;
    if (mode == ThemeMode.system) {
      return Theme
          .of(context)
          .brightness == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  // ヘッダー行（ListTileは使わず高さを厳密制御）
  Widget _headerRow({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return SizedBox(
      height: _kTileHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: _kIconGap),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15.0),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // 小見出し（左詰め・他とトーン合わせ）
  Widget _label(BuildContext context, String text) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return Text(
      text,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
    );
  }

  // 背景変更
  void _onBackgroundChanged(String assetPath) {
    setState(() => _selectedBgAsset = assetPath);
    SettingsManager.setBackgroundAsset(assetPath);
  }

  // 日本語オリジナル保存名 → 表示言語
  String _translatePart(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
      case '有酸素運動':
        return l10n.aerobicExercise;
      case '腕':
        return l10n.arm;
      case '胸':
        return l10n.chest;
      case '背中':
        return l10n.back;
      case '肩':
        return l10n.shoulder;
      case '足':
        return l10n.leg;
      case '全身':
        return l10n.fullBody;
      case 'その他１':
        return l10n.other1;
      case 'その他２':
        return l10n.other2;
      case 'その他３':
        return l10n.other3;
      default:
        return part;
    }
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

  void _onDistanceUnitChanged(String? u) {
    if (u == null) return;
    setState(() => _selectedDistanceUnit = u);
    SettingsManager.setDistanceUnit(u);
  }

  // ===== パーソナル設定：ハンドラ =====
  void _setGender(String value) {
    setState(() => _gender = value);
    widget.settingsBox.put('personal.gender', value);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final first = DateTime(1900, 1, 1);
    final last = DateTime(now.year, now.month, now.day);
    final initial = _birthDate ?? DateTime(now.year - 30, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
      widget.settingsBox.put('personal.birthDate', picked);
      final df = DateFormat('yyyy-MM-dd');
      _birthDateCtrl.text = df.format(picked);
    }
  }

  void _onHeightCmChanged(String text) {
    final v = double.tryParse(text);
    setState(() => _heightCm = v);
    if (v != null) {
      widget.settingsBox.put('personal.heightCm', v);
    }
    _syncFtInFromCm();
  }

  void _onHeightFtInChanged() {
    final ft = double.tryParse(_heightFtCtrl.text) ?? 0.0;
    final inch = double.tryParse(_heightInCtrl.text) ?? 0.0;
    final cm = (ft * 12.0 + inch) * 2.54;
    setState(() => _heightCm = cm);
    widget.settingsBox.put('personal.heightCm', cm);
    _heightCmCtrl.text = cm.isNaN ? '' : cm.toStringAsFixed(1);
  }

  void _syncHeightControllersFromCm() {
    if (_heightCm != null) {
      _heightCmCtrl.text = _heightCm!.toStringAsFixed(1);
      final inchTotal = _heightCm! / 2.54;
      final ft = (inchTotal / 12.0).floor();
      final inch = inchTotal - (ft * 12.0);
      _heightFtCtrl.text = ft.toString();
      _heightInCtrl.text = inch.toStringAsFixed(1);
    } else {
      _heightCmCtrl.text = '';
      _heightFtCtrl.text = '';
      _heightInCtrl.text = '';
    }
  }

  void _syncFtInFromCm() {
    if (_heightCm == null) {
      _heightFtCtrl.text = '';
      _heightInCtrl.text = '';
      return;
    }
    final inchTotal = _heightCm! / 2.54;
    final ft = (inchTotal / 12.0).floor();
    final inch = inchTotal - (ft * 12.0);
    _heightFtCtrl.text = ft.toString();
    _heightInCtrl.text = inch.toStringAsFixed(1);
  }

  void _setManageBodyFat(bool v) {
    setState(() => _manageBodyFat = v);
    widget.settingsBox.put('manage.bodyFat', v);
  }

  void _setManageWaist(bool v) {
    setState(() => _manageWaist = v);
    widget.settingsBox.put('manage.waist', v);
  }

  void _setManageBmi(bool v) {
    setState(() => _manageBmi = v);
    widget.settingsBox.put('manage.bmi', v);
  }

  @override
  void dispose() {
    _heightCmCtrl.dispose();
    _heightFtCtrl.dispose();
    _heightInCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0.0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          l10n.settings,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.40),
                    Colors.black.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      body: CenteredConstrained(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            // ====== 最上部バナー ======
            const AdBanner(screenName: 'settings_top'),
            const SizedBox(height: 6),

            // ─────────────────────────────────
            // グループ①：パーソナル設定（最上段／下辺だけ直角）
            // ─────────────────────────────────
            Card(
              color: colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
              ), // 下は直角
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
                    leading: const Icon(Icons.lock_outline),
                    initiallyExpanded: _isPersonalExpanded,
                    onExpansionChanged: (v) =>
                        setState(() => _isPersonalExpanded = v),
                    expandedAlignment: Alignment.centerLeft,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                    childrenPadding: const EdgeInsets.only(top: 8),
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.personalSettingsTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15.0),
                      ),
                    ),
                    // ---- 中身 ----
                    children: [
                      // 1) 性別（1行／ラジオ横並び）
                      _rowItem(
                        context,
                        label: l10n.gender,
                        control: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _radio(l10n.genderMale, 'male', _gender, (v) =>
                                _setGender(v!)),
                            _radio(l10n.genderFemale, 'female', _gender, (v) =>
                                _setGender(v!)),
                            _radio(l10n.genderUnspecified, 'unspecified',
                                _gender, (v) => _setGender(v!)),

                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2) 生年月日（1行・TextField風）
                      _rowItem(
                        context,
                       label: l10n.birthDate,
                        control: SizedBox(
                          width: 200, // 必要なら調整
                          child: TextField(
                            controller: _birthDateCtrl,
                            readOnly: true,
                            onTap: _pickBirthDate,
                            decoration: InputDecoration(
                              hintText: l10n.notSet,
                              border: OutlineInputBorder(),
                              // 身長ボックスと同じ枠
                              isDense: true,
                              // 低め
                              contentPadding: EdgeInsets.symmetric( // 高さ圧縮
                                horizontal: 10, vertical: 8,
                              ),
                              suffixIcon: Icon(Icons.cake_outlined, size: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3) 身長（1行：入力欄 + 単位ラジオ）
                      // （パーソナル設定 内）身長 1行ブロック（修正後：入力幅を縮小）
                      // （パーソナル設定 内）身長 1行ブロック（コンパイルエラー回避：三項演算子で1要素に統一）
                      _rowItem(
                        context,
                        label: l10n.height,
                        control: LayoutBuilder(
                          builder: (ctx, c) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // ← ここを if/else から三項演算子に変更
                                // 長さ設定に追従：cm / ft+in を自動切替
                                (SettingsManager.currentHeightUnit == 'cm')
                                    ? SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: _heightCmCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: l10n.unitCm,
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onChanged: _onHeightCmChanged,
                                  ),
                                )
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: TextField(
                                        controller: _heightFtCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l10n.unitFt,
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        onChanged: (_) => _onHeightFtInChanged(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 70,
                                      child: TextField(
                                        controller: _heightInCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: l10n.unitIn,
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        onChanged: (_) => _onHeightFtInChanged(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4) 管理トグル（見出しなし・サイズ統一・左詰め）
                      _toggleRow(context, title: l10n.bodyWeightTracking,
                          value: _showWeightInput,
                          onChanged: (v) {
                            setState(() => _showWeightInput = v);
                            SettingsManager.setShowWeightInput(v);
                          }),
                      _toggleRow(context, title: l10n.bodyFatTracking,
                          value: _manageBodyFat,
                          onChanged: _setManageBodyFat),
                      _toggleRow(context, title: l10n.waistTracking,
                          value: _manageWaist,
                          onChanged: _setManageWaist),
                      _toggleRow(context, title: l10n.bmiTracking,
                          value: _manageBmi,
                          onChanged: _setManageBmi),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: _kGap),

            // ─────────────────────────────────
            // グループ②：ストップウォッチ → 部位 → セット数
            // （パーソナル設定が最上段になったため、
            //   ストップウォッチは上辺も直角に変更）
            // ─────────────────────────────────

            // ① ストップウォッチ/タイマー表示（上辺も直角）
            Card(
              color: colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
              margin: _kCardMargin,
              child: Padding(
                padding: _kOuterPad,
                child: _headerRow(
                  icon: Icons.timer_outlined,
                  title: l10n.settingsStopwatchTimerVisibility,
                  trailing: Switch(
                    value: _showStopwatch,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

            // ② 表示する部位（中間カード：角丸なし）
            Card(
              color: colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
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
                    leading: const Icon(Icons.sports_gymnastics_outlined),
                    initiallyExpanded: _isBodyPartsExpanded,
                    onExpansionChanged: (v) =>
                        setState(() => _isBodyPartsExpanded = v),
                    expandedAlignment: Alignment.centerLeft,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                    childrenPadding: EdgeInsets.zero,
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.selectBodyParts,
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15.0),
                      ),
                    ),
                    children: _bodyPartsOriginal.map((original) {
                      final translated = _translatePart(context, original);
                      final current = _selectedBodyParts[original] ?? true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            translated,
                            style: const TextStyle(
                                fontSize: 14.0, fontWeight: FontWeight.w500),
                          ),
                          value: current,
                          onChanged: (bool value) async {
                            setState(() =>
                            _selectedBodyParts[original] = value);
                            await widget.settingsBox.put(
                                'selectedBodyParts', _selectedBodyParts);
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

            // ③ セット数（グループ末尾：下だけ角丸）
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
                padding: _kOuterPad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(
                      icon: Icons.format_list_numbered_outlined,
                      title: l10n.defaultSets,
                      trailing: Text(
                        '$_setCount${l10n.sets}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: _setCount.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _setCount.toString(),
                        onChanged: (double newValue) =>
                            setState(() => _setCount = newValue.round()),
                        onChangeEnd: (v) =>
                            widget.setCountBox.put('setCount', v.round()),
                        activeColor: colorScheme.primary,
                        inactiveColor: colorScheme.onSurfaceVariant.withOpacity(
                            0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: _kGap),

            // ─────────────────────────────────
            // 以下はその他設定
            // ─────────────────────────────────

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

            // ダークモード（ブロック先頭：上だけ角丸）
            Card(
              color: colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
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

            // 背景（中間カード）
            Card(
              color: colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
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
                    leading: const Icon(Icons.wallpaper_outlined),
                    initiallyExpanded: _isBgExpanded,
                    onExpansionChanged: (v) =>
                        setState(() => _isBgExpanded = v),
                    expandedAlignment: Alignment.centerLeft,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                    childrenPadding: EdgeInsets.zero,
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.background,
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15.0),
                      ),
                    ),
                    children: [
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 4 / 3,
                        ),
                        itemCount: allBackgrounds.length + 1,
                        // +1 は「なし」
                        itemBuilder: (context, i) {
                          final asset = (i == 0) ? '' : allBackgrounds[i - 1];
                          final bool isSelected = asset == _selectedBgAsset;
                          return GestureDetector(
                            onTap: () => _onBackgroundChanged(asset),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  width: isSelected ? 2 : 1,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                ),
                                color: asset.isEmpty
                                    ? colorScheme.surface
                                    : null,
                                image: asset.isEmpty
                                    ? null
                                    : DecorationImage(image: AssetImage(asset),
                                    fit: BoxFit.cover),
                              ),
                              alignment: Alignment.center,
                              child: asset.isEmpty
                                  ? Text(
                                l10n.none,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                                  : const SizedBox.shrink(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: _kGap),

            // 単位（重さ＋長さ）※1カードに統合
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
                padding: _kOuterPad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerRow(
                      icon: Icons.fitness_center_outlined,
                      title: l10n.unitTitle,
                      trailing: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    // 行1：重さ
                    _rowItem(
                      context,
                      label: l10n.weightUnit,
                      control: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _radio(l10n.kg,  'kg',  _selectedUnit, (v) => _onUnitChanged(v)),
                          _radio(l10n.lbs, 'lbs', _selectedUnit, (v) => _onUnitChanged(v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 行2：長さ（距離・身長・ウエストの共通単位）
                    _rowItem(
                      context,
                      label: l10n.length, // ←「距離」ではなく「長さ」
                      control: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _radio(l10n.km,   'km',   _selectedDistanceUnit, (v) => _onDistanceUnitChanged(v)),
                          _radio(l10n.mile, 'mile', _selectedDistanceUnit, (v) => _onDistanceUnitChanged(v)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 左ラベル + 右コントロール（1行）
  Widget _rowItem(BuildContext context,
      {required String label, required Widget control}) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64, // 88 → 64 に縮小（さらに左寄せ）
          child: Text(
            label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ),
        const SizedBox(width: 8), // 12 → 8 に縮小
        Expanded(child: control),
      ],
    );
  }

  // ラジオ（テキスト付き／サイズ統一）
  Widget _radio(String label, String value, String group,
      ValueChanged<String?> onChanged) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: group,
            onChanged: onChanged,
            activeColor: cs.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // スイッチ（テキストサイズを他と合わせる）
  Widget _toggleRow(BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
