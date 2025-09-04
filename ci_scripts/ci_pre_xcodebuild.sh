cat > ci_scripts/ci_pre_xcodebuild.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "[CI] pre-xcodebuild start"
REPO="${CI_WORKSPACE:-${CI_PRIMARY_REPOSITORY_PATH:-$PWD}}"
[ -f "$REPO/pubspec.yaml" ] || REPO="$PWD"
[ -d "$REPO/flutter" ] || git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$REPO/flutter"
export PATH="$REPO/flutter/bin:$PATH"
flutter precache --ios
cd "$REPO" && flutter pub get
cd "$REPO/ios" && pod repo update && pod install
echo "[CI] pre-xcodebuild done"
EOF
chmod +x ci_scripts/ci_pre_xcodebuild.sh
git add ci_scripts/ci_pre_xcodebuild.sh
git commit -m "ci: add pre-xcodebuild fallback"
git push origin master
