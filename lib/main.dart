// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'l10n/app_localizations.dart';
import 'models/menu_data.dart';
import 'models/record_models.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'settings_manager.dart';
import 'widgets/bottom_navigation_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await MobileAds.instance.initialize();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MenuDataAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyRecordAdapter());
  }

  await SettingsManager.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final recordsBox = await Hive.openBox<DailyRecord>('dailyRecords');
  final lastUsedMenusBox = await Hive.openBox<dynamic>('lastUsedMenus');
  final settingsBox = await Hive.openBox<dynamic>('settings');
  final setCountBox = await Hive.openBox<int>('setCount');

  runApp(MyApp(
    recordsBox: recordsBox,
    lastUsedMenusBox: lastUsedMenusBox,
    settingsBox: settingsBox,
    setCountBox: setCountBox,
  ));
}

class MyApp extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const MyApp({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 画面リストのインデックスを2つに修正
  // 0:カレンダー, 1:設定
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      // インデックス0: CalendarScreen
      CalendarScreen(
        recordsBox: widget.recordsBox,
        lastUsedMenusBox: widget.lastUsedMenusBox,
        settingsBox: widget.settingsBox,
        setCountBox: widget.setCountBox,
      ),
      // インデックス1: SettingsScreen
      SettingsScreen(
        settingsBox: widget.settingsBox,
        setCountBox: widget.setCountBox,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsManager.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Training Record',
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Inter',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Inter',
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('ja', ''),
          ],
          home: Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: _widgetOptions,
            ),
            bottomNavigationBar: AppBottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}