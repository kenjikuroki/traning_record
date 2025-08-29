// lib/screens/home_screen.dart
import 'dart:ui'; // ← BackdropFilter用
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import 'calendar_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';

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
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
      _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
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
            CalendarScreen(
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                  selectedDate: DateTime.now(),
                ),
                GraphScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                  isActive: _currentIndex == 1,
                ),
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
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.00),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  selectedItemColor: Colors.white,     // 可読性UP
                  unselectedItemColor: Colors.white70, // 可読性UP
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onTap: _onItemTapped,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_today),
                      label: 'Calendar',
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
        ),
    );
  }
}
