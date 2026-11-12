---
platform: Flutter/Dart — Android P0 / iOS P1
version: 0.2.0-DRAFT
updated: 2026-11-12
app_name: Dytava
---
# Dytava / ExcelCompare — mô tả đề tài

> **Phạm vi kỹ thuật được chốt:** [ADR register 11/11/2026](../decisions/ADR_REGISTER_P0_2026-11-11.md). OCR một ảnh/bảng có review được đưa vào Android P0; iOS P1. Chưa có bằng chứng runtime, APK hoặc giảng viên phê duyệt mức OCR tối thiểu.

Đề bài gốc: **So sánh 02 file Excel**, bao gồm phát hiện điểm giống/khác, thống kê, chỉ rõ vị trí khác nhau và **đọc từ file hình ảnh chụp**. Yêu cầu bổ sung: đóng gói thành file cài đặt. Ghi chú học phần hiện có: báo cáo giữa kỳ bằng slide, chấm trực tiếp buổi thứ 10; lịch ngày cụ thể cần xác nhận riêng.

> **Bổ sung 12/11/2026:** [EXP-ADR-001..003](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) chốt scope mở rộng **1 GB mỗi input** và **hai PDF output**. Không đổi PDF input hoặc semantics/OCR gates; chưa là implementation đã chạy.

## Bối cảnh và mục tiêu

Hai tệp có thể trùng tên nhưng khác nội dung. Ứng dụng giúp chọn hai nguồn, đọc dữ liệu với provenance, xác nhận mapping/policy và trình bày sai khác có thể truy vết. Tên tệp không phải identity, raw text không tự thành số và số Excel đã mất biểu diễn không được suy đoán phục hồi.

## Baseline và phạm vi giao

Baseline kỹ thuật hiện hành là Flutter UI + application use cases + Pure Dart domain; adapters/file access/Drift là infrastructure. Android P0 trước, iOS P1 sau. Mã Web/server trong monorepo là implementation riêng, không thay bằng chứng device Flutter.

| Yêu cầu | Phạm vi thiết kế / điều kiện nghiệm thu |
| --- | --- |
| Chọn hai nguồn A/B và preview | Input Contract, raw types/provenance và validation của đúng snapshot |
| Đọc bảng | Kế hoạch P0 XLSX/CSV/TSV, một nguồn ảnh PNG/JPEG; JSON chuyển P1; mỗi adapter phải qua PoC/corpus, không tuyên bố đã hỗ trợ chỉ từ danh sách |
| So sánh/thống kê/chỉ vị trí khác | Core semantic policy + mapping/key/direction đã xác nhận; báo cáo có evidence |
| Đọc ảnh chụp | Bắt buộc theo đề bài gốc; baseline cập nhật đưa OCR reviewed offline vào P0 theo INP-ADR-002. Mức OCR tối thiểu cần giảng viên xác nhận cho nghiệm thu |
| Input dung lượng lớn | Tối đa 1 GB/source theo NFR; streaming/private spill và resource/profile evidence, không kế thừa cap nhỏ |
| Report PDF | Một merged diff PDF cho cả A/B, format theo trạng thái; một PDF báo cáo theo template Dytava, theo Report spec |
| File cài đặt | Android signed APK/AAB theo kênh giao; iOS P1 có signing/device gates riêng. Chưa có evidence build/release trong đợt tài liệu |

## Functional requirements

Input nhận artifact read-only, kiểm tra format/limits, chọn scope/header, giữ raw/null/formula/provenance và chỉ mở mapping khi A/B hợp lệ. Comparison tách mapping và policy khỏi ImportConfig, không tự đoán key/locale. EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED là kết quả comparison, không là datatype.

Các lựa chọn A/B, sheet/scope, header, resource limits, parser, xác nhận dtype/key và retention đã được chốt trong [ADR register](../decisions/ADR_REGISTER_P0_2026-11-11.md) theo engineering baseline; PoC, schema migration và benchmark vẫn cần hoàn thành. Không coi giá trị fixture là phê duyệt sản phẩm.

## Non-functional requirements

Offline-first và read-only; không tự upload, execute macro hay truy cập linked resources. Validation fail closed, có cancellation/cleanup và recheck khi process chết hoặc mất quyền. Hiệu năng/ZIP/image limits cần benchmark thiết bị thật; không dùng con số chưa đo như cam kết.

## UI/UX và tài liệu thực thi

Luồng dự kiến: chọn A/B → cấu hình/preview/review → mapping/key/policy/direction → comparison → chi tiết sai khác/thống kê → export. OCR cần ảnh/geometry và manual review; trạng thái mỗi nguồn hiển thị độc lập. Input PREVIEW_READY của A không có nghĩa phiên đã sẵn sàng.

Nguồn quản lý yêu cầu hiện hành: [PRD](../product/PRD.md) — scope/personas/US; [SRS](../requirements/SRS.md) — FR; [NFR](../requirements/NFR.md) — chất lượng/metrics; [Architecture](../architecture/ARCHITECTURE.md) — module/flows. Contract Input ở [Input](../specs/input/README.md); ngữ nghĩa so sánh ở [Core](EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md); ký và build ở [release guide](EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md). [Master 2.2](EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md) chỉ là tham chiếu lịch sử cho các phần đã tách. [Report Export Spec](../specs/report/README.md) sở hữu layout/template và [Expanded acceptance](../testing/EXPANDED_SCOPE_ACCEPTANCE.md) sở hữu LARGE-TC-* kế hoạch. Toàn bộ đặc tả vẫn DRAFT, chưa chứng minh ứng dụng đã triển khai.
