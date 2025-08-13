// android/app/build.gradle.kts

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- key.properties を読み込み（app モジュール直下に置いた前提。別場所ならパスを調整） ---
val keystorePropertiesFile = file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.yourname.ttrainingrecord"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yourname.ttrainingrecord"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    // --- 署名設定（Release） ---
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                    ?: throw GradleException("key.properties に storeFile がありません")
                val storePasswordProp = keystoreProperties.getProperty("storePassword")
                    ?: throw GradleException("key.properties に storePassword がありません")
                val keyAliasProp = keystoreProperties.getProperty("keyAlias")
                    ?: throw GradleException("key.properties に keyAlias がありません")
                val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
                    ?: throw GradleException("key.properties に keyPassword がありません")

                // storeFile は app モジュールからの相対パスで OK（例: "my-release-key.keystore"）
                storeFile = file(storeFilePath)
                storePassword = storePasswordProp
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
            } else {
                println("warning: key.properties が見つかりません。Release 署名は未設定のままです。")
            }
        }
    }

    buildTypes {
        release {
            // 本番署名
            signingConfig = signingConfigs.getByName("release")

            // ★ shrinkResources エラー対策：R8(コード圧縮)とリソース縮小を両方 ON
            isMinifyEnabled = true
            isShrinkResources = true

            // R8/ProGuard 設定
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // デバッグは最適化OFFでOK
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
