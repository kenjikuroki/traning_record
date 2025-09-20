package com.yourname.ttrainingrecord

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // factoryId は Flutter 側の BigEarningAd(factoryId: "large_media") と一致させる
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "large_media",
            LargeMediaNativeAdFactory(this)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "large_media")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
