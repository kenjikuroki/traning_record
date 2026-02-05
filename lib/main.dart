// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'dart:io' show Platform; // ★ 追加
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/iap_service.dart';
import 'theme/app_theme.dart';

import 'models/menu_data.dart';
import 'screens/home_screen.dart';
import 'settings_manager.dart';
import 'package:audio_session/audio_session.dart';
import 'services/age_signals_service.dart';
import 'services/notification_service.dart';
import 'utils/banner_ad_manager.dart';

Future<void> _initAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music()); // 再生専用
}
// 例えば main() の最初で await _initAudioSession(); を呼ぶ

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase初期化 (設定ファイルがない場合はスキップ)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization skip or error: $e');
  }

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
  await IAPService.instance.init();

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
    // カレンダー広告の先行ロード
    BannerAdManager.instance.preloadCalendarAd();
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

  Future<void> _updateWakelock() async {
    final bool keepOn = SettingsManager.keepScreenOn;
    if (keepOn) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  void _handleKeepScreenOnChanged() {
    _updateWakelock();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateWakelock();
    SettingsManager.keepScreenOnNotifier.addListener(_handleKeepScreenOnChanged);
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
    SettingsManager.keepScreenOnNotifier
        .removeListener(_handleKeepScreenOnChanged);
    WakelockPlus.disable();
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
                    final theme = Theme.of(context);
                    final overlayStyle = theme.brightness == Brightness.light
                        ? SystemUiOverlayStyle.dark.copyWith(
                            statusBarColor: Colors.transparent,
                          )
                        : SystemUiOverlayStyle.light.copyWith(
                            statusBarColor: Colors.transparent,
                          );

                    Widget result = bg.isEmpty
                        ? (child ?? const SizedBox.shrink())
                        : Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(bg),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Theme(
                              data: theme.copyWith(
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

                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: overlayStyle,
                      child: result,
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
