import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  AnchoredAdaptiveBannerAdSize? _anchoredSize; // 端末幅に最適化された高さを取得

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && !_isAdLoaded) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    _loading = true;

    AnchoredAdaptiveBannerAdSize? size;
    try {
      final width = MediaQuery.of(context).size.width.truncate();
      size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width,
      );
    } catch (_) {
      size = null;
    }
    if (!mounted) return;

    setState(() {
      _anchoredSize = size;
    });

    final String adUnitId = _resolveAdUnitId();

    final ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: _anchoredSize ?? AdSize.banner,
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
          debugPrint('広告読み込み失敗: $error');
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

  String _resolveAdUnitId() {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Google公式テストID
          : 'ca-app-pub-3940256099942544/2934735716'; // Google公式テストID
    }

    if (Platform.isAndroid) {
      switch (widget.screenName) {
        case 'calendar':
          return 'ca-app-pub-3331079517737737/2576446816';
        case 'record':
          return 'ca-app-pub-3331079517737737/9588577724';
        case 'settings':
          return 'ca-app-pub-3331079517737737/3704893323';
        case 'graph':
          return 'ca-app-pub-3331079517737737/2942847126'; // ← Graph用Android本番ID
        default:
          return 'ca-app-pub-3940256099942544/6300978111';
      }
    } else if (Platform.isIOS) {
      switch (widget.screenName) {
        case 'calendar':
          return 'ca-app-pub-3331079517737737/1430886104';
        case 'record':
          return 'ca-app-pub-3331079517737737/6962414382';
        case 'settings':
          return 'ca-app-pub-3331079517737737/8271626623';
        case 'graph':
          return 'ca-app-pub-3331079517737737/5566778899'; // ← Graph用iOS本番ID
        default:
          return 'ca-app-pub-3940256099942544/2934735716';
      }
    } else {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double reservedHeight =
        (_anchoredSize?.height ?? AdSize.banner.height).toDouble();

    return SizedBox(
      width: double.infinity,
      height: reservedHeight,
      child: _isAdLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : const SizedBox.expand(),
    );
  }
}
