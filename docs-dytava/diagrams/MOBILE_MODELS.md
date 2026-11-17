---
document_id: DYT-DIAG-MODEL-001
version: 1.0.0
status: DRAFT
owner: Documentation integration role
reviewer: TBD
updated: 2026-11-17
release_baseline: Android P0 mở rộng; UDG3.1
execution_state: NOT_VERIFIED
---

# System, domain và deployment diagrams — Dytava Mobile

Các mô hình dưới đây là **thiết kế mục tiêu**. Tên vai trò/domain objects lấy từ owner contracts; không suy ra class, package, database schema hoặc dependencies đã cài. [Coverage](MOBILE_DIAGRAM_COVERAGE.md) ghi ranh giới P0/extension và nguồn đối chiếu. Các flowchart context/use case/deployment là biểu diễn tương đương bằng Mermaid, không giả định Mermaid hỗ trợ ký pháp UML/C4 native đầy đủ.

| Sơ đồ | Góc nhìn | Bản render |
| --- | --- | --- |
| MOD-01 | Context và use cases | [SVG](mobile-models/01-context-use-cases.svg) |
| MOD-02 | Components, ports và dependency direction | [SVG](mobile-models/02-components.svg) |
| MOD-03 | Domain class model, logical references | [SVG](mobile-models/03-domain-classes.svg) |
| MOD-04 | ER logical của result persistence | [SVG](mobile-models/04-result-erd.svg) |
| MOD-05 | Android deployment và trust boundaries | [SVG](mobile-models/05-deployment.svg) |
| MOD-06 | UDG3.1 L0–L10 và cross-cutting contracts | [SVG](mobile-models/06-udg-layers.svg) |
| MOD-07 | Geometry, merged cells và logical transpose | [SVG](mobile-models/07-geometry.svg) |
| MOD-08 | Canonical signatures, policy/config digest và cache binding | [SVG](mobile-models/08-signatures-cache.svg) |
| MOD-09 | Resource governor và ownership/lease lifecycle | [SVG](mobile-models/09-resources-leases.svg) |
| MOD-10 | Capability/phase gates và extension paths | [SVG](mobile-models/10-extension-gates.svg) |
| MOD-11 | Verification và release evidence gates | [SVG](mobile-models/11-release-gates.svg) |

## MOD-01 — Context và use cases

Nguồn: [PRD](../product/PRD.md), [SRS](../requirements/SRS.md), [ADR scope](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md), [Architecture §1–4](../architecture/ARCHITECTURE.md).

```mermaid
flowchart LR
    user([Người dùng])
    source[Android SAF file provider hoặc camera/gallery]
    output[User-selected output provider]
    subgraph mobile["Dytava Mobile — Android P0 mục tiêu"]
        choose["Chọn hai nguồn độc lập A/B"]
        preview["Inspect, preview, xác nhận một scope/header mỗi phía"]
        ocr["OCR một PNG/JPEG, sửa grid/text và review bắt buộc"]
        config["Confirm mapping, KEY/POSITIONAL, policy và direction"]
        compare["UDG3.1 comparison với provenance và bốn cell verdicts"]
        result["Thống kê, lọc và difference detail hai phía"]
        export["Explicit CSV/JSON, merged diff PDF và Dytava report PDF"]
        lifecycle["Cancel, retry, close và restart/revalidate"]
    end
    user --> choose
    user --> preview
    user --> ocr
    user --> config
    user --> result
    user --> export
    user --> lifecycle
    source -->|"User-scoped read-only access"| choose
    choose --> preview
    preview -->|"Conditional image review"| ocr
    preview -->|"Tabular snapshot validated"| config
    ocr -->|"Reviewed snapshot validated"| config
    config --> compare
    compare --> result
    result --> export
    export -->|"Complete new artifacts"| output
```

Use cases không phải quan hệ UML `include/extend` tự động; edges mô tả phạm vi/tương tác và dependencies của hành trình. P0 không có admin actor, backend/cloud OCR, đăng nhập bắt buộc hoặc upload. Một workbook nhiều sheets chỉ phục vụ chọn một scope; không batch compare. Target input ≤1.000.000.000 bytes mỗi nguồn, vẫn có separate decompression/pixel/resource guards.

## MOD-02 — Components, ports và dependency direction

Nguồn: [Architecture §2–3](../architecture/ARCHITECTURE.md), [ER-1/WP-1](../specs/engine/04_result_runtime.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md).

```mermaid
flowchart TD
    ui["Presentation: Flutter Views / ViewModels"] --> app["Application: use cases và job coordinator"]
    app --> domain["Domain: Pure Dart policy, geometry, matching, typed comparison"]
    app --> ports["Application/domain ports: Input, access, stores, worker, export"]
    domain --> models["Immutable domain models, refs và contracts"]
    domain -.->|"Chỉ abstractions khi cần I/O"| ports
    subgraph infra["Infrastructure implements ports; không được import từ Domain"]
        access["FileAccessPort adapter: scoped read-only SAF"]
        input["Preflight và XLSX/CSV/TSV adapters"]
        ocr["Bundled OCR adapter, extraction và review storage"]
        runtime["Worker transport và WP-1 coordinator adapter"]
        stores["Private snapshot/result stores, single logical writer"]
        exporter["CSV/JSON exporter và manifest builder"]
        pdf["PDF renderer, template registry và local fonts/assets"]
    end
    access -.->|"implements"| ports
    input -.->|"implements"| ports
    ocr -.->|"implements"| ports
    runtime -.->|"implements"| ports
    stores -.->|"implements"| ports
    exporter -.->|"implements"| ports
    pdf -.->|"implements"| ports
```

Đây là **code dependency** view: solid arrow là dependency, dotted `implements` là hướng thực thi abstraction. Không dùng các mũi tên này làm byte/data-flow arrows. Ports thuộc application/domain theo trách nhiệm; không tạo vòng import ngược Infrastructure→Domain→Infrastructure. Composition root bên ngoài Domain wire implementations. Core không import Flutter, Android SDK, OCR SDK, database driver, file picker hoặc URI. Input/OCR không tự canonicalize semantic; exporter không chạy lại Core.

## MOD-03 — Domain class model

Nguồn: [INP-002](../specs/input/02_source_artifacts.md), [ISC-1](../specs/input/11_streaming_snapshot_contract.md), [EP-1](../specs/engine/01_execution_plan.md), [ER-1](../specs/engine/04_result_runtime.md). Đây là logical references; cardinality không buộc materialize arrays trong heap.

```mermaid
classDiagram
    class SourceArtifact {
        artifact_id
        side
    }
    class SnapshotDescriptor {
        snapshot_id
        generation
        source_sha256
        source_bytes
        import_config_revision
        selected_scope
        record_count
        raw_store_ref
    }
    class ValidationReceipt {
        eof
        completed_check_ids
        blocking_issues
        guard_profile_digest
    }
    class RawRecord {
        record_id
        ordinal
        source_span
    }
    class SourceCell {
        raw_kind
        lexical_status
        raw_lexeme
        null_kind
        losses
    }
    class SourceRef {
        artifact_id
        exists
        tagged_location
    }
    class OcrReviewReceipt {
        receipt_id
        source_sha256
        extraction_revision
        grid_revision
        selected_scope_digest
        cell_id
        reviewed_text_digest
    }
    class ComparisonPlan {
        plan_id
        plan_digest
        mode
        direction
        mapping_revision
        ordered_key_field_ids
        confirmation_receipts
    }
    class FieldMapping {
        logical_field_id
        field_ids_a_b
    }
    class CompiledPolicy {
        policy_version
        policy_digest
        encoding_version
    }
    class ResourceProfile {
        profile_id
        revision
        state
        calibration_evidence_refs
    }
    class ResultSnapshot {
        contract_version
        result_id
        state
        scope_completion
        lineage
        ledger_refs
    }
    class ResultValidity {
        result_id
        current_stale_revoked
        invalidation_revision
    }
    class ExportRequest {
        export_id
        attempt_id
        kind
        selection
        template_layout_versions
    }
    SourceArtifact "1" --> "0..*" SnapshotDescriptor : validated revisions
    SnapshotDescriptor "1" --> "1" ValidationReceipt : freeze gate
    SnapshotDescriptor "1" --> "0..*" RawRecord : bounded cursors
    RawRecord "1" --> "0..*" SourceCell : field projection
    SourceCell "1" --> "1" SourceRef : real or declared missing
    SourceCell "1" --> "0..*" OcrReviewReceipt : OCR review history
    ComparisonPlan "0..*" --> "2" SnapshotDescriptor : current A and B
    ComparisonPlan "1" --> "0..*" FieldMapping : confirmed bijection
    ComparisonPlan "0..*" --> "1" CompiledPolicy : effective policy
    ComparisonPlan "0..*" --> "1" ResourceProfile : resolved revision
    ComparisonPlan "1" --> "0..*" ResultSnapshot : completed executions
    ResultSnapshot "1" --> "1" ResultValidity : separate mutable registry
    ExportRequest "0..*" --> "1" ResultSnapshot : immutable published input
```

`CompiledPolicy`, `FieldMapping` và `ResourceProfile` là tên vai trò model để gom các fields trong contract, không định nghĩa schema mới. SourceRef là closed union theo Input; JSON refs thuộc P1, không bật JSON input từ model. OCR receipts chỉ áp OCR; non-OCR cells không mang OCR receipt fields. Một receipt hiện hành cho mỗi selected OCR cell tại freeze; lịch sử revisions không thay thế current receipt gate. SourceArtifact giữ private access metadata tại infrastructure; sơ đồ bỏ access refs khỏi public/Domain projection.

## MOD-04 — Logical ER: result persistence

Nguồn: [ER-1 §1–4](../specs/engine/04_result_runtime.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md). Đây là quan hệ logic, không phải SQL DDL/Drift schema đã tồn tại. IDs/refs nằm trong frozen result/generation, không encode raw key hoặc PII.

```mermaid
erDiagram
    ComparisonPlan ||--o{ JobAttempt : executes
    JobAttempt ||--o{ StagingBatch : stages
    JobAttempt ||--o| ResultSnapshot : may_publish
    ResultSnapshot ||--|| PublishMarker : atomically_published_with
    ResultSnapshot ||--|| ResultValidity : current_registry
    ResultSnapshot ||--o{ RecordOwnership : owns_records
    ResultSnapshot ||--o{ RecordPair : instance_pairs
    ResultSnapshot ||--o{ UnresolvedGroup : abstentions
    ResultSnapshot ||--o{ StructuralEvent : separate_structures
    RecordPair ||--o{ MatchedCell : mapped_cell_pairs
    RecordPair o|--o{ RecordOwnership : matched_owners
    UnresolvedGroup o|--o{ RecordOwnership : unresolved_owners
    ResultSnapshot ||--o{ ExportAttempt : exports
    ExportAttempt ||--o| PublishedArtifact : may_complete
    ResultSnapshot ||--o{ CountGroup : multiset_extension_only
    ResultSnapshot {
        opaque result_id PK
        exact_integer generation
        opaque plan_id
        enum state
        enum scope_completion
        object lineage
        object summary
    }
    RecordOwnership {
        opaque record_id
        enum side
        ordinal ordinal
        enum category
        opaque pair_or_group_ref
    }
    RecordPair {
        opaque pair_id PK
        opaque record_a_id
        opaque record_b_id
        enum content_state
        list flags
    }
    MatchedCell {
        opaque cell_pair_id PK
        opaque pair_id FK
        opaque logical_field_id
        enum verdict
        reference evidence_refs
        reference source_refs
    }
    StagingBatch {
        exact_integer generation
        opaque producer_id
        exact_integer batch_no
        digest checksum
        object committed_counts
    }
```

Ràng buộc bắt buộc dù adapter không dùng SQL:

- Ownership unique `(generation, scope, side, record_id)`, category đúng một trong MATCHED/UNMATCHED/UNRESOLVED. MATCHED có pair ref, UNRESOLVED có group ref, UNMATCHED có reason; không đồng thời cả pair/group. Một pair có đúng hai matched owners A/B trong scope.
- Unique record A và B trong paired ledger; unique `(pair_id, logical_field_id)` cho cells. Zero mapped fields được phép structural-only nhưng pair content UNRESOLVED/NO_MAPPED_FIELDS; không tạo cell giả.
- Batch unique `(generation, producer_id, batch_no)`; replay cùng checksum idempotent, khác checksum là integrity conflict. Không unique raw key toàn DB vì duplicate keys là dữ liệu cần báo.
- `INSTANCE_PAIR`: có record pairs/cells, không CountGroup. `COUNT_GROUP` extension: groups/member cursors/multiplicities, không fabricated instance pairs/cells. ER edges không cho phép trộn hai variants trong một result.
- Result snapshot/marker/COMPLETED publish cùng atomic boundary; validity registry mutable riêng. Summary reconciles ledgers, counters exact integers; JSON adapters dùng decimal strings. PublishedArtifact chỉ có khi commit hoàn chỉnh.

## MOD-05 — Android deployment và trust boundaries

Nguồn: [Architecture §5–7](../architecture/ARCHITECTURE.md), [NFR](../requirements/NFR.md), [ADR register](../decisions/ADR_REGISTER_P0_2026-11-11.md). Sơ đồ deployment logic, không chốt thư viện/plugin chưa PoC.

```mermaid
flowchart LR
    user([Người dùng])
    source["OS file provider: untrusted source bytes, scoped grant"]
    camera["Camera/gallery: explicit action và scoped permission"]
    destination["OS destination provider: complete user-owned exports"]
    subgraph sandbox["Android app sandbox — local P0"]
        subgraph process["App process; whole-process RAM được accounting"]
            ui["Main Dart isolate: Flutter UI và coordinator"]
            worker["Bounded helper isolates: parse/Core/export work"]
            native["Native bridge: SAF/image và bundled OCR recognizer"]
            assets["APK local assets: OCR model, fonts và Dytava branding"]
        end
        storage["App-private disk: immutable spools, raw/SST/style indexes, sort runs"]
        result["Private result store, WAL/journal nếu adapter dùng, pending PDF/JSON/CSV"]
        recovery["Minimal recovery journal; source refs chỉ private broker"]
    end
    user --> ui
    source -->|"Read-only stream qua scoped access"| native
    camera -->|"Bounded image input"| native
    ui -->|"Control và versioned refs"| worker
    worker -->|"Bounded progress/data-ready refs"| ui
    native -->|"Byte streams hoặc OCR text/geometry"| worker
    assets --> native
    assets --> worker
    worker --> storage
    worker --> result
    ui --> recovery
    result -->|"Verified pending/atomic publish strategy"| destination
```

Các stores là logical responsibilities, không bắt buộc ba database/process. Isolates không share mutable heaps; native allocations, message copies, fonts/bitmap, DB cache và WAL đều tính budget. Android can suspend/kill process; không claim background completion hoặc xóa scratch ngay lúc bị kill. Startup sweep và revalidation theo SEQ-08. P0 không có network/backend/cloud dependency; provider có thể network-backed nhưng không tự fetch embedded links hoặc bypass access failure. iOS/Web cần deployment/profile/device evidence riêng; không suy parity.

## MOD-06 — UDG3.1 theo L0–L10

Nguồn: [UDG3.1 index](../specs/engine/README.md). Layers là trách nhiệm logic, không yêu cầu thêm 11 packages, cũng không cấm streaming overlap hợp lệ.

```mermaid
flowchart TD
    l0["L0 EP-1: inspect/preliminary plan, capability và confirmation gates"]
    l12["L1–L2 ISC-1: read-only access, guards, parse, EOF/hash và snapshot freeze"]
    l3["L3 GF-1: confirmed scope/view, axis, merges và Field ID mapping"]
    freeze["Freeze final EP-1 với current snapshots, policy/direction và RP-1"]
    l4["L4 CE-1/CFG-1: typed canonical values, framed keys và signatures"]
    l56["L5–L6: KEY external sort/global grouping hoặc POSITIONAL zip"]
    l7["L7 Core: typed decisions, raw/canonical trace và orthogonal flags"]
    l8["L8 ER-1: ownership/pairs/cells/structural ledgers, audit và publish"]
    l10["L10 EX-1: bounded query, CSV/JSON và hai PDF exporters"]
    l0 --> l12 --> l3 --> freeze --> l4 --> l56 --> l7 --> l8 --> l10
    l9["L9 WP-1/application runtime: attempts, generations, credits, cancel/recovery"]
    rp["RP-1/NFR: finite calibrated budgets và whole-process/disk accounting"]
    l9 -.-> l12
    l9 -.-> l56
    l9 -.-> l8
    l9 -.-> l10
    rp -.-> l0
    rp -.-> l12
    rp -.-> l9
    rp -.-> l10
    raw["Private raw/evidence persistence phục vụ từ Input tới UI/export bằng leases"]
    l12 --> raw
    raw -.-> l3
    raw -.-> l7
    raw -.-> l10
```

L0 có preliminary inspect plan trước EOF nhưng final freeze chỉ sau các preconditions. L8 persistence bắt đầu phục vụ Input, không đợi L7 mới lưu. L9 điều phối xuyên pipeline, không phải stage cuối mới nhận cancel. Domain normalization không diễn ra ở Input. Result query/render chỉ đọc published snapshot, không tái tính semantics.

## MOD-07 — Geometry, merged cells và transpose

Nguồn: [Geometry L3](../specs/engine/02_geometry_mapping.md), [INP-004](../specs/input/04_tabular_structure.md).

```mermaid
flowchart TD
    snapshot["Frozen raw snapshot và SourceRefs gốc"] --> select["Xác nhận một selected scope mỗi phía; bounds/header/hidden policy"]
    select --> proposal["GF-1 deterministic bounded sample: type, header, occupancy và explanations"]
    proposal --> confirm["User confirm orientation và mapping bằng Field IDs; proposal không auto-accept"]
    confirm --> merge["Validate merged ranges/anchors; reject malformed overlap hoặc bounds"]
    merge --> policy{"Confirmed merge policy?"}
    policy -->|"anchorOnly mặc định"| anchor["Value ở anchor; covered positions là MERGED_REFERENCE"]
    policy -->|"visualOnly"| visual["Giữ layout metadata; compare raw physical cells"]
    policy -->|"propagateForGrouping explicit"| grouping["Chỉ group-key field được confirm; anchor references và trace, không copy measure values"]
    anchor --> axis
    visual --> axis
    grouping --> axis{"Confirmed logical axis?"}
    axis -->|"Row-oriented"| rows["SOURCE_ORDINAL cursor và mapped-field projection"]
    axis -->|"Column-oriented"| transpose["External sort bounded logical record/field/physical references; không dense matrix"]
    transpose --> cols["Sequential logical cursor, bounded locality/cache"]
    rows --> view["Frozen view digest/cursor; source coordinates không đổi"]
    cols --> view
    view --> compare["Match/diff bằng logical ordinals và stable field IDs"]
```

GF-1 dùng first source ordinals trong **cả** sample-record/sample-byte budgets; missing features là null, ties giữ proposals, stable ID chỉ ổn định UI. Timeline không có explicit parse profile không được đoán kiểu. Transpose/mapping đổi tạo view/cursor binding mới; không đổi SourceRef. Multi-scope future aggregate phải reject overlap trước freeze; không auto-deduplicate các ô đếm hai lần. Cancel khi build view bỏ staging refs, không publish view một phần.

## MOD-08 — Signatures và cache binding

Nguồn: [CE-1/CFG-1](../specs/core/CANONICAL_ENCODING.md), [EP-1 invalidation](../specs/engine/01_execution_plan.md#3-invalidation-matrix).

```mermaid
flowchart LR
    bytes["Source bytes đã đọc đúng EOF"] --> sourceHash["Source SHA-256 fingerprint; hai artifact slots vẫn độc lập"]
    effective["Resolved effective config/policy và versions; reject unknown ops/duplicate JSON keys"] --> cfg["CFG-1 canonical AST bytes; exact numbers, ordered arrays, UTF-8-sorted object keys"]
    cfg --> digest["Domain-separated policy/config digest; bỏ timestamps, URI và self-digest"]
    raw["Typed raw evidence và confirmed field policy"] --> normalize["Core normalization có trace; unresolved không encode như valid null"]
    normalize --> ce["CE-1 typed length frames; byte lengths, exact decimals và scale facet"]
    ce --> key["Ordered strict key field bytes và key signature"]
    ce --> content["Canonical record bytes và exact-content signature"]
    key --> keyCheck["Hash hit vẫn compare full key bytes; không tolerance/fuzzy"]
    content --> contentCheck["Hash hit vẫn verify full record bytes; không shortcut cell EXACT"]
    sourceHash --> cache["Cache binding: snapshot/import/extraction/view/map/field/policy/engine/encoding versions"]
    digest --> cache
    ce --> cache
    cache --> derivatives["Key/content/match/export caches thêm own mode, direction, selection và template dependencies"]
    derivatives --> invalid["Dependency đổi: invalidate partition/index/result phù hợp; không reuse partial như full"]
```

Source fingerprint là SHA-256 raw bytes không CE framing; signatures khác dùng domain separation `H(domain,payload)` theo CE-1. Key equality không dùng whole-record content hash; sửa non-key value vẫn giữ entity pair nếu key hợp lệ. Tolerance không bắc cầu nên không key/MULTISET grouping. Cache chỉ usable khi raw/evidence leases đủ; same raw text khác locale/source profile không share normalization entry. Không implicit NFC/trim/casefold ở serializer.

Policy precedence theo Core: conservative defaults → policy defaults → field semantic/comparison rules → A/B overrides **chỉ parse**. Compiler reject unknown keys/operations, mapping không bijective, keys thiếu/không strict, tolerance âm, separator conflict hoặc aliases collision. Policy schema_version2, policy_version2.1.0 và engine/encoding versions có nghĩa riêng; không thay thế lẫn nhau.

## MOD-09 — Resource governor và lease ownership

Nguồn: [RP-1](../requirements/RESOURCE_PROFILES.md), [ISC-1](../specs/input/11_streaming_snapshot_contract.md), [ER-1 §7](../specs/engine/04_result_runtime.md#7-resources-cancellation-và-retention).

```mermaid
flowchart TD
    subgraph admission["Admission và pressure behavior"]
        direction TB
        profile["Resolve compatible finite RP-1 profile revision"] --> gate{"USER_COMPARISON có ENABLED profile và VERIFIED capabilities?"}
        gate -->|"Không"| blocked["Fail closed; không fallback profile nhỏ hoặc cloud"]
        gate -->|"Có"| reserve["Preflight RAM/disk headroom; reserve byte/work credits trước allocation"]
        reserve --> pressure{"Runtime pressure?"}
        pressure -->|"Within bound"| chunk["Bounded chunk, commit/drain và yield cho control"]
        chunk --> reserve
        pressure -->|"Soft"| soft["Stop admission, drain, evict reusable cache, spill theo strategy"]
        soft --> reserve
        pressure -->|"Hard hoặc elapsed/work limit"| stop["Stop trước allocation kế tiếp; rollback hoặc counted abstention khi contract cho phép"]
        stop --> noPartial["Input chưa EOF không READY; incomplete result không export"]
    end
    subgraph ownership["Artifact owners và consumers"]
        direction TB
        attempt["Live attempt owns mutable private spool/index/staging"] --> freeze["Validated freeze chuyển ownership/leases rõ ràng"]
        freeze --> snapshot["Snapshot/result owners giữ immutable evidence stores"]
        snapshot --> consumers["UI/Core/export acquire consumer leases"]
        consumers --> release["Idempotent release khi consumer/session xong"]
        release --> live{"Còn owner hoặc consumer hợp lệ?"}
        live -->|"Có"| snapshot
        live -->|"Không"| cleanup["Close/delete private scratch; startup sweep orphan sau kill"]
        cleanup --> retained["Giữ user-exported artifacts; history chỉ safe non-raw metadata nếu opt-in"]
    end
    admission ~~~ ownership
```

Internal `CALIBRATION_TEST` là path riêng với build gate, CALIBRATING finite candidate profiles và safety guards; không dùng cho user compare hoặc production claim. Soft-pressure retries vẫn chịu finite stage/work/inactivity limits, không loop vô hạn. Data queues không chiếm control-reserved bytes; cancel có observe/stop/cleanup bounds riêng. RAM tính UI/all isolates/native/DB/messages/fonts/bitmaps; disk tính source+SST+raw+sort+results+WAL+pending outputs và overlap. Không xóa live snapshot để lấy disk cho export. Không điền ngưỡng chưa đo hoặc suy throughput từ source-size cap.

## MOD-10 — Pha và extension eligibility

Nguồn: [PRD §3](../product/PRD.md#3-release-scope--nguồn-quản-lý-duy-nhất-cho-phase-assignment), [Matching §5–7](../specs/engine/03_candidate_alignment.md#5-multiset-extension), [Core decisions §3–4](../specs/core/COMPARISON_DECISIONS.md#3-dateformulastyle-extensions).

```mermaid
flowchart TD
    requested["Requested platform/format/mode/type/features"] --> p0{"Trong baseline Android P0?"}
    p0 -->|"Có"| p0gate["XLSX/CSV/TSV hoặc tối đa một reviewed image; KEY/POSITIONAL; P0 dtypes"]
    p0gate --> verified{"Current confirmations, VERIFIED capabilities và ENABLED profile?"}
    verified -->|"Có"| run["Frozen P0 plan và four-state typed comparison"]
    verified -->|"Không"| reject["Reject trước RUNNING; không silent switch"]
    p0 -->|"Không"| ext{"Extension capability/version/profile và owner contract đã đủ gate?"}
    ext -->|"Chưa, mặc định disabled"| reject
    ext -->|"Có trong release riêng"| kind{"Extension nào?"}
    kind -->|"MULTISET"| multi["Same full confirmed logical schema; exact canonical equivalence; không tolerance/unresolved"]
    multi --> count["External sort full record bytes; common=min counts, residual multiplicities; COUNT_GROUP"]
    kind -->|"ORDERED_SEQUENCE"| ordered["Confirm order/identity/anchors; unique global strict identity; bounded DP và traceback"]
    ordered --> search{"Unique optimal path, certified band và session budget hợp lệ?"}
    search -->|"Có"| pairs["Eligible instance pairs, rồi Core quyết định cell verdict"]
    search -->|"Tie, uncertified hoặc quá budget"| abstain["Counted whole-segment unresolved; không fake absence hoặc unbounded fallback"]
    kind -->|"DATE/formula/style hoặc platform/format khác"| features["Gate và tests riêng; không tự bật từ schema, icon hoặc web evidence"]
    count --> result["Mode-specific ER-1/query/export support bắt buộc; không legacy coercion"]
    pairs --> result
    abstain --> result
```

Extension count-group không sinh arbitrary instance pairs/cell rates; denominator paired cells bằng0/N/A. ORDERED có insertion/deletion cost1, eligible match cost0; noneligible diagonal bị cấm, path count capped2 để abstain ties. Band chỉ finalize nếu certified optimality hoặc user-confirmed displacement constraint. Candidate/DP/work counters cộng dồn **toàn job**, top-k/truncation không chứng minh absence. Coordinate shift là flag, không P0 definitive MOVED.

DATE serial60/thiếu date-system, DATETIME zone/DST ambiguity và formula cache missing/stale có unresolved decisions theo Core; không suy source metadata. Formula modes không evaluate expressions; style/metadata là facets riêng không trộn cell similarity. JSON input/iOS là P1; PDF input, cloud OCR và unsupported formats không được enable bằng sơ đồ này. Các extension paths là diễn giải contracts có sẵn, không thay phase assignment hoặc khẳng định release đã có.

## MOD-11 — Verification và release evidence gates

Nguồn: [NFR §5](../requirements/NFR.md#5-phương-pháp-test-chỉ-số-và-quality-gates), [RP-1](../requirements/RESOURCE_PROFILES.md), [Build/Release guide](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md), [UDG acceptance](../testing/UDG_CONTRACT_ACCEPTANCE.md).

```mermaid
flowchart TD
    baseline["Owner contracts, phase decisions và versioned schemas/fixtures"] --> review["Review/sign-off và implementation; không đổi PLANNED thành PASS từ docs"]
    review --> tests["PR checks: format/analyze, Dart/Flutter tests và independent golden oracles"]
    tests --> gates["Collect platform-specific evidence cho mọi gate G0–G7"]
    gates --> contracts["G0–G1: contracts/validators, domain unit/golden/property tests"]
    gates --> adapters["G2–G3: XLSX/CSV fidelity và bundled OCR manual-review trên Android"]
    gates --> safety["G4–G5: security/privacy, cancel/restart, performance và accessibility"]
    gates --> large["G7: full valid 1 GB/source corpus và hai PDF, counts/lineage/render QA"]
    contracts --> reconcile["Evidence gắn build/commit, fixture hashes, expected/observed và device/profile versions"]
    adapters --> reconcile
    safety --> reconcile
    large --> reconcile
    reconcile --> package["G6: signed Android APK, checksum, install/run smoke offline trên thiết bị"]
    package --> enabled{"Evidence/review đầy đủ cho advertised capability và RP-1 profile?"}
    enabled -->|"Có"| advertise["Chỉ công bố platform/format/mode/profile đã được kiểm chứng"]
    enabled -->|"Chưa"| pending["Giữ NOT_VERIFIED hoặc disabled; bổ sung tests/implementation/evidence"]
    calibration["Internal CALIBRATION_TEST với finite CALIBRATING profile; safety guards và build gate"] --> reconcile
```

Các cạnh là dependency/evidence flow, không bắt buộc lịch chạy tuần tự hoặc song song. Calibration harness cho phép đo trước enable, tránh vòng lặp yêu cầu ENABLED trước khi có thể tạo evidence. G6 ký/build không thay G7 1 GB/PDF hoặc plugin/device tests. Các TARGET chưa đo (preview, crash-free, coverage, OCR metrics) không được điền thành kết quả. Android evidence không cấp iOS/Web parity; iOS P1 cần signing/permissions/VoiceOver/device gates riêng. Sơ đồ không thực hiện build, ký, upload hoặc phát hành.

## Đọc cùng

[Activity diagrams](MOBILE_ACTIVITIES.md) · [Sequence diagrams](MOBILE_SEQUENCES.md) · [State diagrams](MOBILE_STATES.md) · [Coverage và baseline](MOBILE_DIAGRAM_COVERAGE.md).
