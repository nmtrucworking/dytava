---
document_id: DYT-DOC-CONTROL-001
version: 0.4.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-13
---

# Dytava — Document Control và nguồn quản lý yêu cầu

## 1. Mục đích

Dự án trước đây tập trung nội dung sản phẩm, FR, NFR, kiến trúc trong [ExcelCompare Master 2.2](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md), gây khó quản lý thay đổi và nguy cơ trộn **yêu cầu** với **tính năng đã thực thi**. Từ baseline ngày 12/11/2026, tài liệu được chia theo **bounded ownership**:

| Nguồn chính thức | Sở hữu duy nhất | Không sở hữu |
| --- | --- | --- |
| [PRD — DYT-PRD-001](../product/PRD.md) | User problem, persona, outcome, US-01..US-15, phase/scope, UX journey, stakeholder acceptance | Detailed algorithms, typed schemas, metric benchmarks |
| [SRS — DYT-SRS-001](../requirements/SRS.md) | Functional requirements FR-001..FR-018, cross-feature behavior, pre/postconditions, measurable system acceptance | Raw Input schema/format rules, Core normalization semantics, quality SLO |
| [NFR — DYT-NFR-001](../requirements/NFR.md) | Quality requirements/metrics, resource guardrails, privacy/security/accessibility/reliability verification, evidence gates | Product scope, business comparison logic, module layout |
| [Architecture — DYT-ARCH-001](../architecture/ARCHITECTURE.md) | Architecture drivers, logical components, dependency rules, tech candidates, ports/flows and actual-vs-target matrix | User priority, wire type semantics, evidence that features work |
| [Input Contract — INP-000..011](../specs/input/README.md) | Source metadata/physical raw/provenance, ImportConfig, validation/input state; ISC-1 streaming/snapshot/OCR target0.2/migration | Semantic equivalence or product phase selection |
| [UDG3.1 — thuật toán chính từ DYTAVA_UDG_v3](../specs/engine/README.md) | Execution plan, geometry/candidates/alignment; ER-1/WP-1 runtime extension thuộc Architecture; [gap dispositions](../testing/UDG_CONTRACT_ACCEPTANCE.md) | Không ghi đè scope/FR, Input wire, Core semantic contract, NFR numeric budgets hoặc benchmark evidence |
| [Core Semantic Spec](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) | Canonical values, datatype policies, comparison precedence, key matching semantics, reason codes | File bytes/permission, product release priority |
| [ADR Register](../decisions/ADR_REGISTER_P0_2026-11-11.md) + [Scope expansion](../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) | Quyết định baseline và EXP-ADR-001..003; precedence cho 1 GB/hai PDF | Implementation proof, test PASS, automatic academic approval |
| [Report Export Spec — DYT-REP-001](../specs/report/README.md) | Export kinds, merged diff layout, template Dytava/version, manifest và REP-TC-* | Core equivalence, Input format support, device resource thresholds |
| [Build/Release Guide](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md) | Signing, packaging, CI/device release procedures | Claims a signed APK/IPA already exists |
| [Traceability Matrix](../requirements/TRACEABILITY_MATRIX.md) | Read-only cross-document references to IDs/tests/status/evidence | Redefinition of FR, INP-REQ or test expected values |

**Rule:** nếu hai tài liệu cùng nhắc một ý, tài liệu không sở hữu chỉ ghi **tóm tắt + liên kết**, không tạo định nghĩa thứ hai. Mỗi ID được khai báo ở **một** nguồn; bản tham chiếu ở khác tài liệu có cùng ID.

**Chỉ định thuật toán ngày 13/11/2026:** chủ dự án chọn DYTAVA_UDG_v3 làm thuật toán chính. [Layered review](../project/DYTAVA_UDG_v3/LAYERED_SPEC_REVIEW.md) là snapshot đánh giá ban đầu, nay SUPERSEDED bởi contracts3.1; các `UDG-Lx-*` là gap IDs, không phải FR/test IDs. V3 gốc Markdown/PDF/DOCX giữ làm nguồn review; tiêu đề implementation-ready và các phân pha khác baseline trong bản gốc chưa được chấp nhận chỉ bởi việc chọn thuật toán. Core giữ semantic laws/precedence, UDG thiết kế execution để tuân thủ chúng. Công việc hiện tại chỉ ở docs, chưa cấp trạng thái VERIFIED hoặc bắt đầu triển khai.

**Baseline hoàn thiện docs:** [UDG3.1](../specs/engine/README.md) thay bản v3 gốc/review như nguồn thiết kế hiện hành. [30 gaps](../testing/UDG_CONTRACT_ACCEPTANCE.md) ở trạng thái SPECIFIED_PENDING_REVIEW; [RP-1](../requirements/RESOURCE_PROFILES.md), [ISC-1](../specs/input/11_streaming_snapshot_contract.md), [CE-1](../specs/core/CANONICAL_ENCODING.md), [Core decisions](../specs/core/COMPARISON_DECISIONS.md), [ER-1/WP-1](../specs/engine/04_result_runtime.md), [EX-1](../specs/report/STREAMING_EXPORT_CONTRACT.md) là owner extensions. Chưa có executable schema migration, enabled device profiles hoặc benchmark evidence. Những chữ OPEN trong snapshot review là lịch sử; dispositions mới không có nghĩa code/test đã PASS.

[Baseline bàn giao3.1](SPECIFICATION_BASELINE_3_1.md) liệt kê owner contracts, version/migration, docs QA và ranh giới evidence.

## 2. Tiền lệ khi phát hiện xung đột

Không đặt một thứ tự ưu tiên toàn cục giữa PRD, SRS, NFR, Architecture, Input và Core vì chúng sở hữu lĩnh vực khác nhau. Tìm *domain owner* trong bảng trên và sửa ở owner trước; đồng bộ reference sau. Với trường hợp cross-domain, mở issue/review, không tự chọn văn bản thuận tiện nhất.

1. **Product scope/P0 priority:** ADR 11/11/2026 + EXP-ADR-001..003 (12/11/2026) là quyết định scope hiện hành, PRD giữ phase assignment. EXP ghi đè trần input 10 MiB và loại trừ PDF output; PDF input không đổi.
2. **Behavior FR:** SRS; Input rules/schemas sở hữu raw/wire; Core spec sở hữu semantic equivalence. Không override Input/Core bằng SRS mà không migration/review.
3. **Quality metric:** NFR; con số trong Master cũ chỉ lịch sử và không thành benchmark bằng việc copy.
4. **Design & dependency:** Architecture, bị ràng buộc bởi ADR và các contracts đã được chấp thuận.
5. **Master 2.2:** giữ để audit nguồn lịch sử cho các mục 01–15; **không** sửa song song PRD/SRS/NFR/Architecture tại Master. Các phần release/runbook/roadmap chưa tách riêng chỉ là tham khảo trừ khi có owner chính thức.
6. **Dữ liệu kiểm chứng:** test runner, fixture hashes, device/CI evidence; không lấy word `MUST` hoặc icon/brand asset làm proof.

Đặc biệt: OCR một ảnh có review **Android P0**, input JSON **P1**, P0 mở rộng **input 1 GB/source + CSV/JSON + merged diff PDF + Dytava report PDF**, không auto-resume partial import; `INP-ADR-002` có **external academic sign-off pending**.

## 3. Versioning, state và ownership

Mỗi tài liệu có front matter tối thiểu: `document_id`, `version`, `status`, `owner`, `reviewer`, `updated`, `release_baseline` khi phù hợp.

- `DRAFT`: có thể phản biện, chưa có named review sign-off; version hiện hành ở front matter từng owner doc. UDG3.1 và owner extensions có specification_state=SPECIFIED_PENDING_REVIEW; reviewer cá nhân/calibration/evidence chưa có. Renderer template1.0.0 không tự thành target-streaming capability.
- `REVIEW`: nội dung đã đóng phạm vi và gửi review, nhưng chưa APPROVED.
- `APPROVED`: owner + reviewer, quyết định scope/ADR quan trọng, schemas/fixtures và acceptance được liên kết; **không tự đồng nghĩa implementation PASS**.
- `SUPERSEDED`: có link sang version mới, giữ lịch sử.
- **Implementation/evidence** độc lập: `NOT_IMPLEMENTED`, `IN_PROGRESS`, `VERIFIED` chỉ dùng sau khi có SHA/runner/fixture/device evidence, không tự suy từ documentation status.

**Gap disposition** độc lập: `OPEN` chưa có quyết định thiết kế; `SPECIFIED` đã có owner contract/examples/error-budget semantics/acceptance; `VALIDATED` chỉ sau execution evidence; `CLOSED` chỉ khi scope-specific review+verification đạt. Lần hoàn thiện docs chỉ dùng SPECIFIED, không CLOSED/VALIDATED. Roles trong tài liệu là domain responsibility, không giả tên người đã đồng ý review.

Thay cấu trúc/semantic/wire contract phải version và migration notes tương ứng; thay policy semantic có thể breaking dù app version không đổi. Không hồi tố chuyển `PLANNED` sang `PASS` khi chưa chạy test.

## 4. Workflow change request

1. **Issue/change proposal:** nêu domain owner, lý do, affected IDs và rủi ro ngữ nghĩa/UX/data-loss.
2. **Impact review:** cập nhật các liên kết trong `TRACEABILITY_MATRIX`; rà các ADR, Input schema, Core policy/golden fixtures, các màn hình và gates.
3. **Propose change to owner doc**, cùng version, rationale, before/after behavior; không chỉnh nhiều nguồn định nghĩa cạnh tranh.
4. **Approve:** người phụ trách và reviewer được chỉ định; yêu cầu academic scope như OCR cần xác nhận giảng viên nếu ảnh hưởng nghiệm thu.
5. **Implement/test:** PR code riêng hoặc chung có evidence rõ; biết test nào chưa runnable và device nào chưa test; cập nhật release declaration.
6. **Integrate:** sửa các linked references, kiểm Markdown internal links + manifest SHA256 + schema verifier/CI; giữ PR thay đổi dưới review.

## 5. Approval gates chưa đạt

| Gate | Cần có | Trạng thái |
| --- | --- | --- |
| Owner & reviewer | Phân công được ghi rõ và review sign-off | OPEN |
| Academic OCR scope | Giảng viên xác nhận “một ảnh/một bảng, manual review” đủ yêu cầu | PENDING |
| Input schema migration | ISC-1/target0.2 đã có shape/migration; executable schemas/validators/fixtures còn cần hiện thực | SPECIFIED / NOT_IMPLEMENTED |
| Adapter/Core capabilities | Parser/OCR/semantic integration và golden tests | NOT_VERIFIED |
| Large-input / PDF contracts | RP-1/ER-1/EX-1 đã có lifecycle/budgets/count contracts; profile calibration, schemas/renderer/full-corpus cần thực thi | SPECIFIED / NOT_VERIFIED |
| Quality/release evidence | Device benchmark, privacy, APK build/sign + smoke | NOT_VERIFIED |

**Yêu cầu mở rộng của chủ dự án đã được chấp nhận về scope**; các gate triển khai/kiểm thử không yêu cầu xin lại scope hoặc tự biến yêu cầu thành tùy chọn. Archive/bundle giữ lịch sử, không sửa wire schema/ví dụ cũ bằng thay thế số dung lượng.

**Lưu ý:** Document Control tạo ra *quy tắc quản lý*, không tự phê duyệt các tài liệu hay chốt stakeholder bên ngoài.
