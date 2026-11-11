# ExcelCompare • Flutter Android P0 + iPhone/iOS P1

**Phiên bản tài liệu:** 2.2-FLUTTER-ANDROID-IOS-DESIGN, 11/11/2026.

**Trạng thái:** updated design + Dart core PoC + Flutter source demo skeleton; **không có APK/AAB/IPA đã biên dịch**.

### Tệp chính

- `EXCELCOMPARE_MASTER_ANDROID_IOS.docx`: bản tài liệu đầy đủ, cập nhật 2 nền tảng và các release gates.
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
