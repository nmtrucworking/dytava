---
document_id: DYT-UDG-RUNTIME-001
version: 1.0.0
status: DRAFT
owner: Architecture runtime and result contract roles
reviewer: Runtime and data integrity review roles; assignees pending
updated: 2026-11-13
result_contract: ER-1
worker_protocol: WP-1
---

# Result store, worker và lifecycle — L8/L9

Đây là execution extension của [Architecture](../../architecture/ARCHITECTURE.md). Cell verdicts theo Core, Input states theo INP-008; ER-1/WP-1 là logical contracts để hiện thực sau. Không phải SQL migration, live API hay schema validator đã có.

## 1. ER-1 result descriptor

| Object | Fields/type và constraints |
| --- | --- |
| ResultSnapshot | contract_version=`ER-1`, result_id, session/job_id, generation, plan_id/digest, state=`COMPLETED`, scope_completion=`FULL_SELECTED_SCOPE`, lineage, direction, mode, summary, ledger_refs/checksums, warnings, created_at |
| Lineage | Both artifact/snapshot IDs, source SHA-256/bytes/formats, selected scopes, import/config/extraction/adapter revisions, mapping/view/policy/CE-1/engine/profile versions/digests; không URI/token |
| RecordOwnership | side, snapshot/scope/record_id, ordinal, category=`MATCHED\|UNMATCHED\|UNRESOLVED`, pair_id hoặc unresolved_group_id hoặc unmatched_reason; exactly một category |
| RecordPair | pair_id, record_a_id, record_b_id, identity_rule/version, relation=`PAIRED`, content_state=`UNCHANGED\|MODIFIED\|UNRESOLVED`, flags[], field_pair_cursor_ref; unique A/B in scope |
| MatchedCell | cell_pair_id, pair_id, logical_field_id, source_ref_a/b, verdict bốn trạng thái, kind/flags[], rule_id/version, reason_codes[], raw/canonical/trace evidence refs; không đặt structural cell giả |
| StructuralEvent | structural_event_id, kind=`ROW_ADDED\|ROW_REMOVED\|FIELD_ADDED\|FIELD_REMOVED`, side, actual source_ref/member cursor, direction binding; không cell verdict |
| UnresolvedGroup | group_id, reason, owned_record_cursors A/B, counts A/B, candidate refs optional, search coverage/truncated/budget parameters, remediation; ownership count khác số edges |
| Warning | code/stage/severity, safe metadata và affected refs; không arbitrary raw string log |
| ResultValidity | result_id, current/stale/revoked, invalidation_reason/revision; mutable registry riêng, không mutate immutable snapshot bytes |

IDs là opaque stable IDs trong cùng frozen result; không chứa raw keys/PII. Deterministic logical ordering dựa source ordinals/field order và tie-break identity. Same lineage+policy có cùng semantic content; random session/job/time IDs bị loại khỏi canonical semantic comparison. Result ID không phụ thuộc pagination order.

Content state: mọi matched fields EXACT/EQUIVALENT→UNCHANGED; có DIFFERENT→MODIFIED; nếu không DIFFERENT nhưng có UNRESOLVED→UNRESOLVED. Nếu có cả DIFFERENT và UNRESOLVED: MODIFIED + flag `HAS_UNRESOLVED`, không mất uncertainty. Movement/type/formula/style flags độc lập; record modified/unchanged counts không cộng thêm vào ownership conservation.

Nếu không có mapped fields, pair có content_state=UNRESOLVED với reason NO_MAPPED_FIELDS; không vacuously kết luận UNCHANGED. Có thể hoàn tất structural-only comparison nếu confirmations đầy đủ, paired-cell denominator0 và rates N/A; không tạo cell verdict để lấp mẫu số.

### COUNT_GROUP variant cho MULTISET extension

Result mode MULTISET có `identity_level=COUNT_GROUP`, `record_groups` thay pair ownership ledger: group_id, verified canonical_content_digest/full_bytes_ref, members_a/b cursors/counts, common_count, residual_a/b, equivalence_rule/version và coverage. Mỗi source record thuộc exactly một group; `common=min(a,b)`, `residual_a=a-common`, `residual_b=b-common`. Với duplicate indistinguishable members, không chọn record cụ thể là residual. Structural count events dùng group_id/member-cursor và multiplicity, không fabricated source-specific row link.

Summary namespace `multiset`: input_count_a/b, common_multiplicity, residual_a/b, unresolved_a/b; conservation cộng theo multiplicities. `matched_record_pairs=0`, paired-cell denominator0/N/A; count-group common không gọi là cell EXACT. Query/export hiển thị group equivalence/counts/member refs, không vẽ một–một ngầm. Both count/evidence capabilities cần enabled riêng; KEY/POSITIONAL result vẫn `identity_level=INSTANCE_PAIR`, không trộn ledger variants trong một result.

## 2. Summary và coverage

| Counter | Unit / equation |
| --- | --- |
| input_records_a/b | Validated selected-scope record counts của snapshots |
| matched_record_pairs | Pair count; each side có cùng số MATCHED owners |
| unmatched_records_a/b | Confirmed absence/positional tails theo mode; direction đổi labels, không đổi counters source |
| unresolved_records_a/b | Distinct owned record IDs, không candidate edge count |
| matched_field_pairs | Mapping cardinality; unmatched fields riêng |
| compared_matched_cell_pairs | exact+equivalent+different+unresolved; chỉ cells có confirmed row/field pairs |
| structural_counts | Rows/fields thêm/xóa riêng; không cộng vào cell denominator |
| processed_scope, unresolved_scope | Full selected scope completion và uncertainty counts; two independent dimensions |

Invariants từ Core/SRS: `A=M+UA+RA`, `B=M+UB+RB`; `C=EXACT+EQUIVALENT+DIFFERENT+UNRESOLVED`; zero denominator→rates null + display N/A. Semantic agreement=(exact+equivalent)/C, unresolved giữ trong denominator. Counter types unsigned exact integers serialized decimal strings trong ER-1 JSON adapter để tránh runtime precision loss; không floating count. Rate numeric chỉ presentation, numerator/denominator giữ integer strings.

Bounded abstention hoàn tất: Input full-validated, every record owned, affected known segment/bucket explicitly unresolved và covered by ledger→COMPLETED có uncertainty. Parser chưa EOF, unknown remaining records, thiếu evidence/ledger hoặc system corruption→PARTIAL nếu có safe progress diagnostics, nếu không FAILED. PARTIAL không ResultSnapshot và không export. COMPLETED không có nghĩa “hai nguồn bằng nhau”.

## 3. Persistence, constraints và atomic publication

Stores logic: sessions/jobs, input snapshot descriptors, raw stores, canonical refs, key runs/indexes, match ownership/pairs, cell/structural ledgers, aggregates, staging batches, audit receipts, publish markers, consumer leases và minimal restore journal. FK/unique semantics bắt buộc dù adapter không dùng SQL.

Constraints tối thiểu: unique `(generation,scope,side,record_id)` ownership; unique `(generation,scope,record_a_id)` và tương tự B cho pairs; unique `(pair_id,logical_field_id)` cell pair; unique `(generation,producer_id,batch_no)` staging commit; refs không cross-generation; summaries khớp ledgers; record/field IDs thuộc declared snapshots/mapping. Không unique raw key toàn DB vì duplicate keys là dữ liệu cần báo, không DB insertion error.

Batch flow: reserve bytes/credits → compute ngoài write transaction → writer kiểm generation/idempotency/checksum → insert ledger+batch counts+checkpoint trong bounded transaction → durable ACK → release buffers. Replay cùng batch ID/checksum trả previous ACK, không insert/cộng lại; cùng ID khác checksum→FAILED INTEGRITY_CONFLICT. Transaction bound theo bytes/rows/elapsed profile; batch vượt bound split trước begin, không giữ transaction qua DP/await UI.

Finalize: close producers→verify END counts/checksums/current lineage→audit conservation/uniqueness/evidence→flush stores→writer transaction insert immutable snapshot+publish marker và state COMPLETED cùng nhau. Query/export chỉ thấy published generation. Fail trước marker discard staging; fail sau durable marker có thể re-read published result thay rerun, nhưng validity/recovery guards vẫn áp dụng. Không có per-session giant transaction.

Re-read sau mất ACK chỉ áp dụng khi live generation/leases và Input validity vẫn còn; sau process death phải theo restore/revalidation ở §6–7, không dùng commit marker để bypass startup sweep hoặc biến partial data thành READY.

Full result cursors phải enumerate cả exact/equivalent cells. Cho phép compact ranges/shared contexts khi từng verdict/evidence ref đã được xác định trong compare; expansion chỉ giải mã ledger, không chạy lại comparison trong UI/export. Difference-only ledger không đủ cấp FULL_COMPARISON capability. Aggregates incremental phải reconcile tại finalize; không chỉ tin counters trong progress messages.

## 4. SQLite boundary và query lifetime

Adapter có một logical writer queue. Reader dùng short-lived page queries/leases, không mở read transaction suốt người dùng xem grid hoặc render toàn PDF. Immutable result generation cho phép repeated page reads nhất quán mà không giữ lâu DB read snapshot. WAL/journal bytes tính vào disk budget; writer/checkpoint coordination phải được kiểm thử. [SQLite WAL](https://www.sqlite.org/wal.html) mô tả single-writer và checkpoint bị ảnh hưởng bởi readers; đây là lý do thiết kế bounded cursors/transactions.

Indexes theo access pattern: ownership by generation/scope/side/ordinal; pair by A/B IDs; cells by pair/field order; event filter/order with stable tie-break ID. Secondary indexes chỉ tạo khi query plan/benchmark justify, không mặc định mọi JSON field indexed. Native cache/mmap/WAL allocations nằm trong process budget, không chỉ Dart heap.

## 5. WP-1 envelope và delivery

Mọi command/event cùng envelope: `protocol_version=WP-1`, session_id, job_id, attempt_id, generation, producer_id, sequence_no (positive exact integer), message_id, correlation_id (nullable nếu root), plan_digest, input_snapshot_ids, mapping_revision, policy_digest, payload_type, payload. Progress timestamps optional nonsemantic; source access refs chỉ private broker channel, không public payload/log.

WP-1 JSON adapters serialize sequence/generation/count fields bằng decimal integer strings; binary/message adapters có thể dùng exact integer type khi roundtrip guaranteed. Reject leading-plus/fraction/overflow; không serialize large counters qua double rồi cast lại.

Sequence tăng theo producer/attempt/generation, không global across senders. Receiver dedup `(job,attempt,generation,producer,sequence)`; duplicate same content idempotent, khác content protocol error. Có gap→request bounded retransmission hoặc fail protocol; không tự bỏ terminal/counter events. Retries giữ message ID/idempotency key, new attempt phải ID/generation mới. Stale tuple bị discard, ghi safe count diagnostic, không commit.

| Payload type | Minimum payload / rule |
| --- | --- |
| START | plan_ref, profile_ref, input snapshot refs; worker ACK accepted/rejected trước work |
| PROGRESS | phase, unit_type, completed_units absolute committed, total_units nullable; monotonic trong cùng phase/revision |
| DATA_READY | artifact/cursor ref, byte_count/checksum, lease_id, batch_no; không workbook payload |
| CREDIT / RELEASE | consumer/ref/byte credits, lease; exactly-once effective release |
| NEEDS_REVIEW | issue/group refs, required action, checkpoint consistency; không raw candidates toàn scope |
| RESOLVE | confirmed receipt/revision; old plan invalid→new generation, không mutate old result |
| CANCEL | command_id/reason; control path riêng không sau data backlog |
| CANCEL_ACK | correlation command_id, stopped phases, durable boundary, cleanup status; chỉ sau stop/rollback/leases accounted |
| COMPLETED | result_id/publish_marker; không emit trước durable publish |
| FAILED / PARTIAL | safe code/stage, completion coverage, cleanup state; không reportRef usable |

Worker data channel byte-credit bounded; reserve trước allocate/enqueue, return credits sau consumer durable ACK/release. Producer không được giữ thêm backlog ngoài budget. Long CPU loops nhường event loop theo chunk-work/time budget để nhận CANCEL; polling một cờ chưa được message update không đủ. Helper isolates không share mutable state theo [Flutter isolates](https://docs.flutter.dev/perf/isolates); payload/file refs phải có ownership/lifetime.

## 6. Comparison state transitions

| From | Event/guard | To/effect |
| --- | --- | --- |
| CREATED | START + valid plan/capability/profile | VALIDATING |
| VALIDATING | Current snapshots/confirmations/leases valid | RUNNING |
| VALIDATING/RUNNING | Blocking user decision; safe checkpoint | NEEDS_REVIEW; no publish |
| NEEDS_REVIEW | RESOLVE changes effective plan | Cancel old work, new generation→VALIDATING |
| RUNNING | Producers END + full audit + atomic publish | COMPLETED |
| Active states | CANCEL accepted | CANCELLING; stop producers, release/rollback |
| CANCELLING | Work stopped/consistent cleanup boundary | CANCELLED + ACK |
| Active states | Known safe progress but selected work incomplete | PARTIAL; diagnostics only |
| Active states | Access/protocol/integrity/resource fatal error | FAILED; safe cleanup |
| Terminal state | Duplicate terminal/CANCEL | Idempotent ACK/already-terminal, không thêm result/summary |
| Any active state on process death | Startup journal inspection | INTERRUPTED historical job; Input restore SELECTED/revalidate, no automatic resume |

COMPLETED terminal không tự chuyển CANCELLED; nếu source/plan bị invalidated thì ResultValidity chuyển stale/revoked và chặn new query/export actions theo app contract. Đóng source handle bình thường sau frozen snapshot không giống permission revoke; nếu snapshot đủ evidence thì export không cần mở nguồn gốc. Explicit revoke/source change dùng Input invalidation rules.

## 7. Resources, cancellation và retention

RP-1 governs active workers/default schedule, in-flight bytes, writer backlog, work/timer/cancel budgets. Large workload start active source/sheet work unit=1; increase chỉ theo enabled profile chứng minh aggregate resource bound. Không tự tăng limits khi user chọn file lớn. New profile cần new job, không mutate hard budgets của job hiện hành.

Cancel đo request→observed→stopped→cleanup/ACK riêng. Batch loop yield, stream close, DB rollback/commit boundary và lease release phải có deadlines. Nếu worker không phản hồi, coordinator mark failed/interrupted, strong stop theo platform rồi startup sweep; không gửi fake CANCEL_ACK trước cleanup consistency. Retry finite theo RP-1 max_attempts, chỉ transient errors, new attempt tuple; corruption/unsafe/unsupported không retry vô hạn.

Attempt owns mutable scratch; frozen snapshot/result owners chuyển leases rõ. UI/export consumers giữ result/raw evidence khi đang dùng; session close releases; startup orphan sweep closes/deletes generation không live. History P0 chỉ minimal non-raw descriptors/counters/versions nếu user chọn, không retain file URI/raw/canonical/OCR/parsed stores mặc định. User-exported artifacts do user quản lý; không xóa chúng như temp. Không claim SQLite encryption hoặc background completion guarantee.

## 8. Acceptance

Planned [UDG-TC-015..018](../../testing/UDG_CONTRACT_ACCEPTANCE.md), INP-TC-034..038, LARGE-TC-005/006/008 và REP-TC-008/010/011. Need crash between batch commit/ACK, before/after publish, duplicate replay, stale completion after cancel, held reader/WAL pressure và cleanup with multiple consumers. No runtime verification trong docs update.
