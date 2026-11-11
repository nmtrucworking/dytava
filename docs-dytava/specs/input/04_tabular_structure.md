# Cấu trúc bảng và phạm vi dữ liệu

Document ID: INP-004\
Version: 0.1.0\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 11/11/2026

## 1. Mục đích và phạm vi

Định nghĩa SourceTable, Field, Row và preview mà adapter cung cấp trước normalization. Mô hình chứa được nhiều bảng; số bảng/sheet được phép trong sản phẩm còn chờ INP-ADR-003. Không suy ra hỗ trợ nhiều sheet từ khả năng biểu diễn của schema.

## 2. Thuật ngữ và định nghĩa

Workbook là container XLSX; worksheet là sheet có tên gốc. Table là một scope có trường và các bản ghi, không nhất thiết là Excel structured table. Field có ID ổn định trong snapshot. Header là dữ liệu nhãn, không phải ID. Source record là vị trí record gốc trước khi lọc; row_count chỉ đếm data rows, không tính header.

## 3. Các thành phần dữ liệu

| Entity | Thuộc tính và ý nghĩa |
| --- | --- |
| SourceTable | `table_id`, `artifact_id`, `sheet_name`, `header_row`, `fields`, `row_count`, `source_range`, `capability`, `adapter`; `rows` tùy chọn khi streaming |
| Field | `field_id`, `source_index` (1-based, vị trí nguồn), `header_text` (null khi không header) |
| Row | `row_id`, `source_record` (1-based), `cells` theo thứ tự fields |
| Scope | Excel: sheet/range; CSV/TSV: first/last logical record; JSON: records_pointer; OCR: page |

`sheet_name=null` cho CSV/JSON/OCR; không tạo Sheet1 giả. `header_row` là số dòng worksheet hoặc logical record CSV, không phải physical line trong quoted multiline text; JSON dùng null. `source_range` giữ selection đã xác nhận, không đổi nghĩa thành used range sau parse.

## 4. Quy tắc và ràng buộc

- **INP-RULE-017:** ID table/field/row phải duy nhất trong phạm vi chứa; ID không lấy từ nhãn header. Snapshot thay đổi phải invalidate mapping dựa trên ID cũ.
- **INP-RULE-018:** Một row có đúng số cells bằng fields; cells thiếu phải có kind `missing` với địa chỉ thật và `exists=false`. CSV ragged records bị từ chối ở draft profile, không tự pad/truncate.
- **INP-RULE-019:** Không tự fill merged cells xuống/cạnh. Giữ anchor; vùng merge và hidden flags phải có trong kết quả inspect/preview. Profile `review` chặn tới khi chọn cách xử lý. Không khai báo FULL_SEMANTIC nếu metadata bắt buộc cho chế độ yêu cầu bị mất.
- **INP-RULE-020:** Header trống/trùng giữ nguyên nhãn và có field ID riêng; đưa vào review nếu mapping theo nhãn không duy nhất. Không tự đổi nhãn thành tên nghiệp vụ.

Index worksheet, record và field bắt đầu từ 1. Excel range bao gồm hai đầu, phải trong giới hạn worksheet và đúng thứ tự. Header nằm trong scope; header không có thì dùng `header_row=null`. Scope CSV bao gồm header nếu có; last_record=null nghĩa tới EOF. Hidden include/exclude phải explicit và lưu trong config. Không dùng sampling preview làm bằng chứng toàn tệp hợp lệ.

## 5. Input / Output Contract

Schema chuẩn: [source_table](schemas/source_table.schema.json), [source_cell](schemas/source_cell.schema.json), [source_ref](schemas/source_ref.schema.json).

Adapter port đề xuất:

```text
sniff(bytes) -> candidate formats + evidence
inspect(artifact, limits) -> scopes + merges/hidden metadata + warnings
open(artifact, resolved ImportConfig) -> SourceTable descriptors
rows(table_id, attempt_id) -> Stream<Row>
close(attempt_id) -> released handles/temp resources
```

Descriptor chưa đọc hết có `row_count=null`; khi handoff phải có final count và chứng nhận EOF/validation của đúng attempt. Streaming không bắt buộc nhét toàn bộ rows vào RAM. Materialized fixture có rows; schema chỉ kiểm tra cấu trúc. Validator runtime kiểm tra ID uniqueness, cell count, source indices tăng dần, scope/header bounds, artifact linkage, tổng rows và count.

## 6. Luồng xử lý

Inspect → chọn scope → chọn/xác nhận header → đọc preview giới hạn → phát hiện merge/hidden/duplicate header → resolve config → full parse/stream validation → chốt SourceTable snapshot. Thay scope/header tạo revision mới và bỏ preview/mapping cũ.

## 7. Edge Cases và Error Handling

Sheet không tồn tại, range ngược, header ngoài scope: INP-ERR-011. Header cần xác nhận hoặc merge chưa có quyết định: INP-ERR-012 (REVIEW). Zero data rows không tự được xem là lỗi file zero-byte: giữ bảng rỗng, review theo khả năng comparison đã công bố. JSON array rỗng không suy ra fields: yêu cầu schema/profile hoặc review. Không âm thầm loại hàng trắng cuối bảng; scope và parser profile quyết định.

## 8. Security & Privacy

Giới hạn sheet/row/cell, độ dài field và preview từ resource profile đã benchmark. Không lưu preview có dữ liệu nhạy cảm trong logs. close phải chạy khi EOF, lỗi hoặc cancel.

## 9. Acceptance Criteria

INP-TC-017: header trùng không làm mất cột. INP-TC-018: merged/hidden không bị tự nhân bản hoặc bỏ qua. INP-TC-019: scope/header sai bị chặn. INP-TC-020: descriptor streaming và bảng materialized thống nhất count, ID và provenance. Expected chi tiết tại [registry](09_acceptance_tests.md).

## 10. Open Questions

INP-ADR-003 (số sheet/bảng); INP-ADR-005 (header mặc định). Cần extension schema riêng nếu sẽ serialize merges/visibility thay vì giữ inspect metadata trong adapter; phiên bản hiện tại không tuyên bố bao phủ toàn bộ workbook style model.

## 11. References

[INP-003](03_file_formats.md), [INP-005](05_data_types_provenance.md), [INP-006](06_input_configuration.md). Baseline Flutter Master 2.2 mục 06/07 trong [chỉ mục](../../README.md).
