# Dytava Mobile (Flutter / Android)

Ứng dụng hiện có **nền tảng flow/activity với dữ liệu mẫu**, bám sát [8 activity](../docs-dytava/diagrams/MOBILE_ACTIVITIES.md) và [10 màn hình UI/UX](../docs-dytava/design/UI_UX_SPEC.md). Giao diện đã được nâng cấp bám theo hệ thống nhận diện Dytava Design System v2.0 (màu sắc, typography, status badges, icons, cards, stepper header) với đầy đủ logic xử lý, state/guards và 33 tests pass.

**Đọc trước:** [Mobile implementation — flow, cấu trúc, invariants, walkthrough và backlog](../docs-dytava/guides/MOBILE_IMPLEMENTATION.md).

Flow chạy được: chọn A/B độc lập → review scope/header (hoặc review từng ô OCR giả lập) → mapping 1:1 → xác nhận KEY/POSITIONAL, policy và direction → so sánh → summary/filter/detail → JSON preview. Có cancel/retry, stale callback guards, invalidation và đóng phiên.

**Chưa hỗ trợ tệp thật:** XLSX/CSV/TSV import, OCR ảnh thật, lưu/chia sẻ báo cáo, 1 GB, CSV và hai PDF vẫn chưa được bật. JSON hiện chỉ là preview fixture trong bộ nhớ, không là report production. Core semantic PoC cũ giữ trong diagnostic từ Home. Tests fixture không thay Android/device acceptance.

## Chạy trên macOS bằng VS Code, không cài Android Studio

**Hướng dẫn chính thức của repository:** [RUN_PROJECT.md — macOS + VS Code + Android Emulator CLI](../docs-dytava/guides/RUN_PROJECT.md#4-chạy-flutter-mobile-bằng-vs-code--android-emulator-không-android-studio).

Không cần điện thoại vật lý. Cài Android SDK **Command-line Tools cho Mac ARM**, Android Emulator và system image ARM64. Chỉ dẫn dưới đây áp dụng **sau khi đã cài và tạo AVD `Dytava_API35`** theo hướng dẫn đầy đủ.

**Terminal 1 — mở Android Emulator:**

```bash
emulator -avd Dytava_API35
```

**Terminal 2 — tại thư mục `mobile/`:**

```bash
flutter pub get
flutter devices
flutter run
```

Trong VS Code, bạn cũng có thể chọn **Flutter: Select Device → Android emulator → F5**. Nếu có nhiều thiết bị, dùng `flutter run -d <device-id>`.

**Nếu gặp `sdkmanager: command not found`:** kiểm tra `find "$HOME/Library/Android/sdk" "$HOME/Downloads" -name sdkmanager -type f 2>/dev/null`. Đặc biệt, nếu sdkmanager còn ở `~/Downloads/dytava-sdk-unpack/cmdline-tools/bin/` thì cần chuyển vào `~/Library/Android/sdk/cmdline-tools/latest/` **trước khi** thiết lập PATH. Xem mục 4.2–4.3 của hướng dẫn đầy đủ.

## Kiểm thử và build

Tại `mobile/`:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Tại Home chọn **So sánh mới (dữ liệu mẫu)** và làm theo walkthrough trong implementation guide. Bộ mẫu đủ 4 verdict và một `ROW_ADDED`; diagnostic hai giá trị vẫn nhận A=`8.5`, B=`8,5`. Bản APK debug thường nằm tại `build/app/outputs/flutter-apk/app-debug.apk`.

## Branding

Theme và typography nằm trong `lib/design_system/`. `DytavaAsset` dùng
`flutter_svg` để hiển thị logo, functional icons và Illustration Library từ
`assets/dytava/`, đã khai báo trong `pubspec.yaml`. Bốn trạng thái kết quả
có badge, màu và illustration riêng theo branding chính thức.

Tài nguyên thương hiệu chuẩn được lưu trong thư mục `../branding/`. Từ gốc monorepo, chạy `npm run branding:sync` khi kho `branding/` thay đổi. Chỉ dùng SVG trong runtime, không giải mã các ảnh PNG 4K của thư viện.

## Scope thiết kế mở rộng

[Quyết định 12/11/2026](../docs-dytava/decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) yêu cầu **1 GB/source**, **PDF diff hợp nhất A/B** và **PDF template Dytava**; [Report spec](../docs-dytava/specs/report/README.md) định nghĩa hai đầu ra. Đây là yêu cầu phải triển khai/kiểm thử, chưa là khả năng hiện tại. Mobile mới có flow trên fixture và JSON preview; chưa nhập tệp hoặc xuất report thật.
