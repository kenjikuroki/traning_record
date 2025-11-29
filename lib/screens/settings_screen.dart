// lib/screens/settings_screen.dart
import 'dart:ui'; // BackdropFilter 用
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../widgets/ad_square.dart';
import '../widgets/ad_banner.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import '../constants/backgrounds.dart';
import '../widgets/centered_constrained.dart';
import '../services/calendar_export.dart';
import 'notification_settings_screen.dart';

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
  static const EdgeInsets _kOuterPad =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const double _kUnitLabelWidth = 88.0; // 「重量」「長さ」ラベルの最大幅
  static const double _kUnitBetweenGap = 12.0; // ラベルとラジオの最小間隔

  // ===== 既存状態 =====
  late bool _showStopwatch; // ストップウォッチ表示
  late bool _showIntervalTimer;
  late bool _showTotalVolume;
  late bool _showSatisfaction;
  late bool _showWeightInput; // 体重管理（※パーソナル設定内に移動）
  late bool _showRM;
  late bool _showRIR;
  late bool _showFail;
  late bool _screenOn;

  // カレンダー設定（設定画面表示用）
  String? _selectedCalendarName;

  final List<String> _bodyPartsOriginal = const [
    '有酸素運動',
    '腕',
    '胸',
    '背中',
    '肩',
    '足',
    '腹筋',
    '全身',
    '自重',
    'その他１',
    'その他２',
    'その他３',
  ];
  late Map<String, bool> _selectedBodyParts;
  bool _isBodyPartsExpanded = false;
  bool _isDisplayOptionsExpanded = false;

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
  double? _personalWeightKg;
  final TextEditingController _personalWeightCtrl = TextEditingController();
  final TextEditingController _trainingLocationCtrl = TextEditingController();
  final TextEditingController _birthDateCtrl = TextEditingController();

  // 管理トグル（既定OFF）
  bool _manageBodyFat = false;
  bool _manageWaist = false;
  bool _manageBmi = false;
  bool _manageBmr = false;
  bool _enableAerobicCalories = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // 既存
    _showWeightInput = SettingsManager.showWeightInput;
    _showStopwatch = SettingsManager.showStopwatch;
    _showIntervalTimer = SettingsManager.showIntervalTimer;
    _showTotalVolume = SettingsManager.showTotalVolume;
    _showSatisfaction = SettingsManager.showSatisfaction;
    _showRM = SettingsManager.showRM;
    _showRIR = SettingsManager.showRIR;
    _showFail = SettingsManager.showFail;
    _screenOn = SettingsManager.keepScreenOn;

    // カレンダー設定（SettingsManager から現在値を読み込む）
    _selectedCalendarName = SettingsManager.selectedCalendarName;

    final Map stored =
        (widget.settingsBox.get('selectedBodyParts') as Map?) ?? {};
    _selectedBodyParts = {
      for (final p in _bodyPartsOriginal) p: (stored[p] as bool?) ?? true
    };

    _setCount = widget.setCountBox.get('setCount') ?? 3;
    _themeMode = SettingsManager.currentThemeMode;
    _selectedUnit = SettingsManager.currentUnit;
    _selectedDistanceUnit = SettingsManager.currentDistanceUnit;

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

    final pw = widget.settingsBox.get('personal.weightKg');
    if (pw is num) {
      _personalWeightKg = pw.toDouble();
    } else if (pw is String) {
      _personalWeightKg = double.tryParse(pw);
    }
    _syncWeightControllerFromKg();

    // トレーニング場所
    final loc = widget.settingsBox.get('personal.trainingLocation');
    if (loc is String) {
      _trainingLocationCtrl.text = loc;
    } else {
      _trainingLocationCtrl.text = '';
    }

    _manageBodyFat =
        (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    _manageWaist = (widget.settingsBox.get('manage.waist') as bool?) ?? false;
    _manageBmi = (widget.settingsBox.get('manage.bmi') as bool?) ?? false;
    _manageBmr = (widget.settingsBox.get('manage.bmr') as bool?) ?? false;
    _enableAerobicCalories = SettingsManager.enableAerobicCalories;

    if (_enableAerobicCalories && _personalWeightKg == null) {
      _enableAerobicCalories = false;
      SettingsManager.setEnableAerobicCalories(false);
    }
  }

  // ========== ヘルパ ==========
  bool _darkSwitchValue(BuildContext context) {
    final mode = SettingsManager.currentThemeMode;
    if (mode == ThemeMode.system) {
      return Theme.of(context).brightness == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  // ヘッダー行（ListTile準拠でアイコン/余白を統一）
  Widget _headerRow({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 28,
      leading: SizedBox(
        width: 24,
        child: Icon(
          icon,
          size: 24,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      trailing: trailing,
    );
  }

  void _showSettingsSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<bool> _selectCalendarAndSave() async {
    final l10n = AppLocalizations.of(context)!;
    final result =
        await CalendarExportService.selectCalendarAndStore(context: context);
    switch (result.status) {
      case CalendarExportStatus.success:
        final calendar = result.calendar;
        if (calendar != null) {
          setState(() => _selectedCalendarName = calendar.name);
        }
        return true;
      case CalendarExportStatus.permissionDenied:
        _showSettingsSnack(l10n.calendarExportPermissionRequired);
        return false;
      case CalendarExportStatus.noWritableCalendar:
        _showSettingsSnack(l10n.calendarExportNoWritableCalendar);
        return false;
      case CalendarExportStatus.error:
        _showSettingsSnack(l10n.calendarExportError);
        return false;
      case CalendarExportStatus.cancelled:
        return false;
    }
  }

  // 小見出し（左詰め・他とトーン合わせ）
  Widget _label(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
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
      case '腹筋':
        return l10n.abs;
      case '全身':
        return l10n.fullBody;
      case '自重':
        return l10n.bodyWeightTraining;
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

  Future<void> _onTapCalendarSetting() async {
    await _selectCalendarAndSave();
  }

  Future<void> _onAppColorThemeChanged(int nextIndex) async {
    final l10n = AppLocalizations.of(context)!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsThemeConfirmTitle),
        content: Text(l10n.settingsThemeConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.no),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (ok == true) {
      await SettingsManager.setAppColorThemeIndex(nextIndex);
      if (mounted) setState(() {}); // 画面再描画して即反映
    }
  }

  void _onUnitChanged(String? u) {
    if (u == null) return;
    setState(() {
      _selectedUnit = u;
      _syncWeightControllerFromKg(unitOverride: u);
    });
    SettingsManager.setUnit(u);
  }

  void _onDistanceUnitChanged(String? u) {
    if (u == null) return;
    setState(() => _selectedDistanceUnit = u);
    SettingsManager.setDistanceUnit(u);
    _syncHeightControllersFromCm();
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

  void _syncWeightControllerFromKg({String? unitOverride}) {
    if (_personalWeightKg == null) {
      _personalWeightCtrl.text = '';
      return;
    }
    final unit = unitOverride ?? _selectedUnit;
    final display =
        unit == 'kg' ? _personalWeightKg! : _personalWeightKg! * 2.2046226218;
    _personalWeightCtrl.text = display.toStringAsFixed(1);
  }

  void _onPersonalWeightChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      final hadWeight = _personalWeightKg != null;
      setState(() => _personalWeightKg = null);
      SettingsManager.setPersonalWeightKg(null);
      if (hadWeight && _enableAerobicCalories) {
        _showWeightRequiredSnack();
        setState(() => _enableAerobicCalories = false);
        SettingsManager.setEnableAerobicCalories(false);
      }
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    final unit = _selectedUnit;
    final kg = unit == 'kg' ? parsed : parsed * 0.45359237;
    setState(() => _personalWeightKg = kg);
    SettingsManager.setPersonalWeightKg(kg);
  }

  void _onTrainingLocationChanged(String text) {
    final trimmed = text.trim();
    widget.settingsBox.put('personal.trainingLocation', trimmed);
    SettingsManager.setTrainingLocation(trimmed.isEmpty ? null : trimmed);
  }

  void _showWeightRequiredSnack() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.aerobicCalorieWeightRequired),
          duration: const Duration(seconds: 3),
        ),
      );
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

  void _setManageBmr(bool v) {
    setState(() => _manageBmr = v);
    widget.settingsBox.put('manage.bmr', v);
    SettingsManager.setManageBmr(v);
  }

  Map<String, List<String>> _readCustomExercises() {
    final result = <String, List<String>>{};
    final dynamic raw = widget.settingsBox.get('customExercisesByPart');
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is String && value is List) {
          final entries = value
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (entries.isNotEmpty) {
            result[key] = entries;
          }
        }
      });
    }
    return result;
  }

  Future<void> _openCustomExerciseRemovalPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final customMap = _readCustomExercises();

    final names = <String>{};
    for (final list in customMap.values) {
      names.addAll(list);
    }

    if (names.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.noCustomExercises)),
        );
      return;
    }

    final options = names.toList()..sort();
    int tempIndex = 0;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        l10n.selectExerciseToDelete,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetCtx, null),
                        child: Text(material.cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetCtx, options[tempIndex]),
                        child: Text(
                          l10n.delete,
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    useMagnifier: true,
                    magnification: 1.08,
                    scrollController:
                        FixedExtentScrollController(initialItem: tempIndex),
                    onSelectedItemChanged: (idx) => tempIndex = idx,
                    children: [
                      for (final name in options)
                        Center(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    bool changed = false;
    final updatedMap = <String, List<String>>{};
    customMap.forEach((part, list) {
      final filtered = list.where((name) => name != result).toList();
      if (filtered.length != list.length) {
        changed = true;
      }
      if (filtered.isNotEmpty) {
        updatedMap[part] = filtered;
      }
    });

    if (!changed) {
      return;
    }

    await widget.settingsBox.put('customExercisesByPart', updatedMap);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.customExerciseRemoved(result))),
      );
  }

  @override
  void dispose() {
    _heightCmCtrl.dispose();
    _heightFtCtrl.dispose();
    _heightInCtrl.dispose();
    _personalWeightCtrl.dispose();
    _trainingLocationCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: CenteredConstrained(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              const AdBanner(screenName: 'settings_top'),
              const SizedBox(height: 6),

              // ─────────────────────────────────
              // グループ①：パーソナル設定（最上段／下辺だけ直角）
              // ─────────────────────────────────
              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
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
                      leading: SizedBox(
                        width: 28,
                        child: Icon(
                          Icons.lock_outline,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      initiallyExpanded: _isPersonalExpanded,
                      onExpansionChanged: (v) =>
                          setState(() => _isPersonalExpanded = v),
                      expandedAlignment: Alignment.centerLeft,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                      childrenPadding: const EdgeInsets.only(top: 8),
                      title: Text(
                        l10n.personalSettingsTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colorScheme.onSurface),
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
                              _radio(l10n.genderMale, 'male', _gender,
                                  (v) => _setGender(v ?? _gender)),
                              _radio(l10n.genderFemale, 'female', _gender,
                                  (v) => _setGender(v ?? _gender)),
                              _radio(l10n.genderUnspecified, 'unspecified',
                                  _gender, (v) => _setGender(v ?? _gender)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2) 生年月日（1行・TextField風）
                        _rowItem(
                          context,
                          label: l10n.birthDate,
                          expandControl: false,
                          control: SizedBox(
                            width: 160,
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
                                contentPadding: EdgeInsets.symmetric(
                                  // 高さ圧縮
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
                          expandControl: false,
                          control: LayoutBuilder(
                            builder: (ctx, c) {
                              return Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // ← ここを if/else から三項演算子に変更
                                  // 長さ設定に追従：cm / ft+in を自動切替
                                  (_selectedDistanceUnit == 'km')
                                      ? SizedBox(
                                          width: 110,
                                          child: TextField(
                                            controller: _heightCmCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            decoration: InputDecoration(
                                              labelText: l10n.unitCm,
                                              border:
                                                  const OutlineInputBorder(),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
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
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: l10n.unitFt,
                                                  border:
                                                      const OutlineInputBorder(),
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 8),
                                                ),
                                                onChanged: (_) =>
                                                    _onHeightFtInChanged(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 70,
                                              child: TextField(
                                                controller: _heightInCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                  labelText: l10n.unitIn,
                                                  border:
                                                      const OutlineInputBorder(),
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 8),
                                                ),
                                                onChanged: (_) =>
                                                    _onHeightFtInChanged(),
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

                        _rowItem(
                          context,
                          label: l10n.bodyWeight,
                          expandControl: false,
                          control: SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _personalWeightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText:
                                    _selectedUnit == 'kg' ? l10n.kg : l10n.lbs,
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              onChanged: _onPersonalWeightChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _rowItem(
                          context,
                          label: l10n.trainingLocation,
                          expandControl: false,
                          control: SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _trainingLocationCtrl,
                              decoration: InputDecoration(
                                hintText: l10n.notSet,
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              onChanged: _onTrainingLocationChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4) 管理トグル（見出しなし・サイズ統一・左詰め）
                        _toggleRow(context,
                            title: l10n.bodyWeightTracking,
                            value: _showWeightInput, onChanged: (v) {
                          setState(() => _showWeightInput = v);
                          SettingsManager.setShowWeightInput(v);
                        }),
                        _toggleRow(context,
                            title: l10n.bodyFatTracking,
                            value: _manageBodyFat,
                            onChanged: _setManageBodyFat),
                        _toggleRow(context,
                            title: l10n.waistTracking,
                            value: _manageWaist,
                            onChanged: _setManageWaist),
                        _toggleRow(context,
                            title: l10n.bmiTracking,
                            value: _manageBmi,
                            onChanged: _setManageBmi),
                        _toggleRow(context,
                            title: l10n.bmrTitleShort,
                            value: _manageBmr,
                            onChanged: _setManageBmr),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        l10n.aerobicCalorieToggle,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      _aerobicCalorieHelpButton(context),
                                    ],
                                  ),
                                ),
                              ),
                              Switch(
                                value: _enableAerobicCalories,
                                onChanged: (v) {
                                  if (v && _personalWeightKg == null) {
                                    _showWeightRequiredSnack();
                                    setState(
                                        () => _enableAerobicCalories = false);
                                    SettingsManager.setEnableAerobicCalories(
                                        false);
                                    return;
                                  }
                                  setState(() => _enableAerobicCalories = v);
                                  SettingsManager.setEnableAerobicCalories(v);
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                activeColor: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: _kGap),

              // カレンダー連携（使用するカレンダーを選択）
              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                margin: _kCardMargin,
                child: InkWell(
                  borderRadius: BorderRadius.zero,
                  onTap: _onTapCalendarSetting,
                  child: Padding(
                    padding: _kOuterPad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerRow(
                          icon: Icons.calendar_today_outlined,
                          title: l10n.calendarSettingTitle,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              l10n.calendarSettingCurrentLabel,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _selectedCalendarName ??
                                      l10n.calendarSettingNotSelected,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.calendarSettingHint,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: _kGap),

              // 通知設定（パーソナル設定直後）
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
                    child: Builder(
                      builder: (context) {
                        final s = AppLocalizations.of(context)!;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          minLeadingWidth: 28,
                          leading: SizedBox(
                            width: 24,
                            child: Icon(
                              Icons.notifications_outlined,
                              size: 24,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            s.notiSettingsTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            s.notiSettingsSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationSettingsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: _kGap),

              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
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

              // ─────────────────────────────────
              // グループ②：ストップウォッチ → 部位 → セット数
              // ─────────────────────────────────

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
                      leading: SizedBox(
                        width: 28,
                        child: Icon(
                          Icons.sports_gymnastics_outlined,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      initiallyExpanded: _isBodyPartsExpanded,
                      onExpansionChanged: (v) =>
                          setState(() => _isBodyPartsExpanded = v),
                      expandedAlignment: Alignment.centerLeft,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.selectBodyParts,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colorScheme.onSurface),
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
                              setState(
                                  () => _selectedBodyParts[original] = value);
                              await widget.settingsBox
                                  .put('selectedBodyParts', _selectedBodyParts);
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
                      leading: SizedBox(
                        width: 28,
                        child: Icon(
                          Icons.tune_outlined,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      initiallyExpanded: _isDisplayOptionsExpanded,
                      onExpansionChanged: (v) =>
                          setState(() => _isDisplayOptionsExpanded = v),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 4.0),
                      title: Text(
                        l10n.recordDisplayOptions,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                      children: [
                        const SizedBox(height: 4),
                        _toggleRow(
                          context,
                          title: l10n.intervalTimer,
                          value: _showIntervalTimer,
                          onChanged: (v) {
                            setState(() => _showIntervalTimer = v);
                            SettingsManager.setShowIntervalTimer(v);
                          },
                        ),
                        _toggleRow(
                          context,
                          title: l10n.totalVolumeLabel,
                          value: _showTotalVolume,
                          onChanged: (v) {
                            setState(() => _showTotalVolume = v);
                            SettingsManager.setShowTotalVolume(v);
                          },
                        ),
                        _toggleRow(
                          context,
                          title: l10n.satisfaction,
                          value: _showSatisfaction,
                          onChanged: (v) {
                            setState(() => _showSatisfaction = v);
                            SettingsManager.setShowSatisfaction(v);
                          },
                        ),
                        _toggleRow(
                          context,
                          title: _toggleLabelShowRM(l10n),
                          value: _showRM,
                          onChanged: (v) {
                            setState(() => _showRM = v);
                            SettingsManager.setShowRM(v);
                          },
                        ),
                        _toggleRow(
                          context,
                          title: _toggleLabelShowRIR(l10n),
                          value: _showRIR,
                          onChanged: (v) {
                            setState(() => _showRIR = v);
                            SettingsManager.setShowRIR(v);
                          },
                        ),
                        _toggleRow(
                          context,
                          title: _toggleLabelShowFail(l10n),
                          value: _showFail,
                          onChanged: (v) {
                            setState(() => _showFail = v);
                            SettingsManager.setShowFail(v);
                          },
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: _kGap),

              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                margin: _kCardMargin,
                child: Padding(
                  padding: _kOuterPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerRow(
                        icon: Icons.delete_outline,
                        title: l10n.removeCustomExercises,
                        trailing: TextButton(
                          onPressed: _openCustomExerciseRemovalPicker,
                          child: Text(l10n.open),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.customExerciseRemovalHint,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13.0,
                        ),
                      ),
                    ],
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
                          inactiveColor:
                              colorScheme.onSurfaceVariant.withOpacity(0.3),
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
                    screenName: 'settings',
                  ),
                ),
              ),
              const SizedBox(height: _kGapAd),

              // ダークモード（ブロック先頭：上だけ角丸）
              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
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

              // テーマカラー（中間カード：ダークモードと背景の間）
              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                margin: _kCardMargin,
                child: Padding(
                  padding: _kOuterPad,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading:
                          const Icon(Icons.palette_outlined), // ← アイコンの種類/配置を統一
                      expandedAlignment: Alignment.centerLeft, // ← 展開時も左寄せ
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 0), // ← 高さを合わせる（縦パディング無し）
                      childrenPadding: EdgeInsets.zero, // ← 子の左右/下の余白をゼロに
                      title: Align(
                        alignment: Alignment.centerLeft, // ← タイトルを左寄せ
                        child: Text(
                          l10n.themeColorTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0, // ← 背景の行と同サイズ
                          ),
                        ),
                      ),
                      children: [
                        RadioListTile<int>(
                          title: Text(l10n.themeMonotone),
                          value: 0,
                          groupValue: SettingsManager.currentAppColorThemeIndex,
                          onChanged: (v) =>
                              v == null ? null : _onAppColorThemeChanged(v),
                          dense: true,
                        ),
                        RadioListTile<int>(
                          title: Text(l10n.themeRed),
                          value: 1,
                          groupValue: SettingsManager.currentAppColorThemeIndex,
                          onChanged: (v) =>
                              v == null ? null : _onAppColorThemeChanged(v),
                          dense: true,
                        ),
                        RadioListTile<int>(
                          title: Text(l10n.themeBlue),
                          value: 2,
                          groupValue: SettingsManager.currentAppColorThemeIndex,
                          onChanged: (v) =>
                              v == null ? null : _onAppColorThemeChanged(v),
                          dense: true,
                        ),
                        RadioListTile<int>(
                          title: Text(l10n.themeGreen),
                          value: 3,
                          groupValue: SettingsManager.currentAppColorThemeIndex,
                          onChanged: (v) =>
                              v == null ? null : _onAppColorThemeChanged(v),
                          dense: true,
                        ),
                        RadioListTile<int>(
                          title: Text(l10n.themeYellow),
                          value: 4,
                          groupValue: SettingsManager.currentAppColorThemeIndex,
                          onChanged: (v) =>
                              v == null ? null : _onAppColorThemeChanged(v),
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

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
                      leading: SizedBox(
                        width: 28,
                        child: Icon(
                          Icons.wallpaper_outlined,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      initiallyExpanded: _isBgExpanded,
                      onExpansionChanged: (v) =>
                          setState(() => _isBgExpanded = v),
                      expandedAlignment: Alignment.centerLeft,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.background,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                      children: [
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                                      : DecorationImage(
                                          image: AssetImage(asset),
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

              // 画面オン（アプリ使用中は画面を消灯させない）
              Card(
                color: colorScheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                margin: _kCardMargin,
                child: Padding(
                  padding: _kOuterPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerRow(
                        icon: Icons.screen_lock_portrait,
                        title: l10n.keepScreenOn,
                        trailing: Switch(
                          value: _screenOn,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) {
                            setState(() => _screenOn = v);
                            SettingsManager.setKeepScreenOn(v);
                          },
                          activeColor: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.keepScreenOnHint,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: _kGap),

// 単位（見出し左：アイコン＋「単位」／右：重量行＋その下に長さ行）
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fitness_center_outlined),
                              const SizedBox(width: _kIconGap),
                              Text(
                                l10n.unitTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          minWidth: 64, maxWidth: 88),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          l10n.weightUnit,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: _kUnitBetweenGap),
                                    Flexible(
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          visualDensity: const VisualDensity(
                                              horizontal: -2, vertical: -3),
                                        ),
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            _radio(l10n.kg, 'kg', _selectedUnit,
                                                _onUnitChanged),
                                            _radio(l10n.lbs, 'lbs', _selectedUnit,
                                                _onUnitChanged),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          minWidth: 64, maxWidth: 88),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          l10n.length,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: _kUnitBetweenGap),
                                    Flexible(
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          visualDensity: const VisualDensity(
                                              horizontal: -2, vertical: -3),
                                        ),
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            _radio(
                                                l10n.km,
                                                'km',
                                                _selectedDistanceUnit,
                                                _onDistanceUnitChanged),
                                            _radio(
                                                l10n.mile,
                                                'mile',
                                                _selectedDistanceUnit,
                                                _onDistanceUnitChanged),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 左ラベル + 右コントロール（1行）
  Widget _rowItem(BuildContext context,
      {required String label,
      required Widget control,
      bool expandControl = true}) {
    final cs = Theme.of(context).colorScheme;
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
        expandControl ? Expanded(child: control) : control,
      ],
    );
  }

  // ラジオ（テキスト付き／サイズ統一）
  Widget _radio(
    String label,
    String value,
    String groupValue,
    ValueChanged<String?> onChanged, [
    BuildContext? _ignored,
  ]) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String?>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: cs.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ) ??
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _toggleLabelShowRM(AppLocalizations l10n) {
    final locale = l10n.localeName;
    if (locale.startsWith('ja')) return 'RMを表示';
    if (locale.startsWith('es')) return 'Mostrar RM';
    if (locale.startsWith('id')) return 'Tampilkan RM';
    return 'Show RM';
  }

  String _toggleLabelShowRIR(AppLocalizations l10n) {
    final locale = l10n.localeName;
    if (locale.startsWith('ja')) return 'RIRを表示';
    if (locale.startsWith('es')) return 'Mostrar RIR';
    if (locale.startsWith('id')) return 'Tampilkan RIR';
    return 'Show RIR';
  }

  String _toggleLabelShowFail(AppLocalizations l10n) {
    final locale = l10n.localeName;
    if (locale.startsWith('ja')) return '失敗フラグを表示';
    if (locale.startsWith('es')) return 'Mostrar indicador de fallo';
    if (locale.startsWith('id')) return 'Tampilkan flag kegagalan';
    return 'Show Failure Flag';
  }

  // スイッチ（テキストサイズを他と合わせる）
  Widget _toggleRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                  fontSize: 15,
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

  Widget _aerobicCalorieHelpButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showAerobicCalorieHelp(context),
      customBorder: const CircleBorder(),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.outline),
        ),
        alignment: Alignment.center,
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _showAerobicCalorieHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(l10n.aerobicCalorieInfoTitle),
          content: Text(
            l10n.aerobicCalorieInfoBody.replaceAll('\\n', '\n'),
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

}
