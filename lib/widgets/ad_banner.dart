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
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoaded && !_loading) _loadAd();
  }

  void _loadAd() {
    _loading = true;

    String adUnitId;
    if (kDebugMode) {
      adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    } else {
      if (Platform.isAndroid) {
        if (widget.screenName == 'calendar') {
          adUnitId = 'ca-app-pub-3331079517737737/2576446816';
        } else if (widget.screenName == 'record') {
          adUnitId = 'ca-app-pub-3331079517737737/9588577724';
        } else if (widget.screenName == 'settings') {
          adUnitId = 'ca-app-pub-3331079517737737/3704893323';
        } else {
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
          adUnitId = 'ca-app-pub-3940256099942544/2934735716';
        }
      } else {
        adUnitId = 'ca-app-pub-3940256099942544/6300978111';
      }
    }

    final ad = BannerAd(
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
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('広告の読み込みに失敗: $error');
          if (mounted) setState(() => _loading = false);
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
