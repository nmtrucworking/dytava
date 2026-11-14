---
document_id: DYT-UDG-SPEC-001
version: 3.1.0
status: DRAFT
owner: Algorithm design role; assignee pending
reviewer: Technical review role; assignee pending
updated: 2026-11-13
release_baseline: Android P0 mở rộng; extensions disabled by default
specification_state: SPECIFIED_PENDING_REVIEW
execution_state: NOT_VERIFIED
---

# DYTAVA UDG 3.1 — đặc tả thuật toán chính

Đây là bản đặc tả hiện hành hoàn thiện từ **DYTAVA_UDG_v3**, theo 30 gaps trong [review phân lớp](../../project/DYTAVA_UDG_v3/LAYERED_SPEC_REVIEW.md). Version 3.1.0 là version **thiết kế**, không là app/engine build đã phát hành. Các từ MUST/SHALL biểu thị yêu cầu triển khai sau này. Toàn bộ runtime/benchmark acceptance vẫn NOT_RUN.

V3 gốc là snapshot tham khảo, không dùng đồng thời như một nguồn quy tắc cạnh tranh. Scope thuộc PRD/SRS/ADR; semantic laws thuộc Core; wire Input thuộc Input; budgets thuộc NFR; presentation/export thuộc Report. Bộ này hoàn thiện execution contracts và liên kết đến các owner extensions tương ứng.

## 1. Đọc theo layer

| Layer | Contract nguồn | Trách nhiệm |
| --- | --- | --- |
| L0 | [Plan và capability](01_execution_plan.md) | Phase, preconditions, confirmation, lineage, invalidation |
| L1–2 | [Input streaming/snapshot](../input/11_streaming_snapshot_contract.md) | Access, preflight order, parse passes, spools, OCR handoff, EOF freeze |
| L3 | [Geometry/mapping](02_geometry_mapping.md) | Scope, axis, merged cells, logical cursors, confidence/review |
| L4 | [Canonical encoding](../core/CANONICAL_ENCODING.md) | Byte grammar, key/content/source hashes, policy/cache identities |
| L5–6 | [Index và alignment](03_candidate_alignment.md) | External matching, duplicate ownership, bounded ordered extension |
| L7 | [Comparison decisions](../core/COMPARISON_DECISIONS.md) | Four-state precedence, numeric/date/formula decisions, long text |
| L8–9 | [Result và runtime](04_result_runtime.md) | Ledgers, staging/finalize, worker protocol, lifecycle, backpressure |
| L10 | [Streaming query/export](../report/STREAMING_EXPORT_CONTRACT.md) | Result cursors, manifest, schema bridge, atomic publication |
| Xuyên layer | [Resource/benchmark contract](../../requirements/RESOURCE_PROFILES.md) | Typed budgets, calibration, liveness, accounting và evidence |
| Traceability | [Gap resolution và contract cases](../../testing/UDG_CONTRACT_ACCEPTANCE.md) | 30/30 gap dispositions, examples/oracles, planned tests |

## 2. Các quyết định thiết kế đã chọn

1. P0 chỉ KEY/POSITIONAL, một table mỗi nguồn; XLSX/CSV/TSV và tối đa một ảnh reviewed OCR. 1 GB/source và cả hai PDF giữ scope đã chốt.
2. Source snapshot read-only, bounded raw row store; compare chỉ đọc snapshot frozen. Không đọc nguồn sống để lấp metadata thiếu trong khi compare.
3. P0 KEY dùng external sort + merge join trên canonical key bytes, không thử ghép Cartesian duplicate buckets. SQLite là result/index store tùy adapter, không làm cơ sở tuyên bố O(R).
4. SHA-256 với domain separation cho signatures; hash bằng nhau luôn kiểm bytes. Key và exact-content signatures tách biệt; tolerance không tham gia join/hash grouping.
5. Không auto-accept mapping/axis/key từ confidence. Score chỉ xếp gợi ý; user confirmations là gate. ORDERED/MULTISET là extension, fail closed khi không có căn cứ identity.
6. Batch commits vào staging generation; publish immutable result bằng commit marker sau audit. Không giữ transaction suốt một region.
7. COMPLETED có thể chứa uncertainty đã được kiểm đếm đầy đủ; scope đọc dở không export. Cancel/restart không tái dùng partial READY hoặc checkpoint của attempt cũ.
8. Resource profiles là input bắt buộc có finite limits và calibration evidence; không có profile hợp lệ thì chặn enable. Không biến số thiết kế chưa đo thành benchmark hoặc âm thầm hạ trần sản phẩm.

## 3. Pipeline và invariants

`select → inspect → scope/review → parse/validate EOF → freeze A/B → confirm mapping/policy/direction → canonicalize → build global key index → align → typed diff → audit/publish → query/export`.

Một số thao tác đọc/preview/index có thể overlap trong cùng attempt; chỉ artifact frozen và lineage hiện hành được dùng qua trust boundary. L9 điều phối toàn pipeline. Persistence L8 phục vụ ngay từ Input, không đợi diff xong mới ghi.

Invariants: nguồn không đổi; không fabricated provenance; không implicit coercion; match một–một; unresolved không thành fake added/removed; summary đúng mẫu số; attempt cũ không commit; report/export không tự chạy lại semantics; không cloud fallback; raw scratch chỉ tồn tại khi consumer hợp lệ cần.

## 4. Version và migration

| Thành phần | Version thiết kế hiện hành | Compatibility |
| --- | --- | --- |
| UDG algorithm design | 3.1.0 | Thay thiết kế v3.0 gốc theo các contract trong index này |
| Canonical encoding | CE-1 | Không tương thích record hashes ad-hoc cũ; rebuild canonical/index/cache |
| Input snapshot/OCR handoff | ISC-1; Input extension target 0.2.0 | Wire JSON Schemas 0.1.0 vẫn giữ nguyên; conversion/gates được mô tả tại Input, chưa có validator 0.2.0 |
| Worker protocol | WP-1 | Receiver từ chối version không hỗ trợ; không đoán message shape |
| Engine result | ER-1 | Tách với renderer report schema 1.0.0; explicit bridge tại Report |
| Export request/manifest | EX-1 | Một attempt/output per kind; result lineage bất biến |
| Resource contract | RP-1 | Profile instance phải có calibration revision và evidence trước enable |

Không có migration tự động từ partial v3 JSON sample sang VERIFIED ER-1. Snapshot đã hoàn tất chỉ convert khi có đủ source refs/trace/coverage/counts; thiếu thì re-import/recompare. Input0.1→target0.2 không thêm trường vào schema cũ tại chỗ. Bản PDF/DOCX v3 gốc không được coi đã cập nhật chỉ vì Markdown mới có version.

## 5. Ranh giới hoàn thành

**Hoàn thành đặc tả:** 30 gaps có quyết định/hợp đồng, examples, error/budget behavior và acceptance refs tại registry; không còn phải tự chọn thuật toán hoặc state semantics khi bắt đầu hiện thực P0. **Chưa hoàn thành nghiệm thu:** named reviewers/academic OCR sign-off, schema/validator implementation, parser/renderer PoC, profile calibration và device tests. Những việc này không được đánh dấu PASS bởi lần cập nhật docs.
