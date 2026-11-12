# Acceptance registry và bằng chứng kiểm tra Input

> **ADR status 11/11/2026:** [INP-ADR-001..009 đã chốt](../../decisions/ADR_REGISTER_P0_2026-11-11.md) cho Android P0, gồm OCR có review. Các câu “OPEN”, “OCR P2” hoặc “chưa quyết định” của baseline 0.1.0 khi xung đột là lịch sử; schema và test implementation vẫn DRAFT/PLANNED.

Document ID: INP-009\
Version: 0.1.1 (documentation; wire schemas vẫn 0.1.0)\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 12/11/2026

## 1. Mục đích và phạm vi

Registry duy nhất cho Input, IDs INP-TC-001–040. Giữ số 001–016 từ các bản nháp ban đầu; mở rộng không dùng lại ID semantic TC-01. Planned cases dưới đây là tiêu chí triển khai, không phải adapter/device tests đã pass.

## 2. Thuật ngữ và định nghĩa

Contract verification kiểm tra schemas và ví dụ độc lập với adapter. Adapter acceptance kiểm tra parser/state thực; platform integration kiểm tra SAF/Files/lifecycle trên thiết bị. PASS ở một tầng không chứng minh tầng khác đã hoàn thành.

## 3. Các thành phần dữ liệu

[acceptance_registry.json](fixtures/acceptance_registry.json) chứa id, requirements, rules, owner_document, scenario, procedure, expected và status=PLANNED. Bảng dưới sinh cùng dữ liệu, checker phải kiểm tra consistency. [fixtures README](fixtures/README.md) giải thích bytes, expected cells và giới hạn bằng chứng.

## 4. Quy tắc và ràng buộc

**INP-RULE-040:** Chỉ cập nhật trạng thái test thực thi khi có runner/version, fixture hash, adapter/platform/version và output evidence. Không đổi PLANNED chỉ vì schema ví dụ validate được. Semantic tests vẫn ở docs-dytava/examples/acceptance_cases.json, có chỉ mục riêng; bundle tháng 11 là snapshot lịch sử.

## 5. Input / Output Contract

| ID | Requirement / rule | Dữ liệu và bước kiểm tra | Expected result |
| --- | --- | --- | --- |
| INP-TC-001 | INP-REQ-002, INP-REQ-001, INP-RULE-001 | Hai file cùng tên, bytes khác: Select A/B hai artifact tên trùng | artifact_id khác, sides A/B không bị ghi đè |
| INP-TC-002 | INP-REQ-007, INP-RULE-009 | File hỏng/không đọc được: Preflight nguồn không hợp lệ | FAILED với code đúng nguyên nhân, không snapshot |
| INP-TC-003 | INP-REQ-002, INP-RULE-005 | Quyền đọc thu hồi: Revoke trong parse rồi retry | 006, cleanup; phải recheck quyền trước parse lại |
| INP-TC-004 | INP-REQ-002, INP-REQ-011, INP-RULE-004 | Bytes nguồn bất biến: Hash trước/sau import và cancel | Hash/bytes nguồn không đổi |
| INP-TC-005 | INP-REQ-002, INP-REQ-012, INP-RULE-007 | Hash cùng bytes: Đọc lại cùng chuỗi bytes | SHA-256 xác định, không suy ra ý nghĩa nghiệp vụ |
| INP-TC-006 | INP-REQ-003, INP-RULE-003 | Metadata thiếu/sai: Provider không size/tên/MIME đáng tin | Không dùng metadata để đoán; đếm bytes, sniff cấu trúc |
| INP-TC-007 | INP-REQ-007, INP-RULE-006 | File lớn: Giới hạn bytes nhỏ hơn stream | 004, cleanup, không READY |
| INP-TC-008 | INP-REQ-003, INP-RULE-009 | OOXML hợp lệ: Sniff ZIP chứa package/workbook/worksheet hợp lệ | Chỉ nhận XLSX sau structural validation |
| INP-TC-009 | INP-REQ-003, INP-RULE-014 | ZIP đổi tên .xlsx: Không có workbook parts | 009, không nhận XLSX từ signature đơn lẻ |
| INP-TC-010 | INP-REQ-005, INP-RULE-011 | CSV leading zeros: sample_a.csv, record 2 field 1 | csvText raw_lexeme=00123, không cast số |
| INP-TC-011 | INP-REQ-003, INP-RULE-011 | CSV quote/multiline: sample_a.csv, record 2 note và record 4 note | Một cell chứa LF, một cell x,y; refs record≠line |
| INP-TC-012 | INP-REQ-005, INP-RULE-012 | JSON native/null/missing: [{"s":"123","n":123,"b":false,"z":null},{}] với fields từ record đầu | Giữ string/number/bool/null; record hai missing refs exists=false |
| INP-TC-013 | INP-REQ-007, INP-RULE-014 | Parser exception/corrupt: Truncated XML/JSON/CSV quote không đóng | 009 có cấu trúc, không fallback silent |
| INP-TC-014 | INP-REQ-007, INP-RULE-006 | ZIP expansion/depth limit: Payload vượt decompressed/depth limit | 004 hoặc 017 theo guard, cleanup |
| INP-TC-015 | INP-REQ-005, INP-RULE-015 | XLSX formula/cache/location: Ô có formula và cached number | Biểu thức/cache riêng, cache PRESENT_UNVERIFIED, ref excel |
| INP-TC-016 | INP-REQ-003, INP-RULE-016 | Format chưa triển khai: Registry adapter thiếu xlsb | 008; icon không bật capability |
| INP-TC-017 | INP-REQ-004, INP-RULE-017 | Header trùng: a,a và data 1,2 | Hai field_id khác nhau, nhãn giữ nguyên; review mapping mơ hồ |
| INP-TC-018 | INP-REQ-004, INP-RULE-019 | Merge/hidden: Workbook có merge A1:B1 và hidden row | Inspect lưu metadata; không fill merge hoặc tự bỏ hidden |
| INP-TC-019 | INP-REQ-004, INP-RULE-020 | Scope/header sai: Sheet không tồn tại hoặc header ngoài range | 011, không đọc scope tùy ý |
| INP-TC-020 | INP-REQ-004, INP-REQ-012, INP-RULE-018 | Stream/table invariants: source_tables.expected.json và stream descriptor tương đương | Count=3, cells=4, IDs/source positions khớp; reject mismatch |
| INP-TC-021 | INP-REQ-005, INP-RULE-021 | Numeric identifier mất biểu diễn: XLSX raw 123, format 00000, display 00123 | Giữ raw/display/format; không tái tạo identifier như raw text |
| INP-TC-022 | INP-REQ-005, INP-RULE-023 | Null taxonomy: missing, blank, CSV empty, JSON null, error, 0, false | Bảy trạng thái không bị gộp; lỗi Excel không thành null |
| INP-TC-023 | INP-REQ-005, INP-RULE-024 | JSON precision/pointer: [{"a/b~":9007199254740993}] | Token số chính xác; pointer /0/a~1b~0; adapter mất token khai báo loss |
| INP-TC-024 | INP-REQ-005, INP-RULE-025 | Formula cache thiếu/stale: Formula không v hoặc cache biết stale | MISSING không cached_value; KNOWN_STALE giữ cache+issue, không 0 |
| INP-TC-025 | INP-REQ-005, INP-RULE-024 | Ref đúng nguồn: CSV ref excel giả; JSON pointer escape sai | Schema/runtime reject 014; không Sheet1 giả |
| INP-TC-026 | INP-REQ-006, INP-REQ-012, INP-RULE-029 | Tách config/policy: Thêm alignment/tolerance vào import_config fixture | Schema reject additionalProperties; policy v2 ở file riêng |
| INP-TC-027 | INP-REQ-006, INP-RULE-027 | Revision invalidation: Đổi delimiter/header sau READY | Revision++, old snapshot/mapping invalid; phải parse lại |
| INP-TC-028 | INP-REQ-006, INP-RULE-026 | Binding A/B: source_a trỏ artifact B hoặc format khác manifest | Runtime 011; shape hợp schema không đủ |
| INP-TC-029 | INP-REQ-006, INP-REQ-009, INP-RULE-029 | Mapping/key snapshot: Composite key dùng field đã bị thay | Chặn comparison; không ghép key bằng nối text tùy ý |
| INP-TC-030 | INP-REQ-006, INP-REQ-009, INP-RULE-028 | Inference chưa xác nhận: header detect chưa confirmed; key chỉ suggested | Header: NEEDS_REVIEW; key: chặn Comparison Job tới khi xác nhận |
| INP-TC-031 | INP-REQ-007, INP-RULE-030 | Severity gate: Issue WARNING, REVIEW, ERROR cùng stage | WARNING có điều kiện; REVIEW chặn; ERROR→FAILED |
| INP-TC-032 | INP-REQ-007, INP-RULE-031 | Size unknown/runtime limits: Provider size=null, stream vượt profile | Không size=0 giả; dừng 004 theo bytes thực |
| INP-TC-033 | INP-REQ-007, INP-REQ-011, INP-RULE-032 | Unsafe input/logging: External XML/ZIP traversal/formula text/URI nhạy cảm | Không execute/fetch; 017 khi unsafe; logs không raw/full URI |
| INP-TC-034 | INP-REQ-008, INP-RULE-034 | Happy path và guard: Select→Validate→PreflightValid→ParsedAndValidated | UNSELECTED→SELECTED→PREFLIGHTING→PARSING→PREVIEW_READY; sample chưa EOF không READY |
| INP-TC-035 | INP-REQ-008, INP-RULE-033 | Race cancel/replace: Cancel/replace lúc PARSING rồi nhận Parsed callback cũ | Callback cũ bị bỏ; tài nguyên đóng; không hồi sinh READY |
| INP-TC-036 | INP-REQ-008, INP-REQ-001, INP-REQ-009, INP-RULE-035 | Gate A/B: A READY, B FAILED hoặc NEEDS_REVIEW | Mapping disabled; retry B không sửa A hợp lệ |
| INP-TC-037 | INP-REQ-008, INP-RULE-034 | Revoke/change sau READY: Revoke permission hoặc hash khác snapshot | FAILED 006/015; invalidate snapshot/mapping/job phụ thuộc |
| INP-TC-038 | INP-REQ-008, INP-RULE-036 | Process death: Kill khi PARSING/READY rồi restore journal | SELECTED + 018 nếu còn ref; recheck/parse/hash; không restore READY trực tiếp |
| INP-TC-039 | INP-REQ-010, INP-RULE-037 | OCR review/provenance: ocrText confidence 0.99/0.2/null; sửa crop | Đều PENDING trước confirm; raw giữ nguyên/correction riêng; crop invalidate receipts |
| INP-TC-040 | INP-REQ-010, INP-REQ-011, INP-RULE-039 | OCR privacy/capability: Ảnh lớn, cloud chưa opt-in, ô nhìn giống formula | Giới hạn decode; không cloud; không khôi phục formula/style gốc |

## 6. Luồng xử lý

Chạy contract verifier từ repository root:

```sh
python3 -m venv /tmp/dytava-input-venv
/tmp/dytava-input-venv/bin/pip install -r docs-dytava/specs/input/requirements-validation.txt
/tmp/dytava-input-venv/bin/python docs-dytava/specs/input/validate_contracts.py
```

Runner resolve schema refs offline từ thư mục schemas, check Draft 2020-12 và expected tables/CSV hashes. Negative cases ngăn regression cho null/formula/ref/config. Runtime cross-record validator mẫu chỉ phục vụ fixture integrity. Khi adapter được triển khai, chạy từng planned case qua port thật, lưu evidence riêng; không để test tự tạo expected output bằng chính parser cần kiểm chứng.

## 7. Edge Cases và Error Handling

Các payload nêu inline trong registry là dữ liệu tái tạo case. XLSX/OCR/security/device corpus chưa được cung cấp như binary fixtures trong đợt tài liệu này; planned tests tương ứng chưa executable. Negative schema tests không thay thế corruption/fuzz/ZIP/device tests.

## 8. Security & Privacy

Fixtures là dữ liệu minh họa; không dùng file người thật. Test logs chỉ ghi IDs/error codes, không dump raw input. Malicious corpus phải cô lập, không mở bằng ứng dụng có thực thi active content.

## 9. Acceptance Criteria

Contract gate: đúng 5 schemas, positive/negative examples đạt, hashes/bytes/provenance khớp CSV, IDs registry duy nhất và traceability resolve đủ. Release gate riêng: adapter corpus, performance/security và lifecycle Android/iOS pass theo Master; chưa có evidence trong tác vụ tài liệu.

Scope 1 GB/source có registry riêng tại [LARGE-TC-001..008](../../testing/EXPANDED_SCOPE_ACCEPTANCE.md); report có [REP-TC-001..012](../report/README.md). INP-TC-001..040 và fixture-only-small-v1 giữ nguyên, không giả 1 GB evidence từ contract verifier.

## 10. Open Questions

Ai sở hữu QA/benchmark và thiết bị tham chiếu? Cần binary corpus cùng oracle độc lập cho XLSX date systems/cache, OCR geometry và process death trước khi đánh dấu implementation supported.

## 11. References

[INP-000/index](README.md), [INP-007](07_validation_errors.md), [INP-008](08_import_state_machine.md), [semantic registry index](../../examples/README.md).
