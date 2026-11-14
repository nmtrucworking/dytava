---
document_id: DYT-SRS-001
version: 0.3.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-13
release_baseline: P0 mở rộng (Android trước; web/iOS có gate riêng)
source: EXCELCOMPARE_MASTER_ANDROID_IOS 2.2 sections 03-06 (historical)
---

# Dytava — Software Requirements Specification (SRS)

> **Nguồn chính thức của yêu cầu hệ thống FR-001..FR-018, trạng thái và acceptance logic theo phase.** User need/scope thuộc [PRD](../product/PRD.md), resource/quality limits thuộc [NFR](NFR.md), module/dependencies thuộc [Architecture](../architecture/ARCHITECTURE.md). Không lặp lại nguyên văn INP-RULE hay các thuật toán canonicalization của Core.

## 1. Baseline và phạm vi

**Target:** Android Flutter P0; **hai** source slots A/B; XLSX/CSV/TSV và tối đa một source ảnh PNG/JPEG; một table/scope mỗi source; OCR chỉ khi đã manual review; kết quả CSV/JSON và, theo [scope mở rộng](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md), **input tới 1 GB/source + merged diff PDF + Dytava report PDF**. NFR sở hữu định nghĩa bytes/profile; Report spec sở hữu template/layout. iOS, JSON input, compare formula/style/metadata, cloud OCR là P1+ theo [ADR register](../decisions/ADR_REGISTER_P0_2026-11-11.md).

**Trạng thái tài liệu:** bản đặc tả cần implementation/evidence; code Flutter hiện là UI semantic comparison PoC, chưa là app hoàn chỉnh. Các `INP-TC-*` hiện `PLANNED`. [Input 0.1.0](../specs/input/README.md) định nghĩa raw source, schema, provenance, validation, state; [Core spec](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) định nghĩa canonicalization/semantic correctness.

## 2. Actors và preconditions

**Detailed contracts:** [UDG3.1](../specs/engine/README.md) sở hữu execution plan/geometry/matching; [ISC-1](../specs/input/11_streaming_snapshot_contract.md) sở hữu streaming/Input0.2 target; [CE-1](../specs/core/CANONICAL_ENCODING.md) và [decision tables](../specs/core/COMPARISON_DECISIONS.md) mở rộng Core; [ER-1/WP-1](../specs/engine/04_result_runtime.md) sở hữu result/runtime; [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md) sở hữu query/export; [RP-1](RESOURCE_PROFILES.md) sở hữu budgets/calibration. FR IDs/phase không đổi. Các contracts là DRAFT, executable schema/validators và runtime evidence chưa có.

- **User:** chọn source và scope; review OCR/header/key/policy; chạy và xuất report. Không mặc định user là administrator.
- **System:** giữ access grants trong scope được phép, preflight, resolve config, freeze source snapshot, execute comparison và export an toàn.
- **Input adapter/OCR engine:** thành phần bên trong, không tin dữ liệu/file do người dùng cung cấp.

**Comparison preconditions:** A và B đều `PREVIEW_READY` với hashes/config/parser lineage hiện hành; table-pairing, field mapping, matching mode, key nếu dùng, policy compile+confirm và direction confirmed; OCR source không còn review blocker. Hệ thống phải từ chối job nếu một điều kiện không đạt.

## 3. Functional requirements registry — stable ID của Master

| ID | Requirement SHALL (hành vi bắt buộc) | Pha | Acceptance / refs |
| --- | --- | --- | --- |
| **FR-001** | Chọn 2 artifacts độc lập; xác thực format bằng nội dung, access/size/hash; chặn file không an toàn | P0 | INP-REQ-001/002/003/007, INP-TC-001/002/006 |
| **FR-002** | Chọn và xác nhận đúng 1 table/scope mỗi bên, bao gồm 1 sheet/range nếu XLSX; preview không tự thành READY | P0 | INP-REQ-004, INP-TC-017/019/020 |
| **FR-003** | Giữ raw physical type, source references, field/row identity, loss flags; OCR geometry nguyên gốc | P0 | INP-REQ-005, INP-TC-021..025/039 |
| **FR-004** | Hiển thị sample/field metadata và datatype inference ở dạng **gợi ý**, chưa được coi là semantic truth | P0 | INP-REQ-005/006, INP-TC-029/030 |
| **FR-005** | Mapping cột 1:1 bằng Field IDs hiện hành, xác nhận thủ công; mapping invalid/stale chặn run | P0 | INP-REQ-009, INP-TC-027/029 |
| **FR-006** | Hỗ trợ `POSITIONAL` và `KEY` (một hoặc nhiều key fields có thứ tự); KEY phải confirm và kiểm tra null/duplicate | P0 | INP-TC-030 + Core golden cases |
| **FR-007** | Phát hiện matched/unmatched rows và cells; phân biệt ROW_ADDED/REMOVED, FIELD_ADDED/REMOVED; thay A/B direction đảo added/removed | P0 | Core golden cases + ADR-001 |
| **FR-008** | Exact comparison không đồng nhất missing, blank, empty string, null, zero; không đoán numeric identifier mất biểu diễn | P0 | INP-REQ-005, semantic TC, ADR-006 |
| **FR-009** | Chỉ chuẩn hóa theo typed field policy đã confirm, trả EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED và audit rule/reason | P0 | Core semantic tests và policy digest |
| **FR-010** | So sánh formula expression/cache như một mode riêng; không thực thi/recalculate công thức | P1+ | Test corpus formula |
| **FR-011** | So style/metadata độc lập, không trộn vào cell similarity | P1+ | Metadata golden oracle |
| **FR-012** | OCR **một** PNG/JPEG source, giữ text/geometry và correction; manual review trước handoff; offline bundled | **P0** | INP-REQ-010/011, INP-TC-039/040 + Android E2E |
| **FR-013** | Tổng hợp metrics theo từng đơn vị, detail refs/rules, export CSV diff + JSON manifest an toàn | P0 | Report golden + CSV injection tests |
| **FR-014** | Với cùng snapshot hashes, config/policy digest, engine version và mode, semantic result deterministic; generated_at loại khỏi so sánh | P0 | Repeatability + regression |
| **FR-015** | Hủy/retry/cleanup có guards và không commit partial report; restore sau process death revalidate access/bytes | P0 | INP-TC-003/004/034..038 |
| **FR-016** | Chấp nhận input tới trần **1 GB cho mỗi nguồn**, theo NFR §3; đọc/parse/hash/compare theo stream/chunk và private spill khi cần; preview phân trang, progress/cancel, preflight resources; không dùng trần rows/cells của profile nhỏ như cap sản phẩm | P0 mở rộng | LARGE-TC-001..008; INP-REQ-002/007/008 |
| **FR-017** | Xuất **một PDF diff hợp nhất A/B**, giữ raw evidence, union mapped/unmatched rows/fields, format theo bốn cell statuses và structural labels; full/filtered scope ghi rõ, phân trang không silent truncation | P0 mở rộng | REP-TC-001..005/008..012; Report spec §2 |
| **FR-018** | Xuất **PDF báo cáo theo template Dytava có version**, nhận diện/font local, nguồn/scope/methodology/metrics/diff/unresolved/audit; số liệu nhất quán với result/JSON | P0 mở rộng | REP-TC-003/005..012; Report spec §3 |

**Phân pha thay đổi so với Master:** FR-012 nay Must P0; FR-010/011 P1+, US-11 chuyển Must; P0 mở rộng bổ sung 1 GB/source và hai PDF, thay loại trừ PDF output trước đây; **PDF input** vẫn ở pha riêng. FR ID không bị đánh số lại. SRS này không tuyên bố các ca đã PASS.

## 4. Quy tắc nghiệp vụ cross-feature

### 4.1. Source identity và snapshot

Mỗi slot A/B có `artifact_id` độc lập, kể cả cùng tên hoặc cùng hash; `SourceTable` giữ coordinate thực (XLSX address, CSV logical record + physical lines, OCR image polygon). Preview sample có thể xuất hiện trước EOF nhưng chỉ `ParsedAndValidated` với hash/EOF/config hợp lệ mới chuyển sang `PREVIEW_READY`. Thay bytes/scope/header/parser version làm mất hiệu lực snapshot và mapping cũ. **Input rules/JSON wire shape là nguồn chuẩn tại INP-001..011, theo đúng version**; SRS không định nghĩa schema thứ hai.

### 4.2. Mapping / direction / alignment

Gợi ý UI ban đầu `A_TO_B` nhưng user phải confirm; `A_TO_B`: hàng chỉ ở B là ADDED, chỉ ở A là REMOVED; `B_TO_A` đảo chiều. `KEY`: khóa composite là tuple có thứ tự (không nối bằng delimiter), duplicate/null không được auto-gán hàng đầu tiên. `POSITIONAL`: ghép theo thứ tự, không suy ra có thêm/xóa nếu chỉ reorder. P0 **không** dùng `MULTISET` và `ORDERED_SEQUENCE` (nêu trong Master cho roadmap). Mỗi mapping/reference phải gắn snapshot hiện hành.

### 4.3. Semantic resolution

Trạng thái cell matched pair chỉ thuộc **một** trong `EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED`. `TYPE_CHANGED`, `FORMULA_CHANGED`, `OCR_REVIEWED` là flags/mode-specific, không phải trạng thái thứ năm. `EQUIVALENT` cần rule_id, canonical values và policy/version; thiếu evidence thì `UNRESOLVED`, không ép sang `DIFFERENT`. IDENTIFIER text `00123` khác `123`; nguồn XLSX numeric `123` thiếu lexical evidence cần review/UNRESOLVED, **không tái tạo** thành ID `00123`. Chi tiết semantics và precedence ở [Core spec](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md).

### 4.4. Summary and denominator (không trộn đơn vị)

`compared_matched_pairs = exact + equivalent + different + unresolved`.
`exact_rate = exact / compared_matched_pairs`; `semantic_agreement_rate = (exact + equivalent) / compared_matched_pairs`. Khi mẫu số bằng 0, rate là **N/A** (không tự đặt 100% hoặc 0%). ROW_ADDED/REMOVED, FIELD_ADDED/REMOVED, unmatched, OCR review rate có counters riêng, **không cộng cùng cell pairs**. `UNRESOLVED` nằm trong mẫu số, không được loại khỏi báo cáo để nâng tỷ lệ.

### 4.5. OCR input

Image/camera → bounded decode → orientation/crop → OCR text blocks+geometry → reconstructed grid **draft** → user sửa/xác nhận cell/layout → freeze extraction revision/review receipts → validated `SourceTable` → Comparison. High confidence không bypass confirmation; unknown confidence là `null`; crop/layout edit invalidates receipts; không dựng Excel formula, hidden values, sheet/style từ hình. **ImportConfig 0.1.0 chưa có image scope**: FR-012 bị block bởi schema/version migration theo ADR-002.

### 4.6. Report / export

Bốn export kinds và quy tắc format/merged union/template/lifecycle được định nghĩa tại [Report Export Specification](../specs/report/README.md). FR-013 sở hữu summary/CSV/JSON; FR-017/018 bổ sung PDF. Mọi exporter dùng cùng immutable result snapshot và không tự triển khai lại Core semantics.


JSON report chứa source hashes/identities (không chứa access tokens/URI), engine/policy/config/version, direction, summary, field/record/cell diffs, unresolved, warnings và refs; logical contract ER-1/EX-1 đã có version; executable schema/validator target còn cần hiện thực trước release. CSV an toàn trước spreadsheet formula injection: viết các giá trị chưa tin cậy như **text**, kiểm tra bằng công cụ đọc bảng tính phổ biến; không chỉ thêm dấu nháy rồi mặc định đã an toàn. Export do user khởi tạo, output không ghi đè nguồn, báo cáo dở không hiển thị là completed. DATE/TIME/MONEY chỉ hiển thị nếu có capability + tests.

### 4.7. Dung lượng lớn và giới hạn mở rộng

Trần source, đơn vị byte và profile runtime theo [NFR §3](NFR.md#3-resource-profiles-và-trần-input-1-gb), thay cap conservative của ADR-004. Kích thước unknown phải kiểm đếm bytes khi đọc; đúng trần không được từ chối chỉ vì size, vượt trần phát INP-ERR-004. Một nguồn thất bại không làm READY giả cho cả phiên. Hỗ trợ tới 1 GB cần corpus hợp lệ chạy đến EOF và comparison/export, không chỉ chọn được file.

Snapshot là descriptor + versioned row/result streams/indexes; không bắt buộc materialize toàn bộ cells trong RAM. KEY alignment phải giữ duplicate/null detection toàn scope khi external sort/index; chunk boundaries không làm mất quoted multiline, UTF-8, keys hoặc provenance. Không tự sample/cắt scope để vượt budget. Thiếu scratch/quota/device capability phải báo cụ thể trước hoặc trong attempt, cleanup; không tự upload.

## 5. Các scenario chấp nhận tối thiểu

| Scenario | Preconditions | Expected outcome | Evidence còn thiếu |
| --- | --- | --- | --- |
| E2E-01 XLSX ↔ CSV | Một scope mỗi bên, header/encoding/key/policy confirmed | Diff, summary, two-side source refs, CSV+JSON và hai PDF export theo snapshot | Android parser+core+report integration |
| E2E-02 Same-named A/B | Tên bằng nhau, bytes khác | Independent IDs, không overwrite | INP-TC-001 device |
| E2E-03 Reordered rows | KEY unique đã confirm | Không báo fake changed theo vị trí | Core key oracle |
| E2E-04 Duplicate key | KEY trùng | Review/unresolved; không ghép tùy tiện | Core key oracle |
| E2E-05 Identifier loss | Text 00123 vs XLSX numeric 123 | UNRESOLVED hoặc review theo policy, giữ raw | ADR-006/corpus |
| E2E-06 OCR ↔ CSV | 1 ảnh, một bảng, offline, corrections confirmed | Có thể compare; geometry/raw OCR gắn đúng nguồn | INP-TC-039/040 |
| E2E-07 OCR changed crop | Đã confirm sau OCR | Receipts invalid; mapping/job bị khóa tới re-review | Android OCR state test |
| E2E-08 Cancel / restart | Attempt đang parse; app bị kill | Không partial READY; restore revalidate từ SELECTED | INP-TC-034..038 |
| E2E-09 Export unsafe strings | Cell bắt đầu =,+,-,@, tab/CR | CSV mở như data; không chạy formula | Output security corpus |
| E2E-10 Out-of-budget file | ZIP/image/row count vượt profile | Structured rejection, cleanup, không crash | NFR benchmark/device |
| E2E-11 Large-input boundary | A/B mỗi nguồn tới 1 GB, profile/corpus hợp lệ | Full EOF/hash → compare → export, bounded work, no source mutation | LARGE-TC-001..008 |
| E2E-12 Merged diff PDF | Result có đủ bốn trạng thái và structural changes | Một PDF union, format/refs/raw A/B đúng; source giữ nguyên | REP-TC-001..005 |
| E2E-13 Dytava template PDF | Result/version/template hợp lệ | Đủ khối, metrics nhất quán, fonts và pagination đọc được | REP-TC-006/007/011/012 |

Các cases là **đề xuất nghiệm thu**, không phải test chạy thật; cần runner, fixture hash, platform/version và results. Test registry Input và semantic là nguồn chuyên trách cho expected payload chi tiết.

## 6. Traceability / change gates

Từ FR → `US` → `INP-REQ` hoặc Core semantic rules → `INP-TC`/golden/E2E → implementation → evidence; xem [traceability](TRACEABILITY_MATRIX.md). Khi thay requirement:
- Điều chỉnh **PRD** nếu đổi persona/journey/release priority; **SRS** nếu đổi behavior; **Input/Core** nếu đổi wire rules hoặc equivalence; **NFR** nếu đổi đo lường/quality; **Architecture** nếu đổi module/dependency.
- Phải đánh giá impact lên ADR baseline và EXP-ADR-001..003 và fixtures; không dùng code hiện tại để suy ra requirement được đáp ứng.
- `DRAFT` cho đến khi owner, reviewer, external academic OCR signoff, schema migrations và test evidence được đánh dấu/ghi link rõ ràng.
