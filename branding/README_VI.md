# DYTAVA ICON VAULT 4K — v2.0

Bộ icon chính thức ở mức **bản dựng vector đề xuất** theo ảnh branding Dytava mới. Trong ảnh tham chiếu, logo có hai lớp cyan và tím, biểu đồ cột màu trắng và dấu xác nhận xanh; bộ mới tái dựng các yếu tố đó để triển khai dưới dạng tệp SVG/PNG độc lập. **Không khẳng định khôi phục chính xác path của logo gốc** khi chưa có Figma/AI/SVG source của người thiết kế.

## Thành phần

- **116 biểu tượng chức năng**, mỗi biểu tượng có 3 SVG: `color`, `outline`, `glyph`; cùng PNG 4096×4096, PNG 512×512, và glyph PNG 128×128.
- **18 biểu tượng định dạng tệp** (XLSX, XLS, CSV, TSV, JSON, JSONL, ODS, PDF, XML, HTML, TXT, PNG, JPG, WEBP, HEIC, XLSM, XLSB, MD), SVG + PNG 4096×4096.
- Logo: mark trong suốt, app icon xanh, app icon sáng/tối, biến thể một màu; wordmark SVG và PNG 4K. iOS 1024px opaque, Android adaptive foreground.
- 7 catalog theo loại, 1 poster 4K tổng quan, thư viện tìm kiếm offline trong `catalog/index.html`.
- `mobile/lib/design_system`: Dart theme, registry, ví dụ sử dụng; `mobile/pubspec_assets_snippet.yaml` hướng dẫn khai báo tài nguyên.

## Cấu trúc

```text
DYTAVA_Icon_Vault_4K_v2/
├── mobile/
│   ├── assets/dytava/
│   │   ├── brand/svg/
│   │   ├── brand/png_4k/
│   │   ├── icons/svg/color/
│   │   ├── icons/svg/outline/
│   │   ├── icons/svg/glyph/
│   │   ├── icons/png_4k/
│   │   ├── icons/png_512/
│   │   ├── icons/png_128/
│   │   ├── icons/manifest.json
│   │   ├── formats/svg/
│   │   ├── formats/png_4k/
│   │   ├── adaptive/
│   │   └── design_tokens.json
│   ├── lib/design_system/
│   └── pubspec_assets_snippet.yaml
├── catalog/index.html
├── catalog/*_4k.png
├── documentation/
└── SHA256SUMS.txt
```

## Hướng dẫn cho Flutter

1. Sao chép thư mục `mobile/assets/dytava/` trong bộ assets vào `mobile/assets/dytava/` của repository Flutter. Tương tự sao chép thư mục `mobile/lib/design_system/`.
2. Thêm các thư mục assets vào phần `flutter:` đang tồn tại trong `pubspec.yaml` theo mẫu `mobile/pubspec_assets_snippet.yaml`. **Không tạo 2 khóa `flutter:`**.
3. Để dùng SVG, cài `flutter_svg` với phiên bản tương thích SDK; kiểm tra tính tương thích thay vì khóa một version ngẫu nhiên.
4. Ví dụ:

```dart
SvgPicture.asset(DytavaIcons.compare, width: 24, height: 24);
SvgPicture.asset(DytavaIcons.colorTile('ocr'), width: 72, height: 72);
Image.asset('assets/dytava/icons/png_512/report.png', width: 48);
```

5. PNG 4K phù hợp thiết kế, xuất bản và marketing. **Không tự động thêm toàn bộ thư mục PNG 4K vào Flutter runtime**: mỗi ảnh có 16.777.216 pixels, khi giải mã RGBA chiếm khoảng 64 MiB nếu không có downsampling. Với icon 24–72dp, SVG hoặc PNG 128/512 thực tế hơn.
6. Để đưa app icon lên launcher cần cấu hình Android/iOS native tương ứng. Bản iOS app icon `adaptive/ios-icon-1024.png` có nền kín; Android adaptive có foreground riêng và mã màu nền.

## Màu sử dụng

| Vai trò | Mã HEX |
|---|---|
| Primary | `#2563EB` |
| Secondary | `#3B82F6` |
| Purple | `#8B5CF6` |
| Cyan | `#06B6D4` |
| Green | `#10B981` |
| Amber | `#F59E0B` |
| Red | `#EF4444` |
| Background | `#F3F4F6` |
| Border | `#E5E7EB` |
| White | `#FFFFFF` |

Bốn trạng thái: `EXACT` = xanh lá; `EQUIVALENT` = xanh dương; `DIFFERENT` = đỏ; `UNRESOLVED` = cam. Phải kèm biểu tượng và nhãn, không chỉ màu sắc.

## Kiểm tra chất lượng

- Mỗi PNG 4K được xuất **trực tiếp từ SVG** ở kích thước đích 4096×4096, không upscale từ PNG 128/512.
- SVG là vector độc lập; PNG 4K icon có alpha thật ở các góc ngoài khung.
- Có checksum SHA-256 và manifest tên/path để kiểm kê.
- Font Inter/Roboto chỉ được tham chiếu trong SVG logo (không kèm tệp font).
- Icon OCR/XLSB/sync biểu diễn phạm vi giao diện, không khẳng định tất cả đã được tích hợp hoặc kiểm thử trên thiết bị.
