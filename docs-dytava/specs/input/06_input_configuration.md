# Cấu hình nhập và ranh giới comparison policy

Document ID: INP-006\
Version: 0.1.0\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 11/11/2026

## 1. Mục đích và phạm vi

Tách cấu hình đọc cấu trúc nguồn khỏi mapping/key và semantic policy. Draft schema 0.1.0 chỉ mô tả ImportConfig P0; không phải bản thay thế policy schema v2 và không chứng minh adapters đã triển khai.

## 2. Thuật ngữ và định nghĩa

ImportConfig quyết định cách đọc bytes thành bảng. ComparisonConfig quyết định ghép bảng/trường/hàng và hướng báo cáo. Policy xác định semantic type, locale cho số/ngày, tolerance và null equivalence. Parser profile có ID/version, là tập quy tắc parser được allowlist; không phải script.

## 3. Các thành phần dữ liệu

| ImportConfig | Hiệu lực |
| --- | --- |
| schema_version, config_id, config_revision | Version contract và revision tăng khi effective config đổi |
| resource_profile_ref | Registry hạn mức đã benchmark; không cho file nhập tự nâng limits |
| source_a/source_b.artifact_id, format, scopes | Binding nguồn và selection đã xác nhận |
| header | none / explicit(row) / detect(confirmed_row nullable) |
| encoding, delimiter, parser_profile | CSV/TSV resolved encoding/dialect; XLSX/JSON dùng null cho encoding/delimiter (JSON P0 UTF-8 profile) |
| hidden_content, merged_cells | Quy tắc preview include/exclude/review và anchor_only/review |
| validation_behavior | on_ambiguity=review; ragged_records=reject; invalid_encoding=reject |

Schema: [import_config](schemas/import_config.schema.json). JSON flat records dùng header mode none; field names lấy từ keys. JSON records_pointer="" chọn root array. CSV scopes dùng logical record number, gồm header nếu có.

## 4. Quy tắc và ràng buộc

- **INP-RULE-026:** Cấu hình có version, validation và binding artifact; effective resolved config là immutable theo revision.
- **INP-RULE-027:** Thay bytes, scope, header, encoding hoặc parser version invalidate parsed snapshot và mọi mapping/review phụ thuộc nó.
- **INP-RULE-028:** Inference chỉ là gợi ý. detect chưa có confirmed_row, hidden/merged=review chưa giải quyết hoặc dialect mơ hồ đều chặn PREVIEW_READY.
- **INP-RULE-029:** ImportConfig không nhúng mapping, key, tolerance, currency hoặc toàn bộ policy. Thuộc tính lạ bị schema từ chối.

Không đặt mặc định sản phẩm cho header, chiều A/B, số sheet, retention hay resource limits khi ADR chưa chốt. Fixture dùng explicit values để kiểm tra ví dụ; chúng không trở thành defaults. Với cấu hình điều khiển kiểu đọc, nguồn A và B được phép khác encoding/delimiter/profile. Locale diễn giải decimal/date nằm trong `source_profiles`/`source_overrides` của policy v2, tránh hai nơi cùng định nghĩa semantic parse.

## 5. Input / Output Contract

Comparison handoff descriptor (hợp đồng ứng dụng, chưa có JSON Schema riêng):

```text
InputSnapshot(session_id, A.artifact_id/sha256, B.artifact_id/sha256,
              import_config_id/revision, adapter_id/version per table,
              validated table descriptors + row streams, validation_result,
              snapshot_id)
ComparisonConfig(snapshot_id, direction, table_pairs, field_mapping,
                 key_fields[], policy_ref(id, version, digest), review_receipts)
```

`direction` phải explicit trước báo cáo added/removed (A_TO_B hoặc B_TO_A); chưa chọn default. Một key là mảng một field; composite key là mảng có thứ tự, không nối text bằng delimiter dễ collision. Mapping dùng field IDs và table IDs thuộc snapshot; nhãn header chỉ hỗ trợ hiển thị. Policy v2 hiện có alignment.mapping/keys: ComparisonConfig là binding ứng dụng tới policy đã compile, không tạo bản semantics cạnh tranh. Mapping trong policy ví dụ dùng nhãn phải resolve sang ID duy nhất hoặc review.

Schema không kiểm tra cross-file binding. Runtime phải xác nhận source_a/B trỏ đúng artifact side, format/scopes khớp manifest/tables, resource profile tồn tại, adapter hỗ trợ profile, key/mapping không tham chiếu cột cũ.

## 6. Luồng xử lý

Cấu hình đề xuất → schema validation → bind artifact/scope → preview → user review → freeze revision → full parse → chốt InputSnapshot → mở Mapping khi cả hai nguồn sẵn sàng → compile policy/confirm keys/direction → Comparison Job. Đổi riêng semantic policy có thể tái sử dụng raw snapshot nếu không đổi import semantics; comparison cache phải invalidate theo policy digest.

## 7. Edge Cases và Error Handling

Delimiter nhiều ký tự hoặc CR/LF/NUL/quote character, encoding không biết, scope không hợp format: INP-ERR-011. CSV/TSV malformed/encoding invalid không được chuyển sang replacement characters rồi READY. Header auto detect chưa xác nhận: INP-ERR-012. Key inference chưa confirm không làm hỏng InputSnapshot nhưng chặn Comparison Job. Duplicate key là vấn đề alignment của Core, không phải raw datatype.

## 8. Security & Privacy

Không nhận arbitrary code trong config/profile. Policy refs chỉ resolve trong registry đã kiểm soát; không fetch URL tùy ý từ tệp. Không ghi access tokens vào config xuất ra ngoài. Resource limits là cấu hình ứng dụng có kiểm soát, không là quyền của người cung cấp file.

## 9. Acceptance Criteria

INP-TC-026: tách policy khỏi ImportConfig. INP-TC-027: revision đổi invalidate preview/mapping. INP-TC-028: source binding sai bị chặn. INP-TC-029: composite key/mapping chỉ dùng snapshot hiện hành. INP-TC-030: header detect pending và chưa confirm key không được khởi chạy comparison.

## 10. Open Questions

INP-ADR-001/003/005/008 còn mở. Serializer/digest của effective ImportConfig cần version trước khi triển khai cache; không tái dùng digest policy để đại diện config.

## 11. References

[INP-008](08_import_state_machine.md), [policy v2 chuẩn](../../project/comparison_policy.v2.example.json), [fixture config](fixtures/import_config.example.json), [JSON Schema 2020-12](https://json-schema.org/draft/2020-12/json-schema-core).
