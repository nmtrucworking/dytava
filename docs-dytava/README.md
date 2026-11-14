# Dytava / ExcelCompare — chỉ mục tài liệu

> **Scope mở rộng 12/11/2026:** [EXP-ADR-001..003](decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) đưa **input tối đa 1 GB/source** và **hai PDF output** (diff hợp nhất A/B; báo cáo template Dytava) vào P0 mở rộng. Thay trần conservative 10 MiB và loại trừ PDF output trước đây; PDF input giữ pha riêng. Đây là yêu cầu thiết kế, chưa là capability runtime đã nghiệm thu.

> **Engineering scope baseline 11/11/2026:** [9 ADR được chốt](decisions/ADR_REGISTER_P0_2026-11-11.md) điều chỉnh Android P0 thành XLSX/CSV/TSV + OCR một nguồn ảnh PNG/JPEG có review. JSON/iOS chuyển P1. Đây là quyết định thiết kế, chưa phải evidence ứng dụng đã đạt P0.

Baseline nền tảng là **Flutter/Dart, Android P0 → iOS P1**; ưu tiên tính năng P0 đã được cập nhật bằng ADR register ngày 11/11/2026, ghi đè những phần roadmap Master 2.2 không còn phù hợp. Repository có Web/server riêng và Pure Dart core PoC; phạm vi thiết kế không là danh sách tính năng đã đạt kiểm thử.

**Thuật toán chính (13/11/2026): DYTAVA_UDG_v3, hoàn thiện thành [đặc tả UDG3.1 theo 11 layer](specs/engine/README.md).** [30/30 gaps đã có hợp đồng và acceptance](testing/UDG_CONTRACT_ACCEPTANCE.md), kèm [resource/benchmark contract](requirements/RESOURCE_PROFILES.md). Đây là baseline docs DRAFT, chưa đọc/sửa mã triển khai hoặc chạy benchmark. [Review v3 ban đầu](project/DYTAVA_UDG_v3/LAYERED_SPEC_REVIEW.md) giữ để audit, không là backlog OPEN hiện hành.

[Baseline bàn giao docs3.1](governance/SPECIFICATION_BASELINE_3_1.md) tổng hợp deliverables, compatibility và phần còn chờ implementation/evidence.

**Bắt đầu tại [Document Control](governance/DOCUMENT_CONTROL.md)** để xem nguồn sở hữu và quy trình thay đổi. Bốn tài liệu quản lý chính: **[PRD](product/PRD.md)** (phạm vi/US), **[SRS](requirements/SRS.md)** (FR), **[NFR](requirements/NFR.md)** (quality/measurements), **[Architecture](architecture/ARCHITECTURE.md)** (module/ports). [Traceability Matrix](requirements/TRACEABILITY_MATRIX.md) liên kết yêu cầu → kiểm thử/evidence. [Input contracts — docs0.2 / schemas0.1 DRAFT](specs/input/README.md) tiếp tục sở hữu raw/format/provenance/validation/import state; Core giữ semantic policy/comparison. ADR-001..009 đã được chốt ở mức engineering baseline, không là approval của giảng viên hoặc triển khai.

| Tài liệu / tài nguyên | Vai trò hiện hành |
| --- | --- |
| [Run Project — VS Code + Android Emulator CLI](guides/RUN_PROJECT.md) | Hướng dẫn macOS Apple Silicon không Android Studio/điện thoại ngoài; xử lý sdkmanager, AVD, Flutter run, APK; Web/Core riêng |
| [Document Control](governance/DOCUMENT_CONTROL.md) | Nguồn sở hữu, trạng thái, thứ tự xử lý xung đột, change control |
| [PRD](product/PRD.md) | Persona, outcome, phạm vi pha, US-01..15 và hành trình |
| [SRS](requirements/SRS.md) | FR-001..018, preconditions, expected system behavior |
| [Business Requirements & Workflows](requirements/BUSINESS_REQUIREMENTS.md) | DYT-BRD-001 (DRAFT): quy trình nghiệp vụ, điểm kiểm soát BIZ-* và kịch bản nghiệm thu; không thay PRD/SRS |
| [UI/UX Interaction & Screen Specification](design/UI_UX_SPEC.md) | DYT-UX-001 (DRAFT): luồng 10 màn hình SCR-*, interaction states, UX-TC-*; chưa phải evidence UI đã triển khai |
| [NFR](requirements/NFR.md) | Quality goals, bảo mật, giới hạn bootstrap, cách đo và release gates |
| [Architecture](architecture/ARCHITECTURE.md) | Kiến trúc mục tiêu, module, ports và actual-vs-target gap |
| [Requirement Traceability](requirements/TRACEABILITY_MATRIX.md) | Quan hệ US–FR–INP/Core–Test–Evidence (chưa verified) |
| [Scope expansion 12/11](decisions/ADR_SCOPE_EXPANSION_2026-11-12.md) | Precedence cho 1 GB/source và hai PDF; baseline implementation chưa đạt |
| [Report Export Specification](specs/report/README.md) | Merged diff PDF, template Dytava 1.0.0, output manifest/lifecycle và REP-TC-* |
| [Template renderer Web/CLI](specs/report/RENDERER.md) | Template Dytava 1.0.0, report schema, mẫu PDF và phạm vi implementation hiện tại |
| [Expanded-scope acceptance](testing/EXPANDED_SCOPE_ACCEPTANCE.md) | LARGE-TC-*, corpus 1 GB, memory/disk/EOF và PDF evidence gates |
| [Project Description](project/Project%20Description.md) | Đề bài, phạm vi giao học phần và baseline nền tảng; giữ rõ yêu cầu đọc ảnh |
| [ADR register P0](decisions/ADR_REGISTER_P0_2026-11-11.md) | 9 quyết định A/B, OCR, scope, budgets, header, identifier, XLSX, confirmation và retention |
| [Input index](specs/input/README.md) | Nguồn biên soạn Input; hướng dẫn ưu tiên/versioning/glossary/ADR |
| [Flutter Master 2.2 — Archive Reference](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md) | Snapshot lịch sử; PRD/SRS/NFR/Architecture không biên soạn song song ở Master |
| [UDG3.1 — đặc tả thuật toán theo layer](specs/engine/README.md) | Execution plan, geometry, canonical/index/alignment, verdict/result/runtime/query/export; DRAFT, chưa runtime verified |
| [Gap resolution / UDG-TC-001..020](testing/UDG_CONTRACT_ACCEPTANCE.md) | 30/30 gap dispositions, golden examples, expected behavior và planned acceptance |
| [Resource profiles RP-1](requirements/RESOURCE_PROFILES.md) | Dimensions/budget equations, calibration/enable gates, benchmark/evidence protocol; chưa có enabled device profile |
| [Core semantic spec](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) | Contract canonicalization, policy, bốn kết luận và key semantics mà UDG v3 phải tuân thủ; physical source types dẫn sang Input |
| [Policy v2 chuẩn](project/comparison_policy.v2.example.json) | Một bản để biên soạn tiếp; policy_version=2.1.0, không trộn ImportConfig |
| [Acceptance registry index](examples/README.md) | Tách semantic TC-* và Input INP-TC-* |
| [Build/release guide](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md) | Android/iOS signing và device gates |
| [Architecture diagrams](diagrams/README.md) | DOT/SVG cho pipeline Input; Architecture doc là nguồn cấu trúc toàn app |
| [Core PoC source](../packages/excelcompare_core/README.md) | Mã nguồn chính thức để phát triển tiếp; chưa đầy đủ adapter/provenance |
| [Branding](branding.md) | Nhận diện, không là capability registry |

Trong phạm vi Input, đọc quy tắc tại specs/input/ và wire shape cùng version tại schemas/. Xung đột cùng version phải sửa trước approval; [ISC-1/target Input0.2](specs/input/11_streaming_snapshot_contract.md) là contract thiết kế mới, chưa có executable schema thay0.1. **PRD sở hữu product scope; SRS sở hữu FR; NFR/RP-1 sở hữu quality/budgets; Architecture sở hữu cấu trúc phần mềm; Input sở hữu raw/wire; UDG3.1 sở hữu execution tổng thể; Core/CE-1/decision tables sở hữu semantic equivalence; Report/EX-1 sở hữu presentation/export; ADR sở hữu quyết định đã chốt.** Master/source demo/ZIP và v3 gốc là snapshot lịch sử; không dùng chúng ghi đè contracts hiện hành.

Policy 2.1.0 được chọn từ bundle làm bản chuẩn tại project/. Bản bundle policy/acceptance giữ nguyên để audit, không là nguồn sửa song song. Nhận diện hiện hành dùng Dytava v2.0 tại branding/, web/assets/ và mobile/assets/.

`MANIFEST_SHA256.txt` được tạo lại cho các file tài liệu thực có (bỏ .obsidian và chính manifest). Bundle giữ SHA256SUMS.original.txt để tham chiếu nguồn. Kiểm tra từ docs-dytava bằng `shasum -a 256 -c MANIFEST_SHA256.txt`. Không suy ra chữ ký nguồn/phê duyệt từ checksum.
