# Dytava Mobile (Flutter / Android)

Ứng dụng Flutter hiện dùng thuật toán và luồng xử lý được port từ bản web bằng Dart native, chạy trên isolate.

Chọn A/B (XLSX/CSV/TSV/TXT/JSON) → xem trước/chọn sheet → đề xuất và xác nhận cấu hình → ghép theo khóa, căn chỉnh chuỗi hoặc vị trí → bảng A/B đồng bộ cuộn, lọc và xem chi tiết → CSV/JSON preview và lưu cục bộ.

[Hướng dẫn port web → mobile](../docs-dytava/guides/MOBILE_WEB_PARITY.md) mô tả thuật toán, các khác biệt có chủ đích để sửa lỗi web, test parity và giới hạn. Bộ flow mẫu cũ vẫn có qua injection; OCR thật, PDF và pipeline 1 GB chưa bật.

## Chạy trên macOS bằng VS Code, không cài Android Studio

**Hướng dẫn chính thức của repository:** [RUN_PROJECT.md — macOS + VS Code + Android Emulator CLI](../docs-dytava/guides/RUN_PROJECT.md#4-chạy-flutter-mobile-bằng-vs-code--android-emulator-không-android-studio).

Không cần điện thoại vật lý. Cài Android SDK **Command-line Tools cho Mac ARM**, Android Emulator và system image ARM64. Chỉ dẫn dưới đây áp dụng **sau khi đã cài và tối ưu AVD `Pixel_6a`** (`720×1600` HD+ @ `280dpi`, GPU `host` Metal) theo hướng dẫn đầy đủ.

**Terminal 1 — mở Android Emulator (`Pixel_6a`):**

```bash
emulator -avd Pixel_6a -gpu host
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
flutter build apk --release --split-per-abi
flutter build apk --release
flutter build apk --debug
```

Tại Home chọn **Bắt đầu so sánh**, chọn hai tệp hoặc thử dữ liệu mẫu. Bộ mẫu có các ô trùng, tương đương, khác biệt và một hàng thêm; diagnostic hai giá trị vẫn nhận A=`8.5`, B=`8,5`.

Các bản APK sau khi build nằm tại `mobile/build/app/outputs/flutter-apk/`:
- `app-armeabi-v7a-release.apk`: ~27.3 MB (`28,639,883` bytes, SHA-256: `7298f8bcaf84a3a0448007b49999bb785bd04bd2e6c1b4470151e2f176eb8774`)
- `app-arm64-v8a-release.apk`: ~33.4 MB (`35,003,249` bytes, SHA-256: `a14cfa2fc36c294b62293642ea7317da1e605e7759bdc640da8b62f019f50cd3`)
- `app-x86_64-release.apk`: ~35.4 MB (`37,154,072` bytes, SHA-256: `923bddb7b88efc8f629e53c6789446054a21f60cc055159131b40986fcf1f403`)
- `app-release.apk` (Universal APK): ~88.3 MB (`92,614,380` bytes, SHA-256: `527ccf56b1afb5e62b7c2931d0c7ba75d707b73ca711f5611099dd9acedd21bf`)
- `app-debug.apk`: `build/app/outputs/flutter-apk/app-debug.apk` (`226,165,232` bytes, SHA-256: `02d3fae8e97d5510a8581bd109609c405f63964ecfe5e11549413f45f6c245fa`)

## Branding

Theme và typography nằm trong `lib/design_system/`. `DytavaAsset` dùng
`flutter_svg` để hiển thị logo, functional icons và Illustration Library từ
`assets/dytava/`, đã khai báo trong `pubspec.yaml`. Bốn trạng thái kết quả
có badge, màu và illustration riêng theo branding chính thức.

Tài nguyên thương hiệu chuẩn được lưu trong thư mục `../branding/`. Từ gốc monorepo, chạy `npm run branding:sync` khi kho `branding/` thay đổi. Script `scripts/sync-branding.js` đã được tối ưu để chỉ đồng bộ đúng **101 file SVG** thực tế sử dụng trên mobile (`2` brand SVGs, `6` file format SVGs, `67` glyph icon SVGs, `26` illustration SVGs), loại bỏ hoàn toàn các ảnh raster (`png_4k`, `png_512`, `png_128`, `preview_768`), icon variant trùng lặp (`svg/color`, `svg/outline`) và font không sử dụng (`Plus Jakarta Sans`, `cupertino_icons`), giúp giảm dung lượng `mobile/assets/dytava/` từ `61 MB` xuống `732 KB`.

## Scope thiết kế mở rộng

[Quyết định 12/11/2026](../docs-dytava/decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) yêu cầu **1 GB/source**, **PDF diff hợp nhất A/B** và **PDF template Dytava**; [Report spec](../docs-dytava/specs/report/README.md) định nghĩa hai đầu ra. Đây là yêu cầu phải triển khai/kiểm thử, chưa là khả năng hiện tại. Mobile đã nhập tệp thật và tạo/lưu CSV/JSON; chưa có pipeline 1 GB hoặc PDF.

## So sánh workbook — 20/11/2026

Đối chiếu tất cả worksheet, gồm sheet ẩn/rỗng; tự ghép tên có nghĩa rồi cấu trúc, chỉ yêu cầu chọn cặp chưa rõ. Tên mặc định Sheet1/Sheet2 không làm căn cứ identity. Kết quả có Tất cả/từng cặp; đổi phạm vi xem không chạy lại. Ảnh Place in Cell được so bytes qua metadata/richData/relationships; nội dung chưa resolve giữ UNRESOLVED. Chưa so pixel/OCR/thumbnail ảnh, ảnh nổi chỉ có cảnh báo. Chi tiết tại [đặc tả workbook](../docs-dytava/specs/engine/05_workbook_mapping_and_cell_content.md).

## Giao diện Dytava từ Figma — 22/11/2026

Mobile dùng [thiết kế Dytava](https://www.figma.com/design/rFnyuWVIqLEw3YQUAuElNk/Dytava?node-id=1-23): nền `#F5F8F6`, xanh `#107C41` / `#185C37`, font Inter được đóng gói cục bộ. Logo, minh họa và icon tham chiếu được lưu tại `assets/dytava/figma/`; giấy phép Inter tại `assets/fonts/Inter-OFL.txt`.

Các màn hình được thay: launch (`19:1003`), Home (`1:23`), nhập tệp (`1:90`), preview (`47:30`), cấu hình nâng cao (`47:38`, `47:50`), tiến trình (`1:114`), kết quả (`1:37`), chi tiết (`1:66`), xuất báo cáo (`19:940`), lịch sử (`19:907`), cài đặt (`47:70`) và review OCR mẫu (`47:78`). Navigation bar, Comparison Rail và dashboard kết quả cũ không còn trong luồng ứng dụng.

Quick Compare tự phân tích hai nguồn, chạy khi đề xuất có độ tin cậy cao và chuyển sang review khi chưa chắc chắn. Advanced giữ khả năng chọn sheet/cột, ghép hàng theo vị trí/khóa/chuỗi, loại tác vụ và quy tắc từng cột. Kết quả mặc định là danh sách thay đổi, có thể chuyển sang bảng A/B, lọc toàn workbook/từng sheet và xem cả các ô tương đương hoặc giống nhau.

Nội dung dùng dữ liệu và khả năng thật của mobile: lịch sử chỉ có phiên trong bộ nhớ, xuất CSV/JSON, OCR vẫn là dữ liệu mẫu. Không hiển thị lịch sử, PDF/XLSX export hoặc lưu mặc định lâu dài như tính năng đã triển khai chỉ vì prototype có minh họa. Layout co giãn ở 320–600dp và hỗ trợ chữ 200%; animation launch/progress tôn trọng cài đặt giảm chuyển động.
