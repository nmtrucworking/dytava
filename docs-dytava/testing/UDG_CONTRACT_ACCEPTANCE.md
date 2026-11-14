---
document_id: DYT-QA-UDG-001
version: 1.0.0
status: DRAFT
owner: QA contract role
reviewer: Technical review role; assignee pending
updated: 2026-11-13
specification_state: SPECIFIED_PENDING_REVIEW
execution_state: NOT_RUN
---

# UDG 3.1 — gap resolution và contract acceptance

Nguồn chính: [UDG3.1 index](../specs/engine/README.md). 30 gap IDs thuộc [review v3](../project/DYTAVA_UDG_v3/LAYERED_SPEC_REVIEW.md); bảng dưới đây chỉ ghi disposition/reference. **SPECIFIED** nghĩa đã có quyết định/hành vi/error/budget/acceptance trong docs; không là APPROVED, IMPLEMENTED hoặc VERIFIED. Không có runtime test, profile calibration hay executable schema mới được chạy/tạo trong công việc này.

## 1. Gap resolution — 30/30 có contract

| Gap ID | Quyết định trong đặc tả | Contract owner / acceptance |
| --- | --- | --- |
| UDG-L0-01 | P0 capability matrix đúng scope, extension disabled | [Execution plan §1](../specs/engine/01_execution_plan.md); UDG-TC-001 |
| UDG-L0-02 | RP-1 typed finite dimensions và enable gate, thiếu calibration chặn | [RP-1 §1–3](../requirements/RESOURCE_PROFILES.md); UDG-TC-002 |
| UDG-L1-01 | Mutable/non-seekable nguồn copy immutable rồi parse cùng hash | [ISC-1 §1](../specs/input/11_streaming_snapshot_contract.md); UDG-TC-003 |
| UDG-L1-02 | Preflight order, actual counters, guard trước allocation/cleanup | [ISC-1 §1/5](../specs/input/11_streaming_snapshot_contract.md); UDG-TC-004 |
| UDG-L2-01 | Common SnapshotDescriptor/cursors và target0.2 OCR receipts | [ISC-1 §3–4](../specs/input/11_streaming_snapshot_contract.md); UDG-TC-006 |
| UDG-L2-02 | SST decompressed spool + disk ordinal index | [ISC-1 §2](../specs/input/11_streaming_snapshot_contract.md); UDG-TC-005 |
| UDG-L2-03 | Metadata pass trước data/freeze, EOF safety plan | [ISC-1 §2–3](../specs/input/11_streaming_snapshot_contract.md); UDG-TC-005 |
| UDG-L3-01 | GF-1 deterministic feature vector, không auto-accept P0 | [Geometry §3](../specs/engine/02_geometry_mapping.md); UDG-TC-007 |
| UDG-L3-02 | Reject overlapping scopes, merge refs không nhân cells | [Geometry §1/4](../specs/engine/02_geometry_mapping.md); UDG-TC-008 |
| UDG-L3-03 | Logical transpose bằng external ordered refs/cursors | [Geometry §5](../specs/engine/02_geometry_mapping.md); UDG-TC-008 |
| UDG-L4-01 | CE-1 source/key/content signatures riêng, verify bytes | [CE-1 §1–3](../specs/core/CANONICAL_ENCODING.md); UDG-TC-009/011 |
| UDG-L4-02 | Cấm tolerance/fuzzy join/MULTISET; comparison sau pairing | [CE-1 §4](../specs/core/CANONICAL_ENCODING.md); UDG-TC-010 |
| UDG-L4-03 | Byte/CFG grammar và dependency cache matrix | [CE-1 §1/2/5](../specs/core/CANONICAL_ENCODING.md); UDG-TC-009/010 |
| UDG-L5-01 | Full-scope grouping, duplicate/null ownership và absence proof | [Matching §2](../specs/engine/03_candidate_alignment.md); UDG-TC-012 |
| UDG-L5-02 | P0 external sort+merge, optional B-tree có equivalence proof | [Matching §2.3](../specs/engine/03_candidate_alignment.md); UDG-TC-011/012 |
| UDG-L5-03 | Cumulative candidate caps, truncation→unresolved; no fake absence | [Matching §4](../specs/engine/03_candidate_alignment.md); UDG-TC-013 |
| UDG-L6-01 | Conservative DP recurrence, identity predicate, path ties abstain, bounded traceback | [Matching §6](../specs/engine/03_candidate_alignment.md); UDG-TC-013 |
| UDG-L6-02 | Session-wide work counters, band certification, counted abstention | [Matching §4/6](../specs/engine/03_candidate_alignment.md); UDG-TC-013 |
| UDG-L6-03 | Movement flags không identity, MULTISET count ledger tách | [Matching §5/7](../specs/engine/03_candidate_alignment.md); UDG-TC-011/013 |
| UDG-L7-01 | Core verdict precedence bốn trạng thái; changes là flags | [Comparison §1](../specs/core/COMPARISON_DECISIONS.md); UDG-TC-014/015 |
| UDG-L7-02 | Decimal/date/formula/cache decision tables và extension gates | [Comparison §2–3](../specs/core/COMPARISON_DECISIONS.md); UDG-TC-014 |
| UDG-L7-03 | Semantic text exact compare riêng highlight budget/omission | [Comparison §4](../specs/core/COMPARISON_DECISIONS.md); UDG-TC-014 |
| UDG-L8-01 | ER-1 ownership/pairs/cells/structural counters độc lập | [ER-1 §1–2](../specs/engine/04_result_runtime.md); UDG-TC-015 |
| UDG-L8-02 | Batch idempotent staging commits, constraints và publish marker | [ER-1 §3–4](../specs/engine/04_result_runtime.md); UDG-TC-016 |
| UDG-L8-03 | Full vs partial vs uncertainty, validity registry, lease retention | [ER-1 §2/6/7](../specs/engine/04_result_runtime.md); UDG-TC-015/018 |
| UDG-L9-01 | WP-1 envelope/dedup/sequence/ack và stale guards | [WP-1 §5](../specs/engine/04_result_runtime.md); UDG-TC-016/017 |
| UDG-L9-02 | Byte credits/control reserve, chunk/yield, bounded writer/query | [WP-1 §5/7](../specs/engine/04_result_runtime.md), [RP-1](../requirements/RESOURCE_PROFILES.md); UDG-TC-017 |
| UDG-L9-03 | Checkpoint nội phiên khác restore; restart/revalidate, no raw history | [ER-1 §6–7](../specs/engine/04_result_runtime.md); UDG-TC-018 |
| UDG-L10-01 | Four export kinds, ER-1 stream JSON và legacy bridge guards | [EX-1 §2–4](../specs/report/STREAMING_EXPORT_CONTRACT.md); UDG-TC-019 |
| UDG-L10-02 | Stable cursors, bounded PDF plans/fonts, publish/rollback | [EX-1 §1/5/6](../specs/report/STREAMING_EXPORT_CONTRACT.md); UDG-TC-019/020 |

**Disposition của tất cả 30 hàng: SPECIFIED; review/implementation/execution: PENDING/NOT_VERIFIED.** Numeric calibration là external evidence dependency có quy trình và fail-closed behavior rõ, không được ghi thành design gap đã “đạt hiệu năng”. Existing Input/report executable schema migrations vẫn NOT_IMPLEMENTED; owner/reviewer cá nhân chưa được chỉ định.

## 2. Registry UDG-TC-001..020 — toàn bộ PLANNED/NOT_RUN

Các IDs dưới đây định nghĩa đúng một lần tại đây. Đây là contract-level expected behavior, cần fixture/runner độc lập khi bắt đầu implementation; không thay INP/Core/LARGE/REP registries.

| ID | Procedure / oracle | Expected |
| --- | --- | --- |
| UDG-TC-001 | Enumerate format/platform/mode/phase combinations; thử image-image, multi-sheet batch, ORDERED P0 | P0 đúng capability matrix; unsupported combinations blocked, không silent fallback |
| UDG-TC-002 | Missing/zero/infinite profile dimensions, per-segment cap>session cap, enabled claim không evidence | Reject CONFIG_INVALID/RESOURCE_PROFILE_NOT_ENABLED; source cap không tự giảm; positive full1GB gate vẫn cần |
| UDG-TC-003 | Provider đổi bytes sau inspect, non-seekable/reopen mismatch, source revoke | Parse immutable bound spool hoặc SOURCE_CHANGED; hash/rows cùng bytes; no source writes |
| UDG-TC-004 | Exact byte−1/boundary/+1; unknown size; ZIP claimed expansion nhỏ nhưng actual vượt; disk full trước allocation | Actual count gate đúng; guard/error observed-limit-profile rõ; cleanup, no READY |
| UDG-TC-005 | SST/cardinality cao/inline/rich text, styles/merges sau sheetData, invalid SST ordinal, sparse dimensions lớn | Correct text/metadata/provenance trước freeze; disk index bounded; invalid refs reject, no dense expansion |
| UDG-TC-006 | Convert resolved tabular0.1→target0.2; image config0.1; OCR receipts khác crop/grid/text revisions | New target snapshot ID/digest; image conversion reject; stale receipts block dù confidence1.0 |
| UDG-TC-007 | Ambiguous row/column samples, equal feature vector, missing timeline parse profile | GF-1 stable proposal order, null missing features; luôn confirm, no auto-axis/key |
| UDG-TC-008 | Overlap regions; group merged anchor; transpose wide sparse view; cancel mid-view build | Overlap blocked, no duplicate aggregate cells, real source refs, logical cursor repeatable; no partial frozen view |
| UDG-TC-009 | CE-1 framing vectors, invalid lengths/UTF8, decimal scale/NFC differences; CFG duplicate keys/permuted object keys | Byte equality theo contract; reject malformed; same effective object same digest, arrays order-sensitive |
| UDG-TC-010 | Tolerance chain, numeric key leading zeros, same raw different source locale; policy/map/encoding changes | No tolerance key/MULTISET; identifier loss unresolved; cache invalidates đúng dependencies |
| UDG-TC-011 | Golden G1 bên dưới, mock same hash/different bytes, KEY vs POSITIONAL reorder | One key pair per valid unique key, modified không delete+insert; hash collision detected; no false definitive MOVED |
| UDG-TC-012 | Same key ở different runs/partitions, huge duplicate bucket, invalid-key opposite side | All duplicates globally unresolved; no Cartesian/first-match; absence không chứng minh→unresolved |
| UDG-TC-013 | ORDERED two optimal paths/no anchors, many small segments exceed session budget, uncertified band, truncated top-k, MULTISET duplicates | Extension gate; ties/band/truncation abstain với full ownership; no silent unmatched; count-group không giả paired cells |
| UDG-TC-014 | Four-state decision table, formula missing/stale cache, serial60, text highlight vượt cap | Correct verdict/reason/flags; extension support explicit; omission highlight không thay verdict |
| UDG-TC-015 | Count ledger G1/G2/G3; zero denominator; all records counted unresolved vs input prefix only | Conservation, no mixed units, rates N/A; counted uncertainty có thể COMPLETED; prefix never exportable |
| UDG-TC-016 | Crash trước/sau batch commit/ACK/publish; duplicate batch/message same vs different checksum | Idempotent counters/rows; conflict fail; only durable published generation visible |
| UDG-TC-017 | Queue byte full và CANCEL; worker synchronous loops; sequence gaps/stale events; writer reader pressure | Control nhận trong configured bound, yield, ack sau stop/cleanup; no stale commit; WAL/process bytes accounted |
| UDG-TC-018 | Kill/restart partial parse/compare/export; multiple consumers; permission revoked after READY; close session | Restore SELECTED/revalidate, no resume prefix; no orphan/raw history; active evidence không xóa sớm |
| UDG-TC-019 | Deep keyset pages/filter mismatch; ER-1→legacy bridge count overflow/unsupported provenance; JSON UTF8/escape boundaries | No skip/dup; mismatched cursor reject; no rounded counts/lost refs; bridge unsupported blocked; JSON valid streamed |
| UDG-TC-020 | Full/filtered PDFs long Vietnamese cells/wide bands, unsafe CSV/PDF content, provider lacks pending commit, cancel/publish ACK loss | One complete artifact/kind, counts/text coverage, no execution/network, fail destination early, retry no duplicate output |

## 3. Golden examples có thể review ngay

### G1 — keyed modified, reorder và added

Mapped fields: strict IDENTIFIER `id` và DECIMAL `score`, same physical/lexical input types, no tolerance; `A_TO_B`:

| A ordinal | id | score | B ordinal | id | score |
| --- | --- | --- | --- | --- | --- |
| 1 | SV001 | 8.5 | 1 | SV002 | 8.0 |
| 2 | SV002 | 8.0 | 2 | SV001 | 8.7 |
| — | — | — | 3 | SV003 | 9.0 |

Oracle: A2 records/B3 records; matched pairs2; unmatched A0/B1; unresolved ownership0/0. Four matched-cell pairs: EXACT3, DIFFERENT1, EQUIVALENT0, UNRESOLVED0. Modified records1, unchanged1; added rows1, removed0. Key `SV001` pair giữ identity; score change không DELETE+INSERT. Both matched pairs coordinate-shifted; definitive moved count không phát P0. Swap direction→added0/removed1, raw/pairs/cell verdicts không đổi. Rate exact/semantic agreement=3/4; inserted row cells không cộng denominator.

### G2 — duplicate keys toàn scope

A có2 records cùng keyK ở hai sort runs; B có1 record keyK. Oracle: matched0; unresolved_A2/B1; unmatched0/0; matched-cell denominator0→N/A. Không3 candidate edges làm count3 ở mỗi bên; không arbitrary pair rồi báo còn1 removed. Max bucket work không bao gồm all-to-all disambiguation P0.

### G3 — full uncertainty khác partial work

Full EOF snapshots mỗi bên3 records, tất cả ownership unresolved vì confirmed search rule abstention: `A=0+0+3`, `B=0+0+3`, no paired-cell denominator; result có thể COMPLETED+warnings, không “giống nhau100%”. Nếu parser mới đọc2/3 hoặc chưa biết total, no full snapshot, job PARTIAL/FAILED và export blocked dù prefix cells trông giống nhau.

### G4 — framing và không bắc cầu

`S("ab") = 0000000000000002 6162` (hex, U64BE length2); `S("c") = 0000000000000001 63`. Framed tuple `("ab","c")` khác `("a","bc")`. Booleanfalse tag01 khác integer0 tag04 và text“0” tag03. Decimal8.50 canonical `85@-1`; scale facet2 hoặc* tùy policy. Với tolerance0.1, chain0/0.09/0.18 không tạo một key/equality bucket chung.

## 4. Traceability và evidence

UDG cases gắn FR-001..018 theo [RTM](../requirements/TRACEABILITY_MATRIX.md), ownership scopes theo source contract. Positive1GB/full PDF vẫn theo LARGE-TC-001..008/REP-TC-001..012; parser/OCR theo INP-TC-001..040; semantic golden cũ giữ nguyên. Extension tests không được gộp thành P0 capability.

Một evidence record cần requirement_ids, gap_ids, contract_versions, test_id, status=NOT_RUN/PASS/FAIL, runner/build/commit, fixture hash/generator seed, device/profile/adapter versions, expected/observed counts/verdicts/coverage, raw samples/resource peaks, output integrity refs và redacted log links. Không điền measured fields bằng giả định. Documentation link/fence/hash checks chỉ là docs QA, không thay contract runtime PASS.

## 5. Handoff còn lại sau docs

Review/sign-off theo role đã ghi; chỉ định người thật/academic OCR sign-off; implement versioned Input0.2/ER-1/EX-1/WP-1 validators; parser/native/render compatibility PoCs; calibrate RP-1 instances; execute registries trên device/corpus; build/sign APK. Đây là các việc implementation/evidence tách khỏi phạm vi hoàn thiện docs, không có yêu cầu code được thực hiện trong lần này.
