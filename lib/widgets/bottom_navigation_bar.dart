// lib/widgets/bottom_navigation_bar.dart

import 'package:flutter/material.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        // 戻るボタンを削除しました
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'カレンダー',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '設定',
        ),
      ],
      currentIndex: currentIndex,
      onTap: onTap,
    );
  }
}