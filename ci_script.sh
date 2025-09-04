#!/bin/sh

# Flutterのパッケージ（pubspec.yamlに書かれたもの）を取得します
flutter pub get

# iOSプロジェクトがあるiosディレクトリに移動します
cd ios

# CocoaPodsの依存関係（Podfileに書かれたもの）をインストールします
pod install

# スクリプトが正常に終了したことを示します
exit 0