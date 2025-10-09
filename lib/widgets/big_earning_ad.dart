import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/age_signals_service.dart';
import '../settings_manager.dart';
/// 大きめの収益広告
/// - iOS: まず MREC(300x250) をロードして確実表示 →（任意で）Native を後追いロード
/// - Android: Native 優先 → 失敗時 MREC フォールバック
class BigEarningAd extends StatefulWidget {
  final String androidNativeUnitId;
  final String iosNativeUnitId;
  final String androidBannerUnitId; // MREC/Banner
  final String iosBannerUnitId;     // MREC/Banner
  final String factoryId;           // NativeAd factoryId（iOSで使うならAppDelegate側に登録必須）
  final double height;              // Native表示時の高さ（例: 240〜300）

  const BigEarningAd({
    super.key,
    required this.androidNativeUnitId,
    required this.iosNativeUnitId,
    required this.androidBannerUnitId,
    required this.iosBannerUnitId,
    this.factoryId = 'large_media',
    this.height = 260,
  });

  @override
  State<BigEarningAd> createState() => _BigEarningAdState();
}

class _BigEarningAdState extends State<BigEarningAd> {
  NativeAd? _nativeAd;
  BannerAd? _mrecAd;

  bool _nativeLoaded = false;
  bool _mrecLoaded = false;

  bool _requestedNative = false;
  bool _requestedMrec = false;

  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    if (SettingsManager.demoMode) {
      return;
    }
    // 念のため。main()で初期化済みでも二重で問題なし
    MobileAds.instance.initialize();

    if (Platform.isIOS) {
      // iOSはまずMRECをロードして“必ず出す”
      _loadMrec();
      // （任意）2秒後にネイティブを試す（失敗してもMRECが出ているのでUXを壊さない）
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_nativeLoaded) _loadNative();
      });
    } else {
      // Androidはネイティブ優先 → 失敗でMRECへ
      _loadNative();
    }

    // 4秒ウォッチドッグ：どちらも来ない場合はMRECを要求
    _watchdog = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (!_nativeLoaded && !_mrecLoaded) {
        _loadMrec();
      }
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _nativeAd?.dispose();
    _mrecAd?.dispose();
    super.dispose();
  }

  // ─────────────────────────────
  // Loaders
  // ─────────────────────────────
  void _loadNative() {
    if (_requestedNative) return;
    _requestedNative = true;

    final unitId = Platform.isAndroid
        ? widget.androidNativeUnitId
        : widget.iosNativeUnitId;

    _nativeAd = NativeAd(
      adUnitId: unitId,
      request: AgeSignalsService.instance.buildAdRequest(),
      // iOSで使う場合は factoryId を AppDelegate で登録しておくこと
      factoryId: widget.factoryId,
      // ここは非constにしておく（constにするとVideoOptionsもconst必須でコケやすい）
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(startMuted: true),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _nativeAd = ad as NativeAd;
            _nativeLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // iOS/Androidともに失敗時はMRECへ
          _loadMrec();
        },
      ),
    )..load();
  }

  void _loadMrec() {
    if (_requestedMrec) return;
    _requestedMrec = true;

    final unitId = Platform.isAndroid
        ? widget.androidBannerUnitId
        : widget.iosBannerUnitId;

    _mrecAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.mediumRectangle, // 300x250
      request: AgeSignalsService.instance.buildAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _mrecAd = ad as BannerAd;
            _mrecLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _mrecLoaded = false);
        },
      ),
    )..load();
  }

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (SettingsManager.demoMode) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;

    // 優先：ネイティブ
    if (_nativeLoaded && _nativeAd != null) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    }

    // フォールバック：MREC（サイズはAdSizeに合わせる）
    if (_mrecLoaded && _mrecAd != null) {
      return Center(
        child: SizedBox(
          width: _mrecAd!.size.width.toDouble(),
          height: _mrecAd!.size.height.toDouble(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AdWidget(ad: _mrecAd!),
          ),
        ),
      );
    }

    // ローディング/ノーフィル → スケルトン
    return _AdLoadingSkeleton(height: widget.height, colorScheme: cs);
  }
}

// シマー風の読み込み中プレースホルダ
class _AdLoadingSkeleton extends StatefulWidget {
  final double height;
  final ColorScheme colorScheme;
  const _AdLoadingSkeleton({required this.height, required this.colorScheme});

  @override
  State<_AdLoadingSkeleton> createState() => _AdLoadingSkeletonState();
}

class _AdLoadingSkeletonState extends State<_AdLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value; // 0.0↔1.0
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + t, -1),
                  end: Alignment(t, 1),
                  colors: [
                    cs.surfaceContainerHighest,
                    cs.surfaceContainer,
                    cs.surfaceContainerHighest,
                  ],
                  stops: const [0.1, 0.5, 0.9],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // サムネイル枠
                    Container(
                      width: 120,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // テキストっぽいダミー + CTAっぽいダミー
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line(cs, h: 18, w: 0.7),
                          const SizedBox(height: 10),
                          _line(cs, h: 14, w: 1.0),
                          const SizedBox(height: 6),
                          _line(cs, h: 14, w: 0.9),
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              width: 72,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _line(ColorScheme cs, {required double h, required double w}) {
    return FractionallySizedBox(
      widthFactor: w,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
