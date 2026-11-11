# ExcelCompare • Flutter Android P0 + iPhone/iOS P1

**Phiên bản tài liệu:** 2.2-FLUTTER-ANDROID-IOS-DESIGN, 11/11/2026.

**Trạng thái:** updated design + Dart core PoC + Flutter source demo skeleton; **không có APK/AAB/IPA đã biên dịch**.

### Tệp chính

- `EXCELCOMPARE_MASTER_ANDROID_IOS.md`: bản Markdown Git-friendly.
- `ANDROID_IOS_BUILD_RELEASE_GUIDE.md`: hướng dẫn ký/export APK, AAB, IPA.
- `DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md`: quy tắc datatype/normalization/policy engine, platform parity.
- `comparison_policy.v2.example.json`: policy JSON độc lập Android/iOS.
- `source/`: Flutter UI demo skeleton + Pure Dart PoC module.
- `EXCELCOMPARE_PURE_DART_CORE_POC.zip`: ZIP gốc của prototype Dart.
- `flutter_architecture.png`, `acceptance_cases.json`: sơ đồ và test cases.

### Hướng dẫn sử dụng source

Giải nén bundle, vào `source/apps/mobile`, chạy `flutter create --platforms android,ios .` bằng Flutter SDK phù hợp để sinh hai thư mục native `android/` và `ios/`. Thiết lập signing ở từng nền tảng và chạy lệnh build trong hướng dẫn phát hành.

### Chưa thể tuyên bố

Chưa chạy Flutter/Dart tests, chưa ký hoặc build binary, chưa kiểm thử Android/iPhone thật; chưa có import Excel/CSV, đầy đủ dtype, policy compiler, OCR và báo cáo như sản phẩm cuối.


### Trạng thái sau khi tách Input (11/11/2026)

Điểm vào hiện hành: [docs index](../../README.md), [Input DRAFT](../../specs/input/README.md). Markdown Master/Core được sửa để trỏ tới contract mới; ZIP và source demo giữ nguyên snapshot 2.2; Markdown là nguồn tài liệu hiện hành. Code thực hành hiện hành nằm ở [packages/excelcompare_core](../../../packages/excelcompare_core/README.md) (đường dẫn từ repository root xem docs index); source trong bundle nếu có chỉ là lịch sử. Bản policy/acceptance trong thư mục này là snapshot, không phải nguồn biên soạn song song: [policy chuẩn](../comparison_policy.v2.example.json), [semantic test registry](../../examples/acceptance_cases.json), [Input test registry](../../specs/input/09_acceptance_tests.md).

Sơ đồ có sẵn tại [flutter_architecture.png](../../diagrams/flutter_architecture.png). SHA256SUMS.original.txt giữ manifest bundle cũ, có thể chứa đường dẫn không tồn tại trong checkout này; SHA256SUMS.txt mới kiểm tra các file thực có sau cập nhật. Nội dung snapshot không đồng nghĩa tính năng đã được triển khai.
