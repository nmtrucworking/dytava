---
document_id: DYT-SRS-001
version: 0.1.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-12
release_baseline: Android P0
source: EXCELCOMPARE_MASTER_ANDROID_IOS 2.2 sections 03-06 (historical)
---

# Dytava — Software Requirements Specification (SRS)

> **Nguồn chính thức của yêu cầu hệ thống FR-001..FR-015, trạng thái và acceptance logic theo phase.** User need/scope thuộc [PRD](../product/PRD.md), resource/quality limits thuộc [NFR](NFR.md), module/dependencies thuộc [Architecture](../architecture/ARCHITECTURE.md). Không lặp lại nguyên văn INP-RULE hay các thuật toán canonicalization của Core.

## 1. Baseline và phạm vi

**Target:** Android Flutter P0; **hai** source slots A/B; XLSX/CSV/TSV và tối đa một source ảnh PNG/JPEG; một table/scope mỗi source; OCR chỉ khi đã manual review; kết quả report CSV/JSON. iOS, JSON input, compare formula/style/metadata, cloud OCR là P1+ theo [ADR register](../decisions/ADR_REGISTER_P0_2026-11-11.md).

**Trạng thái tài liệu:** bản đặc tả cần implementation/evidence; code Flutter hiện là UI semantic comparison PoC, chưa là app hoàn chỉnh. Các `INP-TC-*` hiện `PLANNED`. [Input 0.1.0](../specs/input/README.md) định nghĩa raw source, schema, provenance, validation, state; [Core spec](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) định nghĩa canonicalization/semantic correctness.

## 2. Actors và preconditions

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

**Phân pha thay đổi so với Master:** FR-012 nay Must P0; FR-010/011 P1+, US-11 chuyển Must; P0 chỉ CSV/JSON export. FR ID không bị đánh số lại. SRS này không tuyên bố các ca đã PASS.

## 4. Quy tắc nghiệp vụ cross-feature

### 4.1. Source identity và snapshot

Mỗi slot A/B có `artifact_id` độc lập, kể cả cùng tên hoặc cùng hash; `SourceTable` giữ coordinate thực (XLSX address, CSV logical record + physical lines, OCR image polygon). Preview sample có thể xuất hiện trước EOF nhưng chỉ `ParsedAndValidated` với hash/EOF/config hợp lệ mới chuyển sang `PREVIEW_READY`. Thay bytes/scope/header/parser version làm mất hiệu lực snapshot và mapping cũ. **Input rules/JSON wire shape là nguồn chuẩn tại INP-001..010**; SRS không định nghĩa schema thứ hai.

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

JSON report chứa source hashes/identities (không chứa access tokens/URI), engine/policy/config/version, direction, summary, field/record/cell diffs, unresolved, warnings và refs; contract đầy đủ cần bổ sung schema/version trước release. CSV an toàn trước spreadsheet formula injection: viết các giá trị chưa tin cậy như **text**, kiểm tra bằng công cụ đọc bảng tính phổ biến; không chỉ thêm dấu nháy rồi mặc định đã an toàn. Export do user khởi tạo, output không ghi đè nguồn, báo cáo dở không hiển thị là completed. DATE/TIME/MONEY chỉ hiển thị nếu có capability + tests.

## 5. Các scenario chấp nhận tối thiểu

| Scenario | Preconditions | Expected outcome | Evidence còn thiếu |
| --- | --- | --- | --- |
| E2E-01 XLSX ↔ CSV | Một scope mỗi bên, header/encoding/key/policy confirmed | Diff, summary, two-side source refs, CSV+JSON export | Android parser+core+report integration |
| E2E-02 Same-named A/B | Tên bằng nhau, bytes khác | Independent IDs, không overwrite | INP-TC-001 device |
| E2E-03 Reordered rows | KEY unique đã confirm | Không báo fake changed theo vị trí | Core key oracle |
| E2E-04 Duplicate key | KEY trùng | Review/unresolved; không ghép tùy tiện | Core key oracle |
| E2E-05 Identifier loss | Text 00123 vs XLSX numeric 123 | UNRESOLVED hoặc review theo policy, giữ raw | ADR-006/corpus |
| E2E-06 OCR ↔ CSV | 1 ảnh, một bảng, offline, corrections confirmed | Có thể compare; geometry/raw OCR gắn đúng nguồn | INP-TC-039/040 |
| E2E-07 OCR changed crop | Đã confirm sau OCR | Receipts invalid; mapping/job bị khóa tới re-review | Android OCR state test |
| E2E-08 Cancel / restart | Attempt đang parse; app bị kill | Không partial READY; restore revalidate từ SELECTED | INP-TC-034..038 |
| E2E-09 Export unsafe strings | Cell bắt đầu =,+,-,@, tab/CR | CSV mở như data; không chạy formula | Output security corpus |
| E2E-10 Out-of-budget file | ZIP/image/row count vượt profile | Structured rejection, cleanup, không crash | NFR benchmark/device |

Các cases là **đề xuất nghiệm thu**, không phải test chạy thật; cần runner, fixture hash, platform/version và results. Test registry Input và semantic là nguồn chuyên trách cho expected payload chi tiết.

## 6. Traceability / change gates

Từ FR → `US` → `INP-REQ` hoặc Core semantic rules → `INP-TC`/golden/E2E → implementation → evidence; xem [traceability](TRACEABILITY_MATRIX.md). Khi thay requirement:
- Điều chỉnh **PRD** nếu đổi persona/journey/release priority; **SRS** nếu đổi behavior; **Input/Core** nếu đổi wire rules hoặc equivalence; **NFR** nếu đổi đo lường/quality; **Architecture** nếu đổi module/dependency.
- Phải đánh giá impact lên 9 ADR và fixtures; không dùng code hiện tại để suy ra requirement được đáp ứng.
- `DRAFT` cho đến khi owner, reviewer, external academic OCR signoff, schema migrations và test evidence được đánh dấu/ghi link rõ ràng.
