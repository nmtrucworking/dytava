# Dytava — Input Specification

Document ID: INP-000\
Version: 0.1.0\
Status: DRAFT\
Platform: Flutter/Dart — Android P0 / iOS P1\
Owner: TBD\
Updated: 11/11/2026

## Phạm vi và trạng thái

Đây là điểm vào chuẩn cho việc biên soạn Input Contract: hệ thống tiếp nhận gì, diễn giải cấu trúc thế nào, giữ bằng chứng nào, từ chối trường hợp nào và khi nào được giao dữ liệu sang Core. Có 10 đặc tả chuyên đề, 5 JSON Schema và fixtures; bộ này chưa APPROVED. Các quy tắc MUST/không được trong tài liệu là yêu cầu thiết kế đề xuất, không phải chứng cứ đã triển khai.

Baseline sản phẩm: Flutter/Dart, Android P0 và iOS P1 theo Master 2.2. Package `packages/excelcompare_core/` hiện là semantic PoC, chưa có đầy đủ adapter/provenance. Web có implementation riêng; kết quả Web không tự chứng minh contract Flutter đã đạt. Icon/branding không chứng minh định dạng đã được hỗ trợ.

## Mục lục và quyền sở hữu

| Document | Nội dung / nguồn quy tắc duy nhất |
| --- | --- |
| [INP-001 — Scope](01_input_scope.md) | Raw/config/parsed; hai slot A/B; ranh giới Input–Comparison |
| [INP-002 — Artifacts](02_source_artifacts.md) | Metadata/hash/access/read-only/lifecycle; INP-RULE-001–008 |
| [INP-003 — Formats](03_file_formats.md) | Adapter contracts/capabilities; INP-RULE-009–016 |
| [INP-004 — Structure](04_tabular_structure.md) | Table/field/row/header/scope; INP-RULE-017–020 |
| [INP-005 — Types/provenance](05_data_types_provenance.md) | Physical/raw/null/formula/ref; INP-RULE-021–025 |
| [INP-006 — Configuration](06_input_configuration.md) | ImportConfig vs ComparisonConfig/Policy; INP-RULE-026–029 |
| [INP-007 — Validation](07_validation_errors.md) | Severity và INP-ERR-001–018; INP-RULE-030–032 |
| [INP-008 — Import state](08_import_state_machine.md) | Events/guards/recovery A/B; INP-RULE-033–036 |
| [INP-009 — Acceptance](09_acceptance_tests.md) | Registry INP-TC-001–040 và bằng chứng; INP-RULE-040 |
| [INP-010 — OCR](10_ocr_image_input.md) | Thiết kế P2/review/geometry; INP-RULE-037–039 |

Thứ tự đọc: Scope → Artifacts → Formats → Structure → Types → Configuration → Validation → State → Tests; đọc OCR khi đánh giá yêu cầu ảnh.

## Thứ tự ưu tiên và versioning

Trong phạm vi Input, Markdown ở đây sở hữu quy tắc/ngữ nghĩa và schema cùng version sở hữu wire shape. Hai phần phải đồng nhất; nếu mâu thuẫn thì mở issue và chặn approval, không tự chọn một bản để bỏ qua lỗi. Kiểm tra cross-record, trạng thái và permission cần validator runtime; JSON Schema không thay thế chúng. Không suy ra capability runtime từ schema có thể biểu diễn một format.

Master Flutter 2.2 giữ kiến trúc/lộ trình và Core spec giữ normalization, policy compiler, key matching/comparison. Chi tiết Input trong Master được thay bằng liên kết tới bộ này; physical source types do INP-005 sở hữu. Nếu xung đột semantic policy thì xử lý tại Core spec, không nhân bản logic trong Input. Markdown Master/Core là nguồn tài liệu hiện hành.

Schema `$id` dùng namespace `https://dytava.example/specs/input/0.1.0/` để định danh, không phải endpoint đã publish. Resolver phải nạp local/offline, không fetch dữ liệu từ URL do người dùng nhập. schema_version Import=0.1.0 độc lập với policy schema_version=2. Breaking shape/semantics cần tăng contract version và migration notes. config_revision thay đổi mỗi lần effective import config đổi; adapter/parser version và source hashes thuộc snapshot lineage.

## Requirements registry

Các ID dưới đây có đúng một định nghĩa. Test registry tham chiếu requirement/rule, không định nghĩa lại yêu cầu. FR-001 của Master được phân rã thành INP-REQ-001–008; đây là traceability cho bản draft, không sửa nghĩa FR trong tài liệu lịch sử.

| ID | Yêu cầu | Chủ sở hữu | Acceptance |
| --- | --- | --- | --- |
| INP-REQ-001 | Đúng hai source slots độc lập, cả hai hợp lệ trước Mapping | INP-001/008 | INP-TC-001, INP-TC-036 |
| INP-REQ-002 | Identity, access, bytes/hash và lifecycle có thể kiểm chứng | INP-002 | INP-TC-001,003–005 |
| INP-REQ-003 | Định dạng xác thực theo nội dung và capability có version | INP-003 | INP-TC-006,008–009,011,016 |
| INP-REQ-004 | Scope/fields/rows/header có cấu trúc và invariants rõ | INP-004 | INP-TC-017–020 |
| INP-REQ-005 | Giữ physical type, raw/null/formula và provenance | INP-005 | INP-TC-010,012,015,021–025 |
| INP-REQ-006 | ImportConfig có version/binding, tách policy/mapping/key | INP-006 | INP-TC-026–030 |
| INP-REQ-007 | Validation fail closed, limits và diagnostics có cấu trúc | INP-007 | INP-TC-002,007,013–014,031–033 |
| INP-REQ-008 | State/event guards xử lý retry/cancel/races/restore | INP-008 | INP-TC-034–038 |
| INP-REQ-009 | Handoff chỉ với snapshot hiện hành và comparison config đã xác nhận | INP-001/006/008 | INP-TC-029–030,036 |
| INP-REQ-010 | OCR P2 giữ geometry/text/review, không dựng metadata giả | INP-010 | INP-TC-039–040 |
| INP-REQ-011 | Read-only, giới hạn truy cập, offline và không lộ raw/URI qua logs | INP-002/007/010 | INP-TC-004,033,040 |
| INP-REQ-012 | Contract và fixtures kiểm chứng được, evidence không trộn với kế hoạch | INP-009 | INP-TC-005,020,026 |

## Decision register — accepted engineering baseline (11/11/2026)

**Nguồn quyết định có hiệu lực:** [9 ADR Android P0](../../decisions/ADR_REGISTER_P0_2026-11-11.md). Các quyết định dưới đây là **ACCEPTED** bởi nhóm theo baseline kỹ thuật; **không** phải chứng cứ triển khai, benchmark hoặc chấp thuận chính thức của giảng viên. Contract Input 0.1.0 vẫn DRAFT; owner/reviewer chưa được phân công.

| ID | Quyết định kỹ thuật đã chốt | Tình trạng triển khai |
| --- | --- | --- |
| INP-ADR-001 | A baseline/B candidate, A_TO_B là default hiển thị; user phải confirm direction | ACCEPTED / NOT_IMPLEMENTED |
| INP-ADR-002 | OCR Android P0 tối thiểu: một nguồn ảnh PNG/JPEG, bundled offline ML Kit, manual review | ACCEPTED / ACADEMIC_SIGNOFF_PENDING |
| INP-ADR-003 | Một selected table/scope trên mỗi nguồn, một worksheet/range với XLSX | ACCEPTED / NOT_IMPLEMENTED |
| INP-ADR-004 | Profile android-p0-conservative-v1, các trần từ chối tạm trước benchmark | ACCEPTED / BENCHMARK_PENDING |
| INP-ADR-005 | Header first-row chỉ là suggestion; UTF-8 strict, CSV comma/TSV tab, xác nhận explicit | ACCEPTED / NOT_IMPLEMENTED |
| INP-ADR-006 | Không phục hồi leading zeros ở numeric identifier; ambiguity → UNRESOLVED | ACCEPTED / NOT_IMPLEMENTED |
| INP-ADR-007 | XlsxFormatAdapter; Dart excel v4 là ứng viên PoC, loss/capability phải minh bạch | ACCEPTED / PARSER_POC_PENDING |
| INP-ADR-008 | Confirm matching mode/key/dtype/policy/mapping/direction trước run | ACCEPTED / NOT_IMPLEMENTED |
| INP-ADR-009 | App-private temporary scratch, read-only, no raw retention, restore revalidate | ACCEPTED / NOT_IMPLEMENTED |

**P0 Android:** .xlsx/.csv/.tsv + một nguồn ảnh .png/.jpg/.jpeg (không image-image), mỗi nguồn một bảng; comparison + CSV/JSON export và APK. JSON chuyển P1, iOS P1; PDF, multi-page OCR, cloud OCR sau P0. Master 2.2 và các chữ OPEN/P2 trong đặc tả con chỉ còn ý nghĩa lịch sử khi mâu thuẫn với 9 ADR này.

**Bắt buộc trước release:** migration schema InputConfig 0.1.0 để biểu diễn image P0, OCR extraction/review receipt contracts, Flutter adapter/parser PoC và corpus, benchmark Android thật, tests và APK. Không tự đánh dấu các acceptance cases PLANNED là PASS.

## Glossary

| Term | Nghĩa |
| --- | --- |
| Artifact | Bytes/tài nguyên nguồn được chọn, identity khác tên file |
| Raw Input | Bytes và metadata thực có |
| Parsed Input | SourceTable/Field/Row/SourceCell, chưa semantic normalize |
| Provenance / SourceRef | Địa chỉ trong nguồn thật, không phải địa chỉ preview giả |
| Physical / logical / semantic | Storage type / parse interpretation / ý nghĩa do policy xác nhận |
| Capability | Evidence adapter cung cấp cho mode cụ thể, không chỉ extension |
| Snapshot | Bộ raw data + hash/config/parser lineage đã validate và freeze |
| PREVIEW_READY | Một source snapshot đã full validate; chưa đủ để cả job chạy |
| Review | Blocker cần resolution có receipt gắn đúng snapshot/revision |

## Contracts, fixtures và kiểm tra

- [input_artifact.schema.json](schemas/input_artifact.schema.json)
- [source_table.schema.json](schemas/source_table.schema.json)
- [source_cell.schema.json](schemas/source_cell.schema.json)
- [source_ref.schema.json](schemas/source_ref.schema.json)
- [import_config.schema.json](schemas/import_config.schema.json)
- [Fixtures và expected output](fixtures/README.md)
- [Acceptance và lệnh verifier](09_acceptance_tests.md)

Verifier kiểm tra shape, negative examples, cross-file fixture consistency, IDs và local links. Nó không triển khai parser XLSX/OCR hay state machine ứng dụng. Các planned test giữ nguyên trạng thái PLANNED tới khi có evidence tương ứng.
