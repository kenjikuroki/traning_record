// lib/screens/home_screen.dart
import 'dart:ui'; // ← BackdropFilter用
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import 'calendar_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';
import 'album_screen.dart';

class HomeScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const HomeScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<CalendarScreenState> _calendarKey =
      GlobalKey<CalendarScreenState>();
  final GlobalKey<AlbumScreenState> _albumKey = GlobalKey<AlbumScreenState>();
  int _currentIndex = 0;

  int get _currentNavIndex =>
      _currentIndex <= 1 ? _currentIndex : _currentIndex + 1;

  bool get _isAddDisabled => _currentIndex >= 2;

  Widget _buildAddNavIcon(ColorScheme colorScheme,
      {required bool disabled, bool highlighted = false}) {
    final bool usable = !disabled;
    final Color baseBg = highlighted && usable
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final Color bg = usable ? baseBg : colorScheme.surfaceVariant;
    final Color border = usable
        ? colorScheme.outlineVariant.withOpacity(highlighted ? 0.2 : 0.4)
        : colorScheme.outlineVariant.withOpacity(0.6);
    final Color fg = usable
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant.withOpacity(0.75);

    return SizedBox(
      width: 50,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Center(
          child: Icon(
            Icons.add_rounded,
            size: 22,
            color: fg,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) async {
    if (index == 2) {
      if (!_isAddDisabled) {
        await _handleAddAction();
      }
      return;
    }

    final nextIndex = index > 2 ? index - 1 : index;
    if (nextIndex == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = nextIndex);
  }

  Future<void> _handleAddAction() async {
    if (_currentIndex == 0) {
      final state = _calendarKey.currentState;
      if (state != null) {
        await state.handleAddAction();
      }
      return;
    }
    if (_currentIndex == 1) {
      final state = _albumKey.currentState;
      if (state != null) {
        await state.handleAddAction();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final addDisabled = _isAddDisabled;

// ▼ ライト：白地に黒文字／ダーク：黒地に白文字
    final Color navBgColor = colorScheme.primaryContainer; // ← テーマ連動
    final Color navFgColor = colorScheme.onPrimaryContainer; // ← テーマ連動

// AppBar と同一の黒グラデ（すりガラスにグレーを足す）
// Calendar / Album / Graph: 0.58, 0.38, 0.16
// Settings:                 0.60, 0.40, 0.18
    final List<Color> bottomBarColors = (() {
      switch (_currentIndex) {
        case 3: // Settings
          return [
            Colors.black.withOpacity(0.60),
            Colors.black.withOpacity(0.40),
            Colors.black.withOpacity(0.18),
          ];
        default: // Calendar / Album / Graph
          return [
            Colors.black.withOpacity(0.58),
            Colors.black.withOpacity(0.38),
            Colors.black.withOpacity(0.16),
          ];
      }
    })();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: IndexedStack(
          key: ValueKey<int>(_currentIndex),
          index: _currentIndex,
          children: [
            // 0: カレンダー
            CalendarScreen(
              key: _calendarKey,
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
              settingsBox: widget.settingsBox,
              setCountBox: widget.setCountBox,
              selectedDate: DateTime.now(),
            ),
            // 1: アルバム
            AlbumScreen(
              key: _albumKey,
            ),
            // 2: グラフ（isActive のインデックスも 2 に変更）
            GraphScreen(
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
              settingsBox: widget.settingsBox,
              setCountBox: widget.setCountBox,
              isActive: _currentIndex == 2,
            ),
            // 3: 設定
            SettingsScreen(
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
              settingsBox: widget.settingsBox,
              setCountBox: widget.setCountBox,
            ),
          ],
        ),
      ),
      bottomNavigationBar: ColoredBox(
        // ▼ バー“の下”を含めて同色で塗る
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false, // 下だけ余白を確保
          child: BottomNavigationBar(
            currentIndex: _currentNavIndex,
            selectedItemColor: navFgColor,
            unselectedItemColor: navFgColor.withOpacity(0.6),
            // ▼ 背景は透過にして、外側の ColoredBox の色を見せる
            backgroundColor: Colors.transparent,
            elevation: 0,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: _onItemTapped,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_today),
                label: l10n.calendar,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.photo_library_outlined),
                label: l10n.albumTitle,
              ),
              BottomNavigationBarItem(
                icon: _buildAddNavIcon(
                  colorScheme,
                  disabled: addDisabled,
                ),
                activeIcon: _buildAddNavIcon(
                  colorScheme,
                  disabled: addDisabled,
                  highlighted: true,
                ),
                label: l10n.add,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.bar_chart),
                label: l10n.graph,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: l10n.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
