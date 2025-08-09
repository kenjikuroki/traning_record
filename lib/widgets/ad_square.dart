import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdSquare extends StatefulWidget {
  const AdSquare({super.key});

  @override
  State<AdSquare> createState() => _AdSquareState();
}

class _AdSquareState extends State<AdSquare> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  final String adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2177585250' // Androidテスト用レクタングル広告ID
      : 'ca-app-pub-3940256099942544/3001886131'; // iOSテスト用レクタングル広告ID

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
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.mediumRectangle, // AdSize.mediumRectangleは300x250のスクエア型広告です
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          _isAdLoaded = false;
          ad.dispose();
          debugPrint('BannerAd failed to load: $err'); // ★ 追加したログ
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}