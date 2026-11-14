---
document_id: DYT-UDG-PLAN-001
version: 1.0.0
status: DRAFT
owner: Algorithm design role
reviewer: Technical review role; assignee pending
updated: 2026-11-13
---

# Execution plan và capability contract — L0

## 1. Capability matrix

Scope nguồn: [PRD §3](../../product/PRD.md), [SRS](../../requirements/SRS.md), [ADR mở rộng](../../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md). Bảng này là dispatch design, **không là danh sách capability runtime đã enabled**.

| Platform / input | P0 modes thiết kế | Gate bắt buộc | Extensions |
| --- | --- | --- | --- |
| Android / XLSX | KEY, POSITIONAL; một selected sheet/range | Content validation, raw/provenance fidelity, EOF/hash, scope/header confirmations | Formula/style compare, batch multi-sheet chưa enabled |
| Android / CSV, TSV | KEY, POSITIONAL; một table | Strict UTF-8/dialect, physical lines/logical records, EOF/hash | JSON/JSONL input phase riêng |
| Android / một PNG/JPEG | KEY, POSITIONAL qua reviewed SourceTable | Bounded decode, bundled offline OCR, extraction revision, toàn selected cells confirmed | Không image-image, PDF/HEIC/multi-page/cloud |
| Android / output | CSV/JSON + MERGED_DIFF_PDF + DYTAVA_REPORT_PDF | COMPLETED result, EX-1, passive output, fonts/coverage/counts | Không XLSX export P0 |
| iOS / cùng conceptual ports | Chưa enable bởi Android evidence | Platform-specific validation/profile/signing | P1 |
| Web / cùng logical contracts | Capability độc lập | Worker/storage quota/provider/export evidence riêng | Không dùng Node/Web evidence thay Android |

`CapabilityEntry` gồm capability ID/version, platform/build compatibility, format, raw fidelity/loss dimensions, supported mode/types, profile IDs, fixture/evidence refs và `DESIGN_ONLY | CALIBRATING | VERIFIED | DISABLED`. Chỉ VERIFIED được quảng cáo enabled; unknown/unsupported combination bị reject trước compare bằng safe reason. Source ≤1 GB không tự cho phép mọi decompression/pixel/layout.

Benchmark harness có `execution_purpose=CALIBRATION_TEST`, được phép dùng CALIBRATING capabilities/profile với finite candidate limits đã validate và test-only build gate. Không dùng path này cho user comparison/release claim; mọi safety/immutability/no-cloud guards vẫn bật. Điều này cho phép thu evidence trước enable, không tạo vòng lặp “phải verified trước khi được test”.

## 2. Plan fields và freeze

`ComparisonPlan` là immutable descriptor, không chứa URI hoặc workbook graph:

| Field | Điều kiện |
| --- | --- |
| plan_id, plan_version=EP-1, session_id | Opaque IDs, không encode raw/key/filename |
| execution_purpose | USER_COMPARISON mặc định; CALIBRATION_TEST chỉ internal gated harness, ghi rõ mọi evidence |
| snapshot_a_id, snapshot_b_id, input_sha256 | Hai snapshot hiện hành; cùng bytes không nhập chung source identity |
| import_lineage | Artifact/generation/config/adapter/extraction/scope revisions của từng bên |
| scope_pair_id, mapping_revision, field_map | Exactly một scope pair P0; bijection cho mapped fields, unmatched fields riêng |
| mode, ordered_key_field_ids | KEY hoặc POSITIONAL đã confirm; KEY tuple theo thứ tự người dùng |
| policy_id/version/digest, capability_versions | Policy compiled, mọi type/operation có capability |
| direction, confirmation_receipts | Receipt gắn đúng snapshots/mapping/policy/profile và action; thay đổi làm stale |
| engine_contract_version, encoding_version | UDG3.1/CE-1, không lấy app version thay thế |
| resource_profile_id/revision/digest | Profile resolved/compatible theo RP-1 |
| expected_record_counts, work_estimates | Counts từ validated snapshots; estimates mang lower/upper/unknown, không dùng estimate làm oracle |
| plan_digest | Digest canonical configuration theo CE-1; generated_at/access refs không tham gia |

Preliminary plan trước EOF chỉ phục vụ inspect/preview. `freeze` cần A/B PREVIEW_READY, snapshot access valid, OCR receipts đủ, mapping/mode/key/dtype/policy/direction confirmed và profile/capabilities hợp lệ. Mọi thiếu precondition trả `PLAN_PRECONDITION_FAILED` với missing gate list; không tạo comparison job RUNNING. Profile chưa calibrate là `RESOURCE_PROFILE_NOT_ENABLED`, không runtime fallback sang profile nhỏ.

## 3. Invalidation matrix

| Thay đổi | Giữ được | Phải tạo mới / invalid |
| --- | --- | --- |
| Source bytes/access revoke | Bên kia nếu independent | Affected snapshot/receipts, mapping/plan, running jobs/result hiện hành |
| Scope/header/dialect/adapter | Nguồn bên kia; source fingerprint nếu bytes không đổi | Snapshot affected, source-dependent mapping/policy confirmation, canonical/index/result |
| OCR crop/layout/text correction | Raw source image | Extraction/review receipts, Input snapshot, downstream plan/results |
| Field map/axis/key/mode/direction | Frozen raw snapshots | Plan/match/diff/result; canonical cache chỉ reuse theo CE-1 dependencies |
| Field normalization/policy | Frozen snapshots và raw mapping | Policy digest/confirm, affected canonical cache, candidate index khi keys/content đổi, match/diff/result |
| Resource profile | Frozen snapshots nếu raw contract vẫn hợp lệ | New plan/job; không mutate budget của job đang chạy; fail/bounded-abstain theo contract hiện tại |
| Export filter/layout/template | Result snapshot | New export attempt, không compare lại |

Kết quả cũ có thể là historical descriptor nhưng không “current”; P0 không export stale result. New generation không sửa nội dung snapshot đã frozen. Reuse cache phải chứng minh dependency key đầy đủ, không chỉ dựa tên file/raw value.

## 4. Failure và acceptance

Plan validation không log URI/raw values; UI chỉ nhận gate/reason IDs và source positions an toàn. Ví dụ: user chọn KEY nhưng chưa confirm key → blocked; đổi policy sau READY → Input còn READY nhưng plan cũ stale; một OCR side PENDING → blocked dù confidence cao. Size gate/pass không cấp capability VERIFIED.

Verification plan: [UDG-TC-001/002/015/016](../../testing/UDG_CONTRACT_ACCEPTANCE.md), FR-001/002/005/006/012/016, LARGE-TC-001/006. P0 và extension tests được báo riêng.
