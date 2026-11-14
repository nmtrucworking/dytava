---
document_id: DYT-UDG-MATCH-001
version: 1.0.0
status: DRAFT
owner: Algorithm matching role
reviewer: Semantic and performance review roles; assignees pending
updated: 2026-11-13
---

# Candidate generation và alignment — L5/L6

## 1. Mode eligibility

P0 KEY/POSITIONAL phải được confirm theo SRS §4.2; tự suy mode từ sample bị cấm. Extension MULTISET/ORDERED_SEQUENCE chỉ chạy khi capability/version/profile và policy đủ; thiếu thì `MODE_NOT_ENABLED`, không silent switch mode. Hashes/strict keys theo [CE-1](../core/CANONICAL_ENCODING.md); kết luận cell theo Core, không dựa candidate score.

`MatchPlan`: plan/job generation, mode, mapping/policy/encoding digests, input counts, matched-pair cursor, unmatched ownership cursor, unresolved ownership cursor, candidate coverage, rationale và end audit marker. Record ownership exactly một trong matched/unmatched/unresolved trong một scope. Candidate edges có thể nhiều, ownership không đếm theo edges.

## 2. P0 KEY: external sort + merge join

### 2.1. Build

Đọc canonical key tuples từ frozen records; valid key cần complete preserved identifier evidence và không null/parse ambiguity. Write frames `(full_key_bytes, key_signature, record_id, source_ordinal, payload_ref)` vào bounded sort runs. Sort comparator là unsigned lexicographic **full_key_bytes**, record_id tie-break chỉ để repeatability. Digest chỉ là accelerator/bucket hint, không identity và không comparator thay full bytes.

Run size bound theo bytes và records; fan-in bound theo file handles/buffers RP-1. Merge runs theo cùng comparator đến sorted global key cursor. Commit run checksums/counts, close inputs chỉ sau durable next run metadata; fail/cancel dọn abandoned runs. Không giữ tất cả run lists/payloads trong heap. Số passes/bytes reread/write ghi metrics.

### 2.2. Global validity và join

Một pass grouping sau external sort phát `(key_bytes, count, members_cursor)`, kiểm cả scope, không chỉ partition. Group count>1 ở bất kỳ bên→toàn bộ group cùng key ở cả A/B là `UNRESOLVED KEY_DUPLICATE`; không Cartesian fuzzy disambiguation P0. Single invalid/null key records→`UNRESOLVED KEY_INVALID` với source refs. Không chọn first/last record trong group.

Join hai global group cursors:

| A/B group | Kết quả |
| --- | --- |
| Count1 / Count1, full key equal | One matched pair, bất kể content hash đổi |
| Count>1 / bất kỳ cùng key | Unresolved ownership cho mọi member; không pair |
| Valid unique key chỉ một bên, opposite invalid_key_count=0 | Unmatched với confirmed absence trong valid-key universe→ROW_ADDED/REMOVED theo direction |
| Valid unique key chỉ một bên, opposite có invalid keys không biết giá trị | Unresolved `ABSENCE_NOT_PROVEN_INVALID_KEYS`; không khẳng định absence khi key của opposite rows chưa biết |
| Keys khác dù signature cùng | Hai group khác; full-byte compare xử lý collision |

Group/member metadata disk-backed, chỉ giữ count/offset/bounded buffer. Quá key length/parse budget là Input/normalization error hoặc unresolved theo affected scope; không bỏ qua row. Key changed mặc định không có entity link: nếu đủ absence proof thì removed+added, không tự ghép theo content similarity.

### 2.3. Index strategy và chi phí

P0 chọn external sort để full-scope uniqueness và bounded sequential merge có execution plan rõ. Sorting comparison work O(R log R) cộng key-byte comparisons; disk passes phụ thuộc run size/fan-in. Expected hash O(R) không dùng làm guarantee của path này.

SQLite lưu record IDs/refs/results và optional covering key lookup index; nếu adapter chọn B-tree lookup tối ưu thay merge phải chứng minh cùng grouping/collision/absence semantics, bound transaction/cache/I/O và benchmark query plan. Không default build tất cả indexes cùng lúc hoặc DB raw JSON copy nhiều lần. Hash partition extension phải có recursive spill/skew fallback về external sort; giant bucket không tự nới RAM.

## 3. P0 POSITIONAL

Zip logical record cursors theo confirmed view ordinals: pair `A_i ↔ B_i` đến min counts; tails của bên dài hơn là unmatched positional tails, labels theo direction. Không dò key/fuzzy/reorder để sửa pairing; UI ghi rõ “so theo vị trí” và warning khi profile gợi row shift. Same count reordered rows tạo changed cells, không infer insert/delete/reorder identity.

Mapped fields pair theo logical field IDs, không cần full row payload trong RAM. Unmapped fields structural events tách riêng. Input count/checksum mismatch hoặc cursor gap fail match-plan validation, không gọi đó là deletion.

## 4. Candidate coverage và caps

KEY exact join không cần all-to-all candidates. Extension candidate proposals ghi `search_scope`, eligible count, evaluated count, truncated bool, omitted reason, policy/version và complete/unknown coverage. RP-1 chặn total candidates/evaluations/bytes/tokens và elapsed; mọi counters cumulative toàn job, không reset theo segments.

Top-k chỉ UI proposal list, không đủ chứng minh unmatched. Đóng cả known bucket/segment thành unresolved được phép nếu mọi record được counted/owned với reason; otherwise job PARTIAL/FAILED, no export. Fuzzy ranking không tạo confirmed entity link. Manual acceptance tạo mapping/identity receipt gắn both record IDs/snapshot hashes, user action/revision; rerun affected plan generation, giữ audit.

## 5. MULTISET extension

Eligibility: unordered full-record exact canonical equivalence, không tolerance/fuzzy hoặc unresolved canonical field. External sort theo canonical record bytes/CE-1 signature+full verification; count multiplicity mỗi side. Với count a,b: common_count=min(a,b), residual counts theo direction. Không tạo arbitrary source-specific pairs cho identical duplicates.

Toàn bộ selected fields phải có cùng confirmed logical schema và encoder ở hai phía; unmatched fields hoặc field bị loại khỏi canonical record làm mode ineligible cho full-record comparison. Muốn so subset phải chọn/confirm scope khác trước, không drop fields trong matcher.

Result dùng ER-1 count-level group variant: member cursors A/B, common_count và residual_count, `identity_level=COUNT_GROUP`. Không phát matched-cell pair verdict hoặc rate cho instance pairs chưa xác định; aggregate metrics của mode có namespace riêng. P0 pair ledger không nhận COUNT_GROUP; extension phải khai capability serializer/query/export hỗ trợ variant đã đặc tả tại ER-1 trước enable, không ép vào record IDs giả. Với record nội dung đổi mà không key, multiset biểu diễn remove+add ở cấp group-count, không suy modified.

## 6. ORDERED_SEQUENCE extension — conservative ordered contract

### 6.1. Identity và recurrence

Sequence order phải có nghiệp vụ được user confirm. Match predicate `I(i,j)` chỉ true khi explicit stable identity fields strict-equal, complete và **unique toàn scope ở cả hai phía**. Không có fields như vậy thì chỉ dùng full canonical record equality cho alignment proposals; các repeated equal records không được instance-match tự động. Fuzzy similarity chỉ suggestions sau abstention, không substitution identity.

Chọn unit insertion/deletion costs=1, eligible substitution/match cost=0. `D(0,j)=j`, `D(i,0)=i`; `D(i,j)=min(D(i-1,j)+1, D(i,j-1)+1, D(i-1,j-1)+0 nếu I(i,j))`. Noneligible diagonal cost=∞. “Substitution” ở đây link cùng stable identity nhưng content có thể đổi; L7 mới quyết định cell. Không cộng fuzzy score vào equality/DP identity cost. Đổi costs/predicate là contract version change, cần corpus/calibration riêng.

Mỗi state giữ best cost và count paths đạt best capped ở2. Nếu full segment có ≥2 best paths, toàn segment unresolved `ALIGNMENT_TIE`; deterministic sort/tie-break không giải ambiguity identity. Conservative contract có thể abstain kể cả nhiều optimal paths cho cùng pairing; không claim tối đa coverage. Top candidates/scores chỉ để user review.

### 6.2. Anchors, band và traceback

P0 không dùng ordered; extension default **không tự khóa anchors từ equal hash**. Anchors chỉ dùng khi user xác nhận identity pairs/segmentation, monotonic/không overlap; conflicting anchors→review, không drop tự động. Nếu adapter đề xuất auto anchors, chỉ là proposals; chưa có proof/calibration thì không ràng buộc search space.

Preflight segment kiểm product area có overflow-safe arithmetic và counters toàn job. Với segment trong budget, giữ bounded full DP/backpointer store (RAM hoặc spill file theo profile), từng state lưu chosen predecessor khi unique và path-count. Reconstruct path O(n+m) reads sau complete endpoint; DP memory/time accounting tính cả metadata/traceback file. Rolling rows có thể dùng để score nhưng không được tuyên bố đã có path nếu không có reconstruction plan tương đương.

Banded DP chỉ được finalize nếu user xác nhận band/displacement là ràng buộc nghiệp vụ (ghi mode parameters/report scope), hoặc có certified optimality proof từ unbanded search. Default band heuristic không có proof→unresolved `SEARCH_BAND_UNCERTIFIED`, không claim exact global optimum dù path không chạm band edge. Quá DP/traceback/work budget→bounded abstention toàn segment đã counted; không chạy full DP fallback vô hạn.

## 7. Movement và invariants

Pair source positions khác→`COORDINATE_SHIFTED`, không tự `MOVED`: chèn một row có thể shift mọi row sau. P0 không phát definitive moved-entity count. Extension có thể báo `ORDER_RELATION_CHANGED` khi pair tham gia inversion giữa matched ordinals; không suy row nào “đã được di chuyển” từ một trong nhiều minimal edit scripts. Modified và position/order flags độc lập, không exclusive RecordStatus enum.

Conservation áp cùng selected scope, source A/B identity cố định, direction chỉ đổi labels. Unique pair constraints kiểm matchedA/matchedB; invalid/duplicate/unresolved records không tham gia paired ledger. Cumulative total input counts = matched ownership + unmatched + unresolved ở mỗi side. Pair bytes/provenance đi kèm trace, không dùng ordinal làm key cross-source.

## 8. Failure/examples/acceptance

External-sort checksum/cursor count lỗi→FAILED, không unresolved dữ liệu. Candidate/DP cap có thể đóng counted scope thành unresolved theo ER-1, còn Input chưa full validation→PARTIAL/FAILED. Cancel ở run flush/merge/DP chunk/traceback đóng handles và rollback staging generation; worker phải nhận control theo WP-1.

Examples: `SV001/8.5 → SV001/8.7` one pair+modified; duplicate key ở hai partitions unresolved toàn group; null key A có thể che absence B-only→unresolved; all-reordered KEY không false value change nếu payload equal; ORDERED two equal optimal paths→unresolved cả segment. Planned [UDG-TC-011/012/013](../../testing/UDG_CONTRACT_ACCEPTANCE.md), v3 F02–F05/F15/F16/F20, LARGE-TC-002/003/006.
