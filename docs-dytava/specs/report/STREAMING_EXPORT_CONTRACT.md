---
document_id: DYT-REP-STREAM-001
version: 1.0.0
status: DRAFT
owner: Report export contract role
reviewer: Reporting and runtime review roles; assignees pending
updated: 2026-11-13
contract_version: EX-1
---

# Streaming result queries và export — L10

Extension nguồn của [Report spec](README.md). Core conclusions không tính lại trong renderer; [ER-1](../engine/04_result_runtime.md) là immutable source. Existing report schema `dytava-report/1.0.0` và template1.0.0 giữ compatibility, không bị đổi nội dung dưới cùng version.

## 1. Query cursor

`ResultQuery`: result_id, projection (rows/cells/structural/unresolved), filter expression closed AST, order version, requested page records/bytes, after_token. Filter chỉ allowlisted fields/status/kinds/source positions; không arbitrary SQL/regex/script. Validate current COMPLETED result và consumer lease trước query. Ngưỡng requested bị clamp theo RP-1 cả bytes lẫn rows; một item vượt single-item budget trả reference/chunked detail theo declared representation, không truncate silently.

Total order `QO-1`: logical row sequence trước, mapped field order sau, structural category/order tiếp theo và opaque event_id tie-break. KEY row sequence: A logical ordinals cho matched/A-only/unresolved-A; B-only rows sau theo B ordinal; group references dùng deterministic first-owned ordinal. POSITIONAL theo paired/tail ordinal. Unknown/unresolved groups hiển thị nguồn từng phía, không giả one-to-one row. Both source refs luôn giữ source coordinates gốc.

Cursor opaque bind result/generation/schema, projection, filter_digest, order_version và last complete tuple. Không dùng offset làm identity; token sai/stale/khác filter→CURSOR_INVALID, không silently restart rồi duplicate rows. Page có items/byte_count/next_token/end, toàn items được checksum và counted, read lease ngắn. Repeated same request trên published result cho cùng items; UI virtualized cache bounded, không giữ all pages.

Chunked detail: result_id, evidence_id, display_text_version, scalar_offset, scalar_count, utf8_byte_count, text_fragment, next_offset/end và checksum; offsets theo Unicode scalar, server không cắt UTF-8 sequence. Fragment thuộc cùng immutable evidence version; không dùng fragment thiếu để tính semantic verdict. COUNT_GROUP mode dùng group/member cursors, không pair-order giả và không hỗ trợ legacy renderer1.0 instance layout.

Filter counters tính bằng query predicate đã freeze trên cùng result, có full_counts và selected_counts riêng. Không mỗi page tự tính denominator theo visible rows. Unresolved record ownership không cộng vào matched-cell denominator. Filter change tạo query/export selection ID mới, không đổi result.

## 2. EX-1 request và manifest

`ExportRequest`: contract_version=EX-1, export_id/attempt_id, result_id/current_revision, kind, selection (`FULL_COMPARISON|DIFFERENCES_ONLY|FILTERED`, filter AST/digest, equivalent inclusion flag), projection/row_order, locale/timezone, page setup, template/layout/font versions, resource_profile_ref, include_display_names boolean và private destination_ref. DYTAVA_REPORT_PDF bắt buộc template ID/version; MERGED_DIFF_PDF dùng layout version. User xác nhận explicit scope, không tự đổi khi hết budget.

P0 evidence_level=`FULL` mặc định. Redaction extension phải có explicit field/evidence selector, capability/version và user confirmation; output ghi redaction markers/metadata_complete=false, không dùng bản redacted để đạt full-raw fidelity acceptance. MERGED_DIFF_PDF P0 yêu cầu raw A/B nên reject redaction request incompatible, không silently mask rồi ghi FULL.

`ExportManifest`: EX-1, export_id/attempt, result/lineage/schema versions, kind, source IDs/hashes/scopes, direction, policy/engine/import/parser/profile versions, filter/order/template/layout/font versions, full_counts/selected_counts/exported_counts, warnings/capability losses, output bytes/pages/bands, SHA-256 của completed file, completion state, created_at/timezone. Destinations/tokens/internal paths không export.

Exact counts serialized decimal strings; rate nullable với numerator/denominator. PDF/page counts cũng exact integers. Hash completed output nằm private artifact registry/optional user-selected sidecar, **không nhúng self-hash vào chính artifact**. Manifest bên trong JSON/PDF chỉ có semantic lineage/selection/completion info, output hash ở external registry. Sidecar không tự động upload hoặc thay output kinds.

## 3. JSON_REPORT target và bridge renderer1.0

Target JSON export logical contract `dytava-engine-report/1.0.0`: header ER-1/result/lineage/selection/summary/warnings, ordered arrays `record_pairs`, `record_groups`, `cell_pairs`, `structural_events`, `unresolved_groups`, `evidence_catalog`. INSTANCE_PAIR có record_groups=[]; COUNT_GROUP có record_pairs/cell_pairs=[] và mode-specific multiplicity summary theo ER-1. Mỗi array stream theo cursor; referenced evidence có full typed raw/canonical/ref/trace hoặc redaction marker theo request. Fields required/meaning theo ER-1; IDs uniquely resolve within document/catalog; không emit private store refs làm usable public evidence. User-redacted fields phải ghi `redacted=true` và reason, không pretend evidence complete.

Metadata và array delimiters viết incrementally vào private pending file; không build whole JSON string/list. Chuỗi/control chars escape theo RFC8259, decimal canonical values là strings; raw exact numeric lexemes là strings+physical type, không round thành JSON double. UTF-8 text có thể chunk-write trong một JSON string với escaper state giữ xuyên chunks. Closed file phải valid syntax, refs/counts/footer audit khớp trước publish. Chưa có executable JSON Schema/validator cho target trong lần docs này.

Existing `dytava-report/1.0.0` là **legacy presentation envelope**, không synonym ER-1. Adapter bridge chỉ cho subset representable và nhỏ trong admitted memory budget:

| Legacy field | Mapping/guard |
| --- | --- |
| report_id/completion_state/current | result/export identity; COMPLETED/current=true chỉ khi validity check pass |
| inputs A/B | Labels/names theo opt-in, format/scope/parser từ lineage; source SHA bare64hex; size safe integer |
| engine_version/direction/direction_confirmed | Frozen engine/mode/direction và confirmation receipt; không default confirmed=true |
| policy_id/digest/import_config_revision | Effective policy, bare digest; composite import binding string có version, không drop một side revision |
| matching_mode/key_fields/field_mapping | Chỉ KEY/POSITIONAL và confirmed logical IDs; unsupported modes reject |
| summary | ER-1 counts convert sang number chỉ khi≤9007199254740991 và full invariant pass; no rounding |
| differences/left/right | Actual stored verdict/kind/raw/source location, precision-safe strings; không flatten raw number qua float |
| policy | Flat presentation projection do schema1.0 yêu cầu; full effective policy ở authoritative ER-1 export, không nhét nested policy vào field sai schema |
| details_scope/metadata_complete | FULL/DIFFERENCES_ONLY chỉ khi coverage proof đủ; PROVIDED_DETAILS ghi rõ subset; missing evidence không set metadata_complete=true |

SourceRef structured OCR polygon/CSV/XLSX refs cần hiển thị location text nhưng full provenance/evidence phải còn qua ER-1 companion/export binding. Nếu legacy shape không biểu diễn đủ selected semantics/unknowns/unresolved ownership, reject legacy bridge cho yêu cầu đó hoặc user chọn explicitly limited preview; không claim full audit equivalence. Streaming PDF target đọc ER-1 cursors trực tiếp, không phải nạp `differences[]` legacy toàn file. Template version1.0.0 typography/content blocks có thể dùng lại nhưng renderer contract/capability version riêng.

## 4. CSV fidelity và safety

CSV_DIFF row schema cố định gồm row/event IDs, kind/verdict, side/direction, logical field, raw_kind_a/b, displayed_raw_a/b, source_ref_a/b, rule/reason và representation note. Quote/escape dialect đúng không tự chống formula injection. Untrusted text được encode theo safe-text export capability đã test với spreadsheet readers; prefix/escape nếu áp dụng phải ghi representation note, giữ authoritative original lexical evidence trong JSON/report detail để truy vết.

P0 bắt buộc malicious corpus `= + - @ tab CR` và encoding variants không thực thi khi mở. Không gọi một escape rule “an toàn” trước reader-specific tests. Không chạy formulas để validate export. CSV rate/count lineage có thể trong manifest/registry, không thêm raw source handles vào comments.

## 5. PDF streaming layout

Freeze page setup/fonts/local assets trước render. Layout từ logical rows/fields và full/selected counts; styles/status labels theo Report §2. Warnings/UNRESOLVED không bị filter bỏ mặc định. Repeated columns có stable field IDs và band continuation markers.

Vertical pages: bounded row/cell text measurer; cell dài chia continuation fragments có `(row_id,field_id,fragment_index)` và explicit prefix/suffix markers, giữ text reading order; không cắt text theo page height. Horizontal bands: key columns/header repeated, original field order; logical cell xuất đúng một owning band, repeated keys chỉ layout refs, không tăng semantic exported count. Footer `Trang n/N` dùng bounded two-pass page plan spool hoặc reserved placeholder mechanism được adapter chứng minh; không giữ mọi page objects trong RAM.

Band/page plan stores text fragments/coordinates/checksums ngoài RAM khi cần. Embedded/subset fonts bảo toàn Vietnamese/search/copy, glyph caches và output buffers bounded. Passive PDF, no scripts/attachments/remote fetch. One PDF mỗi kind; không tự split thành nhiều files hoặc shrink font đến không đọc được để né budget. Full output vượt page/byte/layout budget→failure, offer explicit new export selection, không gắn FULL cho partial/filter.

Reconciliation gồm unique logical row/cell IDs theo selected scope, continuation coverage không gaps/dup, repeated header/key labels riêng và PDF extraction/render evidence. Result semantic counts không tính duplicated layout cells. Grey-scale labels/accessibility/reading-order kiểm theo REP-TC-012, không claim PDF-UA certification mặc định.

## 6. State và publication protocol

`REQUESTED→VALIDATING→RENDERING→VERIFYING→PUBLISHING→COMPLETED`; cancel/error ở active stage→CANCELLING→CANCELLED hoặc FAILED. Result vẫn immutable, export attempt mới retry không nối bytes cũ.

Validate result current/lease/request/profile/template/destination capability→reserve scratch→render private pending file→flush/close→validate syntax/page/coverage/counts/hash→recheck current validity→publish complete artifact→record external manifest/commit receipt. Invalidation trước publish chặn; concurrent source closing bình thường không fail nếu snapshot evidence đủ, explicit revoke theo ER-1 validity thì fail.

Destination strategy: atomic rename nếu provider support đã verified, hoặc provider pending-object + commit visibility nếu verified. Nếu provider chỉ cho direct visible writes và không rollback/pending guarantee thì **reject destination trước publish**, yêu cầu chọn destination tương thích; không quảng cáo atomicity. Private temp có thể render trước nhưng không xóa result. Failure/cancel close handles/leases, cleanup pending artifact và report explicit cleanup failure khi provider mất quyền; không show successful final output.

Publish durable nhưng ACK mất: lookup by export attempt/idempotency receipt, không write second PDF. Output SHA chỉ tính bytes hoàn chỉnh; hash không là chữ ký/phê duyệt pháp lý. Minimal history không giữ raw contents ngoài session lifecycle.

## 7. Acceptance

Planned [UDG-TC-019/020](../../testing/UDG_CONTRACT_ACCEPTANCE.md), REP-TC-001..012 và LARGE-TC-007. Include legacy bridge rejection/precision, deep pagination/cursor filter mismatch, two-pass pages/long-text continuation, count reconciliation, failed provider commit và duplicate publish retry. Không đánh dấu renderer hiện tại hỗ trợ EX-1/ER-1 large streams bằng tài liệu này.
