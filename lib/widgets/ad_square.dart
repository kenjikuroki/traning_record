import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/age_signals_service.dart';
import '../settings_manager.dart';

/// 利用可能なバナーサイズ
enum AdBoxSize {
  banner, // 320x50
  largeBanner, // 320x100
  mediumRectangle // 300x250
}

class AdSquare extends StatefulWidget {
  /// 表示する広告サイズ
  final AdBoxSize adSize;

  /// 読み込み中や失敗時にダミー枠を表示するか
  final bool showPlaceholder;

  /// 呼び出し元画面名（広告ID判定に使用）
  final String screenName;

  const AdSquare({
    super.key,
    this.adSize = AdBoxSize.mediumRectangle,
    this.showPlaceholder = true,
    required this.screenName,
  });

  @override
  State<AdSquare> createState() => _AdSquareState();
}

class _AdSquareState extends State<AdSquare> with SingleTickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _failedToLoad = false;
  bool _loading = false;
  late final AnimationController _placeholderCtrl;

  AdSize get _adSize {
    switch (widget.adSize) {
      case AdBoxSize.banner:
        return AdSize.banner; // 320x50
      case AdBoxSize.largeBanner:
        return AdSize.largeBanner; // 320x100
      case AdBoxSize.mediumRectangle:
        return AdSize.mediumRectangle; // 300x250
    }
  }

  /// 本番/テストの広告ユニットIDを返す
  String _resolveAdUnitId() {
    // デバッグ時はGoogle公式のテストID
    if (kDebugMode) {
      if (widget.adSize == AdBoxSize.mediumRectangle) {
        return Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/2177585250'
            : 'ca-app-pub-3940256099942544/3001886131';
      } else {
        return Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/6300978111'
            : 'ca-app-pub-3940256099942544/2934735716';
      }
    }

    // 本番用ID
    if (Platform.isAndroid) {
      switch (widget.screenName) {
        case 'calendar':
          return 'ca-app-pub-3331079517737737/2576446816'; // Android カレンダー画面スクエア広告
        case 'settings':
          return 'ca-app-pub-3331079517737737/3704893323'; // Android 設定画面スクエア広告
        default:
          return 'ca-app-pub-3940256099942544/2177585250'; // テストID
      }
    } else if (Platform.isIOS) {
      switch (widget.screenName) {
        case 'calendar':
          return 'ca-app-pub-3331079517737737/1430886104';
        case 'settings':
          return 'ca-app-pub-3331079517737737/8271626623';
        default:
          return 'ca-app-pub-3940256099942544/3001886131';
      }
    } else {
      return 'ca-app-pub-3940256099942544/2177585250';
    }
  }

  @override
  void initState() {
    super.initState();
    _placeholderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    if (!SettingsManager.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isAdLoaded && !_loading) {
          _loadAd();
        }
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _placeholderCtrl.dispose();
    super.dispose();
  }

  void _loadAd() {
    _failedToLoad = false;
    _isAdLoaded = false;
    _loading = true;

    _bannerAd = BannerAd(
      adUnitId: _resolveAdUnitId(),
      request: AgeSignalsService.instance.buildAdRequest(),
      size: _adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _loading = false;
            _placeholderCtrl.stop();
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _failedToLoad = true;
            _isAdLoaded = false;
            _loading = false;
            _placeholderCtrl
              ..reset()
              ..forward();
          });
          debugPrint('AdSquare failed to load: $err');
        },
      ),
    )..load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!SettingsManager.demoMode && !_isAdLoaded && !_loading) {
      _loadAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SettingsManager.demoMode) return const SizedBox.shrink(); // ← 追加

    // 成功
    final bool showAd = _isAdLoaded && _bannerAd != null;
    final s = _expectedSize;

    return SizedBox(
      width: s.width,
      height: s.height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: showAd
            ? ClipRRect(
                key: const ValueKey('square-ad'),
                borderRadius: BorderRadius.circular(12),
                child: AdWidget(ad: _bannerAd!),
              )
            : (widget.showPlaceholder
                ? _SquarePlaceholder(
                    key: const ValueKey('square-placeholder'),
                    animation: _placeholderCtrl,
                    failed: _failedToLoad,
                    size: s,
                  )
                : const SizedBox.shrink()),
      ),
    );
  }

  Size get _expectedSize {
    switch (widget.adSize) {
      case AdBoxSize.banner:
        return const Size(320, 50);
      case AdBoxSize.largeBanner:
        return const Size(320, 100);
      case AdBoxSize.mediumRectangle:
        return const Size(300, 250);
    }
  }
}

class _SquarePlaceholder extends StatelessWidget {
  final Animation<double> animation;
  final bool failed;
  final Size size;

  const _SquarePlaceholder({
    super.key,
    required this.animation,
    required this.failed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double t = animation.value;
        const double start = -1.05;
        const double end = 1.05;
        final double fadeIn = t < 0.25
            ? Curves.easeOutCubic.transform(t / 0.25)
            : 1.0;
        final double scale = t < 0.25
            ? 0.94 + 0.06 * Curves.easeOutCubic.transform(t / 0.25)
            : 1.0;

        final double shimmerPhase = t <= 0.25
            ? 0.0
            : ((t - 0.25) / 0.75).clamp(0.0, 1.0);
        final double shimmerPos = start + (end - start) * shimmerPhase;

        final baseColor = cs.surfaceVariant.withOpacity(0.26);
        final highlight = Colors.white.withOpacity(0.28);

        return Opacity(
          opacity: fadeIn,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
              ),
              child: Stack(
                children: [
                  if (shimmerPhase < 0.98)
                    Align(
                      alignment: Alignment(shimmerPos, 0),
                      child: FractionallySizedBox(
                        widthFactor: 0.24,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                highlight.withOpacity(0.0),
                                highlight,
                                highlight.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (failed)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: cs.onSurfaceVariant,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ad unavailable',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
