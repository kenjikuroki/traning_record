import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdBanner extends StatefulWidget {
  final String screenName;

  const AdBanner({super.key, required this.screenName});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    String adUnitId;
    if (kDebugMode) {
      // デバッグモードではテストIDを使用
      adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Androidテスト用
          : 'ca-app-pub-3940256099942544/2934735716'; // iOSテスト用
    } else {
      // リリースモードでは本番IDを使用
      if (Platform.isAndroid) {
        if (widget.screenName == 'calendar') {
          adUnitId = 'ca-app-pub-3331079517737737/2576446816';
        } else if (widget.screenName == 'record') {
          adUnitId = 'ca-app-pub-3331079517737737/9588577724';
        } else if (widget.screenName == 'settings') {
          adUnitId = 'ca-app-pub-3331079517737737/3704893323';
        } else {
          // デフォルトとして Android のテストIDを使用
          adUnitId = 'ca-app-pub-3940256099942544/6300978111';
        }
      } else if (Platform.isIOS) {
        if (widget.screenName == 'calendar') {
          adUnitId = 'ca-app-pub-3331079517737737/1430886104';
        } else if (widget.screenName == 'record') {
          adUnitId = 'ca-app-pub-3331079517737737/6962414382';
        } else if (widget.screenName == 'settings') {
          adUnitId = 'ca-app-pub-3331079517737737/8271626623';
        } else {
          // デフォルトとして iOS のテストIDを使用
          adUnitId = 'ca-app-pub-3940256099942544/2934735716';
        }
      } else {
        // サポートされていないプラットフォームの場合、AndroidのテストIDを使用
        adUnitId = 'ca-app-pub-3940256099942544/6300978111';
      }
    }

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('広告の読み込みに失敗しました: $error');
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
