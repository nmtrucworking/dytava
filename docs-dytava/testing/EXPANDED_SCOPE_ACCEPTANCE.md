---
document_id: DYT-QA-EXP-001
version: 0.2.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-13
release_baseline: P0 mở rộng
---

# Kế hoạch nghiệm thu input 1 GB và hai PDF

Nguồn yêu cầu: [Scope expansion](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md), [SRS FR-016..018](../requirements/SRS.md), [NFR §3](../requirements/NFR.md#3-resource-profiles-và-trần-input-1-gb), [Report spec](../specs/report/README.md). Toàn bộ test dưới đây **PLANNED/NOT_RUN**. Không có corpus 1 GB hoặc PDF golden được tạo/chạy trong lần cập nhật docs này.

[UDG3.1 contracts](../specs/engine/README.md), [RP-1 calibration](../requirements/RESOURCE_PROFILES.md) và [UDG-TC-001..020](UDG_CONTRACT_ACCEPTANCE.md) bổ sung execution/budget/coverage rules. Positive boundary/full output gates dưới đây giữ nguyên; specs complete không chuyển tests sang PASS.

## 1. Registry dung lượng lớn — LARGE-TC-*

| ID | Requirement | Test / oracle | Expected |
| --- | --- | --- | --- |
| LARGE-TC-001 | FR-016, INP-REQ-002/007 | Valid streaming CSV ở 999.999.999, 1.000.000.000 và 1.000.000.001 byte; size known và unknown | Hai case đầu qua size gate và chạy full valid pipeline; +1 dừng INP-ERR-004 không dựa riêng metadata |
| LARGE-TC-002 | FR-016, NFR-PERF-04 | A/B mỗi nguồn 1 GB, oracle counts/diff độc lập; cả KEY và POSITIONAL | Full EOF/hash, đúng matched/unmatched/status/ref; peak memory/scratch/output có evidence; không cap 20k rows cũ |
| LARGE-TC-003 | FR-016, INP-REQ-005 | UTF-8 split chunk, quoted multiline/escaped quotes, long cells, keys cùng/khác partition | Giữ raw/null/precision/provenance; duplicate/null-key detection toàn scope, không mất/trùng records |
| LARGE-TC-004 | FR-016, NFR-SEC-04 | Valid XLSX lớn trong profile và malicious ZIP có cùng source size dưới 1 GB | Valid case đi hết selected scope; malicious expansion/entry/ratio bị chặn; không tắt guard để đọc file |
| LARGE-TC-005 | FR-015/016, NFR-REL-02/03 | Cancel tại read/parse/index/compare/PDF; kill/restart, revoke provider | Không READY/report giả; cleanup idempotent, startup sweep; revalidate khi restore |
| LARGE-TC-006 | FR-016, NFR-PERF-04 | Low RAM, thiếu disk/quota, extraction/output estimate lớn hơn available | Lỗi có stage/limit/profile và hướng khắc phục, không OOM hoặc upload ngầm; không quảng cáo support trên device fail |
| LARGE-TC-007 | FR-016/017/018 | Large valid result → CSV/JSON + full merged PDF + Dytava PDF | Counts/lineage thống nhất, một PDF mỗi kind; không silent sample/truncate; budgets đo cả rendering/export |
| LARGE-TC-008 | FR-016, NFR-SEC-01/02, NFR-OPS-01 | Hash A/B trước/sau, airplane mode/local web, log/network/storage inspection | Sources giữ nguyên, no raw telemetry/cloud; scratch đúng lifecycle; platform capability ghi riêng |

Case bằng/nhỏ hơn trần chỉ thành PASS khi corpus hợp lệ cho format/profile và đi hết stages đã yêu cầu; một lỗi khác phải có lý do chính xác và không thay thế positive boundary oracle. Dung lượng source 1 GB không mặc định 1 GB RAM hay 1 GB decompressed/output. OCR vẫn có pixel/structure/review gates riêng; test thêm compressed-image bomb, không coi 1 GB là quyền decode không giới hạn.

## 2. Tạo corpus và oracle

Không commit các tệp 1 GB vào Git. Tạo reproducibly bằng generator streaming; ghi generator version/seed, exact byte count và SHA-256. Dùng nhiều records có bounded cell length, quoted UTF-8/multiline và controlled diff positions; chỉnh byte count bằng dữ liệu hợp lệ có oracle, không padding NUL hoặc sparse file rồi coi là valid CSV. Fixture +1 byte phải vẫn hợp lệ về cấu trúc để kiểm riêng size boundary. TSV có corpus tương ứng; XLSX cần corpus/ZIP metadata và decoded counts riêng, không dùng CSV đổi đuôi.

Oracle counts/keys/diff/provenance được xác định độc lập với parser/comparator cần test. Kịch bản full PDF lớn phải ghi page/row/cell reconciliation; nếu vượt budget thiết bị thì ghi FAIL/unsupported cho full export đó, không chuyển sang filtered PDF rồi gọi full PASS. Filtered export được nghiệm thu riêng theo REP-TC-005.

## 3. Nền tảng, phép đo và evidence

Android reference devices theo NFR; web cần browser/version/OS, Worker/storage strategy/quota, local/no-upload inspection; iOS cần device/sandbox riêng khi đến pha triển khai. Không lấy Node unit test hoặc schema validation làm bằng chứng 1 GB trên Flutter/browser.

Evidence record theo [RTM](../requirements/TRACEABILITY_MATRIX.md#3-evidence-record-template), bổ sung:

```yaml
status: NOT_RUN
resource_profile_id: large-input-v1
resource_profile_revision: null
input_sizes_bytes: []
input_sha256: []
generator_version_seed: null
stage_elapsed_ms: null
peak_memory_bytes: null
peak_scratch_bytes: null
output_bytes_and_pages: null
expected_vs_observed_counts: null
pdf_text_and_page_render_evidence: null
cancel_and_cleanup_evidence: null
```

Time/memory budgets chưa benchmark không tự điền số. Tất cả profile-dependent limits phải được resolve trước enable/release; ghi limit failures theo stage, không log nội dung input. G7 chỉ đạt khi LARGE-TC-* và [REP-TC-001..012](../specs/report/README.md#6-acceptance-registry) có runners/evidence phù hợp.
