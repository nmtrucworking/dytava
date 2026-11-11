# 06. Data contracts, schema và provenance

## 6.1. Entities

| Entity | Các trường trọng yếu | Ý nghĩa / constraint |
|---|---|---|
| `ComparisonSession` | id, created_at, engine_version, status, policy_digest | lineage và trạng thái |
| `InputArtifact` | id, uri_hint, file_name, detected_format, sha256, size, selected_scope | không lưu URI public vô thời hạn |
| `SourceTable` | id, artifact_id, sheet_name, row_count, column_count, header_row | phạm vi xử lý |
| `SourceCell` | table_id, row, col, raw_type, raw_value, display, formula | không ghi log/telemetry |
| `FieldMapping` | source_field_a/b, semantic_type, normalization_policy | 1-to-1 mặc định |
| `RecordPair` | key, row_ref_a, row_ref_b, match_mode, status | unique/reference |
| `Difference` | id, category, severity, field, refs, raw/normalized, rule_id, reason | audit trail |
| `OCRToken` | text, polygon, source_image, confidence_optional | geometry và review |
| `ReportManifest` | schema_version, source_hashes, policy_digest, engine, counts | reproducibility |

## 6.2. Versioning

- Dùng SemVer với **engine** và **report schema** độc lập (`engine=1.0.0`, `schema=1`).
- Stable canonical serialization: field order deterministic, UTC timestamps với nguồn timezone, decimal canonical string.
- `policy_digest = SHA-256(canonical_policy_json)`; report kết quả phải chứa snapshot policy hoặc reference kèm hash.
- `source_sha256` chỉ nhằm chứng minh cùng byte tệp, không khẳng định nội dung nghiệp vụ giống nhau.
- Room migrations forward-only, backup/restore có sơ đồ rõ; không xóa database sản phẩm khi migration thất bại.

## 6.3. Output JSON contract

`ComparisonReport` có `source_a`, `source_b`, `mapping`, `policy`, `summary`, `schema_differences`, `record_differences`, `cell_differences`, `unresolved`, `warnings`, `generated_at`. Cả `source_location` và `comparison_location` phải có; tọa độ OCR là pixel polygon thay vì địa chỉ ô Excel gốc.

## 6.4. Referential integrity

`Difference` tham chiếu tới `RecordPair` khi có match; `source_ref` dạng discriminated union `{type:excel, sheet, address}` / `{type:csv, line, field}` / `{type:json, pointer}` / `{type:ocr, page, polygon}`. Không giả lập `Sheet1!A1` cho dữ liệu vốn là JSON/PDF.

## 6.5. Các trường tuyệt đối không ghi telemetry

Nội dung cell raw/canonical, tên cá nhân, danh sách định danh, full path file, file URI, ảnh OCR gốc, access tokens, ảnh bảng. Cho phép metric tổng hợp như `duration_ms`, `format_type`, `row_count_bucket`, `error_code` với consent và chống tái nhận diện.
