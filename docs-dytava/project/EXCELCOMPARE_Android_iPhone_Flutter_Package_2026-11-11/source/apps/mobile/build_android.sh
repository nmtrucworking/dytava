#!/usr/bin/env bash
set -euo pipefail
command -v flutter >/dev/null || { echo "Missing Flutter SDK" >&2; exit 1; }
[[ -d android ]] || { echo "Generate native Android project: flutter create --platforms android,ios ." >&2; exit 1; }
flutter pub get
flutter analyze
flutter test
echo "Ensure Android release signing configured and validated."
flutter build apk --release --split-per-abi
flutter build appbundle --release
echo "Inspect build/app/outputs/flutter-apk and build/app/outputs/bundle/release"
