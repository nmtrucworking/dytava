# Dytava Mobile

Ứng dụng Flutter thử nghiệm so sánh hai giá trị bằng `excelcompare_core`.
Hiện chưa nhập Excel/CSV hoặc xuất báo cáo.

## Chạy và kiểm tra

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

## Branding

Theme và typography nằm trong `lib/design_system/`. `DytavaAsset` dùng
`flutter_svg` để hiển thị logo, functional icons và Illustration Library từ
`assets/dytava/`, đã khai báo trong `pubspec.yaml`. Bốn trạng thái kết quả
có badge, màu và illustration riêng theo branding chính thức.

Từ gốc monorepo, chạy `npm run branding:sync` khi kho `branding/` thay đổi.
Chỉ dùng SVG trong runtime, không giải mã các ảnh PNG 4K của thư viện.

## Scope thiết kế mở rộng

[Quyết định 12/11/2026](../docs-dytava/decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) yêu cầu **1 GB/source**, **PDF diff hợp nhất A/B** và **PDF template Dytava**; [Report spec](../docs-dytava/specs/report/README.md) định nghĩa hai đầu ra. Đây là yêu cầu phải triển khai/kiểm thử, chưa là khả năng hiện tại. Mobile vẫn là PoC so sánh hai giá trị, chưa nhập tệp hoặc xuất report.
