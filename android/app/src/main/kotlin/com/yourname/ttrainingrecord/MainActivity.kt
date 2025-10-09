package com.yourname.ttrainingrecord

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {

    private var ageSignalsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // factoryId は Flutter 側の BigEarningAd(factoryId: "large_media") と一致させる
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "large_media",
            LargeMediaNativeAdFactory(this)
        )

        ageSignalsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.age_signals")
        ageSignalsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAgeSignals" -> {
                    val payload = AgeSignalsProvider.getAgeSignals(applicationContext)
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ageSignalsChannel?.setMethodCallHandler(null)
        ageSignalsChannel = null
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "large_media")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
