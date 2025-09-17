import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../settings_manager.dart';

class AdBanner extends StatefulWidget {
  final String screenName;

  const AdBanner({super.key, required this.screenName});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> with SingleTickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _loading = false;

  AnchoredAdaptiveBannerAdSize? _anchoredSize; // 端末幅に最適化された高さを取得
  late final AnimationController _placeholderCtrl;

  @override
  void initState() {
    super.initState();
    _placeholderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

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
      final media = MediaQuery.of(context);
      final width = media.size.width.truncate();
      final orientation = media.orientation;
      size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        orientation,
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

    // ★実際に使うユニットIDをログ
    debugPrint('[AdMob] ${Platform.isIOS ? "iOS" : "Android"} '
        '${widget.screenName} -> $adUnitId  (kReleaseMode=$kReleaseMode)');

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
            _placeholderCtrl.stop();
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('広告読み込み失敗: code=${error.code}, message=${error.message}');
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _loading = false;
              _bannerAd = null;
            });
            _placeholderCtrl
              ..reset()
              ..forward();
          }
        },
      ),
    );

    ad.load();
  }

  String _resolveAdUnitId() {
    // デバッグは常にGoogle公式のテストID
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Android テストID
          : 'ca-app-pub-3940256099942544/2934735716'; // iOS テストID
    }

    // ここからリリースビルド（本番）
    if (Platform.isAndroid) {
      switch (widget.screenName) {
        case 'calendar':
          return 'ca-app-pub-3331079517737737/2576446816';
        case 'record':
          return 'ca-app-pub-3331079517737737/9588577724';
        case 'settings':
          return 'ca-app-pub-3331079517737737/3704893323';
        case 'graph':
          return 'ca-app-pub-3331079517737737/2942847126';
        case 'album': // ← 追加：アルバム画面(Android)
          return 'ca-app-pub-3331079517737737/8226790329';
        default:
          return 'ca-app-pub-3331079517737737/2576446816';
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
          return 'ca-app-pub-3331079517737737/8642020070';
        case 'album': // ← 追加：アルバム画面(iOS)
          return 'ca-app-pub-3331079517737737/9348300304';
        default:
          return 'ca-app-pub-3331079517737737/1430886104';
      }
    }

 else {
      // ほぼ来ないが、未知プラットフォーム時の無害フォールバック（テストID）
      return 'ca-app-pub-3940256099942544/6300978111';
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _placeholderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SettingsManager.demoMode) return const SizedBox.shrink(); // ← ここ！
    final double reservedHeight =
    (_anchoredSize?.height ?? AdSize.banner.height).toDouble();

    final bool showAd = _isAdLoaded && _bannerAd != null;

    return SizedBox(
      width: double.infinity,
      height: reservedHeight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: showAd
            ? ClipRRect(
                key: const ValueKey('ad'),
                borderRadius: BorderRadius.circular(12),
                child: AdWidget(ad: _bannerAd!),
              )
            : _AdLoadingPlaceholder(
                key: const ValueKey('placeholder'),
                animation: _placeholderCtrl,
              ),
      ),
    );
  }
}

class _AdLoadingPlaceholder extends StatelessWidget {
  final Animation<double> animation;

  const _AdLoadingPlaceholder({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double t = animation.value;
        const double start = -1.05;
        const double end = 1.05;

        final double progress = t.clamp(0.0, 1.0);
        final double fadeIn = progress < 0.25
            ? Curves.easeOutCubic.transform(progress / 0.25)
            : 1.0;
        final double scale = progress < 0.25
            ? 0.94 + 0.06 * Curves.easeOutCubic.transform(progress / 0.25)
            : 1.0;

        final double shimmerPhase = progress <= 0.25
            ? 0.0
            : ((progress - 0.25) / 0.75).clamp(0.0, 1.0);
        final double current = start + (end - start) * shimmerPhase;

        final baseColor = cs.surfaceVariant.withOpacity(0.26);
        final highlight = Colors.white.withOpacity(0.28);

        return Opacity(
          opacity: fadeIn,
          child: Transform.scale(
            scale: scale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: baseColor),
                  if (shimmerPhase < 0.98)
                    Align(
                      alignment: Alignment(current, 0),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
