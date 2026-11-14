---
document_id: INP-011
version: 0.2.0
status: DRAFT
owner: Input contract role
reviewer: Input and runtime review roles; assignees pending
updated: 2026-11-13
contract_version: ISC-1
wire_schema_status: Target 0.2.0 specified; existing JSON Schemas remain 0.1.0
---

# Streaming, snapshot và OCR handoff — L1/L2

Đây là extension nguồn của [Input](README.md), hoàn thiện access/pass plan và logical contract ISC-1. Giữ nguyên physical/raw/ref semantics ở [INP-005](05_data_types_provenance.md), state guards ở [INP-008](08_import_state_machine.md), source limit tại [NFR](../../requirements/NFR.md). Không diễn giải semantic hoặc sửa JSON Schemas 0.1.0 dưới cùng version.

## 1. Access capabilities và thứ tự preflight

`SourceAccessDescriptor`: artifact_id, side, generation, private access_ref, provider size estimate/unknown, `can_seek`, `can_reopen`, access lifetime/revocation semantics. access_ref không đi vào report/log/Domain. Provider metadata không là actual byte count.

Thứ tự bắt buộc: acquire read-only permission → validate selected format prefix/content → resolve compatible RP-1 profile → check known source size và scratch estimate → bounded read/count/hash → format-specific guards trước cấp phát → parse/validate → freeze. EOF/hash và actual byte limit luôn được kiểm kể cả metadata size đúng. Dừng ở byte vượt trần, không hoàn tất nguồn bằng prefix; input hash chỉ final sau EOF.

| Access case | Strategy đã chọn | Fingerprint binding |
| --- | --- | --- |
| Stable local seekable immutable handle | Có thể parse trực tiếp; multi-pass phải dùng cùng stable bytes | Hash đúng stream đã parse, verify trước freeze; stability guarantee ghi vào manifest |
| Reopenable nhưng provider mutable/không có stability guarantee | Copy toàn source vào app-private immutable spool khi count/hash; sau đó parse spool | Freeze dùng SHA-256 của spool/parse bytes, không hash lượt provider khác |
| Non-seekable | Bounded source spool một lượt, sau đó inspect/parse theo format | EOF/count/hash cùng copy; scratch fail thì abort, không fallback RAM |
| Permission revoke/source changed | Invalidate attempt/snapshot, close readers, cleanup theo consumers | Không dùng prefix hash hoặc metadata cũ |

Source spool là dữ liệu nhạy cảm, chỉ internal scoped reference. Trước mỗi pass trên spool kiểm immutable identity/length/checksum metadata; corruption abort. User export không bao giờ target cùng source handle. Hash kiểm input-before/after về sau không phải quyền ghi nguồn.

## 2. Format-specific pass plan

### XLSX

Pass A: inspect OPC/ZIP central directory và relationships trong budgets; validate part names, traversal/overlap/truncation/encryption/CRC strategy. Không trust claimed dimensions/uncompressed sizes để bỏ counters. Declared size/ratio có thể reject sớm; runtime actual expansion counters vẫn bắt buộc.

Pass B: stream relevant workbook metadata, styles, date system, SST và selected worksheet metadata vào bounded stores. SST chọn **immutable decompressed length-framed text spool + disk ordinal→offset/length index**; lookup bằng ordinal và bounded cache. Offset là byte position trong spool không nén, không phải compressed ZIP stream. Inline strings không đòi SST; rich runs giữ resolved text/format losses theo INP-005. Style/merge indexes cũng disk-backed khi vượt cache. Bounded entry/field/token length kiểm trước materialize string.

Pass C: stream selected worksheet cells, resolve refs qua indexes, write raw sparse row store/provenance. Metadata nằm sau sheetData được thu trong metadata pass trước freeze. Không nhân dense rectangle theo declared dimensions; absent cells được tạo missing ref khi logical cursor yêu cầu, không materialize hàng triệu blanks.

Pass D: verify selected scope completeness, cross refs/merges, actual expansion/entry integrity đã đọc, EOF/hash của source spool và whole-package safety scan theo capability. Part chưa đọc đầy đủ không được ghi “CRC verified”; policy phải scan integrity trong bounded pass hoặc khai loss/reject nếu capability yêu cầu. Chỉ freeze khi required checks của adapter manifest đều done. Không đánh đồng selected-table EOF với source read/hash EOF.

### CSV/TSV

Strict UTF-8 decoder và dialect parser incremental qua chunks; giữ CR/LF/escaped quotes/multiline states và physical line counter. Raw field text sau unquote/unescape theo INP-005; source byte hash giữ bằng chứng gốc. Header/scope phải confirmed. Full parser EOF không có pending UTF-8/quote token; logical records và SourceRefs được freeze cùng byte hash. Không truncate long cell; reject vượt profile với observed/limit.

### OCR

Decode chỉ sau dimension/pixel/estimated decoded-bytes guards. Recognizer bundled/offline tạo draft extraction; chỉnh grid/text/crop không sửa raw image/text. Full reviewed table materialize/spool trong budget; handoff chỉ khi tất cả selected cells có receipt hiện hành. OCR không cung cấp formulas/styles/Excel coordinates; loss/capability ghi rõ.

## 3. ISC-1 descriptors và cursors

| Object | Fields bắt buộc / invariant |
| --- | --- |
| SnapshotDescriptor | contract_version, snapshot_id, artifact_id/side, generation, import_attempt_id, source_sha256, source_bytes, format/adapter_version, import_config_version/revision/digest, selected_scope, field descriptors, record_count, capabilities/losses, raw_store_ref, validation_receipt_id |
| ValidationReceipt | snapshot/source binding, EOF=true, actual byte_count/hash, guard/profile digest, completed_check_ids, blocking_issues=[], validated_at; timestamp không tham gia semantic hash |
| RawBatch | snapshot/attempt identity, batch_no, first_ordinal, records, serialized_byte_count, record_count, checksum, next_cursor/end; bytes lẫn count đều bounded |
| RawRecord | snapshot-scoped record_id, ordinal, cells/field refs, source_span; không dùng mutable UI row index làm identity |
| RawCursor | snapshot_id, scope_id, projection, order=SOURCE_ORDINAL, after_ordinal, reader_revision; opaque signed/private token, không URI |
| Lease | owner_id, artifact_ref, purpose, acquired/released state; release idempotent; only active consumer có quyền giữ scratch |

RawStore phản ánh snapshot raw, chưa chứa canonical equality. Cursors repeatable cùng snapshot/projection/order, không trả bản ghi duplicate/skip; no OFFSET-based identity. Batch checksum kiểm serialized bytes của batch frame, không thay source hash. END chỉ sau record_count khớp và checksums/EOF valid.

Transient preview có `provisional=true`, attempt tuple và estimated counts; không SnapshotDescriptor usable. Freeze bằng publish marker sau full validation. A thành READY không ép B READY; source/config changes invalidate đúng dependency graph.

## 4. Target Input 0.2.0 migration — logical fields

Wire validators/schemas 0.2.0 chưa được tạo trong công việc docs. Đây là shape definition để hiện thực sau, unknown fields ở closed objects phải reject; arrays có bounds từ RP-1, IDs phải resolve offline.

`ImportConfig` target: schema_version=0.2.0, artifact_id/side, config_revision, format tag và exactly một union scope:

- tabular: `kind=TABULAR`, table selector/sheet/range, encoding/dialect/header đã resolve theo 0.1 rules; không comparison policy/key/direction.
- image: `kind=IMAGE`, extraction_id/revision, oriented image dimensions, original→oriented/crop affine transform và inverse, selected_grid_id, rows/columns/cell polygons, review_receipt_ids. Transform phải finite/invertible; polygons trong bounds; không infer text cho missing detections.

`OcrExtraction`: extraction_id/revision, source_sha256, recognizer/model/version, image dimensions/transforms, recognized tokens/text+polygons, grid proposal, corrections với original recognized_text và reviewed_text riêng. `OcrReviewReceipt`: receipt_id, artifact/hash, extraction_revision, grid_revision, selected_scope_digest, cell_id, reviewed_text_digest, decision=CONFIRMED, review_action_id. Crop/layout/recognized content/reviewed content đổi invalidate receipts của scope bị ảnh hưởng; freeze không được pha receipts khác revisions.

SourceCell target 0.2 giữ raw_kind/null/lexical/ref meanings cũ; OCR bổ sung extraction/cell/review refs, recognized_text nguyên gốc và reviewed_text dùng cho Core kèm correction trace. `review_state=CONFIRMED` không đủ nếu receipt binding không đúng. Cells không phải OCR không mang OCR receipt fields. Full selected grid có `reviewed_cell_count = selected_cell_count`; không dùng confidence hoặc percentage làm gate thay thế.

Cell do người dùng bổ sung vì OCR không detect được phải có `recognized_text=null`, lexical_status=UNAVAILABLE, loss=OCR_NO_DETECTION và correction_origin=USER_ENTERED; reviewed_text/receipt/polygon tại vị trí thật bắt buộc. Không ghi text user nhập như đã được recognizer đọc. Target0.2 cho phép trường hợp này có annotation; Core dùng reviewed text với trace, không kết luận lexical EXACT từ recognition thiếu. Missing polygon/source region vẫn PROVENANCE_INVALID, không dùng exists=false để phát minh source text.

0.1 tabular config có thể convert deterministically sang 0.2 TABULAR nếu mọi defaults đã resolve, preserve raw policy và gắn new revision/digest. 0.1 không biểu diễn IMAGE: reject image conversion, yêu cầu extraction/review mới. Existing snapshots/caches không “nâng version” tại chỗ; revalidate/re-import rồi tạo ID mới. Retain fixtures/schemas 0.1 làm compatibility; chỉ quảng cáo target 0.2 sau validator/negative tests/versioned schema package.

## 5. Failures, cleanup và test vectors

Guard failures dùng INP errors hiện hành: size/resource limit→004; config/profile unresolved→011; unsafe ZIP/XML→017; thiếu provenance→014; precision/capability loss→013; source changed/revoke→015/006 theo INP-008. Nếu chưa có specific Input error, safe diagnostic mang stage/reason_code internal và existing parent error, không tự reuse một code cho nghĩa khác.

Attempt owns spools/index/stores trước freeze; snapshot lease owns sau freeze. Fail/cancel đóng readers/writers trước cleanup; consumers release thì sweep refs không dùng. Disk full abort staging; không để READY marker. Startup chỉ minimal journal→SELECTED/revalidate, không resume partial rows. TTL là orphan safety fallback, không lý do giữ raw sau close.

| Vector | Expected |
| --- | --- |
| Provider bytes đổi giữa inspect/reopen | Parse immutable copied bytes hoặc invalidate; không mismatch hash/rows |
| UTF-8 dấu Việt/quoted newline tách chunks | Decoded field và physical source lines nguyên vẹn |
| SST index trỏ ngoài spool / metadata sau sheetData | Reject invalid index; late metadata resolve trước READY |
| OCR review rồi crop 1 pixel | Old receipts invalid, compare blocked đến re-review |
| Source đúng trần nhưng decode vượt budget | Structured guard failure; không claim positive 1 GB gate PASS |

Acceptance: [UDG-TC-003..006](../../testing/UDG_CONTRACT_ACCEPTANCE.md), INP-TC-021..025/034..040 và LARGE-TC-001/003/004/005/008. Đây là expected behavior, chưa test runtime.
