// lib/screens/home_screen.dart
import 'dart:ui'; // ← BackdropFilter用
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent, // ← 壁紙を透過表示
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
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
              settingsBox: widget.settingsBox,
              setCountBox: widget.setCountBox,
              selectedDate: DateTime.now(),
            ),
            // 1: アルバム
            const AlbumScreen(),
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
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.22),
                  Colors.black.withOpacity(0.45),
                ],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              backgroundColor: Colors.transparent,
              elevation: 0,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library_outlined),
                  label: 'Album',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Graph',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
