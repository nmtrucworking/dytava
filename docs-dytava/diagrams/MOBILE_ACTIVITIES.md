---
document_id: DYT-DIAG-ACT-001
version: 1.0.0
status: DRAFT
owner: Documentation integration role
reviewer: TBD
updated: 2026-11-17
release_baseline: Android P0 mở rộng; UDG3.1
execution_state: NOT_VERIFIED
---

# Activity cốt lõi — Dytava Mobile

Các sơ đồ mô tả **hành vi mục tiêu** của ứng dụng Flutter/Android theo docs hiện hành, không khẳng định app đã triển khai các chức năng này. Mỗi sơ đồ là một góc nhìn của cùng hành trình; các lời gọi `ACT-xx` trỏ tới sơ đồ chi tiết bên dưới. Không thay đổi hoặc định nghĩa thêm hợp đồng nghiệp vụ.

Ký hiệu: nút tròn là bắt đầu/kết thúc; hình chữ nhật là hoạt động; hình thoi là quyết định; nhãn cạnh là điều kiện. Đây là sơ đồ luồng hoạt động bằng Mermaid, không phải sơ đồ lớp hoặc danh sách Android `Activity` native. A/B là hai slot nguồn độc lập; mũi tên không quy định số worker hoặc bắt buộc xử lý đồng thời.

## Chỉ mục và truy vết

| Sơ đồ | Hoạt động | Yêu cầu / nguồn sở hữu |
| --- | --- | --- |
| [ACT-01](#act-01--hành-trình-tổng-quan) · [SVG](mobile-activities/01-overview.svg) | Bắt đầu → nhập → cấu hình → so sánh → kết quả → xuất | [PRD §5](../product/PRD.md#5-user-journey-p0-và-tiêu-chí-trải-nghiệm), [SRS](../requirements/SRS.md) |
| [ACT-02](#act-02--nhập-và-xác-thực-một-nguồn-ab) · [SVG](mobile-activities/02-import.svg) | Import độc lập cho mỗi slot A/B | FR-001..004/015/016; [INP-008](../specs/input/08_import_state_machine.md), [ISC-1](../specs/input/11_streaming_snapshot_contract.md) |
| [ACT-03](#act-03--ocr-một-ảnh-và-review-bắt-buộc) · [SVG](mobile-activities/03-ocr-review.svg) | Ảnh → OCR cục bộ → sửa/xác nhận → snapshot | FR-012; [INP-010](../specs/input/10_ocr_image_input.md) |
| [ACT-04](#act-04--xác-nhận-cấu-hình-và-đóng-băng-plan) · [SVG](mobile-activities/04-confirm-plan.svg) | Scope/mapping/mode/key/policy/direction → frozen plan | FR-005/006/009/014; [EP-1](../specs/engine/01_execution_plan.md), [Geometry](../specs/engine/02_geometry_mapping.md) |
| [ACT-05](#act-05--udg31-ghép-hàng-và-hoàn-tất-kết-quả) · [SVG](mobile-activities/05-comparison.svg) | KEY/POSITIONAL → ownership → diff → atomic publish | FR-006..009/014; [Matching](../specs/engine/03_candidate_alignment.md), [ER-1](../specs/engine/04_result_runtime.md) |
| [ACT-06](#act-06--quyết-định-trạng-thái-một-cặp-ô) · [SVG](mobile-activities/06-cell-decision.svg) | EXACT / EQUIVALENT / DIFFERENT / UNRESOLVED | FR-008/009; [Core decisions](../specs/core/COMPARISON_DECISIONS.md), [CE-1](../specs/core/CANONICAL_ENCODING.md) |
| [ACT-07](#act-07--xem-chi-tiết-lọc-và-xuất-báo-cáo) · [SVG](mobile-activities/07-query-export.svg) | Query/detail → chọn output → kiểm tra → publish | FR-013/017/018; [Report](../specs/report/README.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md) |
| [ACT-08](#act-08--hủy-lỗi-thay-đổi-nguồn-và-khôi-phục) · [SVG](mobile-activities/08-cancel-recovery.svg) | Cancel, invalidation, retry và process death | FR-015; [INP-008](../specs/input/08_import_state_machine.md), [WP-1](../specs/engine/04_result_runtime.md#5-wp-1-envelope-và-delivery) |

Mermaid trong tài liệu là nguồn chỉnh sửa; các SVG và [PNG tổng quan](mobile-activities/01-overview.png) là bản render dẫn xuất bằng Mermaid 11.12.2.

## ACT-01 — Hành trình tổng quan

**Actor chính:** người dùng. **Hệ thống:** Flutter UI, Input/OCR, Core worker, result store và exporter.

```mermaid
flowchart TD
    S((Bắt đầu)) --> HOME[Người dùng tạo phiên so sánh]
    HOME --> IMPORT[ACT-02: chọn và nhập nguồn A/B]
    IMPORT --> READY{Cả A và B PREVIEW_READY<br/>và snapshot còn hiệu lực?}
    READY -->|Chưa| RECOVER[ACT-08: xử lý review, hủy hoặc lỗi]
    READY -->|Có| CONFIG[ACT-04: xác nhận mapping, mode,<br/>key, policy và chiều so sánh]
    CONFIG -->|Plan hợp lệ và đã xác nhận| RUN[ACT-05 + ACT-06:<br/>UDG3.1 ghép hàng và so sánh ô]
    RUN --> DONE{Kết quả COMPLETED<br/>và còn hiệu lực?}
    DONE -->|Không| RECOVER
    RECOVER --> ACTION{Hành động tiếp theo?}
    ACTION -->|Đổi hoặc nhập lại nguồn| IMPORT
    ACTION -->|Sửa cấu hình hoặc thử lại| CONFIG
    ACTION -->|Đóng phiên| CLOSE
    DONE -->|Có| RESULT[Xem thống kê, lọc và chi tiết sai khác]
    RESULT --> EXPORT{Người dùng chọn xuất?}
    EXPORT -->|Có| REPORT[ACT-07: xuất CSV, JSON,<br/>PDF diff hoặc PDF Dytava]
    REPORT --> RESULT
    EXPORT -->|Kết thúc xem, không xuất thêm| CLOSE[Đóng phiên, release leases và dọn scratch]
    CLOSE --> E((Kết thúc))
```

- `IMPORT` có thể gọi OCR tại ACT-03. P0 nhận XLSX/CSV/TSV và **tối đa một** ảnh PNG/JPEG trong hai nguồn; không ảnh–ảnh.
- Mỗi phía có đúng một table/scope được xác nhận. Đổi nguồn hoặc cấu hình phải qua invalidation tại ACT-08; không xuất kết quả cũ như kết quả hiện hành.
- Trần thiết kế là **1 GB/source**, kèm resource profile, streaming/chunking và private spill theo [NFR §3](../requirements/NFR.md#3-resource-profiles-và-trần-input-1-gb). Đây không phải tuyên bố hiệu năng đã đạt.

## ACT-02 — Nhập và xác thực một nguồn A/B

Chạy riêng cho mỗi slot. Bên A sẵn sàng không làm bên B tự sẵn sàng; retry B giữ được A nếu snapshot A còn hợp lệ.

```mermaid
flowchart TD
    S((Bắt đầu import)) --> PICK[Người dùng chọn tệp hoặc một ảnh cho slot]
    PICK --> SELECTED[Tạo artifact độc lập, tăng generation<br/>và vô hiệu hóa dữ liệu dẫn xuất cũ]
    SELECTED --> PREFLIGHT[PREFLIGHTING: kiểm access, nội dung định dạng,<br/>bytes, capability và resource profile]
    PREFLIGHT --> CHECK{Kết quả preflight?}
    CHECK -->|ERROR hoặc không hỗ trợ| FAIL[FAILED: giữ safe diagnostics<br/>đóng handles và dọn scratch của attempt]
    CHECK -->|REVIEW| REVIEW[NEEDS_REVIEW: hiển thị vấn đề cần xác nhận]
    CHECK -->|Hợp lệ| IMAGE{Nguồn ảnh?}
    IMAGE -->|Có| OCR[ACT-03: OCR và review toàn selected scope]
    IMAGE -->|Không| SCOPE[Người dùng chọn một table/sheet/range,<br/>xác nhận header và encoding/dialect nếu cần]
    SCOPE --> PARSE[PARSING: đọc bounded stream, hash đúng bytes,<br/>giữ raw types và SourceRefs; spill khi cần]
    PARSE --> PARSED{Kết quả parse và validation?}
    PARSED -->|ERROR| FAIL
    PARSED -->|REVIEW| REVIEW
    PARSED -->|Đọc hết scope và bytes hợp lệ| VALIDATE
    OCR -->|Extraction đã xác nhận| VALIDATE[Kiểm EOF/hash, config/scope, review receipts<br/>và generation/attempt/revision hiện hành]
    OCR -->|Cần sửa cấu hình| REVIEW
    OCR -->|ERROR| FAIL
    VALIDATE --> GATE{Đúng attempt, không blocker<br/>và đầy đủ evidence?}
    GATE -->|Có| COMMIT[Commit immutable snapshot<br/>chuyển PREVIEW_READY]
    GATE -->|Callback cũ| DISCARD[Bỏ callback cũ; giữ state của attempt hiện hành]
    GATE -->|REVIEW blocker| REVIEW
    GATE -->|Integrity hoặc validation ERROR| FAIL
    REVIEW --> USER{Người dùng quyết định?}
    USER -->|Sửa và xác nhận| RETRY[Freeze config revision mới<br/>tạo attempt mới và recheck]
    RETRY --> PREFLIGHT
    USER -->|Thay nguồn| PICK
    USER -->|Hủy| CANCEL[ACT-08: cancel và cleanup]
    FAIL --> AGAIN{Người dùng chọn?}
    AGAIN -->|Retry sau khi xử lý lỗi| RETRY
    AGAIN -->|Thay nguồn| PICK
    AGAIN -->|Dừng| E((Kết thúc import))
    COMMIT --> E
    DISCARD --> E
    CANCEL --> E
```

Preview mẫu có thể xuất hiện sớm nhưng **không cấp PREVIEW_READY**. Review không tự retry; cần hành động xác nhận của người dùng. Hủy, thay nguồn, thu hồi quyền hoặc process death ở bất kỳ giai đoạn đang chạy nào xử lý theo ACT-08. Snapshot/evidence stores còn consumer sử dụng không bị dọn như orphan scratch.

## ACT-03 — OCR một ảnh và review bắt buộc

```mermaid
flowchart TD
    S((Bắt đầu OCR)) --> LIMIT{PNG/JPEG, một ảnh/một bảng,<br/>phía còn lại không phải ảnh?}
    LIMIT -->|Không| UNSUPPORTED[Báo input/layout ngoài phạm vi P0]
    LIMIT -->|Có| CAP{Capability OCR bundled,<br/>schema và profile đã đủ gate?}
    CAP -->|Chưa| BLOCK[Chặn OCR, hiển thị gate còn thiếu]
    CAP -->|Có| DECODE[Decode trong pixel/byte budget<br/>giữ hash và geometry ảnh gốc]
    DECODE --> CROP[Người dùng chọn crop/orientation<br/>lưu transform tới ảnh định hướng gốc]
    CROP --> RECOGNIZE[OCR on-device: text blocks và polygons<br/>giữ recognized text; confidence có thể null]
    RECOGNIZE --> GRID[Tái dựng grid nháp, selected cells PENDING]
    GRID --> LAYOUT{Grid có thể review an toàn?}
    LAYOUT -->|Không| REPAIR{Có thể sửa trong phạm vi hỗ trợ?}
    REPAIR -->|Có| EDIT[Người dùng sửa layout hoặc crop]
    REPAIR -->|Không| UNSUPPORTED
    EDIT --> INVALIDATE[Tăng extraction/config revision<br/>invalidate receipts và kết quả dẫn xuất]
    INVALIDATE --> CROP
    LAYOUT -->|Có| PREVIEW[Hiển thị ảnh gốc, overlay, text và grid]
    PREVIEW --> ACTION{Người dùng chọn?}
    ACTION -->|Đổi crop/layout| EDIT
    ACTION -->|Sửa hoặc xác nhận text| CONFIRM[Giữ text gốc và correction riêng<br/>ghi receipt cho các cell được liệt kê rõ]
    CONFIRM --> ALL{Toàn bộ selected cells đã CONFIRMED,<br/>receipts đúng hash và revision?}
    ALL -->|Chưa| PREVIEW
    ALL -->|Có| FREEZE[Freeze extraction revision và receipts<br/>full validation trước handoff ACT-02]
    ACTION -->|Hủy| CANCEL[ACT-08: dừng OCR và cleanup]
    FREEZE --> E((Trả extraction đã xác nhận))
    UNSUPPORTED --> F((Trả lỗi hoặc review cho ACT-02))
    BLOCK --> F
    CANCEL --> F
```

Confidence cao không bỏ qua review. OCR không sinh công thức, hidden values hoặc physical number từ ảnh; không fallback sang cloud. Thay crop/layout làm mất hiệu lực receipts liên quan; text correction phải có receipt gắn revision hiện hành. Lỗi access/decode/resource dừng an toàn theo ACT-08.

## ACT-04 — Xác nhận cấu hình và đóng băng plan

```mermaid
flowchart TD
    S((Bắt đầu cấu hình)) --> INPUT{A/B PREVIEW_READY,<br/>snapshots và OCR receipts hợp lệ?}
    INPUT -->|Không| IMPORT[Quay ACT-02 hoặc ACT-03]
    INPUT -->|Có| SCOPE[Xác nhận cặp scope/view<br/>và orientation nếu có]
    SCOPE --> MAP[Người dùng ghép cột 1:1 bằng Field IDs<br/>xác nhận các field không ghép]
    MAP --> MODE{Chọn matching mode?}
    MODE -->|KEY| KEY[Xác nhận tuple key có thứ tự<br/>strict identifier, không tolerance/fuzzy/null key]
    MODE -->|POSITIONAL| POSITION[Xác nhận so hàng theo ordinal<br/>không tự dò reorder hoặc fuzzy]
    KEY --> POLICY
    POSITION --> POLICY[Chọn và xác nhận policy từng field:<br/>dtype, locale A/B, transforms, nulls, tolerance]
    POLICY --> DIRECTION[Người dùng xác nhận A_TO_B hoặc B_TO_A]
    DIRECTION --> COMPILE[Resolve và compile policy/capabilities<br/>kiểm mapping, key và snapshot bindings]
    COMPILE --> VALID{Đủ confirmation và<br/>capability/profile hợp lệ?}
    VALID -->|Thiếu hoặc cấu hình sai| REVISE[Hiển thị missing gates hoặc lỗi cấu hình]
    REVISE --> MAP
    VALID -->|Có| FREEZE[Freeze EP-1 plan:<br/>snapshots, mapping/policy digests,<br/>direction, versions, profile và receipts]
    FREEZE --> START{Recheck plan và leases<br/>ngay trước START còn hợp lệ?}
    START -->|Không| REVISE
    START -->|Có| JOB[Tạo job/attempt/generation mới<br/>chuyển ACT-05]
    JOB --> E((Plan được chấp nhận))
```

Key null/trùng của dữ liệu được kiểm **toàn selected scope** tại ACT-05, không chứng minh uniqueness từ preview. Plan phải có key definition và confirmation đúng; record không có key hợp lệ được xử lý unresolved, không tự chọn first/last. Cấu hình yêu cầu dtype/operation chưa hỗ trợ bị chặn trước RUNNING. Nếu chỉ so structural differences và không có mapped fields, phải xác nhận rõ; không suy ra các record là UNCHANGED từ tập field rỗng.

## ACT-05 — UDG3.1: ghép hàng và hoàn tất kết quả

```mermaid
flowchart TD
    S((Bắt đầu job)) --> VALIDATE[VALIDATING: kiểm frozen plan,<br/>snapshots, evidence leases và resource profile]
    VALIDATE --> OK{Các gate hiện hành hợp lệ?}
    OK -->|Không| FAIL[FAILED hoặc NEEDS_REVIEW<br/>không publish kết quả]
    OK -->|Có| MODE{RUNNING: mode đã xác nhận?}
    MODE -->|POSITIONAL| ZIP[Zip hai record cursors theo ordinal<br/>tới min count; tails là unmatched]
    MODE -->|KEY| CANON[Canonical hóa strict ordered key tuples<br/>key invalid/null vào unresolved ownership]
    CANON --> SORT[External sort bounded runs theo full key bytes<br/>group toàn scope; đếm invalid keys từng phía]
    SORT --> GROUP{Còn key group trong merge join?}
    GROUP -->|Có| DUP{Group count lớn hơn 1<br/>ở bất kỳ phía nào?}
    DUP -->|Có| DUPLICATE[Mọi member cùng key ở cả hai phía:<br/>UNRESOLVED KEY_DUPLICATE, không pair]
    DUP -->|Không| BOTH{Key unique có ở cả hai phía?}
    BOTH -->|Có| MATCH[Tạo đúng một matched pair<br/>không phụ thuộc content có thay đổi]
    BOTH -->|Không| ABSENCE{Phía đối diện có invalid key<br/>có thể che khuất key đang xét?}
    ABSENCE -->|Có| UNKNOWN[UNRESOLVED<br/>ABSENCE_NOT_PROVEN_INVALID_KEYS]
    ABSENCE -->|Không| UNMATCH[Unmatched với absence proof<br/>gán ROW_ADDED/REMOVED theo direction]
    DUPLICATE --> GROUP
    MATCH --> GROUP
    UNKNOWN --> GROUP
    UNMATCH --> GROUP
    GROUP -->|Không| LEDGER[Chốt match ownership ledger<br/>mỗi record thuộc đúng một category]
    ZIP --> LEDGER
    LEDGER --> FIELDS[Ghi ROW/FIELD_ADDED/REMOVED riêng<br/>không tạo cell verdict cho structural events]
    FIELDS --> CELLS[ACT-06 cho từng mapped cell của matched rows<br/>ghi verdict, raw/canonical refs, rule và reason]
    CELLS --> STAGE[Staging batches bounded và idempotent<br/>commit ledger/counters, ACK và release credits]
    STAGE --> AUDIT[Producers END: kiểm full selected scope,<br/>uniqueness, counts, evidence và conservation]
    AUDIT --> COMPLETE{Đủ coverage và integrity?}
    COMPLETE -->|Không| PARTIAL[PARTIAL hoặc FAILED<br/>chỉ diagnostics, không result/export]
    COMPLETE -->|Có, kể cả có unresolved| PUBLISH[Atomic publish immutable ER-1 snapshot<br/>và marker trong cùng commit]
    PUBLISH --> COMPLETED[COMPLETED: gửi result ID<br/>cho UI query/export]
    COMPLETED --> E((Kết thúc job))
    PARTIAL --> E
    FAIL --> E
```

Các nút ledger/cell/staging biểu diễn thứ tự phụ thuộc logic, không yêu cầu giữ toàn bộ pairs/cells trong RAM; triển khai dùng cursors, stores và batches có giới hạn. KEY so **full framed tuple bytes**, digest chỉ hỗ trợ tăng tốc; không nối key bằng delimiter hoặc coi hash bằng nhau là identity. POSITIONAL gán nhãn tails theo direction, không tìm lại key để “sửa” pairing.

Điều kiện finalize theo ER-1:

- `input_records_a = matched_record_pairs + unmatched_records_a + unresolved_records_a`; phía B tương tự.
- `compared_matched_cell_pairs = exact + equivalent + different + unresolved`.
- Unmatched rows/fields có counters riêng. Không có mapped fields thì paired records mang content state `UNRESOLVED / NO_MAPPED_FIELDS`; cell denominator bằng 0, tỷ lệ hiển thị `N/A`.
- Full coverage có unresolved vẫn có thể `COMPLETED`; xử lý chưa hết scope không được giả là hoàn tất. Hủy/lỗi trong các vòng lặp hoặc commit xử lý theo ACT-08.

## ACT-06 — Quyết định trạng thái một cặp ô

Chỉ gọi khi row pair và field pair đã được xác nhận. Đây là thứ tự ưu tiên theo Core; không dùng candidate score làm cell verdict.

```mermaid
flowchart TD
    S((Bắt đầu cell pair)) --> PAIR{Có confirmed row pair<br/>và field pair?}
    PAIR -->|Không| STRUCT[Ghi structural/unresolved ownership<br/>không tạo matched-cell verdict]
    PAIR -->|Có| SYSTEM{Snapshot hoặc evidence store<br/>bị lỗi hệ thống/integrity?}
    SYSTEM -->|Có| FAIL[Fail job theo ACT-08<br/>không tạo hàng loạt verdict giả]
    SYSTEM -->|Không| EVIDENCE{Policy/capability và evidence đủ,<br/>OCR receipt còn hiệu lực?}
    EVIDENCE -->|Không| UNRESOLVED[UNRESOLVED:<br/>ghi reason và remediation]
    EVIDENCE -->|Có| NORMALIZE[Parse typed values và canonicalize<br/>chỉ theo field policy đã xác nhận]
    NORMALIZE --> PARSED{Cả hai normalization thành công?}
    PARSED -->|Không| UNRESOLVED
    PARSED -->|Có| RAW{Cùng physical kind/null kind, preserved raw lexeme,<br/>valid typed value bằng nhau và mode evidence?}
    RAW -->|Có| EXACT[EXACT]
    RAW -->|Không| SEMANTIC{Canonical exact equality<br/>hoặc permitted absolute tolerance?}
    SEMANTIC -->|Có| EQUIVALENT[EQUIVALENT:<br/>canonical A/B và rule/trace bắt buộc]
    SEMANTIC -->|Không| DIFFERENT[DIFFERENT:<br/>valid inequality và raw A/B evidence]
    EXACT --> TRACE[Ghi một verdict cùng rule/version,<br/>SourceRefs, raw/canonical/trace refs và flags]
    EQUIVALENT --> TRACE
    DIFFERENT --> TRACE
    UNRESOLVED --> TRACE
    TRACE --> E((Trả decision cho ACT-05))
    STRUCT --> E
    FAIL --> F((Trả lỗi job))
```

P0 dtypes: IDENTIFIER, FREE_TEXT, DECIMAL, BOOLEAN, PERCENTAGE. Missing/blank/empty/null/zero/false phân biệt mặc định; không đoán locale, không dùng binary floating point thay exact decimal. Identifier numeric thiếu lexical evidence → unresolved, không dựng lại leading zeros. `TYPE_CHANGED` hoặc `OCR_REVIEWED` là flags, không phải trạng thái thứ năm. Tolerance chỉ theo policy field đã confirm, không áp cho KEY.

## ACT-07 — Xem chi tiết, lọc và xuất báo cáo

```mermaid
flowchart TD
    S((Mở kết quả)) --> CURRENT{Result COMPLETED, current<br/>và có consumer lease?}
    CURRENT -->|Không| BLOCK[Chặn query/export mới<br/>hướng dẫn revalidate hoặc chạy lại]
    CURRENT -->|Có| QUERY[Query phân trang theo stable cursor<br/>hiển thị counters đầy đủ và selected counts riêng]
    QUERY --> ACTION{Người dùng chọn?}
    ACTION -->|Lọc hoặc xem detail| DETAIL[Đọc ledger và raw/canonical/rule/SourceRefs<br/>không chạy lại Core semantics]
    DETAIL --> QUERY
    ACTION -->|Xuất| SELECT[Chọn CSV_DIFF, JSON_REPORT,<br/>MERGED_DIFF_PDF hoặc DYTAVA_REPORT_PDF]
    SELECT --> SCOPE[Xác nhận FULL / DIFFERENCES_ONLY / FILTERED,<br/>locale, timezone, layout/template và destination]
    SCOPE --> VALIDATE[VALIDATING: kiểm result/request/lease,<br/>profile, budgets và destination publish capability]
    VALIDATE --> VALID{Các precondition hợp lệ?}
    VALID -->|Không| ERROR[Thông báo lỗi/gate<br/>không công bố artifact dở]
    VALID -->|Có| RENDER[RENDERING: stream cursors vào private pending file<br/>PDF phân page/band; giữ raw và nhãn trạng thái]
    RENDER --> VERIFY[VERIFYING: flush/close, kiểm syntax/coverage,<br/>counts/pages, output hash và result validity]
    VERIFY --> PASS{Kiểm tra đạt và result còn current?}
    PASS -->|Không| CLEAN[Đóng handles, cleanup pending output<br/>FAILED hoặc CANCELLED, không publish]
    PASS -->|Có| PUBLISH[PUBLISHING: atomic rename hoặc<br/>pending-object commit đã được xác minh]
    PUBLISH --> COMMIT{Publish commit thành công?}
    COMMIT -->|Không| CLEAN
    COMMIT -->|Có| COMPLETE[COMPLETED: artifact và external manifest/receipt<br/>hash completed output nằm ngoài chính artifact]
    COMPLETE --> QUERY
    ERROR --> QUERY
    CLEAN --> QUERY
    ACTION -->|Đóng kết quả| RELEASE[Release consumer lease<br/>giữ user-exported artifacts]
    RELEASE --> E((Kết thúc xem kết quả))
    BLOCK --> E
```

Export do người dùng khởi tạo, không ghi đè nguồn. Retry export tạo attempt mới; nếu commit bền vững nhưng mất ACK thì lookup receipt để tránh xuất trùng. Hủy/lỗi/resource exhaustion tại các active stages đi qua cleanup của ACT-08. Provider chỉ ghi trực tiếp visible output mà không có pending/rollback guarantee bị từ chối trước publish.

Hai PDF là **hai export kinds riêng**: một PDF diff hợp nhất A/B và một PDF theo template Dytava. Một kind tạo một tệp PDF dù nhiều trang. Output ghi scope/filter và counts, không silent truncation hoặc tự thu nhỏ scope khi hết budget. `DIFFERENCES_ONLY` phải giữ unresolved; equivalent inclusion là lựa chọn được ghi rõ. Result stale/partial/cancelled không được export; lease giữ evidence đủ lâu cho renderer.

## ACT-08 — Hủy, lỗi, thay đổi nguồn và khôi phục

Sơ đồ áp dụng ngang cho import, comparison và export. Terminal states của từng loại attempt theo hợp đồng riêng; nhánh cancel bên dưới thể hiện trạng thái comparison/export.

```mermaid
flowchart TD
    S((Sự kiện vòng đời)) --> EVENT{Loại sự kiện?}
    EVENT -->|Người dùng hủy active attempt| CANCEL[Coordinator chuyển CANCELLING<br/>gửi CANCEL qua control path]
    CANCEL --> STOP[Dừng producers, đóng cursors/streams,<br/>rollback/discard staging và release leases]
    STOP --> STOPPED{Đã dừng và cleanup<br/>đến boundary nhất quán?}
    STOPPED -->|Có| ACK[CANCELLED và CANCEL_ACK<br/>không publish partial result/output]
    STOPPED -->|Không phản hồi hoặc cleanup lỗi| FORCE[FAILED hoặc INTERRUPTED<br/>strong stop/sweep; không gửi ACK giả]
    EVENT -->|Fatal access/protocol/integrity/resource error| ERROR[FAILED hoặc PARTIAL theo coverage<br/>safe diagnostics, dừng và cleanup]
    EVENT -->|Thay bytes/scope/header/import config| SOURCE[Invalidate affected snapshot và receipts<br/>hủy job phụ thuộc, tăng generation/revision]
    SOURCE --> STALE[Mark kết quả dẫn xuất stale/revoked<br/>chặn query/export mới]
    STALE --> RESET[Đưa slot thay đổi về SELECTED]
    RESET --> REIMPORT[Quay ACT-02 để chọn hoặc revalidate nguồn<br/>giữ phía còn lại nếu hợp lệ]
    EVENT -->|Đổi mapping/mode/key/policy/direction| POLICY[Giữ raw snapshots còn hợp lệ<br/>invalidate plan và kết quả dẫn xuất]
    POLICY --> REPLAN[Hủy old work nếu còn active<br/>xác nhận và freeze plan mới tại ACT-04]
    EVENT -->|Permission revoked hoặc source changed ngoài app| REVOKE[Source FAILED; invalidate receipts và result<br/>cancel dependent work, cleanup và báo lỗi]
    REVOKE --> REIMPORT
    EVENT -->|Process death, sau đó mở lại app| STARTUP[Đánh dấu job cũ INTERRUPTED<br/>startup sweep orphan scratch]
    STARTUP --> JOURNAL[Chỉ đọc minimal journal<br/>không khôi phục partial rows thành READY]
    JOURNAL --> REF{Còn source ref có thể revalidate?}
    REF -->|Có| SELECTED[Restore SELECTED<br/>recheck access/hash/config rồi import lại]
    REF -->|Không| UNSELECTED[Restore UNSELECTED<br/>yêu cầu chọn nguồn lại]
    SELECTED --> REIMPORT
    UNSELECTED --> REIMPORT
    ACK --> RETRY{Người dùng chọn retry?}
    ERROR --> RETRY
    FORCE --> RETRY
    RETRY -->|Có, nguyên nhân đã xử lý| NEW[Tạo attempt/generation mới theo stage<br/>revalidate; số lần retry theo profile]
    RETRY -->|Không| E((Kết thúc xử lý))
    NEW --> E
    REIMPORT --> E
    REPLAN --> E
```

- Callback/message chỉ commit khi tuple job/attempt/generation/revision còn hiện hành; callback cũ bị bỏ, replay hợp lệ xử lý idempotent. `COMPLETED` không bị đổi thành `CANCELLED` bởi cancel đến muộn.
- Comparison NEEDS_REVIEW: người dùng RESOLVE → cancel old work → new generation → VALIDATING. Không sửa plan đang chạy tại chỗ.
- Đóng handle nguồn bình thường sau frozen snapshot không đồng nghĩa thu hồi quyền. Snapshot đủ evidence có thể phục vụ export qua lease mà không mở lại nguồn gốc.
- Đóng phiên release consumers rồi dọn private scratch/raw/OCR stores không còn owner. Không xóa artifact người dùng đã export. Lịch sử mặc định không lưu raw contents.

## Phạm vi và điều kiện triển khai

Nguồn sở hữu hiện hành: [Document Control](../governance/DOCUMENT_CONTROL.md), [baseline UDG3.1](../governance/SPECIFICATION_BASELINE_3_1.md). Các sơ đồ này là bản dẫn xuất phục vụ phân tích/thiết kế; khi owner contract thay đổi phải cập nhật sơ đồ tương ứng. Capability/profile chưa verified phải được chặn tại validation; sơ đồ không cấp quyền tự bật capability.

Không đưa iOS, JSON input, MULTISET/ORDERED_SEQUENCE, formula/style comparison, PDF input hoặc cloud OCR vào đường P0. Target OCR/schema migration, pipeline 1 GB, result/runtime và hai PDF vẫn cần implementation/device evidence theo owner docs. Công việc này chỉ bổ sung sơ đồ, không thay code mobile hoặc đánh dấu acceptance PASS.
