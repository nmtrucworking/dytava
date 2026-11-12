# Renderer fixtures

`report.json` dùng contract `dytava-report/1.0.0` với oracle được biên soạn từ
`source-a.csv` và `source-b.csv`, SHA-256 và byte sizes khớp tệp thật.
Các fixture là dữ liệu minh họa, không chứa dữ liệu người dùng; parser/engine version
`fixture-authoring`/`fixture-oracle` ghi rõ đây không phải kết quả parser đã chạy.
Hai matched records so sánh hai mapped fields (Giá trị, Ghi chú); ID dùng làm key.
Có đủ bốn cell statuses, một ROW_ADDED và một ROW_REMOVED; tổng matched_cell_pairs=4.

Chạy `npm run report:render` ở gốc repo. Hướng dẫn tại
[renderer](../../specs/report/RENDERER.md); oracle cũ `../report_example.json` vẫn là
snapshot lịch sử, không thay fixture renderer mới.
