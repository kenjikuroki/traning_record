cat > ci_scripts/ci_pre_xcodebuild.sh <<'EOF'
#!/bin/bash
# pre-xcodebuild: xcodebuild 直前にも依存を準備（保険）
set -euo pipefail
echo "[CI] ==== pre-xcodebuild started ===="

REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# Flutter SDK（無ければ取得）
if [ ! -d "$REPO/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
fi
export PATH="$REPO/flutter/bin:$PATH"
flutter precache --ios

cd "$REPO" && flutter pub get
cd "$REPO/ios" && pod repo update && pod install

[ -f "$REPO/ios/Flutter/Generated.xcconfig" ] || { echo "[CI] NG: Generated.xcconfig missing"; exit 5; }
find "$REPO/ios" -name "*.xcfilelist" | sed 's#^#  - #'
echo "[CI] ==== pre-xcodebuild done ===="
EOF
