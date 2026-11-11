# DYTAVA Illustration Library 4K — v1.0

Bộ illustration vector **tự tạo**, theo bộ màu Dytava mới do người dùng cung cấp: primary #2563EB, secondary #3B82F6, purple #8B5CF6, cyan #06B6D4, green #10B981, amber #F59E0B, red #EF4444.

## Nội dung

- **39 artwork tỉ lệ 1:1**: SVG chỉnh sửa và PNG **4096 × 4096 px** nền trong suốt.
- **8 artwork tỉ lệ 16:9**: SVG chỉnh sửa và PNG **4096 × 2304 px** nền trong suốt.
- Preview PNG kích thước nhỏ để duyệt và tích hợp mobile.
- Trang catalog offline `catalog/index.html` (tìm kiếm theo tên/danh mục, link SVG/PNG từng hình).
- Catalog theo 9 nhóm và bản tổng quan `catalog/DYTAVA_ILLUSTRATIONS_OVERVIEW_4K.png`.
- `manifest.json` chứa tên, danh mục, vị trí sử dụng, đường dẫn file và tỉ lệ.
- `mobile/lib/design_system/dytava_illustrations.dart` gồm tất cả các asset constants cho Flutter.

## Nhóm nội dung

| Danh mục | Số lượng | Ví dụ |
|---|---:|---|
| Empty | 12 | Empty files, empty history, no search results, empty OCR, empty mapping |
| Success | 3 | Import, compare, report export |
| Comparison statuses | 4 | EXACT / EQUIVALENT / DIFFERENT / UNRESOLVED |
| Error & warning | 8 | Revoked access, unsupported format, memory limit, offline |
| Processing | 7 | Import, compare, OCR, mapping, normalize, report, cloud optional |
| Security | 3 | Local processing, encrypted data, user consent |
| Education | 2 | Guide, large datasets |
| Onboarding | 6 | Import, mapping, policy, compare, report, privacy |
| Hero | 2 | Get started, empty workspace |

## Copy vào repository

Sao chép `mobile/assets/dytava/illustrations/` của gói vào `mobile/assets/dytava/illustrations/` của dự án Flutter.
Sao chép file `mobile/lib/design_system/dytava_illustrations.dart` vào `mobile/lib/design_system/` dự án.
Trong `mobile/pubspec.yaml`, **gộp** các đường dẫn `flutter.assets` từ `mobile/pubspec_assets_snippet.yaml` vào khóa `flutter:` đang có. Không tạo thêm khóa `flutter:` thứ hai.

Cài thư viện SVG bằng `flutter pub add flutter_svg` (công cụ chọn phiên bản phù hợp với SDK hiện tại). Sau đó:

```dart
import 'package:flutter_svg/flutter_svg.dart';
import 'design_system/dytava_illustrations.dart';

SvgPicture.asset(
  DytavaIllustrations.emptyComparisons,
  width: 240,
  height: 240,
  semanticsLabel: 'Chưa có phiên so sánh',
);
```

## Lưu ý kỹ thuật

- Tệp 4K phù hợp để xuất ảnh, marketing, hoặc resize khi cần. PNG square 4096² RGBA giải mã có thể tiêu tốn **64 MiB RAM/ảnh**; không load toàn bộ kho PNG 4K trong Flutter runtime.
- Ưu tiên **SVG**; fallback sang `preview_768` nếu widget cần bitmap. Android/iOS cần test rendering của `flutter_svg` với dự án thực tế.
- Các illustrations không có câu chữ bên trong artwork để hỗ trợ localization và accessibility. Cần đặt `semanticsLabel`/`Semantics` ở UI.
- Tệp chưa có việc đo kiểm nghiệm thu Flutter runtime trên thiết bị thực. `status-cloud` và OCR là hình minh họa giao diện, **không chứng minh đã tích hợp tính năng cloud/OCR**.
- Mọi PNG 4K được **render trực tiếp từ hình vector SVG**; không phóng ảnh thumbnail lên 4K.
- Ảnh vector này **phỏng theo hệ màu và ngôn ngữ hình dạng** từ ảnh tham chiếu, không giả định là path logo gốc từ Figma.
- SVG và PNG xuất bản không chứa tệp font; assets trong gói được tạo mới cho Dytava.

## Verification

Chạy `python tools/verify_assets.py` tại root thư mục giải nén để kiểm tra số lượng, kích thước, kênh alpha, XML và checksum. Xem `SHA256SUMS.txt` cho hash của mỗi file.
