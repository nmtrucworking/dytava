# ExcelCompare — Android P0 / iPhone-iOS P1: Build & Release Guide

**Ngày:** 11/11/2026 • **Trạng thái:** hướng dẫn cấu hình/CI, chưa có APK/AAB/IPA thực tế.

## Mục tiêu và output

| Priority | Platform | Artifact | Channel |
| --- | --- | --- | --- |
| P0 | Android | `.apk` đã ký (direct install), `.aab` đã ký (Play) | direct APK / Google Play test tracks, production |
| P1 | iPhone/iOS | `.ipa` đã ký và provisioned; `.xcarchive` build archive | TestFlight/App Store, hoặc kênh Apple khác có quyền |

Cùng source Flutter/Dart cho business/UI, nhưng từng platform có native build, permissions, signing và acceptance tests. Export report Excel/CSV/JSON nằm trong ứng dụng, không tương đương export app.

## 1. Chuẩn bị Flutter trên macOS

```bash
flutter doctor -v
flutter devices
flutter create --platforms android,ios .
flutter pub get
flutter analyze
flutter test
```

Nếu đang ở thư mục source Flutter starter đi kèm: giải nén, vào `apps/mobile`, rồi chạy `flutter create --platforms android,ios .` để Flutter sinh dự án native Android/iOS. Lệnh này cần Flutter SDK. Không commit thông tin keystore/profile cá nhân. Flutter SDK, Xcode và Android SDK phải tương thích.

## 2. Android P0 — Signed APK / Play AAB

- Hoàn thiện Android `applicationId`, version, manifest permissions tối thiểu và Android release signing (`android/key.properties` hoặc secret manager; không commit file ký).
- Chạy golden fixtures, fuzz input, XLSX adapter tests, Android physical-device test rồi build.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

**Dự kiến:** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, các ABI khác, và `build/app/outputs/bundle/release/*.aab`. Kiểm tra exact filename/keystore bằng công cụ Gradle/Android, test cài APK thật; AAB tải lên Google Play Console internal track để xác minh việc phân phối. Dùng `flutter build apk --release` nếu cần một fat APK cho demo, đổi lại kích thước lớn hơn.

## 3. iOS P1 — IPA / TestFlight / App Store

Cần macOS, Xcode, Flutter iOS toolchain, Bundle ID không trùng, Apple Developer team, signing certificate/provisioning profile phù hợp. Khả năng chạy thử trên iPhone bằng tài khoản Apple cá nhân khác với phân phối TestFlight/App Store; kiểm tra quyền tài khoản trước khi phát hành.

```bash
flutter pub get
flutter analyze
flutter test
open ios/Runner.xcworkspace
flutter build ipa --release
```

**Dự kiến:** `build/ios/archive/*.xcarchive` và `build/ios/ipa/*.ipa` sau khi ký/đóng gói hoàn tất. Dùng Xcode để thiết lập Signing & Capabilities, chọn team, profile và verify bundle ID. Phân phối beta qua App Store Connect/TestFlight; release chính thức qua App Store, sau khi Apple review. Không đưa IPA cho bất kỳ iPhone nào rồi kỳ vọng cài được: Apple signing/provisioning/distribution restrictions áp dụng.

## 4. iOS/Android platform-parity requirements

| Area | Android P0 | iOS P1 |
| --- | --- | --- |
| File acquisition | SAF/document provider | iOS Files/iCloud provider |
| File persistence | scoped grants; handle revoked URI | sandbox, scoped access; file coordinator if needed |
| Export report | SAF/user-selected destination or share sheet | Files/Share Sheet or approved document export |
| Lifecycle | app background/process death | app background/suspension, iOS memory pressure |
| Release security | keystore, APK signature, Play App Signing | certificates, provisioning, entitlement review |
| QA | APK/AAB physical device + Play internal test | iPhone physical device + TestFlight |

**Không** dùng plugin hỗ trợ Android làm bằng chứng hoạt động trên iOS. Khi iOS integration chưa có, phần chức năng tương ứng phải disable rõ thay vì phát hành một ứng dụng sai kết quả.

## 5. Release acceptance

1. Các tests domain exact/equivalent/different/unresolved pass, không implicit cast identifier/locale.
2. Parity golden JSON report giống nhau giữa Android và iOS khi dùng cùng file hash + policy digest + engine version, sau khi bỏ timestamps.
3. Android: cài được APK trên thiết bị đích, AAB qua internal test; file permissions/read-only; export safe.
4. iOS: build signed IPA, cài/TestFlight trên iPhone thật, read Files/iCloud, share/export, xử lý khi quyền đổi.
5. Privacy/security: không có raw cell content trong telemetry, không gửi cloud nếu thiếu consent, binary secrets không nằm trong Git.
6. Chưa đánh giá thực nghiệm => ghi thiết kế/prototype, không claim production supported.

## 6. CI/CD split

- **PR gate** (Linux/macOS): Dart format/analyze/test, Flutter widget tests, security/dependency checks, golden fixtures.
- **Android release**: signed build trên runner phù hợp, artifact checksum, physical-device tests, upload Play internal track rồi staged rollout.
- **iOS release**: macOS runner với Xcode, signing secrets, `flutter build ipa`, validate/upload App Store Connect và TestFlight, physical-device feedback.
- Pin Flutter channel/version, dependencies, Xcode/AGP compatibility trước khi thiết lập pipeline; soạn release notes riêng cho từng OS.

## 7. Các giới hạn trong gói được cung cấp

Flutter starter được xây dựng dưới dạng **source skeleton**, chưa tích hợp file adapters, hoàn chỉnh UI, database, compiled binaries. Package core Dart là PoC chỉ hỗ trợ 5 semantic dtypes. Hiện môi trường tạo file không cài Flutter/Dart SDK hoặc macOS Xcode nên chưa chạy được `flutter build apk/appbundle/ipa` hay ký ứng dụng.

**Nguồn chính thức (kiểm tra 11/11/2026):**
- https://docs.flutter.dev/deployment/android
- https://docs.flutter.dev/deployment/ios
- https://docs.flutter.dev/platform-integration/ios/setup
