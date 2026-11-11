# Test registry và ví dụ báo cáo

[acceptance_cases.json](acceptance_cases.json) là registry Semantic Comparison hiện hành cho các ca lịch sử TC-01–TC-10: decimal/identifier/null/boolean/date/percentage/money/text. Giữ nguyên IDs và expected behavior; đây là dữ liệu đặc tả, không tự là evidence tất cả dtype đã triển khai.

Input dùng [registry riêng](../specs/input/09_acceptance_tests.md), IDs INP-TC-001–040; không dùng lại TC-01 cho hành vi import. [Bản JSON Input](../specs/input/fixtures/acceptance_registry.json) là registry có thể kiểm tra bằng máy.

Bản acceptance_cases.json trong bundle Flutter tháng 11 có cùng nội dung registry semantic tại thời điểm tạo bundle; giữ như snapshot, không biên soạn song song. Khi sửa ca semantic, sửa file ở thư mục này và thêm evidence khi test runner thực thi. [report_example.json](report_example.json) là ví dụ output lịch sử, không phải Input schema.

Policy v2 dùng để biên soạn tiếp: [comparison_policy.v2.example.json](../project/comparison_policy.v2.example.json), policy_version=2.1.0 (thêm mapping/BOOLEAN passed so với 2.0.0 đã archive). Việc có policy ví dụ không chứng minh Core PoC có policy compiler.
