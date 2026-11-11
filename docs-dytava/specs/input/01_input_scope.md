# Phạm vi và hợp đồng Input

Document ID: INP-001\
Version: 0.1.0\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 11/11/2026

## 1. Mục đích và phạm vi

Input bao gồm toàn bộ nguồn và cấu hình hệ thống tiếp nhận trước thuật toán comparison: bytes A/B, metadata, cấu trúc, physical types, provenance, ImportConfig và validation. Nhóm đặc tả này là DRAFT, chưa phê duyệt hay cam kết hỗ trợ runtime.

## 2. Thuật ngữ và định nghĩa

| Khái niệm | Định nghĩa |
| --- | --- |
| Raw Input | Bytes và metadata thực tế của artifact; không sửa |
| Input Configuration | Lựa chọn người dùng/profile để đọc và diễn giải cấu trúc |
| Parsed Input | SourceTable/Field/Row/SourceCell có provenance; Canonical Table Model ở tầng cấu trúc |
| CanonicalValue | Giá trị semantic đã normalization của Core, nằm sau Input |
| Source A/B | Hai slot nguồn độc lập; không slot nào tự là dữ liệu đúng hoặc bản mới |

EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED là comparison decisions. IMPORTING/FAILED/READY là trạng thái xử lý, không phải input datatype; state enum chính thức của draft tại INP-008.

## 3. Các thành phần dữ liệu

Một phiên so sánh có đúng hai nguồn A và B. Mỗi nguồn gắn một artifact đang được chọn; hai artifact có thể cùng tên hoặc cùng hash và vẫn có identity/side riêng. Artifact có thể chứa nhiều sheet/table; schema biểu diễn nhiều scopes nhưng số bảng cho phép trong một comparison còn mở (INP-ADR-003). Người dùng cung cấp file, chọn scope/header/profile; hệ thống giữ bytes/types/locations; inference chỉ đề xuất; policy xác nhận semantic rules.

| Thành phần | Nguồn định nghĩa |
| --- | --- |
| Artifact/metadata/access | INP-002 |
| Format/parser capability | INP-003 |
| Workbook/sheet/table/field/row | INP-004 |
| Cell/physical type/provenance | INP-005 |
| ImportConfig và binding policy | INP-006 |
| Validation/errors | INP-007 |
| Import state A/B | INP-008 |
| Tests và fixtures | INP-009 |
| OCR | INP-010 |

## 4. Quy tắc và ràng buộc

**INP-REQ-001–012** được quản lý duy nhất trong [README](README.md), quy tắc chi tiết có owner theo tài liệu; tránh chép nhiều định nghĩa cùng ID.

Nguồn hợp lệ khi đọc được đúng snapshot bytes, format/profile có capability đáp ứng chế độ yêu cầu, scope/header resolved, full parse đạt limits/schema/invariants, raw types/provenance được bảo toàn hoặc loss được xử lý, không còn ERROR/REVIEW blocker. Một nguồn hợp lệ chưa đủ cho toàn phiên.

Phạm vi kế hoạch theo Flutter 2.2: Android P0 XLSX/CSV/TSV/JSON flat records; iOS P1; formats P1 JSONL/NDJSON, XLS/XLSM/ODS; P2 PDF/image OCR, XML/HTML table/XLSB. Đây là kế hoạch adapter. Parser Dart/package thật phải có PoC/corpus; icon format không phải bằng chứng support. Đề bài đọc ảnh và lịch P2 còn mâu thuẫn, ghi INP-ADR-002.

## 5. Input / Output Contract

Input Subsystem tiếp nhận file → access/preflight → adapter → validated SourceTable snapshot + issues/capabilities. Core nhận raw evidence cùng ComparisonConfig/Policy đã xác nhận để normalize, align và compare. Input không tính thêm/xóa hàng, tương đương, thống kê diff hay report.

Điều kiện mở Mapping: A và B đều PREVIEW_READY với snapshot còn hiệu lực. Điều kiện bắt đầu Comparison: thêm table pairing, field mapping, key nếu dùng key alignment, policy compile/validation và direction explicit. A_TO_B nghĩa hàng chỉ ở B là thêm, chỉ ở A là xóa; B_TO_A đảo vai trò. Đây là ý nghĩa của lựa chọn explicit, chưa quyết định default hay UX đảo chiều.

Contract máy đọc: [5 schemas](schemas/), [manifest](fixtures/input_manifest.example.json), [config](fixtures/import_config.example.json), [expected tables](fixtures/source_tables.expected.json). Envelope manifest có schema_version, session_id và artifacts đúng hai side; từng artifact validate bằng schema riêng, cross-artifact rules do runtime validator.

## 6. Luồng xử lý

Select A/B độc lập → inspect và cấu hình → parse/preview/review → freeze hai InputSnapshot → Mapping/policy review → Comparison Job. Trình tự state/event cụ thể chỉ định nghĩa tại [INP-008](08_import_state_machine.md).

## 7. Edge Cases và Error Handling

File cùng tên không được trộn identity. Hash bằng nhau không tự skip comparison. Nguồn A READY/B lỗi phải chặn mapping. Cấu trúc không hỗ trợ, dữ liệu mơ hồ, mất quyền hoặc thay bytes phải báo theo INP-007; không âm thầm “sửa” dữ liệu để hợp lệ.

## 8. Security & Privacy

Read-only, offline-first; chỉ truy cập file được chọn. Không chạy macros/formulas/embedded links, không tự upload. Retention/copy strategy còn mở; giữ tối thiểu metadata và làm rõ lifecycle trước release. Chi tiết source lifecycle tại INP-002.

## 9. Acceptance Criteria

INP-TC-001–016 cho source/format, 017–025 cho structure/types, 026–030 config, 031–033 validation, 034–038 state, 039–040 OCR. Chỉ schema/fixture tests hiện có executable evidence; adapter/device behavior còn PLANNED theo [INP-009](09_acceptance_tests.md).

## 10. Open Questions

Tất cả quyết định mở nằm trong [decision register](README.md#decision-register). Không dùng giá trị fixture làm mặc định được phê duyệt. Trước APPROVED cần chốt A/B direction, OCR học phần, sheet cardinality, limits, header, numeric identifier policy, parser PoC, confirmation và retention.

## 11. References

[Documentation index](../../README.md), [Project Description](../../project/Project%20Description.md), [Flutter Master 2.2](../../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md).
