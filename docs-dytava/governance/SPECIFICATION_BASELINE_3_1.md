---
document_id: DYT-DOC-BASELINE-031
version: 1.0.0
status: DRAFT
owner: Documentation integration role
reviewer: Technical review role; assignee pending
updated: 2026-11-13
specification_state: SPECIFIED_PENDING_REVIEW
execution_state: NOT_VERIFIED
---

# Baseline docs UDG3.1 — bàn giao hoàn thiện đặc tả

## 1. Phạm vi bàn giao

Theo yêu cầu chủ dự án, hoàn thiện tài liệu từ 30 gaps của DYTAVA_UDG_v3, dừng ở docs. [UDG3.1](../specs/engine/README.md) là entry hiện hành; [resolution/acceptance](../testing/UDG_CONTRACT_ACCEPTANCE.md) có30/30 SPECIFIED và20 UDG cases PLANNED/NOT_RUN. Không đọc/sửa mã triển khai, không cài dependency, chạy parser/benchmark hoặc tạo executable schema/validator trong lần này.

Đây là specification completion, không phải approval hoặc performance certification. Bản v3.0 gốc Markdown chỉ thêm superseded notice; body/diagrams giữ audit. PDF/DOCX3.0 giữ nguyên bản lịch sử; không claim có bản PDF/DOCX3.1 mới.

## 2. Owner contracts hiện hành

| Domain | Deliverable | Đã đặc tả | Chưa có execution evidence |
| --- | --- | --- | --- |
| Product/FR | PRD/SRS + ADR refs | P0 scope unchanged, capabilities/preconditions | Academic OCR/named sign-off, app acceptance |
| L0 | EP-1 | Frozen plan, matrix, invalidation và calibration harness gate | Plan validator/runtime |
| L1/L2 | ISC-1 | Access/spool/pass plan, snapshot/cursors, target Input0.2/OCR migration | Versioned schemas/validators/adapters/fixtures0.2 |
| L3 | GF-1/geometry | Feature definitions/manual confirmation, overlap, merge/transpose cursors | Device/corpus geometry tests |
| L4/L7 | CE-1/CFG-1 + decisions | Canonical byte grammar, hashes/cache và verdict/type/formula tables | Byte-level parity, typed comparator/golden runner |
| L5/L6 | Matching contract | External sort/global duplicates/absence proof, ordered DP/ties/budgets, count-group multiset | Implemented execution plans/capabilities |
| L8/L9 | ER-1/WP-1 | Ledgers/counts, staging/finalize, sequence/credits, cancel/restart/leases | Repository/worker/process-death tests |
| L10 | EX-1 | Query/JSON/legacy bridge, bounded PDF/publish protocols | Executable target schemas/streaming renderers/provider tests |
| Performance | RP-1 | Typed dimensions, resource actions/accounting, calibration protocol | Numeric device-specific profiles, measured throughput/RAM/cancel |
| QA | UDG-TC-001..020 + existing registries | Oracles/golden examples/traceability | Fixture runners, positive1GB/full PDF/device evidence/APK |

Các con số chưa đo ở performance không được “hoàn thiện” bằng cách điền tùy ý. Thay vào đó, RP-1 đặc tả finite-value requirements, calibration-only path và production enable gates; semantics khi thiếu/hết budget đã đầy đủ. Actual values và named reviewers là dữ liệu triển khai/phê duyệt cần có sau docs.

## 3. Migration và compatibility

- Input0.1 tabular schemas/fixtures giữ compatibility; target0.2 có logical shape/migration tại ISC-1, chưa overwrite schema cũ hoặc auto-enable OCR.
- CE-1 đổi record/key/cache bytes nên rebuild indexes/caches; raw snapshots chỉ reuse khi Input lineage/capability vẫn hợp lệ.
- V3 JSON sample không tự thành ER-1; thiếu coverage/evidence phải recompare. `COMPLETE/UNDETERMINED` legacy được normalize tại explicit compatibility boundary, không phát ra như current statuses.
- Existing renderer schema `dytava-report/1.0.0` giữ nguyên. Target engine JSON `dytava-engine-report/1.0.0` và EX-1 có namespaces riêng; legacy bridge chỉ subset representable, không whole-result memory cho1GB.
- WP-1 không nhận message cũ thiếu attempt/generation/sequence; partial checkpoints không được resume sau process death. P0 restore chọn nguồn/revalidate.
- Root MANIFEST_SHA256 và current bundle SHA256SUMS được refresh cho actual files; original checksum snapshots giữ audit. Checksums không là chữ ký/phê duyệt.

## 4. Docs quality gate

Kiểm tra trước bàn giao: relative Markdown links và code fences; unique document/gap/test IDs; đủ30 gap dispositions/20 case definitions; owner/version/migration references; invariants/golden expected counts; git diff whitespace; checksum manifests. Đây là docs QA, không test engine runtime.

Không sửa `.obsidian/workspace.json` hoặc khôi phục file người dùng đã xóa. Các snapshot/source-data artifacts không liên quan được giữ; không đưa raw user source vào git bằng công việc này. Owner/reviewer vai trò trong docs chưa giả định ai đã ký duyệt.

## 5. Tiếp nhận để triển khai sau

Thứ tự đề xuất: review owner contracts và assign reviewers → versioned validators/fixtures → P0 canonical/keyed/positional engine và bounded Input → ER-1/WP-1/result store → EX-1/renderers → RP-1 calibration/device gates → release. Mỗi gói phải giữ traceability và actual evidence; không gắn nhãn implementation-ready hoặc PASS chỉ từ độ đầy đủ của docs.
