// lib/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/record_models.dart'; // この行が重要です。DailyRecordの定義をインポートします。

class GraphScreen extends StatelessWidget {
  final Box<DailyRecord> recordsBox;

  const GraphScreen({
    super.key,
    required this.recordsBox,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グラフ'),
      ),
      body: const Center(
        child: Text('グラフ機能は未実装です。'),
      ),
    );
  }
}