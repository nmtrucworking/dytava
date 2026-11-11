---
platform: Flutter/Dart — Android P0 / iOS P1
version: 0.1.0-DRAFT
updated: 2026-11-11
app_name: Dytava
---
# Dytava / ExcelCompare — mô tả đề tài

Đề bài gốc: **So sánh 02 file Excel**, bao gồm phát hiện điểm giống/khác, thống kê, chỉ rõ vị trí khác nhau và **đọc từ file hình ảnh chụp**. Yêu cầu bổ sung: đóng gói thành file cài đặt. Ghi chú học phần hiện có: báo cáo giữa kỳ bằng slide, chấm trực tiếp buổi thứ 10; lịch ngày cụ thể cần xác nhận riêng.

## Bối cảnh và mục tiêu

Hai tệp có thể trùng tên nhưng khác nội dung. Ứng dụng giúp chọn hai nguồn, đọc dữ liệu với provenance, xác nhận mapping/policy và trình bày sai khác có thể truy vết. Tên tệp không phải identity, raw text không tự thành số và số Excel đã mất biểu diễn không được suy đoán phục hồi.

## Baseline và phạm vi giao

Baseline kỹ thuật hiện hành là Flutter UI + application use cases + Pure Dart domain; adapters/file access/Drift là infrastructure. Android P0 trước, iOS P1 sau. Mã Web/server trong monorepo là implementation riêng, không thay bằng chứng device Flutter.

| Yêu cầu | Phạm vi thiết kế / điều kiện nghiệm thu |
| --- | --- |
| Chọn hai nguồn A/B và preview | Input Contract, raw types/provenance và validation của đúng snapshot |
| Đọc bảng | Kế hoạch P0 XLSX/CSV/TSV/JSON; mỗi adapter phải qua PoC/corpus, không tuyên bố đã hỗ trợ chỉ từ danh sách |
| So sánh/thống kê/chỉ vị trí khác | Core semantic policy + mapping/key/direction đã xác nhận; báo cáo có evidence |
| Đọc ảnh chụp | Bắt buộc theo đề bài gốc; baseline Flutter xếp OCR ở P2. INP-ADR-002 phải chốt với người phụ trách trước xác lập phạm vi nghiệm thu, chưa được bỏ yêu cầu |
| File cài đặt | Android signed APK/AAB theo kênh giao; iOS P1 có signing/device gates riêng. Chưa có evidence build/release trong đợt tài liệu |

## Functional requirements

Input nhận artifact read-only, kiểm tra format/limits, chọn scope/header, giữ raw/null/formula/provenance và chỉ mở mapping khi A/B hợp lệ. Comparison tách mapping và policy khỏi ImportConfig, không tự đoán key/locale. EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED là kết quả comparison, không là datatype.

A là baseline/B là bản mới hay cho đảo chiều, số sheet, header defaults, device limits, parser lựa chọn, xác nhận dtype/key và retention vẫn là quyết định mở trong [Input decision register](../specs/input/README.md#decision-register). Không coi giá trị fixture là phê duyệt sản phẩm.

## Non-functional requirements

Offline-first và read-only; không tự upload, execute macro hay truy cập linked resources. Validation fail closed, có cancellation/cleanup và recheck khi process chết hoặc mất quyền. Hiệu năng/ZIP/image limits cần benchmark thiết bị thật; không dùng con số chưa đo như cam kết.

## UI/UX và tài liệu thực thi

Luồng dự kiến: chọn A/B → cấu hình/preview/review → mapping/key/policy/direction → comparison → chi tiết sai khác/thống kê → export. OCR cần ảnh/geometry và manual review; trạng thái mỗi nguồn hiển thị độc lập. Input PREVIEW_READY của A không có nghĩa phiên đã sẵn sàng.

Nguồn đặc tả: [Input](../specs/input/README.md), [Flutter Master](EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md), [Core](EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md), [build/release](EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md). Đây là mô tả thiết kế DRAFT; completion của tài liệu không chứng minh các yêu cầu ứng dụng đã triển khai.
