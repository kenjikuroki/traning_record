package com.yourname.ttrainingrecord

import android.content.Context
import android.view.LayoutInflater
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin   // ← これがポイント（ネスト型）
//    GoogleMobileAdsPlugin.NativeAdFactory を実装する

class LargeMediaNativeAdFactory(private val context: Context)
    : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_large_media, null) as NativeAdView

        // View 紐付け
        adView.headlineView     = adView.findViewById(R.id.ad_headline)
        adView.mediaView        = adView.findViewById(R.id.ad_media)
        adView.bodyView         = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.iconView         = adView.findViewById(R.id.ad_app_icon)
        adView.advertiserView   = adView.findViewById(R.id.ad_advertiser)

        // 値セット
        (adView.headlineView as? android.widget.TextView)?.text = nativeAd.headline
        adView.mediaView?.setMediaContent(nativeAd.mediaContent)
        (adView.bodyView as? android.widget.TextView)?.text = nativeAd.body
        (adView.callToActionView as? android.widget.Button)?.text = nativeAd.callToAction
        (adView.iconView as? android.widget.ImageView)?.setImageDrawable(nativeAd.icon?.drawable)
        (adView.advertiserView as? android.widget.TextView)?.text = nativeAd.advertiser

        adView.setNativeAd(nativeAd)
        return adView
    }
}
