# Test registry và ví dụ báo cáo

[acceptance_cases.json](acceptance_cases.json) là registry Semantic Comparison hiện hành cho các ca lịch sử TC-01–TC-10: decimal/identifier/null/boolean/date/percentage/money/text. Giữ nguyên IDs và expected behavior; đây là dữ liệu đặc tả, không tự là evidence tất cả dtype đã triển khai.

Input dùng [registry riêng](../specs/input/09_acceptance_tests.md), IDs INP-TC-001–040; không dùng lại TC-01 cho hành vi import. [Bản JSON Input](../specs/input/fixtures/acceptance_registry.json) là registry có thể kiểm tra bằng máy.

Bản acceptance_cases.json trong bundle Flutter tháng 11 có cùng nội dung registry semantic tại thời điểm tạo bundle; giữ như snapshot, không biên soạn song song. Khi sửa ca semantic, sửa file ở thư mục này và thêm evidence khi test runner thực thi. [report_example.json](report_example.json) là ví dụ output lịch sử, không phải Input schema.

Scope mới: [Report spec](../specs/report/README.md) định nghĩa merged diff PDF + Dytava template PDF và REP-TC-001..012; [Expanded acceptance](../testing/EXPANDED_SCOPE_ACCEPTANCE.md) định nghĩa LARGE-TC-001..008. Đây là registries PLANNED riêng, không đổi IDs/oracle Input và semantic cũ. `report_example.json` vẫn là snapshot lịch sử, không đủ làm contract/template PDF hiện hành; phải version hóa report/export schema trước triển khai.

Policy v2 dùng để biên soạn tiếp: [comparison_policy.v2.example.json](../project/comparison_policy.v2.example.json), policy_version=2.1.0 (thêm mapping/BOOLEAN passed so với 2.0.0 đã archive). Việc có policy ví dụ không chứng minh Core PoC có policy compiler.

[Renderer fixture mới](report-renderer/README.md) dùng schema report 1.0.0, hai CSV nhỏ có hashes thật và oracle bốn trạng thái; chạy `npm run report:render` để tạo PDF template Dytava.
