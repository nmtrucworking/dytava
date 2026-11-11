#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == "Darwin" ]] || { echo "iOS build requires macOS with Xcode" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Missing Xcode" >&2; exit 1; }
command -v flutter >/dev/null || { echo "Missing Flutter SDK" >&2; exit 1; }
[[ -d ios ]] || { echo "Generate native iOS project: flutter create --platforms android,ios ." >&2; exit 1; }
flutter pub get
flutter analyze
flutter test
echo "Configure Apple Team / Bundle ID / signing + provisioning before build."
flutter build ipa --release
echo "Inspect build/ios/archive and build/ios/ipa; sign/provision and distribute via TestFlight/App Store as applicable."
