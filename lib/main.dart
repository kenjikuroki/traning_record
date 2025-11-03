// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'dart:io' show Platform; // ★ 追加
import 'theme/app_theme.dart';

import 'models/menu_data.dart';
import 'screens/home_screen.dart';
import 'settings_manager.dart';
import 'package:audio_session/audio_session.dart';
import 'services/age_signals_service.dart';
import 'services/notification_service.dart';

Future<void> _initAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music()); // 再生専用
}
// 例えば main() の最初で await _initAudioSession(); を呼ぶ

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initAudioSession();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MenuDataAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyRecordAdapter());
  }

  await SettingsManager.initialize();

  await AgeSignalsService.instance.ensureInitialized();

  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissionsIfNeeded();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final recordsBox = await Hive.openBox<DailyRecord>('dailyRecords');
  // 型安全化：List<MenuData> 保持用
  final lastUsedMenusBox = await Hive.openBox<List>('lastUsedMenus');
  final settingsBox = await Hive.openBox<dynamic>('settings');
  final setCountBox = await Hive.openBox<int>('setCount');

  runApp(MyApp(
    recordsBox: recordsBox,
    lastUsedMenusBox: lastUsedMenusBox,
    settingsBox: settingsBox,
    setCountBox: setCountBox,
  ));

  // 初回フレーム描画後に、ATT → 広告初期化 の順で実行（iOSのみ）
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // スプラッシュからホームへの遷移安定のため、短い待機
        await Future.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await MobileAds.instance.initialize();
    } else {
      // iOS以外はそのまま初期化
      await MobileAds.instance.initialize();
    }
  });
}

class MyApp extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List> lastUsedMenusBox;
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  BuildContext? _localizedContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _resetNotificationsLocalized(BuildContext context) async {
    final s = AppLocalizations.of(context)!;
    await NotificationService.instance.resetInactiveTimersLocalized(
      time: const TimeOfDay(hour: 19, minute: 0),
      title3: s.notiInactive3Title,
      body3: s.notiInactive3Body,
      title7: s.notiInactive7Title,
      body7: s.notiInactive7Body,
    );
    await NotificationService.instance.resetDailyFromPrefs(
      title: s.notiDailyTitle,
      randomBody: () {
        final list = [s.notiDailyBodyA, s.notiDailyBodyB]..shuffle();
        return list.first;
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _localizedContext;
      if (ctx != null) {
        _resetNotificationsLocalized(ctx);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ctx = _localizedContext;
      if (ctx != null) {
        _resetNotificationsLocalized(ctx);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsManager.themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SettingsManager.appColorThemeIndexNotifier,
          builder: (context, themeIdx, __) {
            return MaterialApp(
              title: 'TrainingRecord',
              debugShowCheckedModeBanner: false,
              theme: appThemeLight(context),
              darkTheme: appThemeDark(context),
              themeMode: themeMode,

              // l10n
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,

              // 壁紙の即時反映（背景が変わるたびに再ビルド）
              builder: (context, child) {
                _localizedContext = context;
                return ValueListenableBuilder<String>(
                  valueListenable: SettingsManager.backgroundAssetNotifier,
                  builder: (context, bg, __) {
                    if (bg.isEmpty) {
                      return child ?? const SizedBox.shrink();
                    }
                    return Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(bg),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          scaffoldBackgroundColor: Colors.transparent,
                          canvasColor: Colors.transparent,
                          cardColor: Colors.transparent,
                          dialogBackgroundColor: Colors.transparent,
                          bottomSheetTheme: const BottomSheetThemeData(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            elevation: 0,
                          ),
                        ),
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                );
              },

              // ルート画面（戻るで最小化をブロック）
              home: PopScope(
                canPop: false,
                child: HomeScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
