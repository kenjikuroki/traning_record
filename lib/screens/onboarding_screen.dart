import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../settings_manager.dart';

class OnboardingResult {
  const OnboardingResult({this.openRecord = false});

  final bool openRecord;
}

enum TrainingStyle { gym, dumbbell, bodyweight }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
  });

  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;
  int _currentPage = 0;
  bool _importingSample = false;
  // ignore: unused_field
  bool _sampleCreated = false;
  bool _isFinishing = false;
  
  // Configuration State
  TrainingStyle _trainingStyle = TrainingStyle.gym;
  final List<String> _selectedBodyPartsOrder = [];
  final List<int> _selectedWeekdayOrder = [
    DateTime.now().weekday,
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _sampleCreated = SettingsManager.hasImportedSampleRoutine;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Sample Routine Logic ---

  Future<void> _loadSampleRoutineAndFinish({bool openRecord = false}) async {
    if (_importingSample) return;
    setState(() => _importingSample = true);
    try {
      if (!_sampleCreated) {
        await _createSampleRoutine();
        await SettingsManager.setSampleRoutineImported(true);
        setState(() => _sampleCreated = true);
      }
      
      // Delay to show progress
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        // Show Success Dialog
        // Show Rich Success Dialog
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'Success',
          barrierColor: Colors.black.withOpacity(0.6),
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (ctx, anim1, anim2) {
            return const SizedBox();
          },
          transitionBuilder: (ctx, anim1, anim2, child) {
            final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
            return ScaleTransition(
              scale: user_scale_tween(curved),
              child: FadeTransition(
                opacity: anim1,
                child: _SuccessDialogContent(),
              ),
            );
          },
        );
      }

      await _finish(openRecord: openRecord);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.onboardingSampleError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importingSample = false);
      }
    }
  }

  Future<void> _createSampleRoutine() async {
    final List<String> partOrder = _selectedBodyPartsOrder.isEmpty
        ? ['full_body']
        : List<String>.from(_selectedBodyPartsOrder);
    final List<int> weekdayOrder = _selectedWeekdayOrder.isEmpty
        ? [DateTime.now().weekday]
        : List<int>.from(_selectedWeekdayOrder);
    final Set<int> weekdaySet = weekdayOrder.toSet();
    int trainingDayIndex = 0;

    DateTime base = DateTime.now();
    final DateTime start = DateTime(base.year, base.month, base.day);
    final Map<String, List<MenuData>> lastUsedPayload = {};
    bool createdAny = false;

    for (int offset = 0; offset < 14; offset++) {
      final date = start.add(Duration(days: offset));
      final weekday = date.weekday;
      if (!weekdaySet.contains(weekday)) {
        continue;
      }
      
      final partKey = partOrder[trainingDayIndex % partOrder.length];
      trainingDayIndex++;

      final menus = _menusForPart(_trainingStyle, partKey);
      if (menus.isEmpty) {
        continue;
      }
      final originalPart = _originalPartName(partKey);
      lastUsedPayload[originalPart] = menus;

      final dateKey = _dateKey(date);
      if (widget.recordsBox.containsKey(dateKey)) {
        continue;
      }
      final record = DailyRecord(
        date: date,
        menus: {
          originalPart: menus,
        },
        lastModifiedPart: originalPart,
        trainingStart: DateTime(date.year, date.month, date.day, 18, 0),
        trainingEnd: DateTime(date.year, date.month, date.day, 18, 50),
      );
      await widget.recordsBox.put(dateKey, record);
      createdAny = true;
    }

    if (!createdAny) {
      // Fallback: create today
      final fallbackPart = partOrder.first;
      final menus = _menusForPart(_trainingStyle, fallbackPart);
      final originalPart = _originalPartName(fallbackPart);
      if (menus.isNotEmpty) {
        final date = start;
        final dateKey = _dateKey(date);
        await widget.recordsBox.put(
          dateKey,
          DailyRecord(
            date: date,
            menus: {originalPart: menus},
            lastModifiedPart: originalPart,
          ),
        );
        lastUsedPayload[originalPart] = menus;
      }
    }

    for (final entry in lastUsedPayload.entries) {
      await widget.lastUsedMenusBox.put(entry.key, entry.value);
    }

    await widget.settingsBox.put('onboarding_plan', {
      'style': _trainingStyle.name,
      'parts': partOrder,
      'days': weekdayOrder,
    });
  }

  Future<void> _saveSelectedBodyParts() async {
    const allOriginalParts = <String>[
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
    final selectedOriginalParts = _selectedBodyPartsOrder
        .map(_originalPartName)
        .toSet();
    final selectedBodyParts = <String, bool>{
      for (final part in allOriginalParts) part: selectedOriginalParts.contains(part),
    };
    await widget.settingsBox.put('selectedBodyParts', selectedBodyParts);
  }

  String _sampleDescription(AppLocalizations l10n) {
    if (_selectedBodyPartsOrder.isEmpty) {
      return l10n.onboardingSampleDescription;
    }
    final labels = _selectedBodyPartsOrder
        .map((part) => _localizedPartName(l10n, part))
        .toList();
    return '${labels.join('・')}のセットを自動で読み込みます。';
  }

  String _localizedPartName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'full_body':
        return l10n.fullBody;
      case 'chest':
        return l10n.chest;
      case 'back':
        return l10n.back;
      case 'shoulder':
        return l10n.shoulder;
      case 'arm':
        return l10n.arm;
      case 'leg':
        return l10n.leg;
      case 'abs':
        return l10n.abs;
      case 'cardio':
        return l10n.aerobicExercise;
      default:
        return key;
    }
  }

  // --- Expanded Menu Catalog (~5 items per part) ---
  List<MenuData> _menusForPart(TrainingStyle style, String partKey) {
    switch (partKey) {
      case 'full_body':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('バーピー', [15, 12, 10]),
            _bodyweightMenu('スクワット', [20, 20, 20]),
            _bodyweightMenu('プッシュアップ', [15, 12, 10]),
            _bodyweightMenu('懸垂/ボディロー', [8, 8, 8]),
            _bodyweightMenu('マウンテンクライマー', [30, 30, 30]),
            _bodyweightMenu('プランク', [60, 60, 60]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ゴブレットスクワット', [16, 20, 24], [12, 10, 8]),
            _strengthMenu('ダンベルプレス', [14, 16, 18], [12, 10, 8]),
            _strengthMenu('ワンハンドロウ', [16, 18, 20], [12, 10, 8]),
            _strengthMenu('ダンベルショルダープレス', [10, 12, 14], [12, 10, 8]),
            _strengthMenu('ダンベルランジ', [10, 12, 14], [12, 12, 10]),
          ],
          _ => [
            _strengthMenu('バーベルスクワット', [60, 80, 100], [10, 8, 6], satisfaction: 5),
            _strengthMenu('ベンチプレス', [40, 50, 60], [10, 8, 8]),
            _strengthMenu('デッドリフト', [60, 80, 100], [5, 5, 5]),
            _strengthMenu('オーバーヘッドプレス', [30, 35, 40], [10, 8, 8]),
            _strengthMenu('ラットプルダウン', [40, 45, 50], [12, 10, 8]),
          ],
        };
      case 'chest':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('プッシュアップ (Normal)', [15, 12, 10]),
            _bodyweightMenu('ワイドプッシュアップ', [12, 10, 8]),
            _bodyweightMenu('ダイアモンドプッシュアップ', [10, 8, 8]),
            _bodyweightMenu('デクラインプッシュアップ', [12, 10, 10]),
            _bodyweightMenu('ディップス', [10, 8, 8]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ダンベルプレス', [16, 18, 20], [12, 10, 8], satisfaction: 4),
            _strengthMenu('インクラインダンベルプレス', [14, 16, 18], [12, 10, 8]),
            _strengthMenu('ダンベルフライ', [10, 12, 12], [15, 12, 12]),
            _strengthMenu('フロアプレス', [16, 18, 20], [12, 10, 8]),
            _strengthMenu('プルオーバー', [18, 20, 22], [12, 12, 10]),
          ],
          _ => [
            _strengthMenu('ベンチプレス', [40, 50, 60], [10, 8, 6], satisfaction: 5),
            _strengthMenu('インクラインベンチプレス', [30, 40, 50], [10, 8, 6]),
            _strengthMenu('チェストプレス', [40, 50, 60], [12, 10, 8]),
            _strengthMenu('ペックフライ', [30, 35, 40], [15, 12, 12]),
            _strengthMenu('ケーブルクロスオーバー', [15, 20, 25], [15, 12, 12]),
          ],
        };
      case 'back':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('懸垂 (Pull-up)', [8, 6, 5]),
            _bodyweightMenu('チンニング (Chin-up)', [8, 6, 5]),
            _bodyweightMenu('ボディロー (斜め懸垂)', [12, 10, 10]),
            _bodyweightMenu('スーパーマン', [15, 15, 15]),
            _bodyweightMenu('バックエクステンション', [15, 15, 15]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ワンハンドロウ', [18, 20, 22], [12, 10, 8]),
            _strengthMenu('ダンベルデッドリフト', [24, 28, 32], [10, 8, 6]),
            _strengthMenu('ダンベルプルオーバー', [18, 20, 22], [12, 12, 10]),
            _strengthMenu('ベントオーバーロウ', [14, 16, 18], [12, 10, 10]),
            _strengthMenu('シュラッグ', [20, 24, 28], [15, 15, 12]),
          ],
          _ => [
            _strengthMenu('デッドリフト', [60, 80, 100], [8, 6, 4], satisfaction: 5),
            _strengthMenu('ラットプルダウン', [40, 45, 50], [12, 10, 8]),
            _strengthMenu('シーテッドロウ', [40, 45, 50], [12, 10, 8]),
            _strengthMenu('ベントオーバーロウ', [40, 50, 60], [10, 8, 8]),
            _strengthMenu('フェイスプル', [20, 25, 30], [15, 15, 12]),
          ],
        };
      case 'shoulder':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('パイクプッシュアップ', [10, 8, 8]),
            _bodyweightMenu('ハンドスタンドホールド', [30, 30, 30]), // seconds logic handled as reps?
            _bodyweightMenu('ウォールウォーク', [5, 5, 5]),
            _bodyweightMenu('プランクアップダウン', [15, 15, 15]),
            _bodyweightMenu('アームサークル', [30, 30, 30]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ショルダープレス', [14, 16, 18], [12, 10, 8]),
            _strengthMenu('サイドレイズ', [6, 7, 8], [15, 12, 12]),
            _strengthMenu('フロントレイズ', [6, 7, 8], [15, 12, 12]),
            _strengthMenu('リアレイズ', [6, 7, 8], [15, 12, 12]),
            _strengthMenu('アーノルドプレス', [12, 14, 16], [12, 10, 8]),
          ],
          _ => [
            _strengthMenu('オーバーヘッドプレス (Barbell)', [30, 35, 40], [10, 8, 6]),
            _strengthMenu('ショルダープレスマシン', [30, 40, 50], [12, 10, 8]),
            _strengthMenu('ケーブルサイドレイズ', [5, 7, 9], [15, 15, 12]),
            _strengthMenu('フェイスプル', [25, 30, 35], [15, 12, 12]),
            _strengthMenu('アップライトロウ', [25, 30, 35], [12, 10, 10]),
          ],
        };
      case 'leg':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('スクワット', [20, 20, 20]),
            _bodyweightMenu('ランジ', [15, 15, 15]),
            _bodyweightMenu('ブルガリアンスクワット', [10, 10, 10]),
            _bodyweightMenu('カーフレイズ', [20, 20, 20]),
            _bodyweightMenu('グルートブリッジ', [15, 15, 15]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ゴブレットスクワット', [20, 24, 28], [12, 10, 8]),
            _strengthMenu('ダンベルランジ', [12, 14, 16], [12, 12, 10]),
            _strengthMenu('ルーマニアンデッドリフト', [22, 26, 30], [12, 10, 8]),
            _strengthMenu('ブルガリアンスクワット', [10, 12, 14], [10, 10, 8]),
            _strengthMenu('カーフレイズ (Weighted)', [16, 20, 24], [20, 15, 15]),
          ],
          _ => [
            _strengthMenu('バーベルスクワット', [60, 80, 100], [10, 8, 6], satisfaction: 5),
            _strengthMenu('レッグプレス', [100, 120, 140], [12, 10, 8]),
            _strengthMenu('レッグエクステンション', [40, 50, 60], [15, 12, 10]),
            _strengthMenu('レッグカール', [35, 40, 45], [15, 12, 10]),
            _strengthMenu('カーフレイズマシン', [40, 50, 60], [20, 15, 15]),
          ],
        };
      case 'abs':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('クランチ', [20, 20, 20]),
            _bodyweightMenu('レッグレイズ', [15, 15, 15]),
            _bodyweightMenu('プランク', [60, 60, 60]), // seconds
            _bodyweightMenu('バイシクルクランチ', [20, 20, 20]),
            _bodyweightMenu('ロシアンツイスト', [20, 20, 20]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ダンベルクランチ', [10, 12, 14], [15, 12, 12]),
            _strengthMenu('ダンベルサイドベント', [16, 18, 20], [15, 15, 12]),
            _strengthMenu('ウッドチョッパー', [10, 12, 14], [15, 15, 15]),
            _strengthMenu('ロシアンツイスト (Weighted)', [8, 10, 12], [20, 20, 20]),
            _strengthMenu('Vアップ (Weighted)', [5, 5, 5], [12, 10, 10]),
          ],
          _ => [
            _strengthMenu('アブローラー', [0, 0, 0], [12, 10, 10]),
            _strengthMenu('ケーブルクランチ', [30, 35, 40], [15, 12, 12]),
            _strengthMenu('ハンギングレッグレイズ', [0, 0, 0], [12, 10, 8]),
            _strengthMenu('トーソローテーション', [30, 40, 50], [15, 15, 15]),
            _strengthMenu('マシンクランチ', [30, 40, 50], [15, 12, 12]),
          ],
        };
      case 'arm':
        return switch (style) {
          TrainingStyle.bodyweight => [
            _bodyweightMenu('ナロープッシュアップ (Triceps)', [12, 10, 8]),
            _bodyweightMenu('ベンチディップス', [15, 15, 12]),
            _bodyweightMenu('チンニング (逆手/Biceps)', [8, 6, 5]),
            _bodyweightMenu('パイクプッシュアップ (Varied)', [10, 8, 8]),
            _bodyweightMenu('プランクアップダウン', [12, 12, 12]),
          ],
          TrainingStyle.dumbbell => [
            _strengthMenu('ダンベルカール', [10, 12, 14], [12, 10, 8]),
            _strengthMenu('ハンマーカール', [10, 12, 14], [12, 10, 8]),
            _strengthMenu('フレンチプレス', [14, 16, 18], [12, 10, 8]),
            _strengthMenu('トライセプスキックバック', [6, 8, 10], [15, 12, 12]),
            _strengthMenu('コンセントレーションカール', [8, 10, 12], [12, 10, 10]),
          ],
          _ => [
            _strengthMenu('バーベルカール', [20, 25, 30], [12, 10, 8]),
            _strengthMenu('プリチャーカール', [20, 25, 30], [12, 10, 8]),
            _strengthMenu('ケーブルプッシュダウン', [30, 35, 40], [15, 12, 12]),
            _strengthMenu('スカルクラッシャー', [20, 25, 30], [12, 10, 8]),
            _strengthMenu('ケーブルハンマーカール', [25, 30, 35], [15, 12, 12]),
          ],
        };
      case 'cardio':
        return [
          if (style == TrainingStyle.bodyweight) ...[
             _aerobicMenu('ウォーキング', distance: '3.0', duration: '00:30:00', calories: '150'),
             _aerobicMenu('ランニング', distance: '5.0', duration: '00:30:00', calories: '300'),
             _aerobicMenu('HIIT (バーピーなど)', distance: '', duration: '00:15:00', calories: '200'),
             _aerobicMenu('縄跳び', distance: '', duration: '00:10:00', calories: '100'),
             _aerobicMenu('階段昇降', distance: '', duration: '00:20:00', calories: '180'),
          ] else ...[
             _aerobicMenu('ランニングマシン', distance: '5.0', duration: '00:30:00', calories: '300'),
             _aerobicMenu('エアロバイク', distance: '10.0', duration: '00:30:00', calories: '200'),
             _aerobicMenu('クロストレーナー', distance: '', duration: '00:20:00', calories: '220'),
             _aerobicMenu('ローイングマシン', distance: '2.0', duration: '00:10:00', calories: '120'),
             _aerobicMenu('ステアクライマー', distance: '', duration: '00:15:00', calories: '180'),
          ]
        ];
      default:
        return [];
    }
  }

  String _originalPartName(String key) {
    switch (key) {
      case 'full_body': return '全身'; // Added Full Body
      case 'chest': return '胸';
      case 'back': return '背中';
      case 'shoulder': return '肩';
      case 'leg': return '足';
      case 'abs': return '腹筋';
      case 'cardio': return '有酸素運動';
      case 'arm': return '腕';
      default: return key;
    }
  }

  MenuData _strengthMenu(String name, List<double> weights, List<int> reps, {int? satisfaction}) {
    final len = min(weights.length, reps.length);
    final w = weights.take(len).toList();
    final r = reps.take(len).toList();
    final totalVolume = w.isNotEmpty ? _calcVolume(w, r) : 0.0;
    final formatWeight = w.map((v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1)).toList();
    final formatReps = r.map((v) => v.toString()).toList();
    return MenuData(
      name: name,
      weights: formatWeight,
      reps: formatReps,
      checkedStates: List<bool>.filled(len, false),
      failureFlags: List<bool>.filled(len, false),
      rirValues: List<String>.filled(len, ''),
      totalVolume: totalVolume,
      satisfaction: satisfaction,
    );
  }

  double _calcVolume(List<double> weights, List<int> reps) {
    double total = 0;
    for (var i = 0; i < weights.length && i < reps.length; i++) {
      total += weights[i] * reps[i];
    }
    return total;
  }

  MenuData _aerobicMenu(String name, {required String distance, required String duration, required String calories}) {
    return MenuData(
      name: name,
      weights: const [],
      reps: const [],
      distance: distance,
      duration: duration,
      calories: calories,
      checkedStates: const [],
      satisfaction: 5,
    );
  }

  MenuData _bodyweightMenu(String name, List<int> reps) {
    final repsStrings = reps.map((r) => r.toString()).toList();
    return MenuData(
      name: name,
      weights: List<String>.filled(reps.length, '0'),
      reps: repsStrings,
      checkedStates: List<bool>.filled(reps.length, false),
      failureFlags: List<bool>.filled(reps.length, false),
      rirValues: List<String>.filled(reps.length, ''),
      totalVolume: reps.fold<double>(0.0, (prev, e) => prev + e.toDouble()),
      satisfaction: 4,
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _finish({bool openRecord = false}) async {
    if (_isFinishing) return;
    _isFinishing = true;
    await _saveSelectedBodyParts();
    await SettingsManager.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pop(OnboardingResult(openRecord: openRecord));
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Page Content Definitions
    final pages = [
      // 1. Welcome Step
      _WelcomeStep(onNext: _nextPage),
      
      // 2. Configuration Steps
      _StyleSelectionStep(
        current: _trainingStyle,
        onChanged: (v) => setState(() => _trainingStyle = v),
        onNext: _nextPage,
        onBack: _prevPage,
      ),
      _BodyPartSelectionStep(
        selectedParts: _selectedBodyPartsOrder,
        onToggle: (part) {
          setState(() {
            if (_selectedBodyPartsOrder.contains(part)) {
              if (_selectedBodyPartsOrder.length > 1) {
                _selectedBodyPartsOrder.remove(part);
              }
            } else {
              _selectedBodyPartsOrder.add(part);
            }
          });
        },
        onNext: _nextPage,
        onBack: _prevPage,
      ),
      _WeekdaySelectionStep(
        selectedDays: _selectedWeekdayOrder,
        onToggle: (day) {
           setState(() {
            if (_selectedWeekdayOrder.contains(day)) {
              if (_selectedWeekdayOrder.length > 1) {
                _selectedWeekdayOrder.remove(day);
              }
            } else {
              _selectedWeekdayOrder.add(day);
              _selectedWeekdayOrder.sort(); // 曜日はソートしておく
            }
          });
        },
        onNext: _nextPage,
        onBack: _prevPage,
      ),

      // 4. Completion
      _CompletionStep(
        description: _sampleDescription(l10n),
        onStart: () => _loadSampleRoutineAndFinish(openRecord: true),
        onSkip: () => _finish(openRecord: false),
        isBusy: _importingSample,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to enforce flow
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: pages,
              ),
            ),
            // Progress Dots (Optional, but good for context)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Step Widgets ---

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fitness_center, size: 64, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingWelcomeTitle,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcomeBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(l10n.onboardingNext),
            ),
          ),
        ],
      ),
    );
  }
}



class _StyleSelectionStep extends StatelessWidget {
  final TrainingStyle current;
  final ValueChanged<TrainingStyle> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StyleSelectionStep({
    required this.current,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Align(
            alignment: Alignment.topLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingStyleQuestion,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _SelectableCard(
                  selected: current == TrainingStyle.gym,
                  onTap: () => onChanged(TrainingStyle.gym),
                  icon: Icons.fitness_center,
                  label: l10n.onboardingStyleGym,
                ),
                const SizedBox(height: 12),
                _SelectableCard(
                  selected: current == TrainingStyle.dumbbell,
                  onTap: () => onChanged(TrainingStyle.dumbbell),
                  icon: Icons.sports_gymnastics, // Alternate icon
                  label: l10n.onboardingStyleDumbbell,
                ),
                const SizedBox(height: 12),
                _SelectableCard(
                  selected: current == TrainingStyle.bodyweight,
                  onTap: () => onChanged(TrainingStyle.bodyweight),
                  icon: Icons.accessibility_new,
                  label: l10n.onboardingStyleBodyweight,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(l10n.onboardingNext),
          ),
        ],
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _BodyPartSelectionStep extends StatelessWidget {
  final List<String> selectedParts;
  final ValueChanged<String> onToggle;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _BodyPartSelectionStep({
    required this.selectedParts,
    required this.onToggle,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parts = [
      {'key': 'full_body', 'label': '全身', 'icon': Icons.accessibility_sharp}, // Added Full Body
      {'key': 'chest', 'label': l10n.chest, 'icon': Icons.shield},
      {'key': 'back', 'label': l10n.back, 'icon': Icons.accessibility},
      {'key': 'shoulder', 'label': l10n.shoulder, 'icon': Icons.accessibility_new},
      {'key': 'arm', 'label': '腕', 'icon': Icons.fitness_center}, // added arm
      {'key': 'leg', 'label': l10n.leg, 'icon': Icons.directions_walk},
      {'key': 'abs', 'label': l10n.abs, 'icon': Icons.grid_view}, // Simple icon
      {'key': 'cardio', 'label': l10n.aerobicExercise, 'icon': Icons.favorite},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Align(
            alignment: Alignment.topLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingBodyPartQuestion,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
           const SizedBox(height: 8),
           Text('Select all that apply', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: parts.map((p) {
                final key = p['key'] as String;
                final label = p['label'] as String;
                final icon = p['icon'] as IconData;
                final selected = selectedParts.contains(key);
                return _SelectableGridItem(
                  selected: selected,
                  label: label,
                  icon: icon,
                  onTap: () => onToggle(key),
                );
              }).toList(),
            ),
          ),
           FilledButton(
            onPressed: selectedParts.isEmpty ? null : onNext,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(l10n.onboardingNext),
          ),
        ],
      ),
    );
  }
}

class _SelectableGridItem extends StatelessWidget {
   final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

   const _SelectableGridItem({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
     final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
       borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant, size: 32),
            const SizedBox(height: 8),
             Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
               if (selected)
               Padding(
                 padding: const EdgeInsets.only(top: 4),
                 child: Icon(Icons.check_circle, size: 16, color: cs.primary),
               ),
          ],
        ),
      ),
    );
  }
}

class _WeekdaySelectionStep extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<int> onToggle;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _WeekdaySelectionStep({
    required this.selectedDays,
    required this.onToggle,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final formatter = DateFormat.E(locale.toLanguageTag());
    final baseMonday = DateTime(2024, 1, 1);
    final days = List.generate(7, (i) {
      final d = baseMonday.add(Duration(days: i));
      return {'weekday': d.weekday, 'label': formatter.format(d)};
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Align(
            alignment: Alignment.topLeft,
            child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingDayQuestion,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // Today Chip
              FilterChip(
                label: const Text('今日'),
                selected: selectedDays.contains(DateTime.now().weekday),
                showCheckmark: false,
                onSelected: (_) => onToggle(DateTime.now().weekday),
                padding: const EdgeInsets.all(12),
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: selectedDays.contains(DateTime.now().weekday)
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...days.map((d) {
                final weekday = d['weekday'] as int;
                final label = d['label'] as String;
                final selected = selectedDays.contains(weekday);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => onToggle(weekday),
                  padding: const EdgeInsets.all(12),
                );
              }),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(l10n.onboardingNext),
          ),
        ],
      ),
    );
  }
}

class _CompletionStep extends StatelessWidget {
  final String description;
  final VoidCallback onStart;
  final VoidCallback onSkip;
  final bool isBusy;

  const _CompletionStep({
    required this.description,
    required this.onStart,
    required this.onSkip,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
     final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            const Spacer(),
           const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
            l10n.onboardingSampleTitle, // "Sample Routine" or similar header
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
             textAlign: TextAlign.center,
          ),
           const SizedBox(height: 16),
            Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
           const Spacer(),
           if (isBusy)
            const CircularProgressIndicator()
          else ...[
            SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(l10n.onboardingSampleButton), // "Load Sample"
            ),
          ),
          const SizedBox(height: 16),
           TextButton(
            onPressed: onSkip,
            child: Text(l10n.onboardingSkip, style: const TextStyle(color: Colors.grey)),
          ),
          ],
        ],
      ),
    );
  }
}

Animation<double> user_scale_tween(Animation<double> parent) {
  return Tween<double>(begin: 0.8, end: 1.0).animate(parent);
}

class _SuccessDialogContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Menu Created!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'メニューを作成しました。\n素敵なトレーニングライフをお過ごしください！',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Let\'s Start!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
