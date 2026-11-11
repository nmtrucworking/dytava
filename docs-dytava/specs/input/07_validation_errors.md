# Kiểm tra đầu vào và registry lỗi

> **ADR status 11/11/2026:** [INP-ADR-001..009 đã chốt](../../decisions/ADR_REGISTER_P0_2026-11-11.md) cho Android P0, gồm OCR có review. Các câu “OPEN”, “OCR P2” hoặc “chưa quyết định” của baseline 0.1.0 khi xung đột là lịch sử; schema và test implementation vẫn DRAFT/PLANNED.

Document ID: INP-007\
Version: 0.1.0\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 11/11/2026

## 1. Mục đích và phạm vi

Nguồn duy nhất định nghĩa mã lỗi Input. File parse thành công chưa đủ: phải kiểm tra integrity, schema, invariants, limits và review trước khi cấp InputSnapshot. Mọi quy tắc trong nhóm này đang DRAFT.

## 2. Thuật ngữ và định nghĩa

Severity: INFO (bằng chứng), WARNING (không chặn, có thông tin mất mát không ảnh hưởng mode yêu cầu), REVIEW (cần xác nhận/cấu hình), ERROR (attempt thất bại). retryable không đồng nghĩa tự retry. Lỗi Input là chẩn đoán pipeline, không phải kết quả comparison UNRESOLVED.

## 3. Các thành phần dữ liệu

ValidationIssue contract:

```text
{code: INP-ERR-nnn, severity: INFO|WARNING|REVIEW|ERROR,
 stage: ACCESS|PREFLIGHT|PARSE|STRUCTURE|REVIEW|RESTORE,
 source_side, artifact_id, attempt_id, config_revision,
 source_ref?, message_key, remediation_key, retryable, safe_details?}
ValidationResult = {issues[], eof_validated, snapshot_id?, complete}
```

`safe_details` chỉ có metadata allowlist (ví dụ observed_count, limit_name), không raw text/URI. User message bản địa hóa theo message_key; code là khóa ổn định cho máy.

## 4. Quy tắc và ràng buộc

- **INP-RULE-030:** ERROR luôn chặn; REVIEW chặn tới khi xử lý. WARNING chỉ cho qua khi evidence đáp ứng mode yêu cầu. Không downgrade lỗi để đạt READY.
- **INP-RULE-031:** Kiểm tra limits trước và trong khi đọc, không chỉ tin metadata size. Profile bắt buộc quy định bytes, decompressed bytes, ZIP entries/ratio, rows/cells, text length, JSON depth và thời gian/cancel budget.
- **INP-RULE-032:** Không thay invalid bytes, truncate records, bỏ file parts hoặc sửa nguồn để vượt validation. Expected format mismatch có thể review; cấu trúc không an toàn luôn ERROR.

Resource profile fixture-only-small-v1 chỉ phục vụ validation fixtures nhỏ, không là benchmark Android. INP-ADR-004 đã chọn bootstrap profile android-p0-conservative-v1 (10MiB/source; 64MiB uncompressed XLSX; 2.000 ZIP entries; 100:1 ratio; 20.000 rows; 100 columns; 500.000 cells; 12MP image; watchdog 60s), nhưng các giới hạn chưa được benchmark, không phải throughput được bảo đảm. Adapter không resolve được profile phải fail closed (INP-ERR-011).

## 5. Input / Output Contract

| Code | Meaning / message_key | Severity và hướng khắc phục |
| --- | --- | --- |
| INP-ERR-001 | ACCESS_DENIED / input.access_denied | ERROR; chọn/cấp quyền đọc lại |
| INP-ERR-002 | NOT_FOUND / input.not_found | ERROR; chọn nguồn còn tồn tại |
| INP-ERR-003 | EMPTY_FILE / input.empty_file | ERROR; chọn file có bytes; không nhầm bảng zero rows |
| INP-ERR-004 | RESOURCE_LIMIT / input.resource_limit | ERROR; giảm scope hoặc đổi file/profile đã benchmark |
| INP-ERR-005 | READ_FAILED / input.read_failed | ERROR; retry sau khi provider sẵn sàng |
| INP-ERR-006 | PERMISSION_REVOKED / input.permission_revoked | ERROR; tái chọn file, không reuse snapshot không còn hợp lệ |
| INP-ERR-007 | FORMAT_MISMATCH / input.format_mismatch | REVIEW nếu nội dung hợp lệ, ERROR nếu không xác minh được; xác nhận format thực |
| INP-ERR-008 | UNSUPPORTED_FORMAT / input.unsupported_format | ERROR; đổi định dạng hoặc adapter đã chứng minh support |
| INP-ERR-009 | CORRUPTED_STRUCTURE / input.corrupted | ERROR; lấy lại file hợp lệ |
| INP-ERR-010 | PASSWORD_PROTECTED / input.password_protected | ERROR; cung cấp bản đọc được; không brute-force |
| INP-ERR-011 | CONFIG_INVALID / input.config_invalid | ERROR; sửa config/scope/profile/binding |
| INP-ERR-012 | REVIEW_REQUIRED / input.review_required | REVIEW; xác nhận header/dialect/scope/OCR hoặc cấu hình lại |
| INP-ERR-013 | CAPABILITY_LOSS / input.capability_loss | WARNING/REVIEW/ERROR theo mode; chọn adapter khác hoặc mode đủ evidence |
| INP-ERR-014 | PROVENANCE_INVALID / input.provenance_invalid | ERROR; adapter phải sửa địa chỉ, không tạo coordinate giả |
| INP-ERR-015 | SOURCE_CHANGED / input.source_changed | ERROR; chọn/reimport snapshot mới và bỏ review cũ |
| INP-ERR-016 | ENCODING_INVALID / input.encoding_invalid | ERROR; chọn encoding explicit và reparse strict |
| INP-ERR-017 | UNSAFE_CONTENT / input.unsafe_content | ERROR; từ chối ZIP bomb, path traversal, external entities/content execution |
| INP-ERR-018 | IMPORT_INTERRUPTED / input.import_interrupted | REVIEW; restart preflight sau process death, không tiếp tục từ READY giả |

Danh sách retryable phải theo nguyên nhân: read/provider tạm thời có thể retry; corruption/limits/unsupported chỉ retry khi điều kiện thay đổi. Với INP-ERR-013, thiếu dữ liệu cần thiết cho requested mode là ERROR; còn lựa chọn giảm mode là REVIEW; metadata ngoài mode là WARNING có losses. Không xóa evidence khi người dùng acknowledge warning.

Các mã ở bản nháp trước là alias để đọc tài liệu cũ, không được phát ra trong contract mới: INPUT_ACCESS_DENIED→001; INPUT_NOT_FOUND→002; INPUT_EMPTY→003; INPUT_SIZE_EXCEEDED/FORMAT_RESOURCE_LIMIT→004; INPUT_READ_FAILED→005; INPUT_PERMISSION_REVOKED→006; INPUT_FORMAT_MISMATCH/FORMAT_MISMATCH→007; FORMAT_UNSUPPORTED→008; FORMAT_CORRUPTED→009; FORMAT_PASSWORD_PROTECTED→010; FORMAT_STRUCTURE_AMBIGUOUS→012; FORMAT_CAPABILITY_UNAVAILABLE→013; INPUT_SOURCE_CHANGED→015; FORMAT_ENCODING_INVALID→016; FORMAT_UNSAFE_CONTENT→017. Tất cả số trên có prefix INP-ERR-.

## 6. Luồng xử lý

Access/metadata → sniff structural integrity → resource guard → config binding → full parse với limits tăng dần → schema/invariants → resolve review → chốt EOF/hash/snapshot. Lỗi phải gắn đúng attempt/revision; callback của attempt cũ bị bỏ qua. Handoff chỉ khi complete=true, eof_validated=true và không còn blocker.

## 7. Edge Cases và Error Handling

Provider trả size=null: đếm bytes stream; không thay bằng 0. Renamed ZIP: 009, không phải XLSX. Filename/MIME khác format nội dung hợp lệ: 007 REVIEW. Network-backed provider không truy cập được: 005, không tự download từ embedded URLs. Parser exception được map thành chẩn đoán có cấu trúc, không lộ stack/raw content. Cancel là event hợp lệ, không báo lỗi corruption.

## 8. Security & Privacy

Tắt XML external entities/DTD resolution, macro, external workbook links và active content. Không giải nén ra đường dẫn do ZIP entry tự chọn. Bảo vệ depth/size/time trong JSON/OCR/image decoding. Không gửi dữ liệu lên cloud trong preflight. Công thức CSV là text; export injection thuộc output subsystem nhưng raw data không được evaluate khi preview.

## 9. Acceptance Criteria

INP-TC-001–016 giữ tiêu chí access/format ban đầu; INP-TC-031 kiểm tra issue severity/gating; INP-TC-032 kiểm tra size unknown và giới hạn runtime; INP-TC-033 kiểm tra malicious payload và log redaction. Xem [registry](09_acceptance_tests.md).

## 10. Open Questions

INP-ADR-004 đã chốt profile bootstrap; cần benchmark máy thật và hạ trần nếu chưa đạt. Message catalog bản địa hóa và platform-specific exception mapping vẫn là implementation tasks trước release. Schema JSON hiện tại không serialize toàn bộ ValidationIssue; contract ứng dụng ở trên phải có integration tests khi triển khai.

## 11. References

[INP-002](02_source_artifacts.md), [INP-003](03_file_formats.md), [INP-008](08_import_state_machine.md), [acceptance registry](09_acceptance_tests.md).
