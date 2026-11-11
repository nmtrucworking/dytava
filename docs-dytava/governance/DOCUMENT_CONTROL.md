---
document_id: DYT-DOC-CONTROL-001
version: 0.1.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-12
---

# Dytava — Document Control và nguồn quản lý yêu cầu

## 1. Mục đích

Dự án trước đây tập trung nội dung sản phẩm, FR, NFR, kiến trúc trong [ExcelCompare Master 2.2](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md), gây khó quản lý thay đổi và nguy cơ trộn **yêu cầu** với **tính năng đã thực thi**. Từ baseline ngày 12/11/2026, tài liệu được chia theo **bounded ownership**:

| Nguồn chính thức | Sở hữu duy nhất | Không sở hữu |
| --- | --- | --- |
| [PRD — DYT-PRD-001](../product/PRD.md) | User problem, persona, outcome, US-01..US-12, phase/scope, UX journey, stakeholder acceptance | Detailed algorithms, typed schemas, metric benchmarks |
| [SRS — DYT-SRS-001](../requirements/SRS.md) | Functional requirements FR-001..FR-015, cross-feature behavior, pre/postconditions, measurable system acceptance | Raw Input schema/format rules, Core normalization semantics, quality SLO |
| [NFR — DYT-NFR-001](../requirements/NFR.md) | Quality requirements/metrics, resource guardrails, privacy/security/accessibility/reliability verification, evidence gates | Product scope, business comparison logic, module layout |
| [Architecture — DYT-ARCH-001](../architecture/ARCHITECTURE.md) | Architecture drivers, logical components, dependency rules, tech candidates, ports/flows and actual-vs-target matrix | User priority, wire type semantics, evidence that features work |
| [Input Contract — INP-000..010](../specs/input/README.md) | Source metadata, format/adapter capability, raw physical types/provenance, ImportConfig, validation, input state/error, INP-REQ/RULE/TC | Semantic equivalence or product phase selection |
| [Core Semantic Spec](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) | Canonical values, datatype policies, comparison precedence, key matching semantics, reason codes | File bytes/permission, product release priority |
| [ADR Register](../decisions/ADR_REGISTER_P0_2026-11-11.md) | Architectural decisions 001..009 (scope overrides, rationale, tradeoffs, review gates) | Implementation proof, test PASS, automatic academic approval |
| [Build/Release Guide](../project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md) | Signing, packaging, CI/device release procedures | Claims a signed APK/IPA already exists |
| [Traceability Matrix](../requirements/TRACEABILITY_MATRIX.md) | Read-only cross-document references to IDs/tests/status/evidence | Redefinition of FR, INP-REQ or test expected values |

**Rule:** nếu hai tài liệu cùng nhắc một ý, tài liệu không sở hữu chỉ ghi **tóm tắt + liên kết**, không tạo định nghĩa thứ hai. Mỗi ID được khai báo ở **một** nguồn; bản tham chiếu ở khác tài liệu có cùng ID.

## 2. Tiền lệ khi phát hiện xung đột

Không đặt một thứ tự ưu tiên toàn cục giữa PRD, SRS, NFR, Architecture, Input và Core vì chúng sở hữu lĩnh vực khác nhau. Tìm *domain owner* trong bảng trên và sửa ở owner trước; đồng bộ reference sau. Với trường hợp cross-domain, mở issue/review, không tự chọn văn bản thuận tiện nhất.

1. **Product scope/P0 priority:** 9 ADR (11/11/2026) là override được chấp nhận, PRD là bảng phase quản lý hiện hành.
2. **Behavior FR:** SRS; Input rules/schemas sở hữu raw/wire; Core spec sở hữu semantic equivalence. Không override Input/Core bằng SRS mà không migration/review.
3. **Quality metric:** NFR; con số trong Master cũ chỉ lịch sử và không thành benchmark bằng việc copy.
4. **Design & dependency:** Architecture, bị ràng buộc bởi ADR và các contracts đã được chấp thuận.
5. **Master 2.2:** giữ để audit nguồn lịch sử cho các mục 01–15; **không** sửa song song PRD/SRS/NFR/Architecture tại Master. Các phần release/runbook/roadmap chưa tách riêng chỉ là tham khảo trừ khi có owner chính thức.
6. **Dữ liệu kiểm chứng:** test runner, fixture hashes, device/CI evidence; không lấy word `MUST` hoặc icon/brand asset làm proof.

Đặc biệt: OCR một ảnh có review **Android P0**, input JSON **P1**, xuất P0 **CSV/JSON**, không auto-resume partial import; `INP-ADR-002` có **external academic sign-off pending**.

## 3. Versioning, state và ownership

Mỗi tài liệu có front matter tối thiểu: `document_id`, `version`, `status`, `owner`, `reviewer`, `updated`, `release_baseline` khi phù hợp.

- `DRAFT`: đang chuẩn hóa, có thể phản biện, chưa có review sign-off. Bốn tài liệu mới **DRAFT 0.1.0**; owner/reviewer **TBD**.
- `REVIEW`: nội dung đã đóng phạm vi và gửi review, nhưng chưa APPROVED.
- `APPROVED`: owner + reviewer, quyết định scope/ADR quan trọng, schemas/fixtures và acceptance được liên kết; **không tự đồng nghĩa implementation PASS**.
- `SUPERSEDED`: có link sang version mới, giữ lịch sử.
- **Implementation/evidence** độc lập: `NOT_IMPLEMENTED`, `IN_PROGRESS`, `VERIFIED` chỉ dùng sau khi có SHA/runner/fixture/device evidence, không tự suy từ documentation status.

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
| Input schema migration | OCR P0 ImportConfig/receipts/extraction contracts có version | NOT_DONE |
| Adapter/Core capabilities | Parser/OCR/semantic integration và golden tests | NOT_VERIFIED |
| Quality/release evidence | Device benchmark, privacy, APK build/sign + smoke | NOT_VERIFIED |

**Lưu ý:** Document Control tạo ra *quy tắc quản lý*, không tự phê duyệt các tài liệu hay chốt stakeholder bên ngoài.
