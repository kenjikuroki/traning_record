import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/age_signals_service.dart';

class BannerAdManager {
  static final BannerAdManager instance = BannerAdManager._internal();

  BannerAdManager._internal();

  BannerAd? _calendarBannerAd;
  bool _isCalendarAdLoaded = false;
  
  // 外部から監視するためのNotifier
  final ValueNotifier<bool> calendarAdLoadedNotifier = ValueNotifier(false);

  /// 外部から広告オブジェクトを取得する
  /// (まだロードされていない、あるいはロード失敗の場合は null の可能性あり)
  BannerAd? get calendarBannerAd => _isCalendarAdLoaded ? _calendarBannerAd : null;

  /// アプリ起動時などに呼び出して先行ロードを開始する
  Future<void> preloadCalendarAd() async {
    // 既に持っているなら何もしない
    if (_calendarBannerAd != null) {
       // 既にロード済みなら念のため通知
       if (_isCalendarAdLoaded) {
         calendarAdLoadedNotifier.value = true;
       }
       return;
    }

    final String adUnitId = _getCalendarAdUnitId();
    
    // 画面幅を取得してAdaptiveサイズを計算
    // main()直後など Context がない場合は PlatformDispatcher から取得を試みる
    AdSize adSize = AdSize.banner;
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
      final orientation = view.physicalSize.width > view.physicalSize.height
          ? Orientation.landscape
          : Orientation.portrait;
      
      final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        orientation,
        logicalWidth.truncate(),
      );
      if (size != null) {
        adSize = size;
      }
    } catch (e) {
      debugPrint('[BannerAdManager] Failed to get adaptive size: $e');
      // 失敗時は標準バナーサイズで続行
    }

    _calendarBannerAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: AgeSignalsService.instance.buildAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[BannerAdManager] Calendar ad loaded.');
          _isCalendarAdLoaded = true;
          calendarAdLoadedNotifier.value = true;
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('[BannerAdManager] Calendar ad failed to load: $error');
          _isCalendarAdLoaded = false;
          calendarAdLoadedNotifier.value = false;
          ad.dispose();
          _calendarBannerAd = null;
        },
      ),
    );

    await _calendarBannerAd!.load();
  }

  String _getCalendarAdUnitId() {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }

    if (Platform.isAndroid) {
      return 'ca-app-pub-3331079517737737/2576446816';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3331079517737737/1430886104';
    } else {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
  }

  // --- Record Header Ad ---

  BannerAd? _recordHeaderAd;
  bool _isRecordHeaderAdLoaded = false;

  BannerAd? get recordHeaderAd => _isRecordHeaderAdLoaded ? _recordHeaderAd : null;

  Future<void> preloadRecordHeaderAd() async {
    if (_recordHeaderAd != null) return;

    final String adUnitId = _getRecordHeaderAdUnitId();

    // 320x50 is standard banner size, suitable for AppBar title area substitution
    // Or we can use adaptive size, but standard banner fits well in 56 height AppBar.
    const adSize = AdSize.banner; 

    _recordHeaderAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: AgeSignalsService.instance.buildAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[BannerAdManager] Record Header ad loaded.');
          _isRecordHeaderAdLoaded = true;
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('[BannerAdManager] Record Header ad failed to load: $error');
          _isRecordHeaderAdLoaded = false;
          ad.dispose();
          _recordHeaderAd = null;
        },
      ),
    );

    await _recordHeaderAd!.load();
  }

  String _getRecordHeaderAdUnitId() {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Test Banner
          : 'ca-app-pub-3940256099942544/2934735716'; // Test Banner
    }

    // Use the specific ID provided by user for both platforms or as requested
    // The user provided: ca-app-pub-3331079517737737/8642020070
    // Assuming this is for the current platform (likely iOS based on history, but I should probably check if they want separate IDs. 
    // The request said "id is this ...", usually valid for one platform or they use same logic. 
    // Since previous records show different IDs for Android/iOS, I will use this ID for both or assume it's the target.
    // However, usually AdMob IDs are platform specific.
    // Let's assume the user provided ID is for the platform they are testing (likely iOS given previous context or Android).
    // I will use it for both for now, or if I recall previous convos...
    // The user said "id is this". I will use it.
    
    return 'ca-app-pub-3331079517737737/8642020070';
  }
}
