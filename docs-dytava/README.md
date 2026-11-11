# Dytava / ExcelCompare — chỉ mục tài liệu

Baseline thiết kế hiện hành: **Flutter/Dart, Android P0 → iOS P1**, theo Master 2.2 ngày 11/11/2026. Repository có Web/server riêng và Pure Dart core PoC; phạm vi thiết kế không là danh sách tính năng đã đạt kiểm thử.

Bắt đầu tại **[Input Specification 0.1.0 — DRAFT](specs/input/README.md)**: 10 tài liệu chuyên đề, 5 JSON Schema, fixtures và contract verifier. Input sở hữu nguồn/định dạng/cấu trúc/raw types/provenance/config/validation/import states; Core giữ normalization, policy compiler và comparison. Những quyết định sản phẩm còn mở được ghi tại decision register, chưa được mặc định là phê duyệt.

| Tài liệu / tài nguyên | Vai trò hiện hành |
| --- | --- |
| [Project Description](project/Project%20Description.md) | Đề bài, phạm vi giao học phần và baseline nền tảng; giữ rõ yêu cầu đọc ảnh |
| [Input index](specs/input/README.md) | Nguồn biên soạn Input; hướng dẫn ưu tiên/versioning/glossary/ADR |
| [Flutter Master 2.2](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md) | Kiến trúc/lộ trình/release; tóm tắt và dẫn sang Input |
| [Core semantic spec](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md) | Canonicalization, policy và thuật toán; physical source types dẫn sang Input |
| [Policy v2 chuẩn](project/comparison_policy.v2.example.json) | Một bản để biên soạn tiếp; policy_version=2.1.0, không trộn ImportConfig |
| [Acceptance registry index](examples/README.md) | Tách semantic TC-* và Input INP-TC-* |
| [Build/release guide](project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/ANDROID_IOS_BUILD_RELEASE_GUIDE.md) | Android/iOS signing và device gates |
| [Kiến trúc hiện hành](diagrams/README.md) | FileAccess → Preflight → FormatAdapter → SourceTable; ranh giới Core |
| [Core PoC source](../packages/excelcompare_core/README.md) | Mã nguồn chính thức để phát triển tiếp; chưa đầy đủ adapter/provenance |
| [Branding](branding.md) | Nhận diện, không là capability registry |

Trong phạm vi Input, đọc quy tắc tại specs/input/ và wire shape cùng version tại schemas/. Xung đột Markdown/schema phải được sửa trước approval. Master/Core vẫn có quyền trong phần kiến trúc/semantic riêng; không duy trì chi tiết Input đầy đủ ở hai nơi. Markdown Master/Core là nguồn hiện hành; source demo/ZIP trong bundle là snapshot tham khảo.

Policy 2.1.0 được chọn từ bundle làm bản chuẩn tại project/. Bản bundle policy/acceptance giữ nguyên để audit, không là nguồn sửa song song. Nhận diện hiện hành dùng Dytava v2.0 tại branding/, web/assets/ và mobile/assets/.

`MANIFEST_SHA256.txt` được tạo lại cho các file tài liệu thực có (bỏ .obsidian và chính manifest). Bundle giữ SHA256SUMS.original.txt để tham chiếu nguồn. Kiểm tra từ docs-dytava bằng `shasum -a 256 -c MANIFEST_SHA256.txt`. Không suy ra chữ ký nguồn/phê duyệt từ checksum.
