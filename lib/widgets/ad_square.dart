import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

class _AdSquareState extends State<AdSquare> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _failedToLoad = false;

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
    _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _failedToLoad = false;
    _isAdLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: _resolveAdUnitId(),
      request: const AdRequest(),
      size: _adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _failedToLoad = true;
            _isAdLoaded = false;
          });
          debugPrint('AdSquare failed to load: $err');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    // 成功
    if (_isAdLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // プレースホルダー
    if (widget.showPlaceholder) {
      final colorScheme = Theme.of(context).colorScheme;
      final s = _expectedSize;
      return Container(
        width: s.width,
        height: s.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _failedToLoad ? Icons.block : Icons.image_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              _failedToLoad ? 'Ad unavailable' : 'Ad loading…',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
