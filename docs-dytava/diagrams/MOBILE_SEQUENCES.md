---
document_id: DYT-DIAG-SEQ-001
version: 1.0.0
status: DRAFT
owner: Documentation integration role
reviewer: TBD
updated: 2026-11-17
release_baseline: Android P0 mở rộng; UDG3.1
execution_state: NOT_VERIFIED
---

# Sequence diagrams — Dytava Mobile

Mô tả tương tác **mục tiêu**, dẫn xuất từ owner contracts; không là API/implementation hoặc bằng chứng chạy thật. Participants là vai trò logic, không bắt buộc mỗi vai trò thành một isolate/package. Messages diễn giải hành vi trừ các tên WP-1/ER-1/EX-1 đã có trong nguồn. Không bổ sung payload type hoặc wire schema mới.

A/B độc lập; lịch chạy workers tuân RP-1, không mặc định parse hai nguồn song song. Mọi callback/command phải có binding hiện hành; private URI/token chỉ đi qua access broker, không vào Core hoặc public report.

Lỗi/cancel giữa các bước không có nhánh riêng trong hình vẫn dừng attempt theo owner state machine, cleanup và không publish partial. `break` là nhánh kết thúc interaction; không chạy các messages còn lại khi điều kiện break xảy ra.

| Sơ đồ | Luồng | Nguồn chính |
| --- | --- | --- |
| SEQ-01 · [SVG](mobile-sequences/01-import.svg) | Chọn → inspect/review → full parse → freeze | [ISC-1](../specs/input/11_streaming_snapshot_contract.md), [INP-008](../specs/input/08_import_state_machine.md) |
| SEQ-02 · [SVG](mobile-sequences/02-ocr-review.svg) | OCR, corrections và review receipts | [INP-010](../specs/input/10_ocr_image_input.md), [ISC-1 §4](../specs/input/11_streaming_snapshot_contract.md#4-target-input-020-migration--logical-fields) |
| SEQ-03 · [SVG](mobile-sequences/03-plan-invalidation.svg) | Confirm/freeze plan và invalidation | [EP-1](../specs/engine/01_execution_plan.md), [Geometry](../specs/engine/02_geometry_mapping.md), [CE-1](../specs/core/CANONICAL_ENCODING.md) |
| SEQ-04 · [SVG](mobile-sequences/04-worker-publish.svg) · [PNG](mobile-sequences/04-worker-publish.png) | Worker, byte credits, staging và publish | [ER-1/WP-1](../specs/engine/04_result_runtime.md), [RP-1](../requirements/RESOURCE_PROFILES.md) |
| SEQ-05 · [SVG](mobile-sequences/05-query-detail.svg) | Result query, stable cursor, detail/highlight | [EX-1 §1](../specs/report/STREAMING_EXPORT_CONTRACT.md#1-query-cursor), [Core decisions §4](../specs/core/COMPARISON_DECISIONS.md#4-long-text-và-highlight) |
| SEQ-06 · [SVG](mobile-sequences/06-export.svg) | Bốn export kinds và publication | [Report](../specs/report/README.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md) |
| SEQ-07 · [SVG](mobile-sequences/07-cancel-protocol.svg) | Cancel, stale events và delivery guards | [WP-1 §5–7](../specs/engine/04_result_runtime.md#5-wp-1-envelope-và-delivery), [INP-008](../specs/input/08_import_state_machine.md) |
| SEQ-08 · [SVG](mobile-sequences/08-recovery-leases.svg) | Process death, restore và retention | [ER-1 §6–7](../specs/engine/04_result_runtime.md#6-comparison-state-transitions), [ADR-009](../decisions/ADR_REGISTER_P0_2026-11-11.md) |

## SEQ-01 — Import một slot A hoặc B

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant ui as Flutter UI
    participant app as Import coordinator
    participant access as Read-only access broker
    participant input as Input worker và adapter
    participant store as Private snapshot store
    user->>ui: Chọn hoặc thay nguồn cho slot A/B
    ui->>app: SelectFile/ReplaceFile
    app->>app: Invalidate dependencies, generation mới
    app->>access: Acquire scoped read-only access
    access-->>input: Private stream và access capabilities
    input->>input: Validate format prefix/content
    input->>input: Resolve compatible RP-1, known size và scratch headroom
    alt Unsafe, unsupported, access lỗi hoặc thiếu profile
        input-->>app: Structured ERROR, không snapshot
        app->>store: Close attempt handles và cleanup unowned scratch
        app-->>ui: FAILED và remediation
    else Preflight hợp lệ
        alt Mutable provider hoặc non-seekable
            input->>store: Bounded immutable source spool, count/hash cùng bytes
            store-->>input: Spool identity và EOF/hash khi đầy đủ
        else Stable seekable immutable source
            input->>input: Parse cùng stable bytes, hash đúng parsed stream
        end
        input-->>ui: Inspect/provisional preview, chưa PREVIEW_READY
        user->>ui: Xác nhận một scope/header, encoding/dialect và review issues
        ui->>app: Resolved import config/review action
        app->>input: Current config và attempt binding
        alt XLSX
            input->>store: Pass A inspect OPC/ZIP, pass B metadata/SST spool/ordinal index
            input->>store: Pass C selected sparse cells, pass D scope/package checks
        else CSV/TSV
            input->>store: Incremental strict decoder/parser và raw rows/SourceRefs
        else Một PNG/JPEG
            input->>input: SEQ-02 OCR và full selected-cell review
        end
        input->>input: Full EOF, actual bytes/hash, counts, integrity và no blockers
        input-->>app: ParsedAndValidated với generation/attempt/config revision
        alt Tuple cũ hoặc source/snapshot binding không hợp lệ
            app->>store: Discard attempt staging, không publish READY
            app-->>ui: Giữ state hiện hành hoặc safe diagnostic
        else Validation hiện hành đạt
            app->>store: Freeze ISC-1 descriptor và validation receipt/publish marker
            store-->>app: Snapshot ID và evidence lease
            app-->>ui: Slot PREVIEW_READY
        end
    end
```

Review/error phát sinh trong parse cũng đóng stream và chuyển NEEDS_REVIEW/FAILED theo INP-008; ConfirmAndRetry tạo attempt mới. Prefix giữ nguyên trong byte stream đã hash; không hash một lượt provider khác với parsed bytes. XLSX pass A–D là dependencies logic; actual ZIP expansion/entry/token limits vẫn kiểm trong khi đọc, kể cả declared sizes hợp lệ. Một slot thất bại không làm mất snapshot hợp lệ của slot kia.

## SEQ-02 — OCR và review receipts

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant ui as OCR review UI
    participant app as OCR coordinator
    participant ocr as Bundled on-device recognizer
    participant grid as Extraction và geometry
    participant store as Extraction/raw store
    app->>app: Gate tối đa một ảnh PNG/JPEG, một bảng, target schema/capability/profile
    app->>app: Check dimensions/pixels/decoded bytes trước decode
    user->>ui: Chọn crop/orientation
    ui->>app: Confirm image transforms
    app->>store: Giữ ảnh gốc/hash và transform/inverse
    app->>ocr: Local recognition trong budget
    ocr-->>grid: Recognized text/tokens/polygons, confidence hoặc null
    grid->>store: Draft extraction/grid revision, cells PENDING
    store-->>ui: Ảnh gốc, overlay, raw text và grid proposal
    loop Tới khi selected scope đủ receipts hiện hành
        alt Sửa crop/layout/recognized hoặc reviewed content
            user->>ui: Sửa ảnh dẫn xuất, grid hoặc text
            ui->>app: Effective extraction/config change
            app->>store: New revision, invalidate affected receipts và downstream plan/results
            app->>grid: Rebuild affected extraction/grid, OCR lại nếu cần
            grid->>store: Original và correction riêng, không sửa raw image/text
        else Xác nhận cell hoặc batch được liệt kê rõ
            user->>ui: Confirm reviewed text
            ui->>store: Receipt gắn hash, extraction/grid revision, scope và cell
        end
        app->>store: Kiểm reviewed_cell_count bằng selected_cell_count và receipt bindings
        store-->>ui: Remaining blockers hoặc đủ review
    end
    app->>store: Freeze validated extraction, geometry và corrections
    store-->>app: ISC-1 handoff sau full validation
    app-->>ui: Source PREVIEW_READY, có thể dùng trong plan
```

Text do user thêm vì không detect được giữ `recognized_text=null`, `lexical_status=UNAVAILABLE`, loss `OCR_NO_DETECTION`, `correction_origin=USER_ENTERED` và polygon/receipt thật. Không biến text nhập tay thành recognition evidence. Confidence không bypass review; không upload hoặc cloud fallback. Schema0.1 không biểu diễn IMAGE: phải có target0.2 validators/fixtures và capability gates trước enable; sơ đồ không bỏ qua điều kiện này.

## SEQ-03 — Freeze EP-1 và invalidation

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant ui as Mapping/policy UI
    participant app as Plan coordinator
    participant snapshots as Snapshot/validity registry
    participant core as Pure Dart policy và CE-1
    participant worker as Comparison worker
    app->>snapshots: Check A/B PREVIEW_READY, lineage, receipts và leases
    snapshots-->>app: Current immutable descriptors hoặc missing gates
    user->>ui: Confirm scope/view, Field ID mapping, KEY/POSITIONAL và ordered keys
    user->>ui: Confirm dtype/transforms/locale/tolerance và A_TO_B/B_TO_A
    ui->>app: Current confirmation receipts/revisions
    app->>core: Resolve/compile effective policy và config
    core->>core: Reject unsupported operations, CFG-1 digest và CE-1 versions
    core-->>app: Compiled policy/digest hoặc blocking errors
    app->>app: Check enabled capabilities, RP-1 và all confirmations
    break Policy/confirmation/capability/profile hoặc snapshot gate chưa đạt
        app-->>ui: PLAN_PRECONDITION_FAILED hoặc safe gate diagnostic, không START
    end
    app->>snapshots: Recheck current bindings trước freeze/start
    app->>app: Freeze immutable EP-1 plan/digest
    app->>worker: WP-1 START bằng refs, attempt/generation và plan binding
    worker-->>app: ACK accepted hoặc rejected trước work
    opt Effective configuration hoặc source thay đổi
        user->>ui: Replace source/import config hoặc đổi mapping/policy/direction
        ui->>app: Change có revision guard
        app->>worker: CANCEL old dependent work nếu active
        app->>snapshots: Mark dependent results stale/revoked
        alt Bytes/scope/header/parser/extraction thay đổi
            app->>snapshots: Invalidate affected input/receipts, slot SELECTED để revalidate
        else Chỉ mapping/mode/key/policy/direction
            app->>app: Giữ raw snapshots hợp lệ, invalidate plan/caches theo CE-1
        end
        app-->>ui: Yêu cầu confirm/revalidate và tạo plan/generation mới
    end
```

Profile revision đổi cũng cần job mới; nếu profile tham gia import semantics thì revalidate affected Input. Không auto-accept proposal GF-1, không suy key uniqueness từ sample. Null/duplicate keys của records được xử lý ownership trong matching, không tự chọn first-match. Explicit access revoke khác đóng source handle bình thường.

## SEQ-04 — Bounded worker, staging và atomic result publication

```mermaid
sequenceDiagram
    autonumber
    participant app as Job coordinator
    participant worker as Worker với Pure Dart Core
    participant gov as RP-1 governor/credits
    participant writer as Single logical writer
    participant db as Private result/raw stores
    app->>worker: WP-1 START với frozen EP-1 refs và current tuple
    worker->>worker: Validate plan, current snapshots, confirmations và evidence leases
    break START validation bị từ chối
        worker-->>app: ACK rejected và safe diagnostic, không work
    end
    worker-->>app: ACK accepted trước work
    loop Bounded source/view/match/diff batches, có chunk yield
        worker->>gov: Reserve bytes/work trước allocation/enqueue
        gov-->>worker: CREDIT hoặc pressure/failure action
        break Hard pressure hoặc không thể reserve trong configured bound
            worker-->>app: Structured failure và cleanup, không allocation/work mới
        end
        worker->>db: Read snapshot/view cursors, không live source URI
        worker->>worker: KEY external-sort/global groups hoặc POSITIONAL zip
        worker->>worker: Core verdicts, ownership/structural ledgers và trace refs
        worker->>writer: DATA_READY refs/checksum/lease/batch_no, WP-1 envelope
        writer->>writer: Check current tuple, sequence, idempotency và constraints
        alt Batch mới và hợp lệ
            writer->>db: Bounded transaction: ledger + counts + batch checkpoint
            db-->>writer: Durable commit
        else Replay cùng batch ID và checksum
            writer->>db: Lookup prior durable ACK, không insert/count lại
        else Cùng ID khác checksum hoặc integrity conflict
            break Fatal integrity conflict
                writer-->>app: FAILED, cleanup và no publish
            end
        end
        writer-->>worker: Durable ACK cho batch đã chấp nhận
        worker->>gov: RELEASE credits sau durable ACK/consumer release
        writer-->>app: PROGRESS absolute committed units
    end
    worker-->>writer: Producers END, counts/checksums và final cursor coverage
    writer->>writer: Audit ownership, uniqueness, evidence, full coverage và count equations
    alt Full selected scope và integrity đạt
        writer->>db: Flush stores, atomic transaction result + publish marker + COMPLETED
        db-->>writer: Durable result ID/marker
        writer-->>app: COMPLETED chỉ sau publish
    else Incomplete coverage hoặc fatal integrity
        writer->>db: Discard unpublishable staging theo cleanup/lifecycle
        writer-->>app: PARTIAL hoặc FAILED, diagnostics only
    end
```

Nhánh integrity conflict là terminal cho attempt, không tiếp tục vòng lặp/finalize. Audit failure không phát COMPLETED. Byte credits áp cả queue lẫn producer-held buffers; CANCEL có control reserve riêng tại SEQ-07. SQL/SQLite là adapter candidate, invariant single logical writer và transaction semantics không phụ thuộc tên thư viện. Full uncertainty đã có complete ownership có thể COMPLETED; full snapshot không được thay bằng prefix parse.

## SEQ-05 — Stable query, detail và optional highlight

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant ui as Results/detail UI
    participant query as EX-1 query service
    participant store as Immutable result/evidence store
    participant high as Optional highlight worker
    user->>ui: Mở kết quả hoặc thay filter/order projection
    ui->>query: ResultQuery result ID, selection và bounded page request
    query->>store: Check current COMPLETED result và lease
    alt Invalid result hoặc cursor không khớp binding/filter/order
        query-->>ui: Block hoặc CURSOR_INVALID, không silently restart page
    else Valid query
        query->>query: Clamp cả page rows/bytes theo RP-1
        query->>store: Short-lived keyset page theo QO-1, không long read transaction
        store-->>query: Items, checksums, stable next token/end
        query-->>ui: Page + full_counts và selected_counts riêng
        user->>ui: Xem raw/canonical/rule/SourceRef detail
        ui->>query: Evidence request bound result/evidence/display version
        query->>store: Read bounded detail hoặc scalar-safe text chunks
        store-->>ui: Two-side evidence, reason và next offset/end
        opt Người dùng yêu cầu highlight
            ui->>high: Bound result/cell evidence version và highlight budget
            alt Trong budget và evidence đầy đủ
                high-->>ui: COMPLETE highlight offsets trên declared display text
            else Quá budget hoặc không có evidence
                high-->>ui: OMITTED_BUDGET hoặc UNAVAILABLE với reason
            end
        end
    end
```

Highlight không sửa cell verdict và không chạy lại normalization/matching. `NOT_REQUESTED` khi chưa yêu cầu. Text offsets là Unicode scalar positions, không byte/UTF-16 offsets. Unresolved groups hiển thị owned records từng phía, không dựng one-to-one pairs. UI giữ bounded page cache; denominator không tính lại từ các hàng đang hiển thị.

## SEQ-06 — Export và publish artifact hoàn chỉnh

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant ui as Export UI
    participant exp as EX-1 exporter
    participant result as Result/validity/query store
    participant render as Safe serializer/PDF renderer
    participant temp as Private pending output
    participant dest as User-selected destination
    user->>ui: Chọn kind, explicit full/filtered scope và destination
    ui->>exp: Versioned ExportRequest, result/revision, template/layout và profile
    exp->>result: Validate current COMPLETED result, selection/counts và acquire lease
    exp->>dest: Check verified atomic rename hoặc pending-object commit support
    alt Preconditions hoặc destination capability không đạt
        exp->>result: Release lease/reservation đã acquire nếu có
        exp-->>ui: Reject, không publish direct visible partial output
    else Hợp lệ và đã reserve scratch/output budget
        loop Bounded query pages và output chunks/pages/bands
            exp->>result: Read immutable selected cursors/evidence
            result-->>render: Stored verdicts/raw/refs/counts, không recompute semantics
            render->>temp: Stream CSV text-safe, JSON escaped hoặc passive PDF
        end
        exp->>temp: Flush/close, verify syntax/coverage/counts/pages và completed bytes hash
        exp->>result: Recheck current validity trước publish
        alt Cancel/error/quota/revoke hoặc stale result
            exp->>temp: Close handles và cleanup pending bytes
            exp-->>ui: CANCELLED hoặc FAILED, không artifact completed
        else Verification và validity đạt
            exp->>dest: Publish complete artifact bằng verified provider strategy
            alt Publish failure
                exp->>dest: Rollback/cleanup pending object theo provider guarantees
                exp-->>ui: FAILED, báo cleanup failure nếu có
            else Durable publish
                dest-->>exp: Commit/idempotency receipt
                exp->>result: External manifest/receipt và output hash
                exp-->>ui: COMPLETED và artifact reference
            end
        end
        exp->>result: Release evidence/result lease khi consumer xong
    end
```

`CSV_DIFF`, `JSON_REPORT`, `MERGED_DIFF_PDF`, `DYTAVA_REPORT_PDF`: một artifact/attempt/kind. Hai PDF là hai tệp riêng; mỗi kind vẫn một PDF nhiều trang, không tự split. Template Dytava1.0.0 và local fonts/assets theo Report. Full output quá budget thất bại; không tự đổi filtered scope hoặc truncate text. Output hash không nhúng vào chính artifact đã hash. Publish thành công nhưng mất ACK: tra receipt, không ghi tệp thứ hai; cancel sau durable publish không xóa user-owned artifact như temp.

JSON target ER-1 khác legacy renderer envelope1.0.0; bridge chỉ subset representable và admitted memory budget, reject precision/provenance/COUNT_GROUP mismatch. CSV quote đúng dialect chưa đủ chống formula injection; safe-text capability phải có reader-specific evidence. PDF không scripts/attachments/remote fetch.

## SEQ-07 — Cancel và protocol delivery guards

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant ui as Flutter UI
    participant app as Job coordinator
    participant worker as Active producers/workers
    participant writer as Writer và resource owners
    user->>ui: Hủy active attempt
    ui->>app: Cancel current generation
    app->>app: CANCELLING, retain current attempt binding
    app->>worker: WP-1 CANCEL qua reserved control path
    worker->>worker: Observe ở chunk yield, stop producers/cursors/sort/DP/render
    worker->>writer: Settle durable boundary, rollback/discard unpublished staging
    writer->>writer: Close handles, account leases/credits và pending cleanup
    alt Work stopped và cleanup consistency đạt
        writer-->>worker: Consistent cleanup boundary
        worker-->>app: CANCEL_ACK với command correlation và cleanup status
        app-->>ui: CANCELLED
    else Không phản hồi hoặc không đạt cleanup bound
        app->>worker: Controlled strong stop theo platform
        app->>writer: FAILED/INTERRUPTED và orphan sweep khi có thể
        app-->>ui: Failure diagnostic, không fake CANCEL_ACK
    end
    opt Event/message đến muộn hoặc phát lại
        worker-->>app: PROGRESS/DATA_READY/COMPLETED với WP-1 envelope
        alt Tuple cũ
            app->>app: Discard, không commit state/counters/result
        else Duplicate same producer/sequence/content
            app->>app: Idempotent handling, không apply hai lần
        else Sequence gap hoặc duplicate khác content
            app->>app: Bounded retransmission hoặc protocol failure theo hợp đồng
        end
    end
```

Import dùng state/event của INP-008, không bắt buộc phát comparison WP-1 message types. Comparison đã COMPLETED không bị cancel đến muộn đổi thành CANCELLED. Sequence numbers tăng theo producer/attempt/generation; JSON sequence/generation/counts là exact decimal integer strings. Không bỏ qua gaps của terminal/counter events. Khi RESOLVE thay effective plan, cancel old work và new generation → VALIDATING.

## SEQ-08 — Recovery và lease retention

```mermaid
sequenceDiagram
    autonumber
    actor user as Người dùng
    participant app as App startup/session coordinator
    participant journal as Minimal private journal
    participant store as Scratch/snapshot/result owners
    participant access as Scoped access broker
    participant ui as Flutter UI
    app->>journal: Inspect sau process death/relaunch
    journal-->>app: Minimal metadata và interrupted attempt identity
    app->>app: Job đang active trước kill thành historical INTERRUPTED
    app->>store: Startup sweep orphan/unowned generations và pending outputs
    alt Còn private source ref hợp lệ để revalidate
        app->>access: Recheck access, không tin ready/running cũ
        app-->>ui: Restore slot SELECTED, IMPORT_INTERRUPTED issue
    else Không còn ref có thể dùng
        app-->>ui: Restore UNSELECTED, yêu cầu chọn nguồn lại
    end
    user->>ui: Chọn/revalidate nguồn và xác nhận lại khi cần
    ui->>app: Restart import/plan bằng attempt mới
    app->>app: SEQ-01 và SEQ-03, không resume prefix/checkpoint cũ
    opt Trong một phiên live hợp lệ
        ui->>store: Acquire consumer leases để query/detail
        app->>store: Export consumer acquire lease độc lập
        ui->>store: Release UI lease khi xong
        store->>store: Giữ evidence nếu export/consumer khác còn live
        app->>store: Release export/session owner leases khi xong
        store->>store: Cleanup khi không còn owner/consumer cần raw/scratch
    end
    app->>journal: Chỉ giữ safe non-raw history nếu user opt-in
```

Journal có thể giữ private recovery ref theo platform controls; không serialize raw/URI/token vào logs hoặc public history. Sau process death không dùng durable batch/publish marker để bypass revalidation/startup lifecycle. Trong live attempt, mất ACK sau durable batch/publish có thể lookup idempotent receipt nếu lineage/leases còn hợp lệ. User-exported files thuộc người dùng, không bị startup sweep như scratch. Đóng source handle bình thường không phải access revoke.

## Đọc cùng

[Activity diagrams](MOBILE_ACTIVITIES.md) · [State diagrams](MOBILE_STATES.md) · [System/domain diagrams](MOBILE_MODELS.md) · [Coverage và baseline](MOBILE_DIAGRAM_COVERAGE.md). Khi chủ sở hữu hợp đồng đổi nội dung, kiểm tra lại sơ đồ; không tự đổi owner contracts để khớp hình.
