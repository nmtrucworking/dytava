---
document_id: DYT-UDG-LAYERS-001
version: 0.1.0
status: SUPERSEDED
owner: TBD
reviewer: TBD
updated: 2026-11-13
release_baseline: P0 mở rộng; thuật toán DYTAVA_UDG_v3
review_method: Documentation only; no implementation inspection or benchmarks
---

# DYTAVA_UDG_v3 — đặc tả theo layer, điểm chưa hoàn thiện và performance

> **Historical gap assessment:** 30 gaps bên dưới phản ánh thời điểm review v3 gốc. Bản hoàn thiện hiện hành là [UDG3.1](../../specs/engine/README.md); [gap resolution](../../testing/UDG_CONTRACT_ACCEPTANCE.md) đã ghi 30/30 SPECIFIED với owner contracts/acceptance. Các chữ OPEN/đề xuất/điểm dừng trong body giữ làm lịch sử, không là trạng thái backlog mới. Implementation/benchmark vẫn NOT_VERIFIED.

## 1. Kết luận và giới hạn của lần review

**V3 là thuật toán chính, nhưng chưa đủ điều kiện coi là implementation-ready.** Thiết kế đã chọn đúng các hướng cần thiết: typed comparison, hybrid matching, provenance, bounded ingestion, disk-backed processing và audit. Khoảng trống lớn nằm ở hợp đồng giữa các bước, semantics khi hết budget, giới hạn công việc toàn phiên và sự nhất quán với baseline sản phẩm.

Phân tích dựa trên [v3 gốc](DYTAVA_Unified_Data_Geometry_Engine_v3.md), [SRS](../../requirements/SRS.md), [NFR](../../requirements/NFR.md), [Architecture](../../architecture/ARCHITECTURE.md), [Input](../../specs/input/README.md), [Core semantic spec](../EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md), [ADR](../../decisions/ADR_REGISTER_P0_2026-11-11.md), [scope mở rộng](../../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) và [Report spec](../../specs/report/README.md). Không đọc mã triển khai, không đánh giá capability runtime hiện có, không tạo schema executable hoặc test runner.

**Mức chắc chắn:** phát hiện xung đột/còn thiếu là kết luận review docs; độ phức tạp là phân tích thiết kế có giả định; các biện pháp bổ sung là đề xuất DRAFT; mọi throughput, peak memory và latency thực tế đều **chưa đo**. Việc tài liệu khác mô tả PoC không được dùng làm bằng chứng trong lần review này.

`BLOCKER` dưới đây nghĩa cần đóng trước khi triển khai phần bị ảnh hưởng. `HIGH` cần hoàn thiện trước khi công bố đúng/đủ năng lực; `MEDIUM` cần chốt trước khi bật tính năng mở rộng. Mức này khác với thứ tự giao sản phẩm P0/P1/P2. Mọi gap trong tài liệu có trạng thái **OPEN**; viết được hướng xử lý chưa làm gap thành CLOSED.

### 1.1. Các phát hiện ưu tiên

| Ưu tiên | Vấn đề | Tác động | Layer |
| --- | --- | --- | --- |
| BLOCKER | Scope v3 lệch baseline: thiếu CSV/TSV, OCR P0, 1 GB và hai PDF; multi-sheet/ordered được đẩy sớm | Triển khai đúng v3 gốc vẫn có thể sai yêu cầu sản phẩm | L0 |
| BLOCKER | CellStatus v3 không khớp bốn kết luận Core/SRS | Mất EXACT, trộn flags với kết luận, lệch summary/export | L7–8 |
| BLOCKER | Chưa tách identity hash, exact content hash và tolerance comparison | Ghép sai, bỏ sót thay đổi hoặc sai MULTISET | L4–6 |
| BLOCKER | DP budget thiếu tổng công việc, chi phí similarity và traceback | Bounded từng đoạn nhưng phiên vẫn quá tải | L6, L9 |
| BLOCKER | Checkpoint, resume và retention khác ADR-009/Input | Khôi phục dữ liệu chưa hợp lệ hoặc giữ dữ liệu ngoài policy | L8–9 |
| HIGH | SQLite/index chỉ là starter, transaction một region có thể rất lớn | Write amplification, WAL tăng, cancel/commit chậm | L5, L8–9 |
| HIGH | Chưa có profile tài nguyên định lượng hoặc benchmark device | Chưa thể xác nhận 1 GB, RAM hay thời gian xử lý | Tất cả |

## 2. Ownership, baseline và phân lớp

V3 sở hữu **thiết kế thuật toán tổng thể**: geometry → canonical records → candidates → alignment → diff → audit, cùng yêu cầu tích hợp streaming/runtime. Các owner chuyên trách tiếp tục sở hữu contract của mình theo [Document Control](../../governance/DOCUMENT_CONTROL.md). Tài liệu này tham chiếu chúng và đề xuất cách nối; không tạo định nghĩa semantic hoặc wire schema cạnh tranh.

| Chủ đề | V3 gốc | Cách áp dụng trong đặc tả phân lớp |
| --- | --- | --- |
| Định dạng và OCR | §0.1 P0 hai XLSX; OCR P2 | P0 XLSX/CSV/TSV, tối đa một PNG/JPEG đã review; OCR recognizer ngoài core, adapter handoff vẫn P0 theo FR-012 |
| Phạm vi bảng | §0/§14 mở rộng nhiều sheet, region | P0 inventory/chọn một table/scope mỗi nguồn theo FR-002; batch nhiều sheet/region giữ roadmap, không suy ra từ trần 1 GB |
| Mode | §7 hybrid, gợi ý tự chọn | P0 KEY/POSITIONAL phải confirm theo SRS §4.2; ORDERED_SEQUENCE/MULTISET là extension có capability và review riêng |
| Năng lực lớn | §0.1 indexing ngoài RAM ở P1; §13 T4 cho phép reject | P0 mở rộng cần disk spill/external matching khi cần; valid corpus tới 1 GB/source phải chạy hết theo LARGE-TC-*. Safe rejection không thay positive gate |
| Export | §0/§15 JSON/CSV; có PARTIAL report | P0 có CSV/JSON và hai PDF; chỉ snapshot COMPLETED hiện hành được export theo Report §1; partial chỉ là trạng thái tiến độ/chẩn đoán |
| Cell semantics | §8 EQUIVALENT/VALUE_CHANGED/... | Dùng bốn kết luận Core; type/formula/style là flags, không thêm trạng thái thứ năm |
| Recovery | §5.2/§10/§12 checkpoint/resume | P0 restore SELECTED, revalidate/restart theo ADR-009/INP-008; checkpoint nội phiên không cấp quyền resume partial import sau kill |
| Retention | §10.2 complete session giữ theo người dùng | Mặc định chỉ giữ scratch khi consumers cần, cleanup khi release/close/fail/cancel; history tối thiểu không mặc nhiên giữ raw/parsed data |

Phân lớp logic:

```text
L0 Confirmed comparison plan
  → L1 Source access / preflight
  → L2 Physical parse / validated Input snapshot
  → L3 Geometry / mapping / confirmed record schema
  → L4 Policy / canonicalization / typed encoding
  → L5 Candidate indexes
  → L6 Alignment / match plan
  → L7 Typed cell comparison
  → L8 Audited immutable result
  → L10 UI queries / review / exports

L9 điều phối mọi bước: worker, budgets, backpressure, cancel, revisions.
L8 cung cấp persistence cho L2–L7; không phải chỉ lưu ở cuối pipeline.
```

### 2.1. Hợp đồng chung cần hoàn thiện

Mỗi artifact trung gian phải truy về source snapshot IDs/hashes, selected scopes, import/adapter revision, mapping revision, policy digest khi đã có, engine version và mode/direction đã xác nhận. L0 được phép tạo kế hoạch sơ bộ; chỉ freeze kế hoạch compare sau khi Input READY và confirmations hiện hành.

Mỗi batch/cursor cần identity, thứ tự ổn định, phạm vi nguồn, giới hạn **bytes và units**, chủ sở hữu, thời điểm release, lỗi có cấu trúc và quy tắc cancel. Chưa có dữ liệu thì trả unknown, không giả lập số lượng hoặc tiến độ 100%. Proposal fields ở đây cần hợp nhất vào owner schemas trước triển khai; chưa là wire contract đã ban hành.

## 3. L0 — Scope, capabilities và kế hoạch chạy

**Input → output:** yêu cầu A/B + capabilities + selected scopes + confirmations + resource profile → kế hoạch chạy đã freeze. L0 kiểm tra đủ preconditions, không tự suy key/locale/direction để vượt review gate.

**Đã có ở v3:** §0–3 xác định hybrid engine, invariants và các bước; §11 có tên resource dimensions.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L0-01 | BLOCKER | Scope lệch bảng §2 → lập capability matrix theo format × platform × mode × phase, liên kết FR/ADR; giữ phân biệt algorithm support và release support |
| UDG-L0-02 | BLOCKER | `device_profile_defined` chưa thành hợp đồng có version → profile thiếu hoặc không tương thích phải chặn enable; NFR là nơi chốt numeric budgets, không đặt default tùy ý tại từng layer |

**Performance:** không thể chọn strategy chỉ từ compressed file size hoặc sample. Preflight ước lượng có thể chưa biết expanded size/result size; kế hoạch phải mang estimate range, reserved headroom và kiểm đếm runtime. Chi phí inspect và full source hashing phải ghi riêng, tránh che một lượt đọc thêm dưới tên “khởi tạo”.

**Hoàn tất docs khi:** có bảng phase/capability, rules freeze/invalidate và profile reference hiện hành; xác định điểm dừng khi thiếu input/confirmation/budget. Acceptance kế hoạch: FR-001/002/005/006/012/016 và LARGE-TC-001/006.

## 4. L1 — Source access, preflight và fingerprint

**Input → output:** source handle read-only → validated access descriptor + bounded byte stream + fingerprint của đúng bytes đã parse. Đây là trách nhiệm Input, không đưa SAF URI vào Domain.

**Đã có ở v3:** §4 bounded ZIP checks; §10 input bất biến; §11 xử lý encrypted/invalid/resource limits.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L1-01 | BLOCKER | Chưa định nghĩa seek/reopen/non-seekable và source đổi giữa inspect/read → mô tả adapter capabilities, source copy khi cần, hash-on-read và snapshot invalidation; không dùng hash của lượt đọc khác để chứng minh parsed bytes |
| UDG-L1-02 | HIGH | Guard list chưa có thứ tự và ownership cleanup → chỉ rõ size known/unknown, incremental byte counting, zip-part counters và fail point trước cấp phát lớn; giữ INP error/profile refs |

**Performance:** một full read có chi phí tối thiểu theo tổng bytes nguồn thực đọc; non-seekable spool thêm ghi/đọc đĩa. Phải thống kê số full scans, bytes copied và provider latency. Hai nguồn có thể mỗi nguồn đạt 1.000.000.000 byte; source budget không bao gồm expansion/scratch/output, theo NFR §3. Chọn strategy hash/copy/parse cùng lượt khi contract cho phép, vẫn giữ snapshot consistency.

**Hoàn tất docs khi:** có access lifetime, read/spool decision table, counters/abort/cleanup và fingerprint binding. Acceptance kế hoạch: INP-TC-003/006/037, LARGE-TC-001/004/005/008; ZIP traversal/CRC/bomb từ v3 F17.

## 5. L2 — Parse vật lý và validated Input snapshot

**Input → output:** byte stream + ImportConfig → raw typed cells/rows, capabilities/losses, SourceRefs và repeatable snapshot descriptor. Sampling preview có thể sớm; READY chỉ sau EOF/hash/full validation theo INP-008.

**Đã có ở v3:** §4 relationship-based worksheet lookup, sharedStrings/styles, bounded batches và sparse cells.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L2-01 | BLOCKER | Contract `WorkbookReader` chưa bao quát CSV/TSV/OCR P0 và full validation → đặc tả handoff chung SourceTable tại Input; adapter riêng giữ CSV lines/records, XLSX coordinates và OCR polygon/review receipts |
| UDG-L2-02 | HIGH | “Spool/shared-string offsets” chưa nói offset ở đâu và lookup thế nào → chọn thiết kế immutable decompressed spool/index hoặc materialization có bounds; không coi offset trong XML nén là random-access rẻ |
| UDG-L2-03 | HIGH | Streaming rows nhưng metadata/styles/merged ranges có thể chỉ biết muộn → định nghĩa pass plan hoặc provisional records rồi freeze; không cấp READY khi hậu kiểm chưa hoàn tất |

**Performance:** theo expanded bytes XML/CSV thực xử lý, cộng shared-string/style lookups và spool I/O. SST chứa unique strings dùng chung workbook; file hợp lệ cũng có thể dùng inline strings. Rich text có nhiều runs cần fidelity rule riêng ([Microsoft SST](https://learn.microsoft.com/en-us/office/open-xml/spreadsheet/working-with-the-shared-string-table)). Suy ra cho thiết kế: streaming worksheet chưa đủ đảm bảo bounded RAM nếu SST/style index lớn; phải đo cache misses và unique-string bytes, không chỉ rows/s.

Chặn theo byte size của batch/cell/token và số lượng elements; `maxBufferedBatches` riêng lẻ không chặn được một batch chứa text rất dài. CSV quoted multiline/UTF-8 qua chunk, sparse XLSX và shared strings cardinality cao cần workload riêng. OCR phải bounded decode trước bitmap, giữ review gates; không lấy benchmark XLSX làm bằng chứng OCR.

**Hoàn tất docs khi:** mô tả parser passes, raw vs logical boundary, EOF/receipt gates, spool format lifecycle và error/loss propagation; numeric token không bị chuyển sang double ngoài policy. Acceptance kế hoạch: INP-TC-021..025/039/040, LARGE-TC-003/004, v3 F09/F17/F23/F24.

## 6. L3 — Geometry, regions, axis và mapping

**Input → output:** validated descriptors/SourceRefs + user choices → confirmed sheet/table/field mappings và logical record view. P0 một selected scope mỗi nguồn; geometry tự động chỉ là gợi ý.

**Đã có ở v3:** §5 sheet signatures, §6 sparse geometry, merged anchors, logical transpose và axis confidence.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L3-01 | HIGH | Score/δ chưa có feature definitions, labeled corpus hay tie policy → xác định inputs, missing features, confidence calibration và abstention; P0 yêu cầu confirm thay vì auto-accept từ sample |
| UDG-L3-02 | HIGH | Region overlap/merged propagation chưa gắn record ownership → mặc định cấm overlap khi aggregate một scope; roadmap overlap phải khai báo identity/counting theo scope, không cộng hai lần physical cells |
| UDG-L3-03 | MEDIUM | Logical transpose không copy nhưng chưa có scan/index plan → mô tả cursor theo trục, header mapping và locality; group propagation luôn có provenance về anchor gốc |

**Performance:** sheet candidates all-to-all tăng theo `S_A × S_B`; region candidates tương tự. Giảm bằng explicit mappings và blocking signatures, nhưng signature không chứng minh identity. Tra merged range không tự có O(1): cần chọn interval/spatial index, tính cả build/query/storage. Logical transpose giữ RAM thấp nhưng có thể làm I/O rời rạc; cần budget random reads/caches hoặc external ordering, không materialize full rectangle của sparse sheet.

**Hoàn tất docs khi:** có mapping confirmation/invalidation, overlap rule, axis tie cases, logical cursor và merge provenance. Acceptance kế hoạch: FR-002/005, v3 F10/F11/F12/F13/F22/F24; multi-sheet batch chưa là gate P0.

## 7. L4 — Policy, canonicalization, encoding và hash

**Input → output:** raw records + confirmed field policy → canonical typed records, trace refs và signatures có version. Core semantic spec tiếp tục sở hữu normalization/equality; Input không tự canonicalize.

**Đã có ở v3:** §6 typed records, §7 length-delimited keys, §8 typed hashing và không dùng fuzzy làm equality.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L4-01 | BLOCKER | Một “record hash” chưa tách identity/content → định nghĩa key signature cho join, exact canonical content signature cho candidates, source SHA-256 cho bytes; kiểm tra full key/content tương ứng khi hash bằng nhau |
| UDG-L4-02 | BLOCKER | Tolerance/unit/casts có thể không phù hợp quan hệ equivalence để hash → cấm tolerance/fuzzy làm key hoặc MULTISET fingerprint theo Core §5.6; comparison policy quyết định sau pairing |
| UDG-L4-03 | HIGH | Chưa có canonical byte grammar/cache key đầy đủ → đặc tả type tags, field IDs/order, length framing, missing/null/empty, decimal scale/sign, Unicode mode, source-side locale và version digest; reject unsupported policy operations |

**Ví dụ cần khóa semantics:** khóa `SV001` giữ nguyên, điểm `8.5 → 8.7`: keyed matcher vẫn ghép record, L7 báo khác. Hash toàn record thay đổi không được biến thành DELETE+INSERT. Với tolerance 0.1: `0 ~ 0.09`, `0.09 ~ 0.18` nhưng `0 !~ 0.18`; không thể gom thành một lớp hash equality bắc cầu. Hai ví dụ này là reasoning từ contract, chưa là output runtime.

**Performance:** canonicalization/hash tỷ lệ với **bytes/token thực xử lý**, cộng chi phí decimal/Unicode/trace; O(cells) chỉ hợp lý nếu cell length bị chặn và tính rõ bound. Cache canonical values theo snapshot + adapter/import + mapping + field policy + normalization/encoding/engine versions. Chỉ tái sử dụng khi đủ lineage, không cache mỗi `rawValue`. Đo bytes normalized, normalization passes và trace bytes; trace inline đầy đủ trên mọi cell có thể chiếm phần lớn scratch.

**Hoàn tất docs khi:** có grammar và golden bytes minh họa composite key/collision/null/decimal/NFC; chia identity/content hashes; cache invalidation matrix. Acceptance kế hoạch: Core TC-01..10 phù hợp từng rule, v3 F04/F06/F07/F15/F19; không tự thêm ngưỡng fuzzy.

## 8. L5 — Disk indexes và candidate generation

**Input → output:** canonical records/signatures → bounded candidate references, key buckets, duplicate/null diagnostics và candidate coverage. Không xuất candidate payload cả workbook sang UI.

**Đã có ở v3:** §7 key buckets/hash verification; §10 SQLite starter/index; §13 expected hash lookup.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L5-01 | BLOCKER | Duplicate/null checks chưa quy định toàn scope qua partitions → finalize key validity sau khi kiểm hết scope; bucket lớn thành unresolved, không chọn first-match hoặc chỉ check trong batch |
| UDG-L5-02 | HIGH | Chưa chọn hash-partition/external-sort/B-tree plan → ghi rõ build cost, probe order, collation/binary equality, spill/merge fan-in và collision verification; DDL starter chưa là execution plan |
| UDG-L5-03 | HIGH | Fuzzy candidates/large duplicate bucket chưa có cap và completeness marker → bound candidate pairs/bytes/work; nếu cap loại bỏ khả năng xác minh, vùng đó unresolved thay vì kết luận unmatched |

**Performance:** hash index RAM có kỳ vọng lookup O(1) với giả định phân bố/tải phù hợp; SQLite index không tự có đặc tính đó. Tài liệu [SQLite query planning](https://www.sqlite.org/queryplanner.html) mô tả lookup theo index và chi phí tìm kiếm phụ thuộc số rows. Với B-tree plan, phân tích build/probe cần tính logarithmic searches, số hits và I/O; không gán O(R) chung cho mọi disk index.

Hash-partition cần bounds khi skew/collision/bucket quá lớn; external sort cần bounded runs, merge fan-in và scratch cho từng lượt. Một bucket có `a_i` và `b_i` records có thể sinh `a_i × b_i` candidate pairs nếu thử mọi cặp. Full-key verification không miễn phí khi nhiều collision hoặc keys dài. Tách chỉ số index build time, probe time, candidate count, max bucket, bytes reread và page-cache misses.

**Hoàn tất docs khi:** có strategy decision table theo workload, global duplicate invariant, candidate caps/fallback và projection fields; xác định mức completeness khi dừng. Acceptance kế hoạch: Core TC-10, v3 F05/F15/F20, LARGE-TC-002/003/006.

## 9. L6 — Alignment và matching một–một

**Input → output:** candidate graph/index + confirmed mode → match plan gồm matched pairs, unmatched hai phía, unresolved ownership và rationale. Match plan chưa phải kết luận các cell bằng nhau.

**Đã có ở v3:** §7 KEY/ORDERED/POSITIONAL/MULTISET/manual; conservation; bounded DP và abstention.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L6-01 | BLOCKER | DP chưa định nghĩa recurrence/cost/tie và traceback → đặc tả INSERT/DELETE/SUBSTITUTE, stable fields, anchor validation, deterministic ties, traceback memory và abstention; không tự kết luận fuzzy high score là cùng thực thể |
| UDG-L6-02 | BLOCKER | `maxDpCells` chưa nói segment/region/session và score cost → có counters tổng visited states, similarity bytes/tokens, candidate evaluations, elapsed/inactivity; timeout/budget exhaustion không biến remainder thành insert/delete |
| UDG-L6-03 | HIGH | MOVED và duplicate identity chưa tách khỏi matching → định nghĩa coordinate shift vs relative-order move, count-level vs instance-level MULTISET và manual override lineage; key đổi không tự giữ identity |

**Performance:** KEY unique dùng index theo L5; POSITIONAL zip hai record cursors tuyến tính theo records và field bytes đọc. ORDERED không có anchors có worst-case `n × m` DP states; với `n=m=500.000`, đó là **250.000.000.000 states**, chưa tính scoring/traceback. Đây là phép tính lý thuyết, không phải benchmark.

Bounded DP time phải biểu diễn `Σ visitedStates_i × scoreCost_i`, cộng anchor construction và traceback. Nếu score tính lại trên nhiều field/text cho mỗi state, không được coi scoreCost = 1. Rolling rows cho score không tự trả được alignment path; cần bounded backpointers, chia để trị hoặc checkpoint/recompute với đánh đổi được ghi rõ. Banded alignment chỉ tìm trong band; khi không có bằng chứng optimal path nằm trong band, kết quả là giới hạn tìm kiếm/review, không được quảng cáo tương đương DP toàn phần.

Tổng công việc phải bị chặn trên **toàn session**, kể cả nhiều segments nhỏ đều dưới cap. Matching ties có cùng căn cứ phải unresolved; sorting ổn định chỉ đảm bảo reproducibility, không chứng minh identity. P0 chỉ bật KEY/POSITIONAL theo baseline; hoàn thiện ORDERED/MULTISET riêng trước khi enable.

**Hoàn tất docs khi:** có mode-specific algorithm contract, tie/threshold calibration protocol, band/fallback semantics, full-path space bound và counters toàn phiên. Acceptance kế hoạch: v3 F02/F03/F04/F05/F16/F20, conservation, direction swap; ORDERED/MULTISET được ghi test extension, không đổi SRS P0.

## 10. L7 — Typed diff và bốn kết luận cell

**Input → output:** matched record/field pairs + canonical values + policy/evidence → một kết luận `EXACT | EQUIVALENT | DIFFERENT | UNRESOLVED` mỗi matched-cell pair, cùng reason/trace và flags độc lập. Structural changes là events khác đơn vị.

**Đã có ở v3:** §8 typed comparison, formula/cache limitations và fuzzy không phải equality.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L7-01 | BLOCKER | V3 CellStatus không có EXACT, dùng change kinds như statuses → dùng precedence Core §5.6 và SRS §4.3; `VALUE_CHANGED/TYPE_CHANGED/FORMULA_CHANGED/FORMAT_CHANGED` là kind/flag; `UNDETERMINED` ở v3 ánh xạ UNRESOLVED với reason phù hợp |
| UDG-L7-02 | HIGH | Formula/cache/date/precision chưa đủ decision table → định nghĩa missing/stale cache, unsupported functions/metadata, serial 60 và source lexical loss; chặn mode không có capability; formula/style compare giữ P1+ |
| UDG-L7-03 | HIGH | Long-text highlight chưa có work cap → tách semantic verdict khỏi token diff trình bày; cap highlight thì giữ verdict và raw evidence, ghi highlight chưa đầy đủ |

Không suy EXACT chỉ từ canonical/hash bằng nhau: EXACT còn cần physical/lexical/typed evidence theo Core. `EQUIVALENT` phải có rule ID/version, trace và policy digest. Parser/policy/evidence thiếu thành UNRESOLVED hoặc lỗi job theo owner contract; không fallback string equality. Formula text giống nhau không chứng minh cached results đúng/mới; engine không recalculate.

**Performance:** typed comparison gồm field dispatch + bytes đọc/canonical comparison + trace persistence. Text highlight có thể tốn hơn exact compare đáng kể; chạy có budget riêng hoặc lazy khi mở detail, không làm mất kết luận. Lưu reference tới shared policy/trace context và evidence đủ tái kiểm tra, tránh sao chép toàn policy JSON vào mọi cell event.

**Hoàn tất docs khi:** có verdict precedence table, event/flags mapping, unknown/loss cases và long-text degradation rule. Acceptance kế hoạch: Core semantic golden, FR-008/009/010, v3 F06–F09/F19/F23. Không dùng pass formula extension làm điều kiện giả cho capability P0.

## 11. L8 — Audit, persistence và immutable result

**Input → output:** match plan + diff streams + scope completion → result store có counts/provenance, manifest và immutable audited snapshot. L8 phục vụ persistence từ đầu pipeline; chỉ finalize khi toàn scope được validate.

**Đã có ở v3:** §7.5 conservation, §10 DDL starter, §12 transaction/checkpoint và §15 export sample.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L8-01 | BLOCKER | §8 RecordStatus trộn MOVED với MODIFIED; §15 summary chưa có bốn verdict/count units → tách job state, row relation/content/movement, cell verdict, change flags và structural events; summary lấy từ validated ledger |
| UDG-L8-02 | HIGH | §12 transaction bao cả region; schema thiếu match links/constraints/revisions → mô tả bounded batch commits, staging generation, one-to-one uniqueness, commit marker và atomic result publication; chưa viết SQL migration |
| UDG-L8-03 | BLOCKER | PARTIAL/COMPLETE/export/retention chưa nối với baseline → mapping COMPLETE nội bộ sang COMPLETED tại result boundary có version; PARTIAL không phải snapshot được export; lịch sử mặc định không giữ raw dài hạn |

**Audit bắt buộc ở mức thiết kế:**

- Record counts trong cùng một selected scope: `A = matched + removed_A + unresolved_A`, `B = matched + added_B + unresolved_B`; matched count tính theo pairs, không tính thêm moved/modified. Direction ánh xạ labels theo SRS, không đổi source identity.
- Matched cell pairs: `compared = exact + equivalent + different + unresolved`; structural row/field events không cộng vào mẫu số. Mẫu số 0 cho rate N/A theo SRS §4.4.
- Không record nào thuộc hai one-to-one pairs; unresolved candidate graph quản lý record ownership riêng, không đếm một record nhiều lần theo số candidates.
- Count-level MULTISET của roadmap không giả vờ có source-specific pairing; schema phải phân biệt scope/count semantics trước khi bật.
- Snapshot final yêu cầu đầy đủ selected scope, Input EOF/hashes, current revisions, ledger consistency và không còn work bị bỏ qua. **COMPLETED có thể chứa UNRESOLVED verdicts** nếu toàn scope đã xử lý đúng contract; khác với incomplete work/PARTIAL.

Phải phân biệt **bounded abstention** với **bỏ dở scope**: nếu contract cho phép đóng toàn bộ một bucket/segment thành unresolved, mọi record đã được kiểm đếm và gắn reason/coverage rõ thì đó có thể là kết quả hoàn tất có uncertainty. Nếu parser chưa EOF, còn records chưa kiểm đếm, hoặc không đủ ledger để biết phạm vi còn thiếu thì là PARTIAL/FAILED, không được finalize/export. Top-k bị cắt không bao giờ đủ chứng minh một record là ADDED/REMOVED; `searchTruncated` và các provenance/reason tương ứng cần có trong result contract proposal.

**Performance:** ghi theo batch, lưu aggregates có thể audit với ledger và bounded result cursor; UI/export không mỗi lần scan lại toàn events. Dùng total ordering có tie-break ID và index phù hợp cho keyset pagination; OFFSET sâu có thể phải bỏ qua lượng rows lớn. Không nhét raw A/B, canonical, trace và policy nguyên bản lặp nhiều lần nếu có reference ổn định.

SQLite WAL cho concurrent reader/writer nhưng chỉ một writer tại một thời điểm; long-lived read transactions có thể cản checkpoint ([SQLite WAL](https://www.sqlite.org/wal.html)). Suy ra cho thiết kế: cần ownership writer, read-cursor lifetimes, batch transaction và WAL/scratch accounting. Không giữ một write transaction mở suốt CPU matching/diff của region lớn. Atomic publication là commit marker cho staging hoàn chỉnh, không buộc toàn session trong một transaction khổng lồ.

**Hoàn tất docs khi:** có result contract/version migration plan, state mapping, count equations, ledger uniqueness, publish/cleanup protocol và privacy lifetime. Acceptance kế hoạch: FR-007/013/014/015, REP-TC-* đối soát counts, LARGE-TC-005/007/008; chưa có runtime evidence.

## 12. L9 — Worker, scheduling, backpressure và lifecycle

**Input → output:** execution plan + bounded stages → tiến độ, review requests, cancellation và terminal job state. Đây là control layer xuyên L1–L10, không phải bước tính toán sau audit.

**Đã có ở v3:** §9 worker messages/cancel, §11 resource governor, §12 sequence và pseudocode.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L9-01 | BLOCKER | Ví dụ worker thiếu tuple/revision dù văn bản yêu cầu → thống nhất envelope protocolVersion/session/job/attempt/generation/sequence/revisions, ack/retry rules; stale/duplicate events không commit hoặc cộng summary lại |
| UDG-L9-02 | HIGH | Queue mới bound theo batches, chưa bound bytes/time/control path → budget tổng in-flight bytes, writer backlog và consumer credits; control/cancel không kẹt sau data queue; CPU loops phải nhường event loop để nhận cancel |
| UDG-L9-03 | BLOCKER | Checkpoint/resume sau kill khác Input baseline → tách checkpoint consistency nội phiên khỏi cross-process resume; P0 restore revalidate/restart, không phục hồi partial READY; scratch ownership và sweep theo ADR-009 |

**Performance:** helper isolates có bộ nhớ riêng và giao tiếp bằng messages; mutable payloads nói chung có chi phí copy, còn các cơ chế chuyển/ chia sẻ immutable data có quy tắc riêng ([Flutter isolates](https://docs.flutter.dev/perf/isolates)). Suy ra cho thiết kế: đo message bytes/serialization và tổng process memory, dùng cursor/file refs có lifetime rõ, không chuyển object graph workbook qua UI. Isolate cải thiện responsiveness khi tách compute nhưng không tự làm pipeline nhanh hơn.

Nhiều workers có thể cạnh tranh CPU, I/O, cache và single-writer SQLite. Default proposal là active sheet pair = 1 cho workload lớn, chỉ tăng sau benchmark có budget hợp lệ; đây chưa là profile đã ban hành. Governor phải tính memory **toàn process và native allocations**, DB cache/WAL, parser/SST, queues, renderer và UI cùng sống.

Cancellation latency phải đo riêng request→worker-observed, observed→work-stopped, stopped→cleanup/ACK. Chỉ gửi ACK sau boundary nhất quán. Nếu synchronous loop không nhường event loop, message CANCEL có thể chưa được nhận dù có kiểm cờ trong loop; cần đặc tả chunk/yield hoặc cơ chế interrupt phù hợp, chưa chọn implementation.

**Hoàn tất docs khi:** có transition/guard table cho comparison job tách khỏi Input state, envelope duy nhất, credits/queue ownership, cancel deadlines theo profile và crash/restart matrix. Acceptance kế hoạch: INP-TC-034..038, LARGE-TC-005/006, v3 F18/F21 và stale callback/retry không trùng events.

## 13. L10 — UI review, result queries và export

**Input → output:** immutable result snapshot + filter/template + user action → paginated detail, reviewed mappings hoặc một output artifact hoàn chỉnh cho mỗi export kind. Manual override tạo revision/job mới cho phần bị ảnh hưởng; không sửa âm thầm snapshot cũ.

**Đã có ở v3:** §15 virtualized grid, review queue, JSON sample, §16 UX/report stage.

| Gap | Mức | Chưa hoàn thiện → đặc tả cần bổ sung |
| --- | --- | --- |
| UDG-L10-01 | BLOCKER | JSON sample/in-memory events và thiếu hai PDF P0 → dùng Report spec/immutable result cursors; CSV_DIFF, JSON_REPORT, MERGED_DIFF_PDF, DYTAVA_REPORT_PDF; report schema sample v3 chưa thay renderer schema 1.0.0 |
| UDG-L10-02 | HIGH | Chưa có export cancellation/atomic publish và pagination fidelity → xác định cursor ordering, page/band boundaries, repeated headers, long-cell continuation, font buffers, filter counts, provider failure và pending output cleanup |

**Performance:** UI virtualization chỉ giảm widgets hiển thị; query/result cache vẫn phải bounded. Full JSON/CSV/PDF export có chi phí ít nhất theo bytes output; “diff ít” không đảm bảo PDF nhỏ vì FULL_COMPARISON còn exact/equivalent rows. Renderer theo pages/bands, không tạo toàn bộ page objects/DOM trong RAM; tính cả fonts, output buffering và peak overlap với result DB.

Không export partial/stale/cancelled result theo Report §1. Một bản differences-only do người dùng chọn phải ghi filter, counts và unresolved theo Report; không đổi scope âm thầm để vượt budget. Renderer không ghép lại records hay chạy lại normalization. PDF failure không làm mất result snapshot còn hợp lệ; retry export có attempt/output identity riêng.

**Hoàn tất docs khi:** có streaming export request/manifest, result schema mapping/migration, query contract và publish/rollback flow theo Report owner. Acceptance kế hoạch: REP-TC-001..012, LARGE-TC-007, CSV injection và Vietnamese font/text extraction/render QA.

## 14. Mô hình performance toàn pipeline

### 14.1. Ký hiệu và giả định

`B`: tổng source bytes thực đọc A+B; 
`X`: expanded/decoded bytes parser xử lý; `C`: tổng canonical bytes xử lý; 
`R`: tổng records; `H`: candidate hits; 
`V`: bytes xác minh key/content; `Q`: matched record pairs; `F`: mapped fields/pair trung bình; 
`E`: events; `Z`: persisted trace/result bytes; `O`: output bytes; `a_i,b_i`: số records hai phía trong segment/bucket i. Các ký hiệu bytes không thay bằng row counts; nhiều passes phải nhân hoặc ghi riêng chi phí.

| Công đoạn | Chi phí thiết kế | RAM phụ trợ / điều kiện | Phần v3 cần làm rõ |
| --- | --- | --- | --- |
| Access/hash | O(B) cho mỗi full scan, cộng provider I/O | Byte buffers bounded | Số scans/copies và non-seekable spool |
| Parse | O(X) cộng metadata/string lookups | Parser/token + batch + bounded metadata/cache | SST/styles/late merges không nằm trọn RAM |
| Canonicalize/hash | O(C) nếu mỗi byte xử lý bounded; Unicode/decimal/trace tính riêng | Batch/cache/trace buffers | Không coi mọi cell có chi phí bằng nhau |
| KEY hash RAM/partition | Expected O(R + H) cho operations, cộng key bytes/V/spill | RAM bounded chỉ khi partition/skew được xử lý | Không dùng kỳ vọng này cho SQLite B-tree |
| KEY B-tree | Typical build/probe O(R log R + H), cộng bytes/key comparisons/V/I/O | DB cache bounded, index trên disk | Query plan, bulk build và collation cần đặc tả |
| External sort/join | Comparison work O(R log R), merge theo runs; bytes so sánh riêng | Bounded buffers/fan-in, scratch cho runs | Số passes, cleanup và skew |
| POSITIONAL | O(R) record traversal + field bytes compare | Hai bounded cursors | Ordinal/provenance không thay qua chunks |
| ORDERED | O(Σ a_i b_i × scoreCost_i) không band; thực tế chặn visited states toàn phiên | Score rows khác bộ nhớ traceback | Band có điều kiện đúng, fallback unresolved |
| Fuzzy/duplicate bucket | Có thể O(Σ a_i b_i × scoreCost_i) | Candidate graph phải bounded/disk-backed | Top-k/caps không chứng minh absence |
| Typed diff | O(QF) dispatch + canonical/evidence bytes + optional text highlight | Bounded batch | Long text/trace có budget riêng |
| Persist/audit | Theo E/Z + index/transaction costs; constraints theo plan | Bounded writer/cache | WAL, aggregates và staging publication |
| Export | Ít nhất Ω(O); PDF layout/font work bổ sung | Page/band + font/output buffers | Output lớn độc lập compressed source size |

Các biểu thức trên là **phân tích từ thiết kế**, chưa là measured complexity của code. Không có guarantee linear time toàn pipeline vì candidate explosion, external sorting, DP và serialization. LCS score dùng linear-space không đồng nghĩa full alignment path có cùng space/time nếu chưa chọn thuật toán reconstruction.

### 14.2. Budget tổng và lifetime overlap

Đặc tả governor cần kiểm điều kiện tổng, không chỉ cap riêng từng component:

```text
RAM_peak ≈ UI + active parsers + metadata/SST caches + canonical batches
         + candidate/DP/traceback buffers + DB cache + in-flight messages
         + renderer/fonts + native/runtime overhead

Disk_peak ≈ source spools + parsed stores + indexes/sort runs
          + results/traces + WAL/journal + pending outputs + safety reserve
```

Đây là accounting model để đo/chốt profile, không phải phép dự đoán RAM chính xác. Cần tránh đếm trùng shared buffers, đồng thời không bỏ native allocations hoặc source A/B cùng sống. Disk estimate ghi peak theo stage và các consumers còn giữ refs. Không giả định 2 GB nguồn chỉ cần 2 GB disk hoặc 1 GB RAM.

Ngoài dimensions v3 §11, đề xuất bổ sung vào owner NFR/profile registry: in-flight bytes, max single batch/cell token bytes, total candidate evaluations, max bucket work, DP states **toàn phiên**, traceback bytes, similarity token/byte budget, message bytes, writer backlog, WAL/output headroom và cursor lifetime. Giá trị để **TBD** cho tới khi có benchmark/profile review; không bật profile thiếu hard limits.

### 14.3. Đo stage và end-to-end

Ghi `read/preflight`, `parse`, `validate/freeze`, `geometry/mapping`, `canonicalize`, `index`, `match`, `diff`, `audit/finalize`, `query-first-page`, `export/layout/publish`, `cleanup`. Khi stages overlap, tổng stage durations có thể lớn hơn wall time; không cộng để công bố total. Human review time ghi riêng khỏi compute time nhưng vẫn thuộc user journey.

Mỗi stage cần elapsed time, units/bytes thực xử lý, peak RSS/PSS/heap/native khi đo được, scratch/WAL high-water mark, queued bytes, DB/I/O stalls, cancellation latency và outcome/reason. Tách time-to-first-preview khỏi time-to-validated-READY; preview nhanh không chứng minh đọc hết input.

## 15. Benchmark và acceptance plan — chưa chạy

### 15.1. Ma trận workload

| Workload | Mục đích | Layers | Oracle / liên kết |
| --- | --- | --- | --- |
| Nhỏ, no-change/1-cell edit/reorder/key đổi | Correctness và baseline overhead | L4–8 | V3 F01–F07/F15; Core semantic cases |
| A/B lớn, KEY và POSITIONAL, bytes sát/đúng/vượt trần | Năng lực thật tới 1 GB/source | L0–10 | LARGE-TC-001/002; valid EOF/hash/full result |
| Duplicate/null keys ở hai chunks/partitions, skew bucket | Global detection và candidate work bounds | L5–6 | LARGE-TC-003; F05/F15 |
| XLSX unique SST lớn, inline/rich strings, styles nhiều | Metadata/cache/spool pressure | L1–4 | LARGE-TC-004; F19/F24 |
| Sparse rất rộng, merged headers, timeline ngang | Geometry/locality, không dense expansion | L2–3 | F10/F11/F24 |
| ORDERED không anchors, repeated anchors, ties và nhiều segments | DP/traceback/session budget | L5–6/L9 | F16/F20; extension only |
| Toàn bộ rows/cells đổi, text dài, trace nhiều | Event/output explosion | L7–10 | Audit counts + long-text oracle; LARGE-TC-007 |
| Full PDF và filtered PDF riêng, nhiều bands/long Vietnamese text | Fidelity, fonts và output budgets | L8–10 | REP-TC-001..012 |
| Một OCR source có crop/review changes | Handoff P0, invalidation và bounded bitmap | L0–4/L9 | INP-TC-039/040; không dùng XLSX oracle thay OCR |
| Cancel, late callback, permission revoke, kill, disk full | Không false READY/completed, cleanup đúng | L1–2/L8–10 | INP-TC-034..038; LARGE-TC-005/006/008 |

V3 T0–T6 bổ sung workload shape nhưng cần nói rõ rows/sheet hay tổng workbook, số selected scopes, average/max cell bytes, unique-string cardinality, change density, candidate density và modes. Các tier không thay LARGE-TC boundary corpus. ZIP bomb/malformed phải fail bounded; positive large-file case không được pass chỉ nhờ từ chối.

### 15.2. Protocol và cách đọc số liệu

Theo NFR và expanded acceptance, evidence phải có fixture hashes/generator seed, input bytes, expected counts/diff, device RAM/chipset/OS, release build/SDK/adapter/engine/policy/profile versions, available disk, thermal/background conditions và runner logs đã redacted. Android reference 4 GB/6 GB theo NFR; web/iOS có gate riêng.

Tách cold/warm, chạy lặp và giữ raw samples. V3 yêu cầu ≥5 runs có thể dùng thăm dò, **chưa đủ để khẳng định tail p95 ổn định**; số runs và percentile estimator cần được chốt theo biến động/độ tin cậy mong muốn, không bịa p95 từ ít samples rồi gọi SLO. Calibration data và holdout evaluation phải tách để tránh chọn threshold từ test công bố.

Match quality báo precision/recall, coverage/abstention, false pairings và unresolved theo đơn vị record/cell; không bỏ unresolved để nâng accuracy. End-to-end phải đối soát full EOF, source immutability, actual counts/refs, all outputs, peak resource, cancel/cleanup. Performance nhanh nhưng sai match/count/source là FAIL.

Không có con số cells/s, seconds/1 GB, RAM MB hay số workers tối ưu được công bố trong tài liệu này. Chỉ NFR/profile owner được chốt target/limits sau evidence; tài liệu này không thay NFR-PERF-01..04 bằng số giả định.

## 16. Danh mục việc cần đóng ở giai đoạn docs

| Thứ tự | Gói đặc tả | Gap liên quan | Output reviewable trước implementation |
| --- | --- | --- | --- |
| D0 | Reconcile baseline/ownership | L0-01/02, L7-01, L8-03 | Scope/capability matrix, status mapping và NFR/profile references |
| D1 | Input/snapshot/geometry contracts | L1-*, L2-*, L3-* | Read/spool/pass plan, EOF/provenance/receipt gates, geometry cursors/mapping rules |
| D2 | Canonical encoding/policy/cache | L4-* | Byte grammar, identity/content separation, tolerance restrictions và lineage invalidation examples |
| D3 | Matching execution contracts | L5-*, L6-* | Index strategy, global duplicates, candidate bounds, DP recurrence/traceback/tie/fallback |
| D4 | Result/audit/runtime contracts | L7-*, L8-*, L9-* | Four-state verdicts, ledgers, staged commit, worker envelope, cancel/restore/lifetime tables |
| D5 | Query/export/performance contracts | L10-*, §14–15 | Streaming result/export mapping, budget accounting và benchmark/evidence protocol |

Các ký hiệu `Lx-*` trong bảng là nhóm gap `UDG-Lx-*` ở các layer trên. Mỗi gap chỉ đóng khi owner contract có version/reference, example input/output, edge/error/budget behavior và acceptance mapping rõ. Schema migration, numeric budgets và sign-off chưa có thì giữ OPEN; không sửa oracle lịch sử hoặc đánh dấu VERIFIED chỉ vì có đề xuất.

**Điểm dừng hiện tại:** bàn giao bản review phân lớp và backlog hoàn thiện đặc tả. Không bắt đầu các sprint triển khai M1–M7 của v3, không lựa chọn thư viện như dependency đã cài, không sửa hoặc chạy mã nguồn dự án. Test IDs được tham chiếu là kế hoạch kiểm chứng về sau.

## 17. Tham chiếu kỹ thuật bên ngoài

Đã đối chiếu ngày 13/11/2026; chỉ dùng để kiểm tra cơ chế nền tảng, không chứng minh Dytava đã triển khai:

- [Flutter — Concurrency and isolates](https://docs.flutter.dev/perf/isolates): memory/message behavior; suy luận ảnh hưởng pipeline ghi tại L9.
- [Microsoft — Working with the shared string table](https://learn.microsoft.com/en-us/office/open-xml/spreadsheet/working-with-the-shared-string-table): workbook SST, inline/rich strings; yêu cầu thiết kế bổ sung tại L2.
- [SQLite — Query Planning](https://www.sqlite.org/queryplanner.html): index/search cost; phân tích strategy riêng tại L5 và §14.
- [SQLite — Write-Ahead Logging](https://www.sqlite.org/wal.html): writer/checkpoint constraints; đề xuất transaction/lifetime tại L8.

Các công thức DP, candidate cross-product, byte/output lower bound và accounting model là phân tích thiết kế trong review này; không phải số đo hoặc trích dẫn benchmark từ các nguồn trên.
