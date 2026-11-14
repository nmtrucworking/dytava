---
document_id: DYT-UDG-INDEX-001
version: 0.2.0
status: DRAFT
owner: TBD
reviewer: TBD
updated: 2026-11-13
release_baseline: P0 mở rộng; thuật toán DYTAVA_UDG_v3
---

# DYTAVA_UDG_v3 — thuật toán chính và đặc tả theo layer

**DYTAVA_UDG_v3 là thiết kế thuật toán chính của dự án**, theo chỉ định chủ dự án ngày 13/11/2026. Công việc hiện tại dừng ở **phân tích và đặc tả tài liệu**. Chưa đánh giá mã nguồn, chọn dependency, triển khai hay chạy benchmark.

Đọc [UDG3.1 — đặc tả hoàn thiện theo layer](../../specs/engine/README.md) trước. [Gap resolution](../../testing/UDG_CONTRACT_ACCEPTANCE.md) ghi 30/30 gaps đã SPECIFIED cùng examples và planned acceptance; review/implementation/device verification vẫn độc lập.

| Tài liệu | Vai trò |
| --- | --- |
| [UDG3.1 contracts](../../specs/engine/README.md) | Nguồn hiện hành cho thiết kế thuật toán; liên kết Input/Core/NFR/Report owner extensions |
| [Layered spec review](LAYERED_SPEC_REVIEW.md) | Snapshot gap assessment trước khi hoàn thiện; status hiện hành tại gap resolution |
| [V3 gốc — Markdown](DYTAVA_Unified_Data_Geometry_Engine_v3.md) | Historical source, body giữ để truy vết; superseded bởi UDG3.1 |
| [V3 gốc — PDF](DYTAVA_Unified_Data_Geometry_Engine_v3.pdf) / [DOCX](DYTAVA_Unified_Data_Geometry_Engine_v3.docx) | Bản tham khảo cùng bộ; chưa đồng bộ nội dung review mới |
| [Core semantic contract](../EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) | Sở hữu định nghĩa EXACT/EQUIVALENT/DIFFERENT/UNRESOLVED, normalization và policy; v3 sử dụng contract này |

Việc chọn v3 làm thuật toán chính **không tự thay đổi** phạm vi trong [SRS](../../requirements/SRS.md) và [ADR mở rộng](../../decisions/ADR_SCOPE_EXPANSION_2026-11-12.md). P0 vẫn gồm XLSX/CSV/TSV, tối đa một ảnh OCR có review, một selected table mỗi nguồn, KEY/POSITIONAL, 1 GB/source và bốn export kinds. Multi-sheet batch, ordered/multiset và resume là thiết kế mở rộng, chưa tự trở thành yêu cầu P0. OCR engine ở ngoài comparison core nhưng OCR connector thuộc đường vào P0.

Tiêu đề “IMPLEMENTATION-READY” trong bản v3 gốc không chứng minh khả năng triển khai/runtime. Các gap thiết kế đã có quyết định tại UDG3.1, còn executable schemas/validators, profile calibration, parser/renderer PoC và nghiệm thu chưa thực hiện. Tất cả acceptance/benchmark là **PLANNED/NOT_RUN**; PDF/DOCX gốc giữ bản lịch sử, không được coi đã đồng bộ3.1.

## Bản đồ layer

| Layer | Trách nhiệm | Mục v3 gốc liên quan |
| --- | --- | --- |
| L0 | Scope, capability và kế hoạch chạy đã xác nhận | §0–3, §11 |
| L1 | Truy cập nguồn, preflight, fingerprint | §4, §10–11 |
| L2 | Parse vật lý, stream và Input snapshot | §4, §6 |
| L3 | Geometry, sheet/region/field mapping, axis | §5–6 |
| L4 | Policy, canonicalization, encoding và hash | §6–8 |
| L5 | Index và sinh candidates | §7, §10, §13 |
| L6 | Alignment và matching một–một | §7 |
| L7 | Typed diff và kết luận cell | §8 |
| L8 | Audit, result store, snapshot thống kê | §7.5, §10, §12, §15 |
| L9 | Worker, scheduler, backpressure và lifecycle | §9–12 |
| L10 | UI review, query phân trang và export | §15–16 |

Các layer mô tả trách nhiệm logic, không yêu cầu 11 process hay 11 package. L9 điều phối xuyên suốt; persistence của L8 cũng được dùng trong ingestion/indexing, không đợi đến cuối mới ghi đĩa.
