import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:ttraining_record/widgets/ad_banner.dart';
import 'package:ttraining_record/screens/calendar_screen.dart';
import 'package:ttraining_record/screens/record_screen.dart';
import 'package:ttraining_record/screens/settings_screen.dart';
import '../models/record_models.dart';
import '../models/menu_data.dart';

class GraphScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const GraphScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          l10n.graph,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20.0,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'こんにちは',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const AdBanner(screenName: 'graph'),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Record',
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
        currentIndex: 2, // グラフ画面なので2
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surface,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => CalendarScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                  selectedDate: DateTime.now(),
                ),
              ),
                  (route) => false,
            );
          } else if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => RecordScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                  selectedDate: DateTime.now(),
                ),
              ),
                  (route) => false,
            );
          } else if (index == 3) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                ),
              ),
                  (route) => false,
            );
          }
        },
      ),
    );
  }
}