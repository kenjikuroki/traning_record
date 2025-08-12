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
  bool _loading = false;

  // Medium Rectangle は固定 300x250
  static const _size = AdSize.mediumRectangle;

  String get _adUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2177585250'
      : 'ca-app-pub-3940256099942544/3001886131';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && !_isAdLoaded) {
      _load();
    }
  }

  void _load() {
    _loading = true;
    final ad = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: _size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _bannerAd = ad as BannerAd;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _loading = false;
              _bannerAd = null;
            });
          }
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ★ ここでも先にサイズを確保
    return SizedBox(
      width: _size.width.toDouble(),
      height: _size.height.toDouble(), // 250px を先取り
      child: _isAdLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : const SizedBox.expand(),
    );
  }
}
