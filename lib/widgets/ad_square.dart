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

  final String adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2177585250'
      : 'ca-app-pub-3940256099942544/3001886131';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoaded && !_loading) _loadAd();
  }

  void _loadAd() {
    _loading = true;
    final ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.mediumRectangle,
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
          _isAdLoaded = false;
          _loading = false;
          ad.dispose();
          debugPrint('BannerAd failed to load: $err');
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
