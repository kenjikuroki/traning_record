cat > ci_scripts/ci_post_clone.sh <<'EOF'
#!/bin/bash
# post-clone: リポジトリ取得直後に実行（依存を必ず用意）
set -euo pipefail
echo "[CI] ===== post-clone started ====="

REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
echo "[CI] REPO=$REPO"

# Flutter SDK
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"
flutter --version
flutter precache --ios

# 依存取得（Generated.xcconfig 生成）
cd "$REPO" && flutter pub get

# CocoaPods
cd "$REPO/ios" && pod repo update && pod install

# 確認
[ -f "$REPO/ios/Flutter/Generated.xcconfig" ] && echo "[CI] OK: Generated.xcconfig"
find "$REPO/ios" -name "*.xcfilelist" | sed 's#^#  - #'
echo "[CI] ===== post-clone done ====="
EOF
