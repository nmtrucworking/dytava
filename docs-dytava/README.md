# Dytava / ExcelCompare — chỉ mục tài liệu

> **Engineering scope baseline 11/11/2026:** [9 ADR được chốt](decisions/ADR_REGISTER_P0_2026-11-11.md) điều chỉnh Android P0 thành XLSX/CSV/TSV + OCR một nguồn ảnh PNG/JPEG có review. JSON/iOS chuyển P1. Đây là quyết định thiết kế, chưa phải evidence ứng dụng đã đạt P0.

Baseline nền tảng là **Flutter/Dart, Android P0 → iOS P1**; ưu tiên tính năng P0 đã được cập nhật bằng ADR register ngày 11/11/2026, ghi đè những phần roadmap Master 2.2 không còn phù hợp. Repository có Web/server riêng và Pure Dart core PoC; phạm vi thiết kế không là danh sách tính năng đã đạt kiểm thử.

**Bắt đầu tại [Document Control](governance/DOCUMENT_CONTROL.md)** để xem nguồn sở hữu và quy trình thay đổi. Bốn tài liệu quản lý chính: **[PRD](product/PRD.md)** (phạm vi/US), **[SRS](requirements/SRS.md)** (FR), **[NFR](requirements/NFR.md)** (quality/measurements), **[Architecture](architecture/ARCHITECTURE.md)** (module/ports). [Traceability Matrix](requirements/TRACEABILITY_MATRIX.md) liên kết yêu cầu → kiểm thử/evidence. [Input Specification 0.1.0 — DRAFT](specs/input/README.md) tiếp tục sở hữu raw/format/provenance/validation/import state; Core giữ semantic policy/comparison. ADR-001..009 đã được chốt ở mức engineering baseline, không là approval của giảng viên hoặc triển khai.

| Tài liệu / tài nguyên | Vai trò hiện hành |
| --- | --- |
| [Run Project — VS Code + Android Emulator CLI](guides/RUN_PROJECT.md) | Hướng dẫn macOS Apple Silicon không Android Studio/điện thoại ngoài; xử lý sdkmanager, AVD, Flutter run, APK; Web/Core riêng |
| [Document Control](governance/DOCUMENT_CONTROL.md) | Nguồn sở hữu, trạng thái, thứ tự xử lý xung đột, change control |
| [PRD](product/PRD.md) | Persona, outcome, phạm vi pha, US-01..12 và hành trình |
| [SRS](requirements/SRS.md) | FR-001..015, preconditions, expected system behavior |
| [NFR](requirements/NFR.md) | Quality goals, bảo mật, giới hạn bootstrap, cách đo và release gates |
| [Architecture](architecture/ARCHITECTURE.md) | Kiến trúc mục tiêu, module, ports và actual-vs-target gap |
| [Requirement Traceability](requirements/TRACEABILITY_MATRIX.md) | Quan hệ US–FR–INP/Core–Test–Evidence (chưa verified) |
| [Project Description](project/Project%20Description.md) | Đề bài, phạm vi giao học phần và baseline nền tảng; giữ rõ yêu cầu đọc ảnh |
| [ADR register P0](decisions/ADR_REGISTER_P0_2026-11-11.md) | 9 quyết định A/B, OCR, scope, budgets, header, identifier, XLSX, confirmation và retention |
| [Input index](specs/input/README.md) | Nguồn biên soạn Input; hướng dẫn ưu tiên/versioning/glossary/ADR |
| [Flutter Master 2.2 — Archive Reference](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md) | Snapshot lịch sử; PRD/SRS/NFR/Architecture không biên soạn song song ở Master |
| [Core semantic spec](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) | Canonicalization, policy và thuật toán; physical source types dẫn sang Input |
| [Policy v2 chuẩn](project/comparison_policy.v2.example.json) | Một bản để biên soạn tiếp; policy_version=2.1.0, không trộn ImportConfig |
| [Acceptance registry index](examples/README.md) | Tách semantic TC-* và Input INP-TC-* |
| [Build/release guide](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md) | Android/iOS signing và device gates |
| [Architecture diagrams](diagrams/README.md) | DOT/SVG cho pipeline Input; Architecture doc là nguồn cấu trúc toàn app |
| [Core PoC source](../packages/excelcompare_core/README.md) | Mã nguồn chính thức để phát triển tiếp; chưa đầy đủ adapter/provenance |
| [Branding](branding.md) | Nhận diện, không là capability registry |

Trong phạm vi Input, đọc quy tắc tại specs/input/ và wire shape cùng version tại schemas/. Xung đột Markdown/schema phải được sửa trước approval. **PRD sở hữu product scope; SRS sở hữu FR; NFR sở hữu quality; Architecture sở hữu cấu trúc phần mềm; Input sở hữu raw/wire; Core spec sở hữu semantic equivalence; ADR sở hữu quyết định đã chốt.** Master/Core source demo/ZIP trong bundle chỉ là snapshot lịch sử; Core semantic spec vẫn là nguồn thuật toán hiện hành. Không duy trì định nghĩa trùng ở Master.

Policy 2.1.0 được chọn từ bundle làm bản chuẩn tại project/. Bản bundle policy/acceptance giữ nguyên để audit, không là nguồn sửa song song. Nhận diện hiện hành dùng Dytava v2.0 tại branding/, web/assets/ và mobile/assets/.

`MANIFEST_SHA256.txt` được tạo lại cho các file tài liệu thực có (bỏ .obsidian và chính manifest). Bundle giữ SHA256SUMS.original.txt để tham chiếu nguồn. Kiểm tra từ docs-dytava bằng `shasum -a 256 -c MANIFEST_SHA256.txt`. Không suy ra chữ ký nguồn/phê duyệt từ checksum.
