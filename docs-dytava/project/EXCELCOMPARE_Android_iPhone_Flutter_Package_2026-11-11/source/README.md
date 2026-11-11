# ExcelCompare Flutter source starter — Android P0 / iOS P1

This is **source scaffold only** (no `android/` or `ios/` generated yet), containing an interactive two-value semantic comparison demo powered by the existing pure Dart PoC. It is **not the full ExcelCompare product** and includes **no signed APK/AAB/IPA**.

## Setup on macOS with Flutter + Xcode + Android SDK

```sh
cd apps/mobile
flutter create --platforms android,ios .
flutter pub get
flutter analyze
flutter run -d <device-id>
flutter build apk --release --split-per-abi
flutter build appbundle --release
flutter build ipa --release
```

The build commands require native platform setup and release signing. `flutter build ipa` requires macOS/Xcode. See `../../ANDROID_IOS_BUILD_RELEASE_GUIDE.md` in the bundle.

## Limitations

Only interactive value comparison UI; no file import, row matching, report export, OCR, policy compiler, or secured persistence. The core supports IDENTIFIER/FREE_TEXT/DECIMAL/BOOLEAN/PERCENTAGE only. The source was not compiled/tested in this artifact build environment.
